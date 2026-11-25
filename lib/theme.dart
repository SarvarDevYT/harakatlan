import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Qadam Qal'a colour tokens (same values as the design canvas).
class QC {
  static const bg = Color(0xFF0B0B0B);
  static const surface = Color(0xFF171717);
  static const surface2 = Color(0xFF222222);
  static const navBg = Color(0xEB1B1B1B);
  static const lime = Color(0xFFD4FF3F);
  static const limeDark = Color(0xFF7E9A1E);
  static const text = Color(0xFFF5F5F2);
  static const textSoft = Color(0xFFC9C9C4);
  static const muted = Color(0xFFA3A39D);
  static const glass = Color(0x0DFFFFFF);
  static const glassBorder = Color(0x14FFFFFF);
  static const outline = Color(0xFF3A3A38);
  static const blue = Color(0xFF6E94E0);
  static const blueSoft = Color(0xFF8DB4F2);
  static const orange = Color(0xFFF2B36B);
  static const gold = Color(0xFFF2C94C);
  static const red = Color(0xFFFF5A4E);
}

TextStyle display(double size,
        {Color color = QC.text,
        FontWeight weight = FontWeight.w700,
        double? height,
        double letterSpacing = -0.3}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing);

TextStyle body(double size,
        {Color color = QC.text, FontWeight weight = FontWeight.w400, double? height}) =>
    GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: height);

TextStyle hand(double size, {Color color = QC.lime}) =>
    GoogleFonts.caveat(fontSize: size, color: color, fontWeight: FontWeight.w700, height: 1);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: QC.bg,
    colorScheme: const ColorScheme.dark(
      primary: QC.lime,
      onPrimary: QC.bg,
      surface: QC.surface,
      onSurface: QC.text,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
      bodyColor: QC.text,
      displayColor: QC.text,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: QC.lime,
      contentTextStyle: body(14, color: QC.bg, weight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QC.glass,
      hintStyle: body(15, color: QC.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: QC.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: QC.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: QC.lime, width: 1.5),
      ),
    ),
  );
}
