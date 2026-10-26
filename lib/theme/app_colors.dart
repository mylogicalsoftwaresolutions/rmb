import 'package:flutter/material.dart';

class AppColors {
  // Theme State
  static ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true); // True = Dark Blue Theme, False = White Theme

  // App Bar and Footer
  static Color get appBar => const Color(0xFF1D428A);
  static Color get footer => const Color(0xFF1D428A);
  
  // Primary elements
  static Color get primary => const Color(0xFF1D428A);
  static Color get primaryLight => const Color(0xFF244FA0);
  static Color get primaryMid => const Color(0xFF1F3870);
  
  // Secondary (Premium Gold)
  static Color get secondary => const Color(0xFFD4AF37);
  static Color get secondaryDark => const Color(0xFFB49126);
  static Color get secondarySoft => const Color(0x2ED4AF37);

  /// Brighter yellow used for the bottom navigation bar accent — icons,
  /// labels, the Submit circle and the top rule. Deliberately distinct from
  /// the premium gold above, which stays on cards and headings.
  static Color get navAccent => const Color(0xFFFDB913);
  
  // Backgrounds
  static Color get bg => isDarkMode.value ? const Color(0xFF102A5C) : const Color(0xFFFFFFFF);
  static Color get card => isDarkMode.value ? const Color(0xFF2654A8) : const Color(0xFFFFFFFF);
  
  // Card Gradient
  static LinearGradient get cardGradient => isDarkMode.value 
      ? const LinearGradient(
          // Web: linear-gradient(180deg, #244fa0 0%, #1d428a 100%)
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF244FA0), Color(0xFF1D428A)],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF9FAFB)],
        );
  
  // Foreground colors for content sitting ON a card (AppColors.card).
  // White theme -> white card: dark text, blue labels.
  // Dark theme  -> blue card:  white text, gold labels.
  static Color get onCard => isDarkMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get onCardMuted => isDarkMode.value ? const Color(0xFFD6E0F5) : const Color(0xFF374151);
  static Color get onCardLabel => isDarkMode.value ? const Color(0xFFE3EBF9) : const Color(0xFF1D428A);
  static Color get onCardDivider => isDarkMode.value ? const Color(0x33FFFFFF) : const Color(0xFFE5E7EB);

  // Typography
  static Color get text => isDarkMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get textDark => isDarkMode.value ? const Color(0xFFF3F4F6) : const Color(0xFF111827); 
  static Color get textMuted => const Color(0xFF9CA3AF); 
  static Color get border => isDarkMode.value ? const Color(0x47FFFFFF) : const Color(0xFFE5E7EB);

  /// Stronger card outline for the activity screens (referrals, C-Notes, R2R,
  /// testimonials, Give & Ask), where the cards need to read as distinct
  /// panels against the blue background.
  static Color get borderBright =>
      isDarkMode.value ? const Color(0x8CFFFFFF) : const Color(0xFFCBD5E1);

  /// Heading accent on cards: yellow on the blue theme, blue on the white
  /// theme. Gold on white only reaches ~2.3:1 contrast, so it is not used
  /// there.
  /// Accent outline that flips with the theme: blue on the white theme,
  /// yellow on the blue theme. Used for profile cards and empty-state cards.
  static Color get accentBorder =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFF1D428A);

  // ─── Profile popup menu ────────────────────────────────────────────────────
  // The menu surface follows the platform theme, so the two entries swap
  // accents: gold reads on the dark surface, blue on the light one.

  static Color get menuPrimary =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFF244FA0);

  static Color get menuSecondary =>
      isDarkMode.value ? const Color(0xFFFFFFFF) : const Color(0xFFD4AF37);

  // ─── Utility pages (meetings, events, attendance, scan, reports, alerts) ───
  // White theme values are identical to what these screens already used, so
  // only the blue theme changes.

  static Color get pageSurface =>
      isDarkMode.value ? const Color(0xFF1D428A) : const Color(0xFFFFFFFF);

  static Color get pageCardBorder =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFFE5E7EB);

  // ─── Activity record rows ──────────────────────────────────────────────────
  // Referrals, C-Notes, R2R, Testimonials, Visitors and Give & Ask rows:
  // white card with black text and blue headings on the white theme; blue
  // card with white text and yellow headings on the blue theme.

  static Color get onRecordCard =>
      isDarkMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF111827);

  static Color get onRecordCardLabel =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFF1D428A);

  static Color get onRecordCardMuted =>
      isDarkMode.value ? const Color(0xFFD6E0F5) : const Color(0xFF4B5563);

  static Color get onRecordCardDivider =>
      isDarkMode.value ? const Color(0x33FFFFFF) : const Color(0xFFE5E7EB);

  static Color get cardHeading =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFF1D428A);

  /// Border for inputs in modals (e.g. Add Referrals Given, Log Visitor):
  /// Yellow (0xFFFFC107) in blue theme, primary blue in white theme.
  static Color get inputBorder =>
      isDarkMode.value ? const Color(0xFFFFC107) : const Color(0xFF1D428A);

  /// Border for Search Records input boxes:
  /// Yellow (0xFFFFC107) in blue theme, subtle border in white theme.
  static Color get searchBorder =>
      isDarkMode.value ? const Color(0xFFFFC107) : borderBright;

  /// Border for Chapter Leaderboard and stats page cards:
  /// Yellow (0xFFFFC107) in blue theme, subtle in white theme.
  static Color get leaderboardBorder =>
      isDarkMode.value ? const Color(0xFFFFC107) : const Color(0xFF1D428A).withValues(alpha: 0.2);

  // ─── Submit-activity bottom sheet ──────────────────────────────────────────
  // The blue-theme values below are exactly what the sheet used to hardcode,
  // so switching to these tokens leaves the blue theme untouched and only
  // gives the white theme a white sheet with blue-bordered inputs.

  static Color get modalSurface =>
      isDarkMode.value ? const Color(0xFF1D428A) : const Color(0xFFFFFFFF);

  /// Input fill on the sheet: dark navy on the blue theme, white on the
  /// white theme.
  static Color get modalInput =>
      isDarkMode.value ? const Color(0xFF102A54) : const Color(0xFFFFFFFF);

  static Color get onModal =>
      isDarkMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF111827);

  static Color get onModalMuted =>
      isDarkMode.value ? const Color(0x8AFFFFFF) : const Color(0xFF6B7280);

  /// Field labels on the sheet: gold on blue, blue on white.
  static Color get modalLabel =>
      isDarkMode.value ? const Color(0xFFD4AF37) : const Color(0xFF1D428A);

  /// The category tiles on the first step of the sheet.
  static Color get modalTile =>
      isDarkMode.value ? const Color(0xFF143864) : const Color(0xFFF3F6FC);
  
  // Sidebar
  static Color get sidebar => const Color(0xFF1D428A);
  static Color get sidebarText => const Color(0xFFFFFFFF);
  static Color get sidebarActive => const Color(0xFF244FA0);
  
  // Status Colors
  static Color get success => const Color(0xFF22C55E);
  static Color get danger => const Color(0xFFF87171);
  static Color get warning => const Color(0xFFD4AF37);
  static Color get info => const Color(0xFF38BDF8);
}
