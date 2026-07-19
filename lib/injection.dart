import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'core/network/connectivity_service.dart';
import 'core/offline/offline_write_queue_service.dart';
import 'core/network/firebase_service.dart';
import 'core/security/secure_storage_service.dart';
import 'features/auth/data/datasources/firebase_auth_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/driver/data/datasources/driver_firebase_source.dart';
import 'features/driver/data/repositories/driver_repository_impl.dart';
import 'features/driver/domain/repositories/driver_repository.dart';
import 'features/notifications/data/datasources/notification_history_firebase_source.dart';
import 'features/notifications/data/repositories/notification_history_repository_impl.dart';
import 'features/notifications/domain/repositories/notification_history_repository.dart';
import 'features/organization/data/datasources/organization_firebase_source.dart';
import 'features/organization/data/repositories/organization_repository_impl.dart';
import 'features/organization/domain/repositories/organization_repository.dart';
import 'features/parking/data/datasources/parking_spot_firebase_source.dart';
import 'features/parking/data/repositories/parking_spot_repository_impl.dart';
import 'features/parking/domain/repositories/parking_spot_repository.dart';
import 'features/registration/data/datasources/household_firebase_source.dart';
import 'features/registration/data/repositories/household_repository_impl.dart';
import 'features/registration/domain/repositories/household_repository.dart';
import 'features/trucks/data/datasources/truck_firebase_source.dart';
import 'features/trucks/data/datasources/truck_local_source.dart';
import 'features/trucks/data/repositories/truck_repository_impl.dart';
import 'features/trucks/domain/repositories/truck_repository.dart';
import 'features/water_delivery/data/datasources/water_delivery_firebase_source.dart';
import 'features/water_delivery/data/repositories/water_delivery_repository_impl.dart';
import 'features/water_delivery/domain/repositories/water_delivery_repository.dart';
import 'shared/services/eta_service.dart';
import 'shared/services/location_service.dart';
import 'shared/services/priority_service.dart';
import 'shared/services/push_notification_service.dart';
import 'shared/services/report_export_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ── Firebase ──────────────────────────────────────────────────────────
  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );
  getIt.registerLazySingleton<FirebaseAuth>(
    // Arabic-localized transactional emails (password reset, etc.) —
    // Firebase ships built-in Arabic templates for these, so this is all
    // that's needed client-side; no custom Console template required.
    () => FirebaseAuth.instance..setLanguageCode('ar'),
  );

  // ── Hive Boxes ────────────────────────────────────────────────────────
  getIt.registerLazySingleton<Box<String>>(
    () => Hive.box<String>('truckCache'),
    instanceName: 'truckCache',
  );
  getIt.registerLazySingleton<Box<String>>(
    () => Hive.box<String>('settings'),
    instanceName: 'settings',
  );
  getIt.registerLazySingleton<Box<dynamic>>(
    () => Hive.box<dynamic>('householdData'),
    instanceName: 'householdData',
  );
  getIt.registerLazySingleton<Box<String>>(
    () => Hive.box<String>('offlineQueue'),
    instanceName: 'offlineQueue',
  );

  // ── Security ──────────────────────────────────────────────────────────
  getIt.registerLazySingleton<SecureStorageService>(
    SecureStorageService.new,
  );

  // ── Core Services ─────────────────────────────────────────────────────
  getIt.registerLazySingleton<FirebaseService>(
    () => FirebaseService(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<ConnectivityService>(
    ConnectivityService.new,
  );
  getIt.registerLazySingleton<EtaService>(EtaService.new);
  getIt.registerLazySingleton<PriorityService>(PriorityService.new);
  getIt.registerLazySingleton<LocationService>(LocationService.new);
  getIt.registerLazySingleton<OfflineWriteQueueService>(
    () => OfflineWriteQueueService(
      getIt<Box<String>>(instanceName: 'offlineQueue'),
      getIt<FirebaseFirestore>(),
    ),
  );
  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(
      getIt<SecureStorageService>(),
      getIt<NotificationHistoryRepository>(),
      getIt<AuthRepository>(),
    ),
  );
  getIt.registerLazySingleton<ReportExportService>(ReportExportService.new);

  // ── Data Sources ──────────────────────────────────────────────────────
  getIt.registerLazySingleton<TruckFirebaseSource>(
    () => TruckFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<TruckLocalSource>(
    () => TruckLocalSource(
      getIt<Box<String>>(instanceName: 'truckCache'),
    ),
  );
  getIt.registerLazySingleton<FirebaseAuthSource>(
    () => FirebaseAuthSource(getIt<FirebaseAuth>()),
  );
  getIt.registerLazySingleton<DriverFirebaseSource>(
    () => DriverFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<HouseholdFirebaseSource>(
    () => HouseholdFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<ParkingSpotFirebaseSource>(
    () => ParkingSpotFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<WaterDeliveryFirebaseSource>(
    () => WaterDeliveryFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<OrganizationFirebaseSource>(
    () => OrganizationFirebaseSource(getIt<FirebaseFirestore>()),
  );
  getIt.registerLazySingleton<NotificationHistoryFirebaseSource>(
    () => NotificationHistoryFirebaseSource(getIt<FirebaseFirestore>()),
  );

  // ── Repositories ──────────────────────────────────────────────────────
  getIt.registerLazySingleton<TruckRepository>(
    () => TruckRepositoryImpl(
      firebaseSource: getIt<TruckFirebaseSource>(),
      localSource: getIt<TruckLocalSource>(),
      connectivityService: getIt<ConnectivityService>(),
    ),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<FirebaseAuthSource>()),
  );
  getIt.registerLazySingleton<DriverRepository>(
    () => DriverRepositoryImpl(
      getIt<DriverFirebaseSource>(),
      connectivity: getIt<ConnectivityService>(),
      offlineQueue: getIt<OfflineWriteQueueService>(),
    ),
  );
  getIt.registerLazySingleton<HouseholdRepository>(
    () => HouseholdRepositoryImpl(
      getIt<HouseholdFirebaseSource>(),
      connectivity: getIt<ConnectivityService>(),
      offlineQueue: getIt<OfflineWriteQueueService>(),
    ),
  );
  getIt.registerLazySingleton<ParkingSpotRepository>(
    () => ParkingSpotRepositoryImpl(getIt<ParkingSpotFirebaseSource>()),
  );
  getIt.registerLazySingleton<WaterDeliveryRepository>(
    () => WaterDeliveryRepositoryImpl(
      firebaseSource: getIt<WaterDeliveryFirebaseSource>(),
      connectivityService: getIt<ConnectivityService>(),
    ),
  );
  getIt.registerLazySingleton<OrganizationRepository>(
    () => OrganizationRepositoryImpl(getIt<OrganizationFirebaseSource>()),
  );
  getIt.registerLazySingleton<NotificationHistoryRepository>(
    () => NotificationHistoryRepositoryImpl(
      getIt<NotificationHistoryFirebaseSource>(),
    ),
  );
}
