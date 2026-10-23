import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthService {
  AuthService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;
  final http.Client _client;

  // Static so listeners survive the service locator being reset.
  static final _sessionExpiredController = StreamController<void>.broadcast();
  static final _loggedOutController = StreamController<void>.broadcast();

  /// Emits when the server rejected the stored token (401) and it was cleared.
  static Stream<void> get sessionExpired => _sessionExpiredController.stream;

  /// Emits when the user logged out and the token was cleared.
  static Stream<void> get loggedOut => _loggedOutController.stream;

  Future<String?> get token => _storage.read(key: _tokenKey);

  /// Global 401 handler. Only acts if the rejected token is still the stored
  /// one, so a late 401 from an old session can't log out a newer login.
  Future<void> handleUnauthorized(String? sentToken) async {
    final current = await token;
    if (current == null || current.isEmpty || current != sentToken) return;

    await _storage.delete(key: _tokenKey);
    _sessionExpiredController.add(null);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    return _authenticate(
      'register',
      {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _authenticate('login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> _authenticate(
    String endpoint,
    Map<String, String> body,
  ) async {
    final response = await _client.post(
      _endpoint(endpoint),
      headers: const {'Accept': 'application/json'},
      body: body,
    );
    final responseBody = _readResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response.statusCode, responseBody);
    }

    final authResponse = _asJsonObject(responseBody);
    final tokenValue = authResponse['token'];
    if (tokenValue is! String || tokenValue.isEmpty) {
      throw const AuthException(
          'The server returned an invalid authentication response.');
    }

    await _storage.write(key: _tokenKey, value: tokenValue);
    return authResponse;
  }

  Future<void> logout() async {
    final savedToken = await token;
    if (savedToken == null || savedToken.isEmpty) {
      await _storage.delete(key: _tokenKey);
      _loggedOutController.add(null);
      return;
    }

    try {
      final response = await _client.post(
        _endpoint('logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $savedToken',
        },
      );
      final responseBody = _readResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _responseError(response.statusCode, responseBody);
      }
    } finally {
      await _storage.delete(key: _tokenKey);
      _loggedOutController.add(null);
    }
  }

  Future<Map<String, dynamic>> currentUser() async {
    final savedToken = await token;
    if (savedToken == null || savedToken.isEmpty) {
      throw const AuthException('You are not logged in.');
    }

    final response = await _client.get(
      _endpoint('user'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $savedToken',
      },
    );
    final responseBody = _readResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await handleUnauthorized(savedToken);
      }
      throw _responseError(response.statusCode, responseBody);
    }

    final userResponse = _asJsonObject(responseBody);
    final user = userResponse['user'];
    return user is Map<String, dynamic> ? user : userResponse;
  }

  Uri _endpoint(String path) {
    final baseUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$baseUrl/$path');
  }

  String _readResponse(http.Response response) => response.body;

  Map<String, dynamic> _asJsonObject(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const AuthException('The server returned an invalid response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  AuthException _responseError(int statusCode, String responseBody) {
    Map<String, dynamic> response = {};
    if (responseBody.isNotEmpty) {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        response = Map<String, dynamic>.from(decoded);
      }
    }

    final fieldErrors = <String, List<String>>{};
    final errors = response['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List) {
          fieldErrors[entry.key.toString()] =
              value.map((message) => message.toString()).toList();
        }
      }
    }

    final message = statusCode == 429
        ? 'Too many attempts. Please wait a minute before trying again.'
        : response['message'] is String
            ? response['message'] as String
            : statusCode == 422
                ? 'Please check the entered details.'
                : 'The request failed. Please try again.';

    return AuthException(
      message,
      statusCode: statusCode,
      fieldErrors: fieldErrors,
    );
  }
}

class AuthException implements Exception {
  const AuthException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => message;
}
