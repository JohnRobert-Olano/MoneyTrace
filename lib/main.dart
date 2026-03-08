import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_ai_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

// Global ValueNotifier to instantly react to Theme changes across the app
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  
  // Initialize AI in the background so it doesn't block the UI and cause a black screen
  LocalAIService.instance.initialize().ignore();
  
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

  // Load saved theme if any
  final savedTheme = prefs.getString('themeMode') ?? 'dark';
  if (savedTheme == 'light') {
    appThemeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'system') {
    appThemeNotifier.value = ThemeMode.system;
  } else {
    appThemeNotifier.value = ThemeMode.dark;
  }

  runApp(MoneyTraceApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class MoneyTraceApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  
  const MoneyTraceApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        final textTheme = GoogleFonts.poppinsTextTheme();
        
        return MaterialApp(
          title: 'MoneyTrace',
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            textTheme: textTheme,
            cupertinoOverrideTheme: const CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: Color(0xFF3D5AFE),
            ),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3D5AFE), // Royal Blue
              secondary: Color(0xFF00E676), // Lime Green
              primaryContainer: Colors.white,
              onPrimaryContainer: Colors.black87,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6F9), // Light Gray
            cardColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFFF4F6F9),
              foregroundColor: Colors.black87,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black87),
              titleTextStyle: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            cupertinoOverrideTheme: const CupertinoThemeData(
              brightness: Brightness.dark,
              primaryColor: Color(0xFF3D5AFE),
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3D5AFE),
              secondary: Color(0xFF00E676),
              primaryContainer: Color(0xFF1E272E),
              onPrimaryContainer: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF121212),
              elevation: 0,
              titleTextStyle: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          home: hasCompletedOnboarding ? const DashboardScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}
