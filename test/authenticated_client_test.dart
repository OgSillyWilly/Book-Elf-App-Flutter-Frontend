import 'package:bookshelf_app/services/authenticated_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late http.BaseRequest? captured;

  MockClient inner(int status) => MockClient((request) async {
        captured = request;
        return http.Response('{}', status);
      });

  setUp(() => captured = null);

  test('adds Authorization and Accept headers', () async {
    final client = AuthenticatedClient(
      tokenProvider: () async => 'abc',
      onUnauthorized: (_) async {},
      inner: inner(200),
    );

    await client.get(Uri.parse('https://example.test/api/books'));

    expect(captured!.headers['Authorization'], 'Bearer abc');
    expect(captured!.headers['Accept'], 'application/json');
  });

  test('adds headers to multipart requests', () async {
    final client = AuthenticatedClient(
      tokenProvider: () async => 'abc',
      onUnauthorized: (_) async {},
      inner: inner(200),
    );

    final request = http.MultipartRequest(
        'POST', Uri.parse('https://example.test/api/books/1/cover'));
    await client.send(request);

    expect(captured!.headers['Authorization'], 'Bearer abc');
  });

  test('omits Authorization without a token', () async {
    final client = AuthenticatedClient(
      tokenProvider: () async => null,
      onUnauthorized: (_) async {},
      inner: inner(200),
    );

    await client.get(Uri.parse('https://example.test/api/books'));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('calls the global handler once with the sent token on 401', () async {
    final handled = <String?>[];
    final client = AuthenticatedClient(
      tokenProvider: () async => 'abc',
      onUnauthorized: (token) async => handled.add(token),
      inner: inner(401),
    );

    final response = await client.get(Uri.parse('https://example.test/api/books'));

    expect(response.statusCode, 401);
    expect(handled, ['abc']);
  });

  test('does not call the handler on success or 404', () async {
    var calls = 0;
    for (final status in [200, 404]) {
      final client = AuthenticatedClient(
        tokenProvider: () async => 'abc',
        onUnauthorized: (_) async => calls++,
        inner: inner(status),
      );
      await client.get(Uri.parse('https://example.test/api/books'));
    }

    expect(calls, 0);
  });
}
