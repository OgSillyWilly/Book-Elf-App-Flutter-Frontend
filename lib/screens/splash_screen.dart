import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  /// Called once the splash is done; the argument says whether a valid session exists.
  final ValueChanged<bool> onInitializationComplete;
  final ThemeMode themeMode;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
    required this.themeMode,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // Wait for the animation and the session check, then navigate
    _initialize();
  }

  Future<void> _initialize() async {
    final minimumSplash = Future.delayed(const Duration(milliseconds: 2500));
    final authenticated = await _hasValidSession();
    await minimumSplash;
    if (mounted) widget.onInitializationComplete(authenticated);
  }

  Future<bool> _hasValidSession() async {
    final auth = getIt<AuthService>();
    final token = await auth.token;
    if (token == null || token.isEmpty) return false;

    try {
      await auth.currentUser().timeout(const Duration(seconds: 10));
      return true;
    } on AuthException catch (e) {
      // A 401 means the token is invalid (already cleared by AuthService).
      return e.statusCode != 401;
    } catch (_) {
      // Offline or slow server: keep the session and let the screens report errors.
      return true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final backgroundColor = isDark ? const Color(0xFF0A1929) : const Color(0xFFF7F4EF);
    final textColor = isDark ? const Color(0xFFE3F2FD) : const Color(0xFF3E2723);
    final accentColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF6D4C41);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Book icon
                    Icon(
                      Icons.auto_stories,
                      size: 80,
                      color: accentColor,
                    ),
                    const SizedBox(height: 24),
                    // App name
                    Text(
                      'Book Elf',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jouw digitale boekenkast',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.7),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
