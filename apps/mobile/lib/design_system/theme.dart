import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Tokens {
  static const cream = Color(0xfff8f9f5);
  static const graphite = Color(0xff101413);
  static const green = Color(0xff2e7346);
  static const paleGreen = Color(0xff94d9aa);
  static const warning = Color(0xff855400);
  static const critical = Color(0xffb1362c);
  static const radius = 24.0;
  static const space = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0, 48.0];

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(seedColor: green, brightness: brightness).copyWith(
          primary: dark ? paleGreen : green,
          onPrimary: dark ? graphite : Colors.white,
          surface: dark ? graphite : cream,
          surfaceContainer: dark ? const Color(0xff1b211e) : Colors.white,
          surfaceContainerHighest: dark
              ? const Color(0xff242c27)
              : const Color(0xffedf1eb),
          onSurface: dark ? const Color(0xfff0f3ee) : const Color(0xff17221b),
          onSurfaceVariant: dark
              ? const Color(0xffbac4bd)
              : const Color(0xff626d66),
          outlineVariant: dark
              ? const Color(0xff323c35)
              : const Color(0xffe4e9e2),
          primaryContainer: dark
              ? const Color(0xff203b2b)
              : const Color(0xffe6f1e6),
          onPrimaryContainer: dark
              ? const Color(0xffc3edcd)
              : const Color(0xff235a35),
          error: dark ? const Color(0xffffb4a9) : critical,
        );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'EatMeSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'EatMeDisplay',
          height: 1.02,
          fontSize: 35,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'EatMeDisplay',
          height: 1.08,
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'EatMeDisplay',
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontFamily: 'EatMeSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontFamily: 'EatMeDisplay',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          letterSpacing: 0,
          height: 1.35,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        ),
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        iconColor: scheme.primary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 0.10),
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          backgroundColor: dark ? const Color(0xff327f49) : green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide.none,
          backgroundColor: scheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
