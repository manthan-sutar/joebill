import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary  = Color(0xFF0D0D1A);
const kSurface  = Color(0xFF13132B);
const kCard     = Color(0xFF1C1C3A);
const kCardAlt  = Color(0xFF222244);
const kAccent   = Color(0xFFE94560);
const kGreen    = Color(0xFF00C896);
const kAmber    = Color(0xFFFFB347);
const kBlue     = Color(0xFF4A9EFF);
const kTextLight = Color(0xFFF2F2F2);
const kTextMuted = Color(0xFF7A7A9A);
const kDivider   = Color(0xFF252545);

// Consistent spacing scale
const double kSpaceXS  = 4;
const double kSpaceSM  = 8;
const double kSpaceMD  = 16;
const double kSpaceLG  = 24;
const double kSpaceXL  = 32;
const double kSpaceXXL = 48;

// Consistent radius scale
const double kRadiusSM  = 8;
const double kRadiusMD  = 12;
const double kRadiusLG  = 16;
const double kRadiusXL  = 20;
const double kRadiusXXL = 28;

// Consistent padding presets
const kPadPage    = EdgeInsets.all(kSpaceMD);
const kPadCard    = EdgeInsets.all(kSpaceMD);
const kPadCardLG  = EdgeInsets.all(kSpaceLG);

ThemeData buildTheme() {
  final base = ThemeData.dark();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: kAccent,
      secondary: kGreen,
      surface: kSurface,
      onPrimary: Colors.white,
      onSurface: kTextLight,
    ),
    scaffoldBackgroundColor: kPrimary,

    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLG)),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kTextLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: kTextLight,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: kTextLight, size: 22),
    ),

    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(color: kTextLight, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.poppins(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 26),
      titleLarge: GoogleFonts.poppins(color: kTextLight, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: GoogleFonts.poppins(color: kTextLight, fontWeight: FontWeight.w600, fontSize: 15),
      bodyLarge: GoogleFonts.poppins(color: kTextLight, fontSize: 15),
      bodyMedium: GoogleFonts.poppins(color: kTextLight, fontSize: 13),
      bodySmall: GoogleFonts.poppins(color: kTextMuted, fontSize: 12),
      labelSmall: GoogleFonts.poppins(color: kTextMuted, fontSize: 11, letterSpacing: 0.8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceMD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMD),
        borderSide: const BorderSide(color: kDivider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMD),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      labelStyle: GoogleFonts.poppins(color: kTextMuted, fontSize: 13),
      hintStyle: GoogleFonts.poppins(color: kTextMuted, fontSize: 13),
      prefixIconColor: kTextMuted,
      suffixIconColor: kTextMuted,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kAccent.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white54,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMD)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: kSpaceLG),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
        minimumSize: const Size(0, 50),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextLight,
        side: const BorderSide(color: kDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMD)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: kSpaceLG),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        minimumSize: const Size(0, 48),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTextMuted,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: kSpaceSM, vertical: kSpaceXS),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLG)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kAccent,
      unselectedItemColor: kTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: kCardAlt,
      selectedColor: kAccent.withValues(alpha: 0.2),
      labelStyle: GoogleFonts.poppins(color: kTextLight, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSM)),
      side: const BorderSide(color: kDivider),
      padding: const EdgeInsets.symmetric(horizontal: kSpaceSM, vertical: kSpaceXS),
    ),

    dividerTheme: const DividerThemeData(color: kDivider, space: 1, thickness: 1),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceXS),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMD)),
      tileColor: Colors.transparent,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: kCard,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusXL)),
      titleTextStyle: GoogleFonts.poppins(
        color: kTextLight,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: GoogleFonts.poppins(color: kTextLight, fontSize: 14),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: kCardAlt,
      contentTextStyle: GoogleFonts.poppins(color: kTextLight, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMD)),
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.all(kSpaceMD),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kGreen : kTextMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kGreen.withValues(alpha: 0.3) : kDivider),
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor: kAccent,
      labelColor: kAccent,
      unselectedLabelColor: kTextMuted,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
      dividerColor: kDivider,
    ),
  );
}
