import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared building blocks for the member-facing pages.
///
/// Every page that uses these reads the same way: a white page, blue section
/// headings, near-black body copy and white cards lifted off the background
/// with a soft shadow. Screens should pull colours and text styles from here
/// rather than hardcoding `Colors.white` / `Colors.black54`, which silently
/// break whenever the theme flips.
class AppUI {
  static const double cardRadius = 16;
  static const EdgeInsets pagePadding = EdgeInsets.all(16);

  // ─── Colours ───────────────────────────────────────────────────────────────

  /// Page background — white on the white theme, app blue on the blue theme.
  static Color get pageBg => AppColors.bg;

  /// Section headings and labels: blue on the white theme, yellow on the
  /// blue theme.
  static Color get heading => AppColors.cardHeading;

  /// Body copy sitting on a card.
  static Color get body => AppColors.onCard;

  /// De-emphasised body copy (captions, secondary rows).
  static Color get muted => AppColors.onCardMuted;

  static Color get divider => AppColors.onCardDivider;

  // ─── Text styles ───────────────────────────────────────────────────────────

  /// Small uppercase label above a block of content.
  static TextStyle sectionLabel({double size = 12}) => TextStyle(
        color: heading,
        fontSize: size,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );

  /// Blue heading for a card or page section.
  static TextStyle headingText({double size = 16}) => TextStyle(
        color: heading,
        fontSize: size,
        fontWeight: FontWeight.bold,
      );

  /// Black title inside a card.
  static TextStyle titleText({double size = 16}) => TextStyle(
        color: body,
        fontSize: size,
        fontWeight: FontWeight.bold,
      );

  static TextStyle bodyText({double size = 14, FontWeight? weight}) => TextStyle(
        color: body,
        fontSize: size,
        fontWeight: weight,
      );

  static TextStyle mutedText({double size = 12}) => TextStyle(
        color: muted,
        fontSize: size,
      );

  // ─── Elevation ─────────────────────────────────────────────────────────────

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 6),
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  // ─── Web-matched card recipe ───────────────────────────────────────────────
  // Mirrors the values in the web app's app.css so the two clients agree:
  //   background:    linear-gradient(180deg, #244fa0 0%, #1d428a 100%)
  //   border-radius: var(--rmb-radius)  -> 15px
  //   box-shadow:    var(--rmb-shadow)  -> 0 4px 24px rgba(14, 33, 72, 0.35)
  //   border:        1px solid rgba(255, 255, 255, 0.28)

  static const double webRadius = 15;

  /// rgba(14, 33, 72, 0.35) -> 0.35 * 255 = 89 = 0x59
  static List<BoxShadow> get webShadow => const [
        BoxShadow(
          color: Color(0x590E2148),
          blurRadius: 24,
          offset: Offset(0, 4),
        ),
      ];

  /// var(--rmb-shadow-lg): 0 12px 40px rgba(14, 33, 72, 0.45)
  static List<BoxShadow> get webShadowLg => const [
        BoxShadow(
          color: Color(0x730E2148),
          blurRadius: 40,
          offset: Offset(0, 12),
        ),
      ];

  /// The standard dashboard card surface.
  static BoxDecoration get panel => BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(webRadius),
        border: Border.all(color: AppColors.accentBorder, width: 1.5),
        boxShadow: webShadow,
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.accentBorder, width: 1.5),
        boxShadow: cardShadow,
      );

  // ─── Date picker ───────────────────────────────────────────────────────────

  /// Shared `builder` for showDatePicker. The pickers used to set
  /// `onSurface: AppColors.card`, which is white on the white theme — the day
  /// numbers were white on a white sheet and effectively invisible.
  static Widget datePickerTheme(BuildContext context, Widget? child) {
    const blue = Color(0xFF1D428A);
    const ink = Color(0xFF111827);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: blue,          // header band + selected day
          onPrimary: Colors.white, // text on the header band
          onSurface: ink,          // day numbers
          surface: Colors.white,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: blue, width: 1.5),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: blue,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      child: child!,
    );
  }

  // ─── App bar ───────────────────────────────────────────────────────────────

  /// Blue app bar with white content, consistent across every page.
  static AppBar appBar(
    String title, {
    VoidCallback? onBack,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      backgroundColor: AppColors.appBar,
      foregroundColor: Colors.white,
      elevation: 2,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// A white, rounded, elevated surface — the standard container for content.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: AppUI.cardDecoration,
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: onTap,
      child: card,
    );
  }
}

/// Blue section heading with an optional leading icon, used above card groups.
class AppSectionHeading extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;

  const AppSectionHeading(this.text, {super.key, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppUI.heading, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(text, style: AppUI.headingText())),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Consistent empty state for lists that have no rows yet.
class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const AppEmptyState(this.message,
      {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppUI.mutedText(size: 13),
          ),
        ],
      ),
    );
  }
}
