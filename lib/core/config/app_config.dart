enum AppFlavor { dev, staging, prod }

class AppConfig {
  AppConfig._({
    required this.flavor,
    required this.appName,
    required this.firestoreEmulatorHost,
  });

  static AppConfig? _instance;

  static AppConfig get instance {
    assert(
      _instance != null,
      'AppConfig has not been initialised. Call AppConfig.init() in main().',
    );
    return _instance!;
  }

  static void init() {
    const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

    final flavor = AppFlavor.values.firstWhere(
      (f) => f.name == flavorName,
      orElse: () => AppFlavor.dev,
    );

    _instance = _buildConfig(flavor);
  }

  static AppConfig _buildConfig(AppFlavor flavor) {
    return switch (flavor) {
      AppFlavor.dev => AppConfig._(
          flavor: AppFlavor.dev,
          appName: 'AquaPath Dev',
          firestoreEmulatorHost: 'localhost:8080',
        ),
      AppFlavor.staging => AppConfig._(
          flavor: AppFlavor.staging,
          appName: 'AquaPath Staging',
          firestoreEmulatorHost: null,
        ),
      AppFlavor.prod => AppConfig._(
          flavor: AppFlavor.prod,
          appName: 'AquaPath',
          firestoreEmulatorHost: null,
        ),
    };
  }

  final AppFlavor flavor;
  final String appName;
  final String? firestoreEmulatorHost;

  bool get isProduction => flavor == AppFlavor.prod;
  bool get isDevelopment => flavor == AppFlavor.dev;
  bool get isStaging => flavor == AppFlavor.staging;

  @override
  String toString() => 'AppConfig(flavor: ${flavor.name}, app: $appName)';
}
