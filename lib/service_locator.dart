import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/interfaces/i_data_service.dart';
import 'services/implementations/api_data_service.dart';
import 'services/auth_service.dart';
import 'services/authenticated_client.dart';
import 'services/google_books_service.dart';
import 'services/image_upload_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Service mode configuration
enum ServiceMode {
  api,    // Use Laravel API (network required)
  local,  // Use local SQLite database (offline)
}

/// Setup dependency injection
/// Call this once in main() before runApp()
Future<void> setupServiceLocator({ServiceMode? mode}) async {
  // Load saved preference if no mode specified
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('service_mode') ?? 'api';
  final activeMode = mode ?? (savedMode == 'local' ? ServiceMode.local : ServiceMode.api);

  // Save mode preference
  await prefs.setString('service_mode', activeMode == ServiceMode.local ? 'local' : 'api');
  
  // Register data service based on mode
  switch (activeMode) {
    case ServiceMode.api:
      getIt.registerLazySingleton<IDataService>(() => ApiDataService());
      break;

    case ServiceMode.local:
      // TODO: Initialize SQLite database first and register a local IDataService.
      // A local mode must also be scoped per user once it exists.

      // For now, throw error as local mode is not yet implemented
      throw UnimplementedError(
        'Local database mode is not yet implemented. '
        'Please use API mode for now.'
      );
  }

  // Register other services that don't change between modes
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<AuthenticatedClient>(() {
    final auth = getIt<AuthService>();
    return AuthenticatedClient(
      tokenProvider: () => auth.token,
      onUnauthorized: auth.handleUnauthorized,
    );
  });
  getIt.registerLazySingleton<GoogleBooksService>(() => GoogleBooksService());
  getIt.registerLazySingleton<ImageUploadService>(() => ImageUploadService());
}

/// Switch between API and Local mode at runtime
/// This resets all services and re-registers them with the new mode
Future<void> switchServiceMode(ServiceMode newMode) async {
  // Unregister all services
  await getIt.reset();

  // Re-register with new mode
  await setupServiceLocator(mode: newMode);
}

/// Get current service mode
Future<ServiceMode> getCurrentServiceMode() async {
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('service_mode') ?? 'api';
  return savedMode == 'local' ? ServiceMode.local : ServiceMode.api;
}
