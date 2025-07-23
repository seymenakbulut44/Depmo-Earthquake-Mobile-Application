import 'package:flutter/material.dart';

class DepmoDesign {
  // Uygulama adı
  static const String appName = 'DEPMO';

  // Font ailesi
  static const String fontFamily = 'Montserrat';

  // Renkler
  static const Color primaryColor = Color(0xFFE50000);
  static const Color secondaryColor = Colors.redAccent;// Logo'daki Depmo kırmızısı
  static const Color primaryBlack = Color(0xFF000000);
  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFEEEEEE);

  // Deprem büyüklüğü renkleri (mevcut kodunuzdaki gibi)
  static const Color magnitudeLow = Colors.green;       // < 3.0
  static const Color magnitudeMediumLow = Colors.yellow;  // 3.0-4.0
  static const Color magnitudeMedium = Colors.orange;     // 4.0-5.0
  static const Color magnitudeMediumHigh = Colors.deepOrange; // 5.0-6.0
  static const Color magnitudeHigh = Colors.red;        // > 6.0

  // Metin Stilleri
  static const TextStyle headlineStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    fontSize: 22.0,
    color: primaryBlack,
  );

  static const TextStyle titleStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    fontSize: 18.0,
    color: primaryBlack,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    color: primaryBlack,
  );

  static const TextStyle captionStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    color: grey,
  );

  // Buton Stilleri
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: white,
    textStyle: const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Deprem büyüklüğüne göre renk döndüren yardımcı fonksiyon
  static Color getMagnitudeColor(double magnitude) {
    if (magnitude < 3.0) {
      return magnitudeLow;
    } else if (magnitude < 4.0) {
      return magnitudeMediumLow;
    } else if (magnitude < 5.0) {
      return magnitudeMedium;
    } else if (magnitude < 6.0) {
      return magnitudeMediumHigh;
    } else {
      return magnitudeHigh;
    }
  }

  // Uygulama Teması
  static ThemeData getAppTheme({required bool isDarkMode}) {
    if (isDarkMode) {
      return getDarkTheme();
    }

    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: white,
          letterSpacing: 1.2,
        ),
      ),
      useMaterial3: true,
    );
  }
  // Koyu tema
  static ThemeData getDarkTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      primarySwatch: Colors.red,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Color(0xFF1F1F1F),
        background: Color(0xFF121212),
        error: Colors.redAccent,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1F1F1F),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      fontFamily: 'Montserrat',
    );
  }

}

