import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'datos/local_data_service.dart';
import 'datos/supabase_config.dart';
import 'datos/supabase_database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDataService.instance.restoreOpenAttendanceSessions();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    try {
      final profile = await SupabaseDatabaseService.instance
          .restoreCurrentProfile();
      if (profile != null) {
        SessionController.instance.login(profile);
      }
    } catch (_) {}
  }
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const MyApp());
}

class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  bool get isDark => mode.value == ThemeMode.dark;

  void toggle() {
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6D28D9),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B5CF6),
      brightness: Brightness.dark,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'PracticApp',
          themeMode: mode,
          builder: (context, child) {
            final width = MediaQuery.sizeOf(context).width;
            if (width <= 520) return child ?? const SizedBox.shrink();
            final dark = Theme.of(context).brightness == Brightness.dark;
            return ColoredBox(
              color: dark ? const Color(0xFF0F172A) : const Color(0xFFE5E7F5),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF3F4FF),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          theme: _buildTheme(lightScheme, false),
          darkTheme: _buildTheme(darkScheme, true),
          routerConfig: router,
        );
      },
    );
  }
}

ThemeData _buildTheme(ColorScheme colorScheme, bool dark) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111827)
        : const Color(0xFFF3F4FF),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: dark ? Colors.white : const Color(0xFF111827),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _animatedButtonStyle(colorScheme),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _animatedButtonStyle(colorScheme),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _animatedButtonStyle(colorScheme, outlined: true),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _animatedButtonStyle(colorScheme, compact: true),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 180),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withValues(alpha: .14)
              : null,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 8,
      focusElevation: 10,
      hoverElevation: 10,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      pressElevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
  );
}

ButtonStyle _animatedButtonStyle(
  ColorScheme colorScheme, {
  bool outlined = false,
  bool compact = false,
}) {
  return ButtonStyle(
    animationDuration: const Duration(milliseconds: 190),
    minimumSize: WidgetStatePropertyAll(Size(compact ? 36 : 44, 42)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 8 : 12,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? colorScheme.primary.withValues(alpha: outlined ? .12 : .18)
          : null,
    ),
  );
}
