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

  static const bool isFirebaseStaging =
      String.fromEnvironment('FIREBASE_ENV') == 'staging';

  static const String stagingFunctionsProjectId = String.fromEnvironment(
    'STAGING_PROJECT_ID',
    defaultValue: 'truthworld-staging',
  );

  static const String cloudFunctionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: isFirebaseStaging
        ? 'https://asia-south1-$stagingFunctionsProjectId.cloudfunctions.net'
        : 'https://asia-south1-truthworld-1.cloudfunctions.net',
  );

  static const String cdnBaseUrl = String.fromEnvironment(
    'CDN_BASE_URL',
    defaultValue: 'https://cdn.truthworld.in',
  );

  /// Whether public thumbnails & avatars should be served via Google Cloud CDN (cdn.truthworld.in).
  /// Defaults to false for zero-disruption local development until the Google Cloud Storage bucket
  /// IAM condition (Storage Object Viewer on allUsers for thumbnails/) is provisioned.
  static bool enableCdnThumbnails = const bool.fromEnvironment(
    'ENABLE_CDN_THUMBNAILS',
  );

  /// Root URL for publicly cached video thumbnails & poster images
  static String get cdnThumbnailsUrl => '$cdnBaseUrl/thumbnails';

  /// Root URL for protected/gated video streams (requires session attestation)
  static String get cdnVideosUrl => '$cdnBaseUrl/videos';

  // ─── Typesense Instant Search Cluster Configuration ──────────────────────
  static const String typesenseHost = String.fromEnvironment(
    'TYPESENSE_HOST',
    defaultValue: '26z51dwhpsoq0kv8p-1.a1.typesense.net',
  );

  static const String typesenseSearchKey = String.fromEnvironment(
    'TYPESENSE_SEARCH_KEY',
    defaultValue: 'pw6fZJ3XVEdZHcSJAEGwwYh3xZXsMPyc',
  );

  static const int typesensePort = int.fromEnvironment(
    'TYPESENSE_PORT',
    defaultValue: 443,
  );

  static const String typesenseProtocol = String.fromEnvironment(
    'TYPESENSE_PROTOCOL',
    defaultValue: 'https',
  );

  static const bool enableTypesenseSearch = bool.fromEnvironment(
    'ENABLE_TYPESENSE_SEARCH',
    defaultValue: true,
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
