import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/books_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'config/app_config.dart';
import 'service_locator.dart';
import 'services/auth_service.dart';
import 'utils/image_cache_utils.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment configuration
  await AppConfig.load();
  
  // Setup dependency injection
  await setupServiceLocator();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  StreamSubscription<void>? _sessionExpiredSubscription;
  StreamSubscription<void>? _loggedOutSubscription;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _sessionExpiredSubscription =
        AuthService.sessionExpired.listen((_) => _onSessionExpired());
    _loggedOutSubscription =
        AuthService.loggedOut.listen((_) => _showLogin());
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    _loggedOutSubscription?.cancel();
    super.dispose();
  }

  // Global 401 handling: back to the login screen with an explanation.
  void _onSessionExpired() {
    _showLogin();
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Je sessie is verlopen. Log opnieuw in.')),
    );
  }

  void _showLogin() {
    clearImageCaches();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) setState(() => _isAuthenticated = false);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _onInitializationComplete(bool authenticated) {
    setState(() {
      _isInitialized = true;
      _isAuthenticated = authenticated;
    });
  }

  void _onAuthenticated() {
    setState(() => _isAuthenticated = true);
  }
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = _themeMode == ThemeMode.dark;
    await prefs.setBool('isDarkMode', !isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Book Elf',
      debugShowCheckedModeBanner: false, // Verberg DEBUG banner
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: !_isInitialized
          ? SplashScreen(
              onInitializationComplete: _onInitializationComplete,
              themeMode: _themeMode,
            )
          : !_isAuthenticated
              ? LoginScreen(onAuthenticated: _onAuthenticated)
              : BooksListScreen(
                  onThemeToggle: toggleTheme,
                  isDarkMode: _themeMode == ThemeMode.dark,
                ),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5D4037),
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F4EF),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFF7F4EF),
        foregroundColor: Color(0xFF3E2723),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3E2723),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6E1D9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6E1D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6D4C41), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D4C41),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6D4C41),
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A237E),
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0D1B2A), // Heel donkerblauw
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFF1B263B), // Iets lichter donkerblauw
        foregroundColor: Color(0xFFE0E1DD),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E1DD),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B263B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF415A77)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF415A77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF778DA9), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF415A77),
          foregroundColor: const Color(0xFFE0E1DD),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF415A77),
        foregroundColor: Color(0xFFE0E1DD),
      ),
    );
  }
}
