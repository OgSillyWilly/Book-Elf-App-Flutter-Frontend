import 'package:flutter/foundation.dart' show kDebugMode;
import '../config/app_config.dart';

/// Normalize image URLs to work across different platforms (web and mobile)
/// 
/// - If the URL is already a full URL (starts with http:// or https://), return as-is
/// - If the URL is a relative path (starts with /), prepend the API base URL
String? normalizeImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }

  // If it's already a full URL, return as-is
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  // If it's a relative path, prepend the base URL (without /api suffix)
  if (url.startsWith('/')) {
    final baseUrl = AppConfig.apiBaseUrl.replaceAll('/api', '');
    final normalized = '$baseUrl$url';
    
    if (kDebugMode) {
      print('DEBUG normalizeImageUrl: $url -> $normalized');
    }
    
    return normalized;
  }

  return url;
}

/// Whether [url] points at the backend's image proxy, which requires the
/// bearer token. Third-party hosts never match, so the token is not leaked.
bool isAuthenticatedImageUrl(String url) {
  final uri = Uri.tryParse(url);
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (uri == null || base == null || !uri.hasAuthority) return false;

  return uri.host == base.host &&
      uri.port == base.port &&
      uri.path.contains('/image-proxy');
}
