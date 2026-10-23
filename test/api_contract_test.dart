import 'dart:convert';

import 'package:bookshelf_app/models/book.dart';
import 'package:bookshelf_app/services/api_exceptions.dart';
import 'package:bookshelf_app/services/implementations/api_data_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiDataService serviceWith(int status, [String body = '{}']) {
  return ApiDataService(
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: '');
    SharedPreferences.setMockInitialValues({});
  });

  group('404 handling', () {
    test('getBook throws NotFoundException', () {
      expect(serviceWith(404).getBook(1), throwsA(isA<NotFoundException>()));
    });

    test('getSeriesWithProgress throws NotFoundException', () {
      expect(serviceWith(404).getSeriesWithProgress(1),
          throwsA(isA<NotFoundException>()));
    });

    test('getChallengeWithDetails throws NotFoundException', () {
      expect(serviceWith(404).getChallengeWithDetails(1),
          throwsA(isA<NotFoundException>()));
    });

    test('updateBook keeps NotFoundException instead of wrapping it', () {
      expect(serviceWith(404).updateBook(1, {}),
          throwsA(isA<NotFoundException>()));
    });
  });

  group('422 handling', () {
    final body = jsonEncode({
      'message': 'The selected series id is invalid.',
      'errors': {
        'series_id': ['The selected series id is invalid.'],
      },
    });

    test('createBook exposes the series_id error', () async {
      await expectLater(
        serviceWith(422, body).createBook({'series_id': 99}),
        throwsA(isA<ValidationException>().having(
            (e) => e.firstError('series_id'),
            'series_id error',
            'The selected series id is invalid.')),
      );
    });

    test('updateBook exposes the series_id error', () async {
      await expectLater(
        serviceWith(422, body).updateBook(1, {'series_id': 99}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a non-JSON body falls back to a generic message', () {
      final e = ValidationException.fromBody('oops');
      expect(e.fieldErrors, isEmpty);
      expect(e.message, isNotEmpty);
    });
  });

  group('Book.series_id', () {
    test('is parsed from and written to JSON', () {
      final book = Book.fromJson({'title': 'A', 'author': 'B', 'series_id': 7});
      expect(book.seriesId, 7);
      expect(book.toJson()['series_id'], 7);
    });

    test('is null when absent', () {
      final book = Book.fromJson({'title': 'A', 'author': 'B'});
      expect(book.seriesId, isNull);
    });
  });
}
