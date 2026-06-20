import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/storage/hive_storage.dart';
import 'features/notifications/data/notification_service.dart';

/// Global navigator key shared between [GoRouter] and [NotificationService]
/// so that FCM-driven navigation can occur outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    bool firebaseInitialized = false;
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
    } catch (e) {
      debugPrint('Firebase initialization failed: $e. Running in dev-mode without Firebase.');
    }

    await Hive.initFlutter();
    await HiveStorage.init();

    if (firebaseInitialized) {
      try {
        // Set up FCM listeners (foreground, background tap, terminated state).
        // Must be called after Firebase.initializeApp() and Hive.init().
        await NotificationService.initialize(navigatorKey);
      } catch (e) {
        debugPrint('Failed to initialize FCM listeners: $e');
      }
    }
  }

  runApp(const ProviderScope(child: StudioGalleryApp()));
}

class StudioGalleryApp extends ConsumerWidget {
  const StudioGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Studio Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

/// Centralised theme definition for the Studio Gallery app.
///
/// Uses a rich dark palette inspired by premium photography apps:
/// - Background: near-black (#0D0D0D)
/// - Surface: dark charcoal (#1A1A1A)
/// - Primary accent: warm gold (#E8B86D)
/// - Secondary accent: rose pink (#E87070)
abstract class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const _primaryGold = Color(0xFFE8B86D);
  static const _onPrimary = Color(0xFF1A1100);
  static const _secondaryRose = Color(0xFFE87070);
  static const _bgDark = Color(0xFF0D0D0D);
  static const _surfaceDark = Color(0xFF1A1A1A);
  static const _surfaceVariantDark = Color(0xFF262626);
  static const _onSurfaceDark = Color(0xFFF2F2F2);
  static const _onSurfaceVariantDark = Color(0xFFAAAAAA);

  // ── Dark theme (primary) ───────────────────────────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryGold,
      onPrimary: _onPrimary,
      secondary: _secondaryRose,
      onSecondary: Colors.white,
      surface: _surfaceDark,
      onSurface: _onSurfaceDark,
      surfaceContainerHighest: _surfaceVariantDark,
      onSurfaceVariant: _onSurfaceVariantDark,
      error: Color(0xFFFF6B6B),
      outline: Color(0xFF3A3A3A),
    ),
    scaffoldBackgroundColor: _bgDark,
    // ── AppBar ────────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: _bgDark,
      foregroundColor: _onSurfaceDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: _onSurfaceDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    // ── Cards ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: _surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2E2E2E)),
      ),
      margin: EdgeInsets.zero,
    ),
    // ── Input fields ──────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceVariantDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
      labelStyle: const TextStyle(color: _onSurfaceVariantDark),
      hintStyle: const TextStyle(color: Color(0xFF555555)),
      prefixIconColor: _onSurfaceVariantDark,
      suffixIconColor: _onSurfaceVariantDark,
    ),
    // ── Filled buttons ────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primaryGold,
        foregroundColor: _onPrimary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),
    // ── Text buttons ──────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryGold,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    // ── Segmented button ──────────────────────────────────────────────────────
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryGold;
          return _surfaceVariantDark;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _onPrimary;
          return _onSurfaceVariantDark;
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    // ── Dividers ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E2E2E),
      thickness: 1,
      space: 1,
    ),
    // ── Icon theme ────────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: _onSurfaceVariantDark),
    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceVariantDark,
      selectedColor: _primaryGold.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: _onSurfaceDark, fontSize: 12),
      side: const BorderSide(color: Color(0xFF3A3A3A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    // ── ListTile ──────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: _onSurfaceVariantDark,
      textColor: _onSurfaceDark,
    ),
    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceVariantDark,
      contentTextStyle: const TextStyle(color: _onSurfaceDark),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // ── Text ──────────────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineLarge: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: _onSurfaceDark),
      bodyMedium: TextStyle(color: _onSurfaceVariantDark),
      bodySmall: TextStyle(color: Color(0xFF777777), fontSize: 12),
      labelLarge: TextStyle(
        color: _onSurfaceDark,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );

  // ── Light theme ───────────────────────────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _primaryGold,
      onPrimary: _onPrimary,
      secondary: _secondaryRose,
      onSecondary: Colors.white,
      surface: Color(0xFFF7F7F7),
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: Color(0xFFEEEEEE),
      onSurfaceVariant: Color(0xFF666666),
      error: Color(0xFFD32F2F),
      outline: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFF5F5F5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEEEEEE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF666666)),
      hintStyle: const TextStyle(color: Color(0xFF999999)),
      prefixIconColor: const Color(0xFF666666),
      suffixIconColor: const Color(0xFF666666),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primaryGold,
        foregroundColor: _onPrimary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryGold,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5E5E5),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: Color(0xFF666666),
      textColor: Color(0xFF1A1A1A),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF333333),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineLarge: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF666666)),
      bodySmall: TextStyle(color: Color(0xFF999999), fontSize: 12),
      labelLarge: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}
