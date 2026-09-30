// views/command_center.dart — the District Health Officer's landing page.
// Which of my facilities break first this week, and can any of them help
// each other.

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

typedef _Fac = ({String phc, double maxRisk, int critical, int pairs});

class CommandCenter extends StatefulWidget {
  final MockData data;
  final String selectedPhc;
  final ValueChanged<String> onOpenFacility;
  final List<Recommendation> recommendations;
  final int criticalCount;
  final int watchCount;
  final void Function(Recommendation) onApprove;
  const CommandCenter({
    super.key,
    required this.data,
    required this.selectedPhc,
    required this.onOpenFacility,
    required this.recommendations,
    required this.criticalCount,
    required this.watchCount,
    required this.onApprove,
  });

  @override
  State<CommandCenter> createState() => _CommandCenterState();
}

enum _Sort { urgency, name, critical }

class _CommandCenterState extends State<CommandCenter> {
  _Sort _sort = _Sort.urgency;
  bool _desc = true;
  String _query = '';
  Severity? _filter;

  List<_Fac> get _facs {
    final q = _query.trim().toLowerCase();
    final rows = <_Fac>[];
    widget.data.inventory.forEach((phc, meds) {
      if (q.isNotEmpty &&
          !phc.toLowerCase().contains(q) &&
          !widget.data.nameOf(phc).toLowerCase().contains(q)) {
        return;
      }
      var maxR = 0.0;
      var crit = 0;
      for (final m in meds.values) {
        final r = m.risk?.risk ?? 0;
        if (r > maxR) maxR = r;
        if (r >= 80) crit++;
      }
      if (_filter != null && SeverityStyle.of(maxR).level != _filter) return;
      rows.add((phc: phc, maxRisk: maxR, critical: crit, pairs: meds.length));
    });
    rows.sort((a, b) {
      final c = switch (_sort) {
        _Sort.urgency => a.maxRisk.compareTo(b.maxRisk),
        _Sort.name => a.phc.compareTo(b.phc),
        _Sort.critical => a.critical.compareTo(b.critical),
      };
      return _desc ? -c : c;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final facs = _facs;
    final totalPairs = widget.data.allRows().length;
    final recs = widget.recommendations;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ViewHeader(
        title: 'Command Center',
        subtitle: 'Thiruvallur district · 8 facilities · 7-day stock-out forecast',
      ),
      _kpis(widget.criticalCount, widget.watchCount, totalPairs, recs.length),
      const SizedBox(height: Gap.xl),
      _riskSection(facs),
      const SizedBox(height: Gap.xl),
      _lower(recs),
    ]);
  }

  Widget _kpis(int critical, int watch, int pairs, int recCount) =>
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final ratio = cols == 4 ? 1.0 : (cols == 2 ? 0.5 : 1.0);
        final tiles = <Widget>[
          KpiTile(
            label: 'Critical now',
            value: '$critical',
            caption: 'pairs at 80%+ stock-out risk',
            icon: Icons.crisis_alert,
            accent: AppColors.critical,
            tooltip: 'Risk 80+. A supervisor alert fires for these.',
          ),
          KpiTile(
              label: 'Watch list',
              value: '$watch',
              caption: 'pairs at 30-79% risk',
              icon: Icons.visibility_outlined,
              accent: AppColors.info),
          KpiTile(
              label: 'Tracked pairs',
              value: '$pairs',
              caption: 'facility x medicine, all facilities',
              icon: Icons.grid_view_outlined,
              accent: AppColors.inkFaint),
          KpiTile(
              label: 'Transfers queued',
              value: '$recCount',
              caption: 'surplus to deficit, awaiting approval',
              icon: Icons.swap_horiz,
              accent: AppColors.primary),
        ];
        return Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            for (final t in tiles)
              SizedBox(
                width: cols == 1
                    ? double.infinity
                    : c.maxWidth * ratio - Gap.md / 2,
                child: t,
              ),
          ],
        );
      });

  Widget _riskSection(List<_Fac> facs) => PanelCard(
        title: 'Facilities by urgency',
        subtitle:
            "Sorted by worst-case risk across that facility's medicines",
        trailing: _sortBtn(),
        child: facs.isEmpty
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'No facilities match',
                message: 'No facility matches this filter. Clear the search or '
                    'pick a different severity.',
              )
            : Column(children: [
                _filters(),
                const SizedBox(height: Gap.md),
                for (final f in facs) _facRow(f),
              ]),
      );

  Widget _sortBtn() => PopupMenuButton<_Sort>(
        tooltip: 'Change sort order',
        initialValue: _sort,
        onSelected: (v) => setState(() {
          _sort = v;
          _desc = true;
        }),
        itemBuilder: (c) => const [
          PopupMenuItem(
              value: _Sort.urgency,
              child: Text('Sort: worst-case risk', style: TextStyle(fontSize: 13))),
          PopupMenuItem(
              value: _Sort.critical,
              child: Text('Sort: count critical', style: TextStyle(fontSize: 13))),
          PopupMenuItem(
              value: _Sort.name,
              child: Text('Sort: facility name', style: TextStyle(fontSize: 13))),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.swap_vert, size: 15, color: AppColors.inkMuted),
            const SizedBox(width: 5),
            const Text('Sort', style: AppText.label),
          ]),
        ),
      );

  Widget _filters() => Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body,
              decoration: const InputDecoration(
                  hintText: 'Search facilities',
                  prefixIcon: Icon(Icons.search, size: 17)),
            ),
          ),
          for (final s in Severity.values) _chip(s),
        ],
      );

  Widget _chip(Severity s) {
    final st = SeverityStyle.of(switch (s) {
      Severity.critical => 85,
      Severity.high => 65,
      Severity.watch => 40,
      Severity.healthy => 10,
    });
    final on = _filter == s;
    return InkWell(
      onTap: () => setState(() => _filter = on ? null : s),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? st.bg : AppColors.surface,
          border: Border.all(
              color: on ? st.fg : AppColors.border, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (on) ...[
            Icon(Icons.check, size: 13, color: st.fg),
            const SizedBox(width: 4),
          ],
          Text(st.label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: on ? st.fg : AppColors.inkMuted)),
        ]),
      ),
    );
  }

  Widget _facRow(_Fac f) {
    final sel = f.phc == widget.selectedPhc;
    return Semantics(
      button: true,
      label: '${f.phc}, ${widget.data.nameOf(f.phc)}, worst risk '
          '${f.maxRisk.round()} percent, ${f.critical} critical',
      child: InkWell(
        onTap: () => widget.onOpenFacility(f.phc),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryLight : Colors.transparent,
            border: Border(
              bottom: const BorderSide(color: AppColors.border, width: 1),
              left: BorderSide(
                  color: sel ? AppColors.primary : Colors.transparent,
                  width: 3),
            ),
          ),
          child: Row(children: [
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(f.phc, style: AppText.numeric),
                    if (sel) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.check_circle,
                          size: 13, color: AppColors.primary),
                    ],
                  ]),
                  Text(widget.data.nameOf(f.phc),
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            SizedBox(width: 78, child: StatusPill.severity(f.maxRisk)),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: LayoutBuilder(builder: (context, c) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RiskMeter(value: f.maxRisk),
                      const SizedBox(height: 5),
                      if (c.maxWidth > 160)
                        Text(
                          '${f.pairs} medicine pairs tracked'
                          '${f.critical > 0 ? ' · ${f.critical} critical' : ''}',
                          style: AppText.caption,
                        ),
                    ],
                  )),
            ),
            const SizedBox(width: Gap.md),
            SizedBox(
              width: 52,
              child: Text('${f.maxRisk.round()}%',
                  textAlign: TextAlign.right,
                  style: AppText.numeric.copyWith(
                      fontSize: 15, color: SeverityStyle.of(f.maxRisk).fg)),
            ),
            const SizedBox(width: Gap.sm),
            const Icon(Icons.chevron_right,
                size: 17, color: AppColors.inkFaint),
          ]),
        ),
      ),
    );
  }

  Widget _lower(List<Recommendation> recs) =>
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        final queue = PanelCard(
          title: 'Approval queue',
          subtitle: 'Redistribution recommendations awaiting sign-off',
          trailing: recs.isEmpty
              ? null
              : StatusPill('${recs.length} PENDING',
                  fg: AppColors.warn, bg: AppColors.warnBg, dense: true),
          child: recs.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing needs approval',
                  message: 'No facility has a deficit a neighbour can cover. The '
                      'matcher runs every 30 minutes and will surface a transfer here.',
                )
              : Column(children: [for (final r in recs.take(4)) _recRow(r)]),
        );
        final health = _network();
        if (!wide) {
          return Column(children: [queue, const SizedBox(height: Gap.lg), health]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: queue),
          const SizedBox(width: Gap.lg),
          Expanded(flex: 2, child: health),
        ]);
      });

  Widget _recRow(Recommendation r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.infoBg, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.swap_horiz, size: 15, color: AppColors.info),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${r.quantity} × ${Medicine.prettyKey(r.medicine)}',
                      style: AppText.label),
                  const TextSpan(
                      text: '  donor to recipient',
                      style: TextStyle(color: AppColors.inkFaint)),
                ]), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${r.fromPhc} ${widget.data.nameOf(r.fromPhc)}  →  '
                  '${r.toPhc} ${widget.data.nameOf(r.toPhc)}',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          FilledButton(
            onPressed: () => widget.onApprove(r),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            ),
            child: const Text('Approve'),
          ),
        ]),
      );

  /// Risk mix per facility. Small multiples beat a pie chart when a reader must
  /// compare the same quantity across 8 items.
  Widget _network() {
    final facs = widget.data.facilitiesByUrgency();
    return PanelCard(
      title: 'Network health',
      subtitle: 'Risk mix per facility · NLEM 2022 standard',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final phc in facs)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(children: [
              SizedBox(
                  width: 58,
                  child:
                      Text(phc.replaceFirst('PHC-', ''), style: AppText.mono)),
              Expanded(child: _stack(phc)),
            ]),
          ),
        const SizedBox(height: Gap.sm),
        // Wrap, not Row: four legend chips do not fit a 390px phone.
        Wrap(spacing: Gap.md, runSpacing: Gap.sm, children: [
          _legend(AppColors.critical, '80+'),
          _legend(AppColors.warn, '60-79'),
          _legend(AppColors.info, '30-59'),
          _legend(AppColors.healthy, '<30'),
        ]),
      ]),
    );
  }

  Widget _stack(String phc) {
    final meds = widget.data.inventory[phc]?.values ?? const <Medicine>[];
    var c = 0, h = 0, w = 0, g = 0;
    for (final m in meds) {
      final r = m.risk?.risk ?? 0;
      if (r >= 80) {
        c++;
      } else if (r >= 60) {
        h++;
      } else if (r >= 30) {
        w++;
      } else {
        g++;
      }
    }
    final total = (c + h + w + g).clamp(1, 1 << 30);
    Widget seg(int n, Color col, String label) => n == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: n,
            child: Tooltip(
              message: '$label: $n medicine pairs',
              child: Container(
                height: 20,
                margin: const EdgeInsets.only(right: 1.5),
                decoration: BoxDecoration(
                    color: col, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          );
    return Row(children: [
      seg(c, AppColors.critical, 'Critical'),
      seg(h, AppColors.warn, 'High'),
      seg(w, AppColors.info, 'Watch'),
      seg(g, AppColors.healthy, 'Healthy'),
      const SizedBox(width: 6),
      Text('$total', style: AppText.mono),
    ]);
  }

  Widget _legend(Color c, String label) => Padding(
        padding: const EdgeInsets.only(right: Gap.md),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption),
        ]),
      );
}
