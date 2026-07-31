import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/driver/domain/repositories/driver_repository.dart';
import '../../features/driver/presentation/driver_register_screen.dart';
import '../../features/driver/presentation/driver_route_map_screen.dart';
import '../../features/driver/presentation/driver_schedule_screen.dart';
import '../../features/driver/presentation/driver_settings_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/organization/presentation/area_management_screen.dart';
import '../../features/organization/presentation/driver_management_screen.dart';
import '../../features/organization/presentation/live_monitoring_screen.dart';
import '../../features/organization/presentation/notification_center_screen.dart';
import '../../features/organization/presentation/org_dashboard_screen.dart';
import '../../features/organization/presentation/org_login_screen.dart';
import '../../features/organization/presentation/org_settings_screen.dart';
import '../../features/organization/presentation/reports_screen.dart';
import '../../features/organization/presentation/resident_management_screen.dart';
import '../../features/organization/presentation/schedule_management_screen.dart';
import '../../features/organization/presentation/truck_management_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/truck_detail/presentation/truck_detail_screen.dart';
import '../../features/trucks/presentation/trucks_list_screen.dart';
import '../../features/water_delivery/presentation/water_delivery_screen.dart';
import '../auth/user_role.dart';
import '../security/secure_storage_service.dart';
import 'go_router_refresh_stream.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = GetIt.I<AuthRepository>();
  final driverRepo = GetIt.I<DriverRepository>();
  final storage = GetIt.I<SecureStorageService>();

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: false,

    // Re-run `redirect` the instant sign-in/sign-out happens, without
    // waiting for the next user-initiated navigation.
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),

    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final onSplash = loc == RouteNames.splash;
      final onAuthScreen = loc == RouteNames.login || loc == RouteNames.signup;
      final onOrgLoginScreen = loc == RouteNames.orgLogin;
      final onDriverScreen = loc.startsWith('/driver/');
      final onOrgScreen = loc.startsWith('/org') && !onOrgLoginScreen;

      // Splash owns its own navigation timing (brand moment + async
      // checks) — don't fight it on the very first frame.
      if (onSplash) return null;

      final isAuthed = authRepo.currentUser != null;

      // Signed out: only the three "front door" screens are reachable.
      // Organization has its own dedicated door and is never offered the
      // resident/driver login — this is a deliberate separation, not an
      // oversight.
      if (!isAuthed) {
        if (onAuthScreen || onOrgLoginScreen) return null;
        return onOrgScreen ? RouteNames.orgLogin : RouteNames.login;
      }

      // Role is read from the cached ID-token claim — a local decode, not
      // a Firestore round trip — so it's cheap to check on every redirect.
      // It legitimately can be null for a few seconds right after
      // sign-up while the claim-setting Cloud Function runs; the
      // sign-up/driver-registration flows already await
      // `waitForRoleClaim()` before navigating away, so by the time the
      // router sees the new auth state the claim is normally already
      // present. The `pendingAccountRole` / `isDriver` fallbacks below
      // exist only to cover that narrow race and pre-migration accounts.
      var role = await authRepo.getCurrentRole();

      // ── Signed in, sitting on the resident/driver auth screens ───────
      if (onAuthScreen) {
        role ??= await _resolveRoleFallback(authRepo, driverRepo, storage);

        if (role == UserRole.organization) {
          // An organization credential should never reach this screen in
          // practice (separate login door), but fail safe rather than
          // dropping them into the resident/driver app if it ever does.
          return RouteNames.orgDashboard;
        }
        if (role == UserRole.driver) {
          return RouteNames.driverSchedule;
        }
        if (role == UserRole.resident) {
          final onboardingDone = await storage.isOnboardingComplete;
          if (!onboardingDone) return RouteNames.onboarding;
          final registrationDone = await storage.isRegistrationComplete;
          if (!registrationDone) return RouteNames.register;
          return RouteNames.home;
        }

        // Brand-new sign-up, claim not resolved yet by any signal — fall
        // back to whichever profile-completion screen matches the choice
        // made on the sign-up form.
        final pendingRole = await storage.pendingAccountRole;
        if (pendingRole == 'driver') return RouteNames.driverRegister;
        final onboardingDone = await storage.isOnboardingComplete;
        if (!onboardingDone) return RouteNames.onboarding;
        final registrationDone = await storage.isRegistrationComplete;
        if (!registrationDone) return RouteNames.register;
        return RouteNames.home;
      }

      // ── Signed in, sitting on the organization login screen ──────────
      if (onOrgLoginScreen) {
        if (role == UserRole.organization) return RouteNames.orgDashboard;
        // A resident/driver credential that ends up here is denied — the
        // Organization door does not fall through to the regular app.
        return RouteNames.orgLogin;
      }

      // ── Route guards: deny access when the claim doesn't match ───────
      //
      // `role` above came from the cheap cached-token read — which can be
      // null not only right after sign-up, but also on a cold restart if
      // the locally persisted ID token predates a role claim that was
      // already granted (e.g. a driver's claim was set last session, but
      // the token cached on disk is the pre-claim one). Evicting someone
      // out of a role-scoped area on a merely-unresolved role — rather
      // than a CONFIRMED mismatch — is exactly how a real driver used to
      // get silently bounced into the resident shell on cold start. Every
      // eviction below now re-resolves an unresolved role authoritatively
      // (forced token refresh, then the pre-migration Firestore signal)
      // before deciding, instead of defaulting straight to "not this
      // role".
      if (onOrgScreen && role != UserRole.organization) {
        role ??= await _resolveRoleFallback(authRepo, driverRepo, storage);
        if (role != UserRole.organization) {
          return RouteNames.orgLogin;
        }
      }
      if (onDriverScreen) {
        final onDriverRegisterScreen = loc == RouteNames.driverRegister;
        // A signed-in user with no role claim yet is, by definition,
        // exactly who /driver/register exists for — a resident or
        // organization account is never in that state (they already
        // have a claim), so `role == null` here only ever means "brand
        // new driver sign-up, hasn't submitted the registration form
        // yet". Blocking this case (as an earlier version of this guard
        // did) made it impossible for a new driver to ever reach their
        // own registration screen: GoRouter re-evaluates `redirect` on
        // the resolved location too, so the redirect-to-driverRegister
        // above would immediately be followed by this guard bouncing
        // them straight back out. Only try to resolve the ambiguity when
        // it's NOT that brand-new-signup case.
        if (role == null && !onDriverRegisterScreen) {
          role = await _resolveRoleFallback(authRepo, driverRepo, storage);
        }
        final isNewDriverCompletingRegistration =
            role == null && onDriverRegisterScreen;
        if (role != UserRole.driver && !isNewDriverCompletingRegistration) {
          return role == UserRole.organization
              ? RouteNames.orgDashboard
              : RouteNames.home;
        }
      }
      if (!onOrgScreen && !onDriverScreen) {
        // Resident-facing shell: keep organization/driver accounts out of
        // it entirely, even via a stale deep link.
        if (role == UserRole.organization) return RouteNames.orgDashboard;
        if (role == UserRole.driver) return RouteNames.driverSchedule;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        name: 'signup',
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        name: 'register',
        builder: (_, __) => const RegistrationScreen(),
      ),
      GoRoute(
        path: RouteNames.schedule,
        name: 'schedule',
        builder: (_, __) => const ScheduleScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/truck/:id',
        name: 'truckDetail',
        builder: (_, state) => TruckDetailScreen(
          truckId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/water-delivery/:truckId',
        name: 'waterDelivery',
        builder: (_, state) => WaterDeliveryScreen(
          truckId: state.pathParameters['truckId'] ?? '',
        ),
      ),

      // ── Driver-facing routes ─────────────────────────────────────────
      GoRoute(
        path: RouteNames.driverRegister,
        name: 'driverRegister',
        builder: (_, __) => const DriverRegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.driverSchedule,
        name: 'driverSchedule',
        builder: (_, __) => const DriverScheduleScreen(),
      ),
      GoRoute(
        path: RouteNames.driverRouteMap,
        name: 'driverRouteMap',
        builder: (_, state) => DriverRouteMapScreen(
          routeId: state.pathParameters['routeId'] ?? '',
        ),
      ),
      GoRoute(
        path: RouteNames.driverSettings,
        name: 'driverSettings',
        builder: (_, __) => const DriverSettingsScreen(),
      ),

      // ── Organization-facing routes ────────────────────────────────────
      GoRoute(
        path: RouteNames.orgLogin,
        name: 'orgLogin',
        builder: (_, __) => const OrgLoginScreen(),
      ),
      GoRoute(
        path: RouteNames.orgDashboard,
        name: 'orgDashboard',
        builder: (_, __) => const OrgDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.orgDrivers,
        name: 'orgDrivers',
        builder: (_, __) => const OrgDriverManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orgAreas,
        name: 'orgAreas',
        builder: (_, __) => const OrgAreaManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orgResidents,
        name: 'orgResidents',
        builder: (_, __) => const OrgResidentManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orgTrucks,
        name: 'orgTrucks',
        builder: (_, __) => const OrgTruckManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orgSchedule,
        name: 'orgSchedule',
        builder: (_, __) => const OrgScheduleManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orgNotifications,
        name: 'orgNotifications',
        builder: (_, __) => const OrgNotificationCenterScreen(),
      ),
      GoRoute(
        path: RouteNames.orgLiveMonitoring,
        name: 'orgLiveMonitoring',
        builder: (_, __) => const OrgLiveMonitoringScreen(),
      ),
      GoRoute(
        path: RouteNames.orgReports,
        name: 'orgReports',
        builder: (_, __) => const OrgReportsScreen(),
      ),
      GoRoute(
        path: RouteNames.orgSettings,
        name: 'orgSettings',
        builder: (_, __) => const OrgSettingsScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: 'home',
                builder: (_, __) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.trucks,
                name: 'trucks',
                builder: (_, __) => const TrucksListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.notifications,
                name: 'notifications',
                builder: (_, __) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                name: 'profile',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Resolves a signed-in user's role when the cheap cached-claim read came
/// back null — covering both the narrow window right after sign-up (claim
/// not yet visible) and a cold-started session whose locally persisted ID
/// token predates a role claim that was already granted.
///
/// Tries, in order:
///  1. A forced ID-token refresh — one network round trip, but
///     authoritative, and directly resolves the stale-cached-token case.
///  2. The pre-migration Firestore `drivers/{uid}` existence check, for
///     accounts created before the custom-claims migration and therefore
///     never carrying a `driver` claim at all.
///  3. `pendingAccountRole`, set locally at sign-up time before the claim
///     exists anywhere yet.
Future<UserRole?> _resolveRoleFallback(
  AuthRepository authRepo,
  DriverRepository driverRepo,
  SecureStorageService storage,
) async {
  final uid = authRepo.currentUser?.uid;
  if (uid == null) return null;
  final refreshed = await authRepo.refreshRoleClaim();
  if (refreshed != null) return refreshed;
  if (await driverRepo.isDriver(uid)) return UserRole.driver;
  final pendingRole = await storage.pendingAccountRole;
  if (pendingRole == 'resident') return UserRole.resident;
  return null;
}
