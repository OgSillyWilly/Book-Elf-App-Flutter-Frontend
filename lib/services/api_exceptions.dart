import 'dart:convert';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The record does not exist, or belongs to another user (the API answers 404 for both).
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Niet gevonden']);
}

/// 422 response with per-field messages (`errors: {field: [messages]}`).
class ValidationException extends ApiException {
  const ValidationException(super.message, this.fieldErrors);

  final Map<String, List<String>> fieldErrors;

  String? firstError(String field) {
    final errors = fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  factory ValidationException.fromBody(String body) {
    var message = 'De ingevoerde gegevens zijn ongeldig.';
    final fieldErrors = <String, List<String>>{};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded['message'] is String) message = decoded['message'] as String;
        final errors = decoded['errors'];
        if (errors is Map) {
          for (final entry in errors.entries) {
            final value = entry.value;
            if (value is List) {
              fieldErrors[entry.key.toString()] =
                  value.map((e) => e.toString()).toList();
            }
          }
        }
      }
    } catch (_) {
      // Keep the generic message when the body is not JSON.
    }

    if (fieldErrors.isNotEmpty) {
      message = fieldErrors.values.expand((e) => e).join('\n');
    }
    return ValidationException(message, fieldErrors);
  }
}
