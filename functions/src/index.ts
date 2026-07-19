import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

/**
 * AquaPath role model: a Firebase Auth custom claim `role` is the single
 * source of truth for authorization everywhere in the app (router
 * guards, Firestore rules). This file is the only place that claim is
 * ever set — never trust a client-writable Firestore field for it.
 */

// ── resident / driver claims: set automatically on profile creation ────
//
// A client can create their own `households/{uid}` or `drivers/{uid}`
// document (Firestore rules require request.auth.uid == uid), but only
// this trigger — running with Admin SDK privileges — can turn that into
// an actual authorization claim. This is deliberate: it means "have a
// household doc" and "are authorized as a resident" are two different
// facts that happen to usually coincide, not the same fact, closing the
// gap the pre-migration code had (role derived by re-reading Firestore
// on every navigation, with no real claim behind it at all).

export const onHouseholdCreated = onDocumentCreated(
  "households/{uid}",
  async (event) => {
    const uid = event.params.uid as string;
    await applyRoleClaim(uid, "resident");
  }
);

export const onDriverProfileCreated = onDocumentCreated(
  "drivers/{uid}",
  async (event) => {
    const uid = event.params.uid as string;
    await applyRoleClaim(uid, "driver");
  }
);

async function applyRoleClaim(uid: string, role: "resident" | "driver") {
  const user = await auth.getUser(uid).catch(() => null);
  if (!user) return;

  // Never downgrade/overwrite an existing role claim — most relevantly,
  // never let a resident/driver document creation clobber an
  // `organization` claim. This should not be reachable in practice
  // (organization accounts have no client path to create a household or
  // driver doc), but the check costs nothing and removes the failure
  // mode entirely rather than relying on that being true forever.
  const existingRole = (user.customClaims ?? {})["role"];
  if (existingRole === "organization") return;
  if (existingRole === role) return;

  await auth.setCustomUserClaims(uid, { role });
}

// ── organization accounts: no self-service path ────────────────────────
//
// Only an already-authenticated organization account may call this. It
// creates a brand-new Firebase Auth user, sets the `organization` claim
// directly (skipping the create-a-profile-doc-first flow residents/
// drivers use), and writes the `organizations/{uid}` profile document.
//
// Bootstrapping problem: the very first organization account has no
// existing organization account to invoke this on its behalf. That
// account must be created once, manually, with the Firebase Admin SDK /
// CLI (`firebase auth:import` or a one-off script calling
// `admin.auth().setCustomUserClaims(uid, { role: 'organization' })`) —
// intentionally outside the app's normal request flow, and outside the
// scope of what a Cloud Function can safely automate.
export const createOrganizationUser = onCall(async (request) => {
  if (request.auth?.token?.role !== "organization") {
    throw new HttpsError(
      "permission-denied",
      "Only an existing organization account can create another one."
    );
  }

  const { email, password, orgName, contactPhone } = request.data as {
    email?: string;
    password?: string;
    orgName?: string;
    contactPhone?: string;
  };

  if (!email || !password || !orgName) {
    throw new HttpsError(
      "invalid-argument",
      "email, password, and orgName are required."
    );
  }

  const newUser = await auth.createUser({ email, password });
  await auth.setCustomUserClaims(newUser.uid, { role: "organization" });

  await db.collection("organizations").doc(newUser.uid).set({
    orgName,
    contactEmail: email,
    contactPhone: contactPhone ?? "",
    createdAt: new Date().toISOString(),
    createdBy: request.auth!.uid,
  });

  return { uid: newUser.uid };
});

// ── driver activation/deactivation ──────────────────────────────────────
//
// Pairs with OrganizationFirebaseSource.setDriverStatus, which only
// updates the Firestore-visible `status` field. This callable is what
// actually locks a deactivated driver out of Firebase Auth itself —
// without it, "deactivated" would only be a display state a disabled
// driver could still ignore by staying signed in.
export const setDriverStatus = onCall(async (request) => {
  if (request.auth?.token?.role !== "organization") {
    throw new HttpsError(
      "permission-denied",
      "Only an organization account can change driver status."
    );
  }

  const { driverUid, active } = request.data as {
    driverUid?: string;
    active?: boolean;
  };

  if (!driverUid || typeof active !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "driverUid and active are required."
    );
  }

  await auth.updateUser(driverUid, { disabled: !active });
  await db.collection("drivers").doc(driverUid).update({
    status: active ? "active" : "inactive",
  });

  return { ok: true };
});

// ── resident delivery notifications ─────────────────────────────────────
//
// The app already subscribes residents to an FCM topic keyed by their
// registered area (`area_<sanitized-name>` — see
// notification_prefs_provider.dart / push_notification_service.dart), so
// notifying everyone in an area on delivery confirmation is a topic
// publish, not a per-token fan-out.
export const onDeliveryConfirmed = onDocumentCreated(
  "water_deliveries/{deliveryId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const areaName = (data["areaName"] as string) ?? "";
    const amount = (data["amountLiters"] as number) ?? 0;
    if (!areaName) return;

    const topic = `area_${sanitizeTopic(areaName)}`;

    await messaging.send({
      topic,
      notification: {
        title: "وصلت شاحنة المياه",
        body: `تم تسجيل توزيع ${amount} لتر في منطقتك`,
      },
      data: {
        type: "delivery_confirmed",
        areaName,
        deliveryId: event.params.deliveryId as string,
      },
    });
  }
);

// Must exactly mirror `PushNotificationService.topicSuffixFor` in
// push_notification_service.dart — hex-encodes each UTF-16 code unit so
// Arabic area names produce a deterministic, FCM-topic-valid string.
// Any divergence between the two silently breaks delivery notifications.
function sanitizeTopic(raw: string): string {
  const normalized = raw.trim();
  let out = "";
  for (let i = 0; i < normalized.length; i++) {
    out += normalized.charCodeAt(i).toString(16).padStart(4, "0");
  }
  return out;
}

// ── Organization-authored notifications ─────────────────────────────────
//
// An organization writes `notifications/{id}` (Firestore rules restrict
// that create to the organization role — see firestore.rules); this
// trigger is what actually turns that document into a push. Scoped to a
// single area's topic if `areaName` is set, or fanned out to every
// registered area's topic for a general broadcast — there's no single
// "all users" topic, since residents only ever subscribe to their own
// area's topic (see notification_prefs_provider.dart).
export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title = (data["title"] as string) ?? "";
    const body = (data["body"] as string) ?? "";
    const areaName = data["areaName"] as string | undefined;
    if (!title && !body) return;

    if (areaName) {
      await messaging.send({
        topic: `area_${sanitizeTopic(areaName)}`,
        notification: { title, body },
        data: { type: "org_broadcast", notificationId: event.params.notificationId as string },
      });
      return;
    }

    // Broadcast: one send per registered area topic. Areas are a small,
    // organization-managed collection (dozens, not thousands), so a
    // sequential loop here is fine — no need for batching infrastructure
    // at this scale.
    const areasSnapshot = await db.collection("areas").get();
    await Promise.all(
      areasSnapshot.docs.map((areaDoc) => {
        const name = areaDoc.data()["name"] as string | undefined;
        if (!name) return Promise.resolve();
        return messaging.send({
          topic: `area_${sanitizeTopic(name)}`,
          notification: { title, body },
          data: { type: "org_broadcast", notificationId: event.params.notificationId as string },
        });
      })
    );
  }
);
