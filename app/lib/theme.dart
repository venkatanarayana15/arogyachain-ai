// theme.dart — design tokens. Data-dense enterprise console, teal, restrained.
// Every risk signal carries a WORD as well as a colour: colour alone fails for
// ~8% of men and fails entirely on a field-clinic projector.

import 'package:flutter/material.dart';

/// 4/8dp rhythm. Dense because a District Health Officer scans 30+ rows.
class Gap {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

class AppColors {
  static const primary = Color(0xFF0B6E4F);
  static const primaryDark = Color(0xFF07513B);
  static const primaryLight = Color(0xFFE6F2ED);

  static const critical = Color(0xFFB91C1C);
  static const criticalBg = Color(0xFFFEE2E2);
  static const warn = Color(0xFFB45309);
  static const warnBg = Color(0xFFFEF3C7);
  static const healthy = Color(0xFF15803D);
  static const healthyBg = Color(0xFFDCFCE7);
  static const info = Color(0xFF1D4ED8);
  static const infoBg = Color(0xFFDBEAFE);

  static const bg = Color(0xFFF6F8F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAFBFC);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF475569); // 7.6:1 on white
  static const inkFaint = Color(0xFF64748B); // 4.8:1 on white
}

class AppText {
  /// Tabular figures so digits align down every numeric column.
  static const tabular = [FontFeature.tabularFigures(), FontFeature.slashedZero()];

  static const display = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6,
      color: AppColors.ink, height: 1.15);
  static const title = TextStyle(
      fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.2,
      color: AppColors.ink);
  static const section = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9,
      color: AppColors.inkFaint);
  static const body = TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4);
  static const bodyMuted =
      TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.4);
  static const label =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const numeric = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink,
      fontFeatures: tabular);
  static const mono = TextStyle(
      fontSize: 12, fontFamily: 'monospace', color: AppColors.inkMuted, height: 1.35);
  static const caption =
      TextStyle(fontSize: 12, color: AppColors.inkFaint, height: 1.35);
}

enum Severity { critical, high, watch, healthy }

class SeverityStyle {
  final Severity level;
  final Color fg, bg;
  final String label;
  const SeverityStyle(this.level, this.fg, this.bg, this.label);

  static SeverityStyle of(double r) {
    if (r >= 80) return const SeverityStyle(Severity.critical,
        AppColors.critical, AppColors.criticalBg, 'CRITICAL');
    if (r >= 60) return const SeverityStyle(
        Severity.high, AppColors.warn, AppColors.warnBg, 'HIGH');
    if (r >= 30) return const SeverityStyle(
        Severity.watch, AppColors.info, AppColors.infoBg, 'WATCH');
    return const SeverityStyle(
        Severity.healthy, AppColors.healthy, AppColors.healthyBg, 'HEALTHY');
  }
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.info,
    onSecondary: Colors.white,
    error: AppColors.critical,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    focusColor: AppColors.primary.withValues(alpha: 0.14),
    dividerTheme: const DividerThemeData(
        color: AppColors.border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40), // 40px + padding clears 44dp target
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: AppColors.borderStrong),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 11),
      hintStyle: AppText.bodyMuted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration:
          BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      waitDuration: const Duration(milliseconds: 400),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      selectedIconTheme:
          const IconThemeData(color: AppColors.primary, size: 22),
      unselectedIconTheme:
          const IconThemeData(color: AppColors.inkFaint, size: 22),
      selectedLabelTextStyle: const TextStyle(
          color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle:
          const TextStyle(color: AppColors.inkFaint, fontSize: 12),
      indicatorColor: AppColors.primaryLight,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      height: 66,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Surface with an optional header row. Every view uses this so the vertical
/// rhythm is identical across the product.
class PanelCard extends StatelessWidget {
  final String? title, subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  const PanelCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
  });

  @override
  Widget build(BuildContext c) => Card(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title!, style: AppText.title),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(subtitle!, style: AppText.caption),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: Gap.lg),
              ],
              child,
            ],
          ),
        ),
      );
}

/// Status pill. Always shows text — never colour alone.
/// The Text is Flexible so a pill in a tight column ellipsizes instead of
/// overflowing its parent.
class StatusPill extends StatelessWidget {
  final String text;
  final Color fg, bg;
  final IconData? icon;
  final bool dense;
  const StatusPill(this.text,
      {super.key, required this.fg, required this.bg, this.icon, this.dense = false});

  factory StatusPill.severity(double r, {bool dense = false}) {
    final s = SeverityStyle.of(r);
    return StatusPill(s.label, fg: s.fg, bg: s.bg, dense: dense);
  }

  @override
  Widget build(BuildContext c) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 8, vertical: dense ? 2 : 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 11 : 13, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: dense ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      );
}

/// KPI tile: one number, one label, one line of context.
class KpiTile extends StatelessWidget {
  final String label, value, caption;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? tooltip;
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext c) {
    final tile = Semantics(
      button: onTap != null,
      label: '$label: $value. $caption',
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(label.toUpperCase(),
                      style: AppText.section,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(value,
                style: AppText.display
                    .copyWith(fontSize: 30, fontFeatures: AppText.tabular)),
            const SizedBox(height: Gap.xs),
            Text(caption, style: AppText.caption, maxLines: 2),
          ],
        ),
      ),
    );
    final wrapped =
        onTap == null ? tile : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: tile);
    return tooltip == null ? wrapped : Tooltip(message: tooltip!, child: wrapped);
  }
}

/// Empty state. Never a bare "No data" — says what would be here and why.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(Gap.lg),
                decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt, shape: BoxShape.circle),
                child: Icon(icon, size: 26, color: AppColors.inkFaint),
              ),
              const SizedBox(height: Gap.lg),
              Text(title,
                  style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: Gap.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(message,
                    style: AppText.bodyMuted, textAlign: TextAlign.center),
              ),
              if (action != null) ...[
                const SizedBox(height: Gap.lg),
                action!,
              ],
            ],
          ),
        ),
      );
}

/// Thin risk meter. Screen readers get the number, not a colour.
class RiskMeter extends StatelessWidget {
  final double value;
  const RiskMeter({super.key, required this.value});

  @override
  Widget build(BuildContext c) {
    final s = SeverityStyle.of(value);
    return Semantics(
      label: 'Risk ${value.round()} percent, ${s.label}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(s.fg),
          ),
        ),
      ),
    );
  }
}

/// Page header used at the top of every view.
class ViewHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ViewHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.display.copyWith(fontSize: 24)),
                  if (subtitle != null) ...[
                    const SizedBox(height: Gap.xs),
                    Text(subtitle!, style: AppText.bodyMuted),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(
                  spacing: Gap.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions),
          ],
        ),
      );
}
