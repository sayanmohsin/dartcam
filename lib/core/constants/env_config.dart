class EnvConfig {
  EnvConfig._();

  /// thingd.cloud server URL. Set via --dart-define=THINGD_CLOUD_URL=
  static String get cloudUrl =>
      const String.fromEnvironment('THINGD_CLOUD_URL',
          defaultValue: 'https://api.thingd.cloud');

  /// thingd.cloud API key. Set via --dart-define=THINGD_CLOUD_API_KEY=
  static String get cloudApiKey =>
      const String.fromEnvironment('THINGD_CLOUD_API_KEY',
          defaultValue: '');

  /// Whether cloud credentials are configured via environment variables.
  static bool get hasCloudConfig => cloudApiKey.isNotEmpty;
}
