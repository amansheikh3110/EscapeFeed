import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/app_selector_screen.dart';
import 'screens/settings_screen.dart';
import 'services/timer_manager.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NexusColors.void_,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => TimerManager(),
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NexusColors.void_,
    );

    return MaterialApp(
      title: 'Nexus Control',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
          bodyColor: NexusColors.textPrimary,
          displayColor: NexusColors.textBright,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: NexusColors.textBright,
            letterSpacing: 2,
          ),
          iconTheme: const IconThemeData(color: NexusColors.textSecondary),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: NexusColors.neonCyan,
          inactiveTrackColor: NexusColors.overlay,
          thumbColor: NexusColors.neonCyan,
          overlayColor: NexusColors.neonCyan.withOpacity(0.12),
          valueIndicatorColor: NexusColors.elevated,
          valueIndicatorTextStyle: const TextStyle(color: NexusColors.textBright),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        colorScheme: const ColorScheme.dark(
          primary: NexusColors.neonCyan,
          secondary: NexusColors.neonPurple,
          surface: NexusColors.surface,
          error: NexusColors.danger,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/selector': (context) => const AppSelectorScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
