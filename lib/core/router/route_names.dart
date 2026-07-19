abstract final class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const onboarding = '/onboarding';
  static const register = '/register';
  static const schedule = '/schedule';
  static const home = '/';
  static const trucks = '/trucks';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/settings';
  static const truckDetail = '/truck/:id';
  static const waterDelivery = '/water-delivery/:truckId';

  // ── Driver-facing routes ──────────────────────────────────────────────
  static const driverRegister = '/driver/register';
  static const driverSchedule = '/driver/schedule';
  static const driverRouteMap = '/driver/map/:routeId';
  static const driverSettings = '/driver/settings';

  // ── Organization-facing routes ─────────────────────────────────────────
  // Deliberately NOT nested under the resident/driver auth flow — the
  // Organization role has its own dedicated sign-in screen and is never
  // reachable through the resident/driver sign-up form. See app_router.dart.
  static const orgLogin = '/org/login';
  static const orgDashboard = '/org';
  static const orgDrivers = '/org/drivers';
  static const orgResidents = '/org/residents';
  static const orgTrucks = '/org/trucks';
  static const orgSchedule = '/org/schedule';
  static const orgNotifications = '/org/notifications';
  static const orgLiveMonitoring = '/org/live';
  static const orgAreas = '/org/areas';
  static const orgReports = '/org/reports';
  static const orgSettings = '/org/settings';

  static String truckDetailOf(String id) => '/truck/$id';
  static String waterDeliveryOf(String truckId) => '/water-delivery/$truckId';
  static String driverRouteMapOf(String routeId) => '/driver/map/$routeId';
}
