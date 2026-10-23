import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../models/series.dart';
import '../../models/reading_challenge.dart';
import '../../config/app_config.dart';
import '../../service_locator.dart';
import '../api_exceptions.dart';
import '../authenticated_client.dart';
import '../interfaces/i_data_service.dart';

/// API implementation of IDataService
/// Communicates with Laravel backend via REST API
class ApiDataService implements IDataService {
  ApiDataService({http.Client? client})
      : _client = client ?? getIt<AuthenticatedClient>();

  final http.Client _client;

  // Get API base URL from settings or AppConfig default
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('api_base_url');
    
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    
    // Use AppConfig for platform-specific URLs
    return AppConfig.apiBaseUrl;
  }
  
  // Synchronous getter for direct usage (delegates to AppConfig)
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  static const Duration timeout = Duration(seconds: 15);
  static const Duration importTimeout = Duration(seconds: 45);

  // Test of de API bereikbaar is
  @override
  Future<bool> testConnection() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/books'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Book>> getBooks() async {
    try {
      final url = await getBaseUrl();
      List<Book> allBooks = [];
      int currentPage = 1;
      int lastPage = 1;
      
      // Fetch all pages
      do {
        final response = await _client.get(
          Uri.parse('$url/books?page=$currentPage'),
          headers: {'Accept': 'application/json'},
        ).timeout(timeout);
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          // Handle new API response structure with data and total
          List<dynamic> data;
          if (responseData is Map && responseData.containsKey('data')) {
            data = responseData['data'];
            lastPage = responseData['last_page'] ?? 1;
          } else if (responseData is List) {
            // Fallback for old API response format
            data = responseData;
          } else {
            throw Exception('Onverwachte API response structuur');
          }
          
          allBooks.addAll(data.map((json) => Book.fromJson(json)).toList());
          currentPage++;
        } else {
          throw Exception('Server antwoordde met status ${response.statusCode}');
        }
      } while (currentPage <= lastPage);
      
      return allBooks;
    } on TimeoutException {
      final url = await getBaseUrl();
      throw Exception('Verbinding timeout - controleer of de server draait op $url');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  // Nieuwe methode die ook het totaal aantal resultaten retourneert
  @override
  Future<BooksResponse> getBooksWithTotal() async {
    try {
      final url = await getBaseUrl();
      List<Book> allBooks = [];
      int total = 0;
      int currentPage = 1;
      int lastPage = 1;
      
      // Fetch all pages
      do {
        final response = await _client.get(
          Uri.parse('$url/books?page=$currentPage'),
          headers: {'Accept': 'application/json'},
        ).timeout(timeout);
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          // Handle new API response structure with data and total
          List<dynamic> data;
          
          if (responseData is Map && responseData.containsKey('data')) {
            data = responseData['data'];
            total = responseData['total'] ?? data.length;
            lastPage = responseData['last_page'] ?? 1;
          } else if (responseData is List) {
            // Fallback for old API response format
            data = responseData;
            total = data.length;
          } else {
            throw Exception('Onverwachte API response structuur');
          }
          
          allBooks.addAll(data.map((json) => Book.fromJson(json)).toList());
          currentPage++;
        } else {
          throw Exception('Server antwoordde met status ${response.statusCode}');
        }
      } while (currentPage <= lastPage);
      
      return BooksResponse(books: allBooks, total: total);
    } on TimeoutException {
      final url = await getBaseUrl();
      throw Exception('Verbinding timeout - controleer of de server draait op $url');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  @override
  Future<Book> createBook(Map<String, dynamic> bookData) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.post(
        Uri.parse('$url/books'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(bookData),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        return Book.fromJson(json.decode(response.body));
      } else if (response.statusCode == 422) {
        throw ValidationException.fromBody(response.body);
      } else {
        throw Exception('Kon boek niet aanmaken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout - controleer of de server draait');
    }
  }

  @override
  Future<Book> getBook(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/books/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return Book.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw const NotFoundException('Boek niet gevonden');
      } else {
        throw Exception('Kon boek niet ophalen: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout - controleer of de server draait');
    }
  }

  @override
  Future<Book> updateBook(int id, Map<String, dynamic> bookData) async {
    final url = await getBaseUrl();
    try {
      final response = await _client.put(
        Uri.parse('$url/books/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(bookData),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return Book.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw const NotFoundException('Boek niet gevonden');
      } else if (response.statusCode == 422) {
        throw ValidationException.fromBody(response.body);
      } else {
        throw Exception('Kon boek niet bijwerken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout - controleer of de server draait');
    } on ApiException {
      rethrow;
    } catch (e) {
      // Meer gedetailleerde error info voor debugging
      throw Exception('Update mislukt: ${e.toString()}\n\nURL: $url/books/$id\n\nOm dit op te lossen:\n- Open Chrome DevTools (F12)\n- Ga naar Network tab\n- Probeer opnieuw\n- Check of er een CORS error is (rood)\n\nOf gebruik een mobiele versie/emulator waar dit probleem niet optreedt.');
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.delete(
        Uri.parse('$url/books/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Kon boek niet verwijderen');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout - controleer of de server draait');
    }
  }

  Future<String> importBooks(String filePath, List<int> fileBytes) async {
    try {
      final url = await getBaseUrl();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$url/books/import'),
      );
      
      request.headers['Accept'] = 'application/json';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filePath.split('/').last,
        ),
      );

      final streamedResponse = await _client.send(request).timeout(importTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['message'] ?? 'Boeken succesvol geïmporteerd!';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Kon boeken niet importeren');
      }
    } on TimeoutException {
      throw Exception('Import timeout - bestand is mogelijk te groot of server reageert niet');
    }
  }

  Future<String> getTemplateUrl() async {
    final url = await getBaseUrl();
    return '$url/books/template/download';
  }

  Future<List<Book>> getBooksByYear(int year) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/books?year_read=$year'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle new API response structure with pagination
        List<dynamic> data;
        if (responseData is Map && responseData.containsKey('data')) {
          // Paginated response - extract data array
          data = responseData['data'];
        } else if (responseData is List) {
          // Fallback for old API response format (simple array)
          data = responseData;
        } else {
          throw Exception('Onverwachte API response structuur');
        }
        
        return data.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      final url = await getBaseUrl();
      throw Exception('Verbinding timeout - controleer of de server draait op $url');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getReadingHistory() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/books/reading-history'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      final url = await getBaseUrl();
      throw Exception('Verbinding timeout - controleer of de server draait op $url');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  // ==================== SERIES API ====================
  
  Future<List<Series>> getSeries({String? search}) async {
    try {
      final url = await getBaseUrl();
      var uri = '$url/series';
      if (search != null && search.isNotEmpty) {
        uri += '?search=$search';
      }
      
      final response = await _client.get(
        Uri.parse(uri),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> data;
        
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else if (responseData is List) {
          data = responseData;
        } else {
          throw Exception('Onverwachte API response structuur');
        }
        
        return data.map((json) => Series.fromJson(json)).toList();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getSeriesWithProgress(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/series/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw const NotFoundException('Serie niet gevonden');
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Series> createSeries(Map<String, dynamic> seriesData) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.post(
        Uri.parse('$url/series'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(seriesData),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        return Series.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kon serie niet aanmaken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Series> updateSeries(int id, Map<String, dynamic> seriesData) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.put(
        Uri.parse('$url/series/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(seriesData),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return Series.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kon serie niet bijwerken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<void> deleteSeries(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.delete(
        Uri.parse('$url/series/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Kon serie niet verwijderen');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  // ==================== READING CHALLENGES API ====================
  
  Future<List<ReadingChallenge>> getReadingChallenges() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/reading-challenges'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => ReadingChallenge.fromJson(json)).toList();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  Future<ReadingChallenge?> getActiveChallenge() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/reading-challenges/active'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return ReadingChallenge.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null; // No active challenge
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    } catch (e) {
      if (e.toString().contains('404')) return null;
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getChallengeWithDetails(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/reading-challenges/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw const NotFoundException('Challenge niet gevonden');
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Map<String, dynamic>> getChallengeSuggestions(int challengeId, {int limit = 10}) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/reading-challenges/$challengeId/suggestions?limit=$limit'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<ReadingChallenge> createChallenge(Map<String, dynamic> challengeData) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.post(
        Uri.parse('$url/reading-challenges'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(challengeData),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        return ReadingChallenge.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kon challenge niet aanmaken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<ReadingChallenge> updateChallenge(int id, Map<String, dynamic> challengeData) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.put(
        Uri.parse('$url/reading-challenges/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(challengeData),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return ReadingChallenge.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kon challenge niet bijwerken: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<void> deleteChallenge(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.delete(
        Uri.parse('$url/reading-challenges/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Kon challenge niet verwijderen');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  // ==================== STATISTICS API ====================
  
  Future<Map<String, dynamic>> getStatisticsOverview() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/overview'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    } catch (e) {
      throw Exception('Verbindingsfout: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getAuthorProgress(String author) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/author-progress?author=${Uri.encodeComponent(author)}'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Map<String, dynamic>> getReadingPatterns({int? year}) async {
    try {
      final url = await getBaseUrl();
      var uri = '$url/statistics/reading-patterns';
      if (year != null) {
        uri += '?year=$year';
      }
      
      final response = await _client.get(
        Uri.parse(uri),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Map<String, dynamic>> getStatisticsByType() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/by-type'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<List<Book>> getTopRatedBooks({int limit = 10}) async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/top-rated?limit=$limit'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<List<Map<String, dynamic>>> getYearlyHistory() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/yearly-history'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }

  Future<Map<String, dynamic>> getSeriesProgress() async {
    try {
      final url = await getBaseUrl();
      final response = await _client.get(
        Uri.parse('$url/statistics/series-progress'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server antwoordde met status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Verbinding timeout');
    }
  }
}
