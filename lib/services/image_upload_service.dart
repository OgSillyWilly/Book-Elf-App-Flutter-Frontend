import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../service_locator.dart';
import 'authenticated_client.dart';

class ImageUploadService {
  static String get _baseUrl => AppConfig.apiBaseUrl;
  static AuthenticatedClient get _client => getIt<AuthenticatedClient>();

  // Determine mime type from filename
  static String _getMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg'; // fallback
    }
  }

  // Upload from File (mobile/desktop)
  static Future<String?> uploadBookCover(int bookId, File imageFile) async {
    if (kIsWeb) {
      throw Exception('Use uploadBookCoverFromBytes for web platform');
    }

    try {
      final uri = Uri.parse('$_baseUrl/books/$bookId/cover');
      
      var request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers['Accept'] = 'application/json';
      
      // Read file as bytes and use fromBytes instead of fromPath
      final bytes = await imageFile.readAsBytes();
      final filename = imageFile.path.split('/').last;
      final mimeType = _getMimeType(filename);
      final mediaType = MediaType.parse(mimeType);
      
      request.files.add(http.MultipartFile.fromBytes(
        'cover',
        bytes,
        filename: filename,
        contentType: mediaType,
      ));

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Return the cover URL from response (backend now returns full URL)
        final coverUrl = responseData['cover_url'] as String;
        return coverUrl;
      } else {
        throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload cover: $e');
    }
  }

  // Upload from bytes (web platform)
  static Future<String?> uploadBookCoverFromBytes(int bookId, Uint8List imageBytes, String filename) async {
    try {
      final uri = Uri.parse('$_baseUrl/books/$bookId/cover');
      
      var request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers['Accept'] = 'application/json';
      
      final mimeType = _getMimeType(filename);
      final mediaType = MediaType.parse(mimeType);
      
      request.files.add(http.MultipartFile.fromBytes(
        'cover',
        imageBytes,
        filename: filename,
        contentType: mediaType,
      ));

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Return the cover URL from response (backend now returns full URL)
        final coverUrl = responseData['cover_url'] as String;
        return coverUrl;
      } else {
        throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload cover: $e');
    }
  }

  static Future<void> deleteBookCover(int bookId) async {
    try {
      final uri = Uri.parse('$_baseUrl/books/$bookId/cover');
      
      final response = await _client.delete(uri);

      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete cover: $e');
    }
  }
}
