import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/network/api_client.dart';

void main() {
  test('API client accepts a bracketed production IPv6 URL', () {
    const baseUrl = 'https://[2606:4700:4700::1111]';
    final client = ApiClient(baseUrl: baseUrl);

    expect(client.dio.options.baseUrl, baseUrl);
    expect(Uri.parse('$baseUrl/bootstrap').host, '2606:4700:4700::1111');
    expect(Uri.parse('$baseUrl/bootstrap').scheme, 'https');
  });
}
