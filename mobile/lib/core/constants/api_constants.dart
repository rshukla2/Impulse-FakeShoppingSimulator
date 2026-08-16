import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// True only for a GitHub Pages build created before the production API URL
  /// has been configured. It keeps the static deployment honest while the
  /// DigitalOcean backend is still being provisioned.
  static const bool isDeploymentPreview =
      bool.fromEnvironment('DEPLOYMENT_PREVIEW', defaultValue: false);

  /// Backend URL supplied with `--dart-define=API_BASE_URL=https://...`.
  ///
  /// Local defaults cover Flutter web, iOS Simulator, and Android Emulator.
  /// Physical devices must use a reachable LAN or HTTPS URL via dart-define.
  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Endpoint paths
  static const String health = '/health';
  static const String bootstrap = '/bootstrap';
  static const String shopping = '/shopping';
  static const String groceries = '/groceries';
  static const String food = '/food';
  static const String restaurants = '/restaurants';
  static const String categories = '/categories';
  static const String search = '/search';
}
