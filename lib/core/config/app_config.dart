enum Environment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appTitle,
    required this.apiBaseUrl,
    required this.enableDebugLogs,
    required this.enablePerformanceMonitoring,
    this.defaultPlayerPoolSize = 3,
  });
  final Environment environment;
  final String appTitle;
  final String apiBaseUrl;
  final bool enableDebugLogs;
  final bool enablePerformanceMonitoring;
  final int defaultPlayerPoolSize;

  static const String cloudFunctionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://asia-south1-truthworld-1.cloudfunctions.net',
  );

  static const String cdnBaseUrl = String.fromEnvironment(
    'CDN_BASE_URL',
    defaultValue: 'https://storage.googleapis.com',
  );

  static late AppConfig _instance;
  static AppConfig get instance => _instance;

  static void initialize({
    required Environment environment,
    String? appTitle,
    String? apiBaseUrl,
    bool? enableDebugLogs,
    bool? enablePerformanceMonitoring,
    int? defaultPlayerPoolSize,
  }) {
    _instance = AppConfig(
      environment: environment,
      appTitle: appTitle ?? 'TruthWorld',
      apiBaseUrl: apiBaseUrl ?? 'https://truthworld.app/api',
      enableDebugLogs:
          enableDebugLogs ?? (environment == Environment.development),
      enablePerformanceMonitoring: enablePerformanceMonitoring ?? true,
      defaultPlayerPoolSize: defaultPlayerPoolSize ?? 3,
    );
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
