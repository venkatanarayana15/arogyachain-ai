// shell.dart — app shell: top bar, navigation, responsive routing.
//
// Responsive strategy (LayoutBuilder, per Flutter guidance — no fixed widths):
//   >= 900px  persistent NavigationRail  (District Health Officer on a laptop)
//   <  900px  bottom NavigationBar         (PHC pharmacist on a phone)
// Identical view content either way, so the recorded demo works at any size.

import 'package:flutter/material.dart';

import 'theme.dart';

enum AppView { command, facility, transfers, evidence }

class NavDest {
  final AppView view;
  final String label;
  final IconData icon, selected;
  final String tooltip;
  const NavDest(this.view, this.label, this.icon, this.selected, this.tooltip);
}

const kDests = <NavDest>[
  NavDest(AppView.command, 'Command', Icons.dashboard_outlined, Icons.dashboard,
      'District-wide risk overview'),
  NavDest(AppView.facility, 'Facility', Icons.local_pharmacy_outlined,
      Icons.local_pharmacy, 'Facility inventory and voice capture'),
  NavDest(AppView.transfers, 'Transfers', Icons.swap_horiz_outlined,
      Icons.swap_horiz, 'Redistribution approval queue'),
  NavDest(AppView.evidence, 'Evidence', Icons.insights_outlined, Icons.insights,
      'Model validation and disclosed limits'),
];

const double kRailBreakpoint = 900;

class AppShell extends StatelessWidget {
  final AppView view;
  final ValueChanged<AppView> onView;
  final Widget body;
  final String facilityLabel;
  final bool demoMode;
  final VoidCallback? onFacilitySwitch;
  final List<Widget> actions;

  const AppShell({
    super.key,
    required this.view,
    required this.onView,
    required this.body,
    required this.facilityLabel,
    required this.demoMode,
    this.onFacilitySwitch,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= kRailBreakpoint;
          return Scaffold(
            appBar: _topBar(wide),
            body: wide
                ? Row(children: [
                    _rail(),
                    const VerticalDivider(width: 1),
                    Expanded(child: _body(wide)),
                  ])
                : _body(false),
            bottomNavigationBar: wide ? null : _bottomBar(),
          );
        },
      );

  Widget _body(bool wide) => Container(
        color: AppColors.bg,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1500 : 720),
              // SizedBox(double.infinity) is load-bearing: without it a Column
              // sizes to its widest child instead of the viewport, so a wide
              // table child can push the whole page off-screen.
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? Gap.xl : Gap.md,
                    Gap.xl,
                    wide ? Gap.xl : Gap.md,
                    wide ? Gap.xl : 88, // clear the bottom bar
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // On a phone the AppBar cannot hold title + facility
                      // switcher + badge. The badge is a credibility signal, so
                      // it moves into the content rather than being clipped.
                      if (demoMode && !wide) ...[
                        const DemoBanner(),
                        const SizedBox(height: Gap.lg),
                      ],
                      body,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  PreferredSizeWidget _topBar(bool wide) => AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: wide ? Gap.xl : Gap.md,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.health_and_safety_outlined,
                  size: 17, color: Colors.white),
            ),
            const SizedBox(width: Gap.md),
            const Text('ArogyaChain AI',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            if (wide) ...[
              const SizedBox(width: Gap.md),
              Container(width: 1, height: 20, color: AppColors.border),
              const SizedBox(width: Gap.md),
              _facilityPill(),
            ],
          ],
        ),
        actions: [
          if (!wide) _facilityIcon(),
          ...actions,
          if (demoMode && wide) ...[
            Tooltip(
              message: 'Synthetic dataset. No real patient data is used.',
              child: const Padding(
                padding: EdgeInsets.only(right: Gap.md),
                child: StatusPill('DEMO MODE',
                    fg: AppColors.warn,
                    bg: AppColors.warnBg,
                    icon: Icons.info_outline),
              ),
            ),
          ],
          const SizedBox(width: Gap.sm),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      );

  /// Compact switcher for narrow viewports; full label lives in the tooltip
  /// and in the Facility view header, so nothing is lost — only moved.
  Widget _facilityIcon() => Tooltip(
        message: 'Facility: $facilityLabel — tap to switch',
        child: IconButton(
          onPressed: onFacilitySwitch,
          icon: const Icon(Icons.apartment_outlined, size: 20),
          color: AppColors.inkMuted,
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _facilityPill() => Tooltip(
        message: 'Acting as District Health Officer, Thiruvallur district',
        child: InkWell(
          onTap: onFacilitySwitch,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment_outlined,
                    size: 15, color: AppColors.inkFaint),
                const SizedBox(width: Gap.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(facilityLabel,
                      style: AppText.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more,
                    size: 15, color: AppColors.inkFaint),
              ],
            ),
          ),
        ),
      );

  Widget _rail() => NavigationRail(
        selectedIndex: kDests.indexWhere((d) => d.view == view),
        onDestinationSelected: (i) => onView(kDests[i].view),
        labelType: NavigationRailLabelType.all,
        destinations: kDests
            .map((d) => NavigationRailDestination(
                  icon: Tooltip(message: d.tooltip, child: Icon(d.icon)),
                  selectedIcon: Icon(d.selected),
                  label: Text(d.label),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ))
            .toList(),
      );

  Widget _bottomBar() => NavigationBar(
        selectedIndex: kDests.indexWhere((d) => d.view == view),
        onDestinationSelected: (i) => onView(kDests[i].view),
        destinations: kDests
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                  tooltip: d.tooltip,
                ))
            .toList(),
      );
}

/// Honesty banner for narrow viewports. Stating the demo condition is part of
/// the product's credibility, so it must never be the thing that gets clipped.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        decoration: BoxDecoration(
          color: AppColors.warnBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.warn.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.warn),
            const SizedBox(width: Gap.sm),
            const Expanded(
              child: Text('DEMO MODE · synthetic dataset, no real patient data',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.warn, height: 1.3)),
            ),
          ],
        ),
      );
}
