import 'package:http/http.dart' as http;

/// HTTP client for all Book Elf backend calls.
/// Adds the `Accept` and `Authorization` headers and reports 401 responses
/// to a single global handler. Never use it for third-party hosts.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required Future<String?> Function() tokenProvider,
    required Future<void> Function(String? sentToken) onUnauthorized,
    http.Client? inner,
  })  : _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized,
        _inner = inner ?? http.Client();

  final Future<String?> Function() _tokenProvider;
  final Future<void> Function(String? sentToken) _onUnauthorized;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenProvider();

    request.headers.putIfAbsent('Accept', () => 'application/json');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      await _onUnauthorized(token);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
