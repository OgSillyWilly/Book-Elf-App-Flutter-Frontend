import 'package:bookshelf_app/service_locator.dart';
import 'package:bookshelf_app/services/auth_service.dart';
import 'package:bookshelf_app/utils/url_utils.dart';
import 'package:bookshelf_app/widgets/cover_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _api = 'https://api.example.test/api';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL_MOBILE=$_api\nAPI_BASE_URL_WEB=$_api');
  });

  group('isAuthenticatedImageUrl', () {
    test('matches the backend image proxy', () {
      expect(isAuthenticatedImageUrl('$_api/image-proxy?url=https%3A%2F%2Fx.test%2Fa.jpg'), isTrue);
    });

    test('does not match public storage covers', () {
      expect(isAuthenticatedImageUrl('https://api.example.test/storage/covers/1/a.jpg'), isFalse);
    });

    test('does not match third-party hosts, even with a proxy-like path', () {
      expect(isAuthenticatedImageUrl('https://books.google.com/api/image-proxy?x=1'), isFalse);
      expect(isAuthenticatedImageUrl('https://books.google.com/cover.jpg'), isFalse);
    });
  });

  group('CoverImage', () {
    Future<void> pumpCover(WidgetTester tester, String url, {String? token}) async {
      FlutterSecureStorage.setMockInitialValues(
          token == null ? {} : {'auth_token': token});
      await getIt.reset();
      getIt.registerSingleton<AuthService>(AuthService());

      await tester.pumpWidget(MaterialApp(
        home: CoverImage(imageUrl: url, width: 40, height: 60),
      ));
      await tester.pump();
    }

    testWidgets('sends the token for image-proxy URLs', (tester) async {
      await pumpCover(tester, '$_api/image-proxy?url=abc', token: 'tok');

      final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.httpHeaders, {'Authorization': 'Bearer tok'});
    });

    testWidgets('does not request a proxy URL without a token', (tester) async {
      await pumpCover(tester, '$_api/image-proxy?url=abc');

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('sends no token to third-party URLs', (tester) async {
      await pumpCover(tester, 'https://books.google.com/cover.jpg', token: 'tok');

      final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.httpHeaders, isNull);
    });
  });
}
