import 'dart:convert';

import 'package:bookshelf_app/config/app_config.dart';
import 'package:bookshelf_app/screens/login_screen.dart';
import 'package:bookshelf_app/service_locator.dart';
import 'package:bookshelf_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late FlutterSecureStorage storage;

  Future<void> pumpLogin(WidgetTester tester, http.Response response,
      {VoidCallback? onAuthenticated}) async {
    dotenv.testLoad(fileInput: '');
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    await getIt.reset();
    getIt.registerSingleton<AuthService>(AuthService(
      storage: storage,
      client: MockClient((_) async => response),
    ));

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onAuthenticated: onAuthenticated ?? () {}),
    ));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Inloggen'));
    // The spinner keeps animating after success, so avoid pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('validates empty fields locally', (tester) async {
    await pumpLogin(tester, http.Response('{}', 200));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Inloggen'));
    await tester.pump();

    expect(find.text('Voer je e-mailadres in'), findsOneWidget);
    expect(find.text('Voer je wachtwoord in'), findsOneWidget);
  });

  testWidgets('shows server 422 errors on the matching field', (tester) async {
    await pumpLogin(
      tester,
      http.Response(
        jsonEncode({
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['Deze gegevens komen niet overeen.'],
          },
        }),
        422,
      ),
    );

    await submit(tester);

    expect(find.text('Deze gegevens komen niet overeen.'), findsOneWidget);
  });

  testWidgets('shows a friendly message on 429', (tester) async {
    await pumpLogin(tester, http.Response('{"message":"Too Many Attempts."}', 429));

    await submit(tester);

    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('stores the token and reports success', (tester) async {
    var authenticated = false;
    await pumpLogin(
      tester,
      http.Response(
        jsonEncode({
          'user': {'name': 'A', 'email': 'a@b.test'},
          'token': 'tok123',
          'token_type': 'Bearer',
        }),
        200,
      ),
      onAuthenticated: () => authenticated = true,
    );

    await submit(tester);

    expect(authenticated, isTrue);
    expect(await getIt<AuthService>().token, 'tok123');
    expect(AppConfig.apiBaseUrl, isNotEmpty);
  });
}
