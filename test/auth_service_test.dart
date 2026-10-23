import 'dart:convert';

import 'package:bookshelf_app/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  AuthService serviceWith(http.Response Function(http.Request) handler) {
    return AuthService(
      storage: const FlutterSecureStorage(),
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status);

  setUp(() {
    dotenv.testLoad(fileInput: '');
    FlutterSecureStorage.setMockInitialValues({});
    requests = [];
  });

  group('login and register', () {
    test('login stores the token and survives a new service instance',
        () async {
      final service = serviceWith((_) => json(200, {
            'user': {'id': 1},
            'token': 'abc',
            'token_type': 'Bearer',
          }));

      await service.login(email: 'a@b.test', password: 'secret');

      expect(requests.single.url.path, endsWith('/login'));
      expect(requests.single.bodyFields['email'], 'a@b.test');
      expect(await service.token, 'abc');
      // A fresh instance simulates an app restart.
      expect(await AuthService().token, 'abc');
    });

    test('register sends the confirmation and stores the token', () async {
      final service = serviceWith((_) => json(201, {'user': {}, 'token': 't1'}));

      await service.register(
        name: 'N',
        email: 'a@b.test',
        password: 'secret123',
        passwordConfirmation: 'secret123',
      );

      expect(requests.single.url.path, endsWith('/register'));
      expect(requests.single.bodyFields['password_confirmation'], 'secret123');
      expect(await service.token, 't1');
    });

    test('422 exposes field errors and stores no token', () async {
      final service = serviceWith((_) => json(422, {
            'message': 'invalid',
            'errors': {
              'email': ['These credentials do not match our records.'],
            },
          }));

      await expectLater(
        service.login(email: 'a@b.test', password: 'wrong'),
        throwsA(isA<AuthException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.fieldErrors['email']?.first, 'email error',
                'These credentials do not match our records.')),
      );
      expect(await service.token, isNull);
    });

    test('429 maps to a friendly message', () async {
      final service = serviceWith((_) => json(429, {'message': 'Too Many Attempts.'}));

      await expectLater(
        service.login(email: 'a@b.test', password: 'x'),
        throwsA(isA<AuthException>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.message, 'message', contains('Too many attempts'))),
      );
    });

    test('a response without a token is rejected', () async {
      final service = serviceWith((_) => json(200, {'user': {}}));

      await expectLater(
        service.login(email: 'a@b.test', password: 'x'),
        throwsA(isA<AuthException>()),
      );
      expect(await service.token, isNull);
    });
  });

  group('logout', () {
    test('revokes the token on the server and clears it', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
      final service = serviceWith((_) => json(200, {'message': 'ok'}));
      final loggedOut = AuthService.loggedOut.first;

      await service.logout();

      expect(requests.single.url.path, endsWith('/logout'));
      expect(requests.single.headers['Authorization'], 'Bearer abc');
      expect(await service.token, isNull);
      await loggedOut.timeout(const Duration(seconds: 1));
    });

    test('clears the token even when the server call fails', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
      final service = serviceWith((_) => json(500, {'message': 'boom'}));

      await expectLater(service.logout(), throwsA(isA<AuthException>()));
      expect(await service.token, isNull);
    });

    test('without a token it makes no request but still emits loggedOut',
        () async {
      final service = serviceWith((_) => json(200, {}));
      final loggedOut = AuthService.loggedOut.first;

      await service.logout();

      expect(requests, isEmpty);
      await loggedOut.timeout(const Duration(seconds: 1));
    });
  });

  group('currentUser', () {
    test('returns the user for a valid token', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
      final service = serviceWith(
          (_) => json(200, {'user': {'id': 1, 'name': 'Sam'}}));

      final user = await service.currentUser();

      expect(user['name'], 'Sam');
      expect(requests.single.headers['Authorization'], 'Bearer abc');
    });

    test('throws without a token and makes no request', () async {
      final service = serviceWith((_) => json(200, {}));

      await expectLater(service.currentUser(), throwsA(isA<AuthException>()));
      expect(requests, isEmpty);
    });

    test('a 401 clears the token and emits sessionExpired', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
      final service = serviceWith((_) => json(401, {'message': 'Unauthenticated.'}));
      final expired = AuthService.sessionExpired.first;

      await expectLater(service.currentUser(), throwsA(isA<AuthException>()));

      expect(await service.token, isNull);
      await expired.timeout(const Duration(seconds: 1));
    });
  });

  group('handleUnauthorized', () {
    test('ignores a 401 for an older token', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'new'});
      final service = serviceWith((_) => json(200, {}));

      await service.handleUnauthorized('old');

      expect(await service.token, 'new');
    });

    test('clears the token when it is still the current one', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
      final service = serviceWith((_) => json(200, {}));

      await service.handleUnauthorized('abc');

      expect(await service.token, isNull);
    });
  });
}
