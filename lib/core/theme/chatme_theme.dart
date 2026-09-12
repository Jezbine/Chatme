import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Extension thème-aware pour accès rapide depuis BuildContext
/// Spec §6 : toujours passer par Theme.of(context)
extension ChatMeThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  /// Bulle envoyée : #E9E6F7 en clair, #2A2560 en sombre (spec §2/§3)
  Color get bubbleSent => isDark ? ChatMeColors.darkSurfaceBubbleSent : ChatMeColors.surfaceBubbleSent;
  /// Bulle reçue : surface
  Color get bubbleReceived => cs.surfaceContainerHighest;
  Color get textPrimary => cs.onSurface;
  Color get textSecondary => cs.onSurfaceVariant;
}

/// ThemeExtension pour bulles — permet `Theme.of(context).extension<ChatMeBubbleTheme>()` !
@immutable
class ChatMeBubbleTheme extends ThemeExtension<ChatMeBubbleTheme> {
  final Color sent;
  final Color received;
  final Color sentText;
  final Color receivedText;
  const ChatMeBubbleTheme({
    required this.sent,
    required this.received,
    required this.sentText,
    required this.receivedText,
  });
  @override
  ChatMeBubbleTheme copyWith({Color? sent, Color? received, Color? sentText, Color? receivedText}) =>
      ChatMeBubbleTheme(
        sent: sent ?? this.sent,
        received: received ?? this.received,
        sentText: sentText ?? this.sentText,
        receivedText: receivedText ?? this.receivedText,
      );
  @override
  ChatMeBubbleTheme lerp(ThemeExtension<ChatMeBubbleTheme>? other, double t) {
    if (other is! ChatMeBubbleTheme) return this;
    return ChatMeBubbleTheme(
      sent: Color.lerp(sent, other.sent, t)!,
      received: Color.lerp(received, other.received, t)!,
      sentText: Color.lerp(sentText, other.sentText, t)!,
      receivedText: Color.lerp(receivedText, other.receivedText, t)!,
    );
  }
}

class ChatMeColors {
  // === MODE CLAIR - spec §2 ===
  static const Color violet = Color(0xFF3C3489); // Primary
  static const Color violetVariant = Color(0xFF2C2566); // Primary variant
  static const Color secondary = Color(0xFF6C63B5); // Secondary / Accent
  static const Color bg = Color(0xFFFFFFFF); // Background
  static const Color surface = Color(0xFFF5F5F7); // Surface cartes/bulles reçues
  static const Color surfaceBubbleSent = Color(0xFFE9E6F7); // Bulle envoyée
  static const Color ink = Color(0xFF1A1A1A); // Texte principal
  static const Color inkSoft = Color(0xFF6E6E73); // Texte secondaire
  static const Color iconColor = Color(0xFF4A4A4A); // Icônes inactives
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color inputFill = Color(0xFFF5F5F7);
  static const Color cardBg = Color(0xFFF5F5F7);
  static const Color appBarBg = Color(0xFFFFFFFF);
  static const Color bottomNavBg = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  // Aliases compatibilité ancienne nomenclature
  static const Color violetLight = Color(0xFF6C63B5);
  static const Color violetPale = Color(0xFFE9E6F7);
  static const Color surfaceVariant = Color(0xFFF5F5F7);

  // === MODE SOMBRE - spec §3 ===
  static const Color darkPrimary = Color(0xFF6C63B5);
  static const Color darkPrimaryVariant = Color(0xFF8A82CC);
  static const Color darkSecondary = Color(0xFFA69CE0);
  static const Color darkBg = Color(0xFF121212); // jamais #000000
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceBubbleSent = Color(0xFF2A2560); // #3C3489 assombri ~30%
  static const Color darkInk = Color(0xFFF2F2F2);
  static const Color darkInkSoft = Color(0xFFA0A0A5);
  static const Color darkIcon = Color(0xFFC4C4C4);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkDivider = Color(0xFF2C2C2E);
  static const Color darkInputFill = Color(0xFF1E1E1E);
  static const Color darkCardBg = Color(0xFF1E1E1E);
  static const Color darkAppBarBg = Color(0xFF121212);
  static const Color darkBottomNavBg = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFEF5350);
  static const Color darkSuccess = Color(0xFF66BB6A);
  static const Color darkVioletPale = Color(0xFF2A2444);

  // Couleurs métier inchangées
  static const Color cProfil = Color(0xFF1D9E75);
  static const Color cDiscussion = Color(0xFF3C3489);
  static const Color cAppel = Color(0xFF378ADD);
  static const Color cDocuments = Color(0xFFBA7517);
  static const Color cReactions = Color(0xFFD4537E);
  static const Color cPortefeuille = Color(0xFF639922);
}

class ChatMeTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ChatMeColors.violet,
          brightness: Brightness.light,
        ).copyWith(
          primary: ChatMeColors.violet,
          onPrimary: Colors.white,
          primaryContainer: ChatMeColors.violetVariant,
          secondary: ChatMeColors.secondary,
          surface: ChatMeColors.surface,
          onSurface: ChatMeColors.ink,
          onSurfaceVariant: ChatMeColors.inkSoft,
          surfaceContainerHighest: ChatMeColors.surface,
          outline: ChatMeColors.border,
          error: ChatMeColors.error,
          tertiary: ChatMeColors.success,
        ),
        scaffoldBackgroundColor: ChatMeColors.bg,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: ChatMeColors.appBarBg,
          foregroundColor: ChatMeColors.ink,
          surfaceTintColor: ChatMeColors.appBarBg,
          systemOverlayStyle: SystemUiOverlayStyle.dark, // icônes sombres sur clair §2
        ),
        cardTheme: CardTheme(
          color: ChatMeColors.cardBg,
          surfaceTintColor: ChatMeColors.cardBg,
          elevation: 2, // ombre en clair §4
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ChatMeColors.border, width: 0.5),
          ),
        ),
        dividerColor: ChatMeColors.divider,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: ChatMeColors.violet,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ChatMeColors.violet,
            side: const BorderSide(color: ChatMeColors.violet),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ChatMeColors.inputFill,
          hintStyle: const TextStyle(color: ChatMeColors.inkSoft),
          labelStyle: const TextStyle(color: ChatMeColors.inkSoft),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ChatMeColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ChatMeColors.violet, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(color: ChatMeColors.error),
        ),
        iconTheme: const IconThemeData(color: ChatMeColors.iconColor),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: ChatMeColors.bottomNavBg,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: ChatMeColors.violet,
          unselectedItemColor: ChatMeColors.inkSoft,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: ChatMeColors.bg,
          surfaceTintColor: ChatMeColors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: ChatMeColors.bg,
          surfaceTintColor: ChatMeColors.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ChatMeColors.ink),
          bodySmall: TextStyle(color: ChatMeColors.inkSoft),
        ),
        extensions: const [
          ChatMeBubbleTheme(
            sent: ChatMeColors.surfaceBubbleSent,
            received: ChatMeColors.surface,
            sentText: ChatMeColors.ink,
            receivedText: ChatMeColors.ink,
          ),
        ],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ChatMeColors.darkPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: ChatMeColors.darkPrimary,
          onPrimary: Colors.white,
          primaryContainer: ChatMeColors.darkPrimaryVariant,
          secondary: ChatMeColors.darkSecondary,
          surface: ChatMeColors.darkSurface,
          onSurface: ChatMeColors.darkInk,
          onSurfaceVariant: ChatMeColors.darkInkSoft,
          surfaceContainerHighest: ChatMeColors.darkSurface,
          outline: ChatMeColors.darkBorder,
          error: ChatMeColors.darkError,
          tertiary: ChatMeColors.darkSuccess,
        ),
        scaffoldBackgroundColor: ChatMeColors.darkBg,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: ChatMeColors.darkAppBarBg,
          foregroundColor: ChatMeColors.darkInk,
          surfaceTintColor: ChatMeColors.darkAppBarBg,
          systemOverlayStyle: SystemUiOverlayStyle.light, // icônes claires sur sombre §3
        ),
        cardTheme: CardTheme(
          color: ChatMeColors.darkCardBg,
          surfaceTintColor: ChatMeColors.darkCardBg,
          elevation: 0, // pas d'ombre en sombre §4 -> bordure
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ChatMeColors.darkBorder, width: 0.8),
          ),
        ),
        dividerColor: ChatMeColors.darkDivider,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: ChatMeColors.darkPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ChatMeColors.darkPrimary,
            side: const BorderSide(color: ChatMeColors.darkPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ChatMeColors.darkInputFill,
          hintStyle: const TextStyle(color: ChatMeColors.darkInkSoft),
          labelStyle: const TextStyle(color: ChatMeColors.darkInkSoft),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ChatMeColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ChatMeColors.darkPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(color: ChatMeColors.darkError),
        ),
        iconTheme: const IconThemeData(color: ChatMeColors.darkIcon),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: ChatMeColors.darkBottomNavBg,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: ChatMeColors.darkPrimary,
          unselectedItemColor: ChatMeColors.darkInkSoft,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: ChatMeColors.darkSurface,
          surfaceTintColor: ChatMeColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: ChatMeColors.darkSurface,
          surfaceTintColor: ChatMeColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ChatMeColors.darkInk),
          bodySmall: TextStyle(color: ChatMeColors.darkInkSoft),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ChatMeColors.darkPrimary;
            return ChatMeColors.darkInkSoft;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ChatMeColors.darkPrimary.withOpacity(0.5);
            return ChatMeColors.darkBorder;
          }),
        ),
        extensions: const [
          ChatMeBubbleTheme(
            sent: ChatMeColors.darkSurfaceBubbleSent,
            received: ChatMeColors.darkSurface,
            sentText: ChatMeColors.darkInk,
            receivedText: ChatMeColors.darkInk,
          ),
        ],
      );
}
