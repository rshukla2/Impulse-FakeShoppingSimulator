/// Impulse runs only as a static portfolio demo. Every "API" request is
/// answered in-app by StaticDemoInterceptor from the bundled catalog snapshot
/// in assets/static_demo/; nothing goes over the network.
class ApiConstants {
  /// Placeholder base URL. Requests never leave the app.
  static const String defaultBaseUrl = 'https://impulse.static-demo';

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
