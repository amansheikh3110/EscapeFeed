import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/app_selector_screen.dart';
import 'screens/settings_screen.dart';
import 'services/timer_manager.dart';
import 'services/theme_notifier.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerManager()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: const CtrlApp(),
    ),
  );
}

class CtrlApp extends StatelessWidget {
  const CtrlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'ctrl.',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/selector': (_) => const AppSelectorScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }

  ThemeData _darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFFA78BFA),
        secondary: const Color(0xFF6366F1),
        surface: const Color(0xFF111113),
        error: kColorDanger,
      ),
      extensions: const [CtrlColors.dark],
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF7C3AED),
        secondary: const Color(0xFF4F46E5),
        surface: Colors.white,
        error: kColorDanger,
      ),
      extensions: const [CtrlColors.light],
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }
}
