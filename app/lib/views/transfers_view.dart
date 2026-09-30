// views/transfers_view.dart — the DHO approval queue. Bulk actions because
// signing off eight transfers one at a time is the tediency multi-select exists
// to solve.

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class TransfersView extends StatefulWidget {
  final MockData data;
  final List<Recommendation> recommendations;
  final void Function(Recommendation) onApproveOne;
  final void Function(List<Recommendation>) onApproveMany;
  final List<String> approvedIds;
  const TransfersView({
    super.key,
    required this.data,
    required this.recommendations,
    required this.onApproveOne,
    required this.onApproveMany,
    required this.approvedIds,
  });

  @override
  State<TransfersView> createState() => _TransfersViewState();
}

class _TransfersViewState extends State<TransfersView> {
  final Set<String> _sel = {};

  @override
  Widget build(BuildContext context) {
    final recs = widget.recommendations;
    final selected = recs.where((r) => _sel.contains(r.id)).toList();
    final units = selected.fold<int>(0, (a, r) => a + r.quantity);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ViewHeader(
        title: 'Transfers',
        subtitle: 'Redistribution recommendations awaiting District Health '
            'Officer approval',
        actions: [
          if (widget.approvedIds.isNotEmpty)
            StatusPill('${widget.approvedIds.length} EXECUTED TODAY',
                fg: AppColors.healthy,
                bg: AppColors.healthyBg,
                icon: Icons.check_circle_outline),
        ],
      ),
      if (recs.isEmpty)
        PanelCard(
          child: EmptyState(
            icon: Icons.task_alt,
            title: widget.approvedIds.isEmpty
                ? 'No transfers needed'
                : 'Queue cleared',
            message: widget.approvedIds.isEmpty
                ? 'No facility has a deficit a neighbour can cover. The matcher '
                    're-runs every 30 minutes and will surface a transfer here.'
                : '${widget.approvedIds.length} transfer(s) executed. Stock has moved; '
                    'risk scores recompute within 30 minutes.',
          ),
        )
      else ...[
        _bulkBar(selected, units),
        const SizedBox(height: Gap.lg),
        PanelCard(
          title: 'Pending recommendations',
          subtitle: 'Select all you agree with, then approve in one action',
          child: Column(children: [
            _header(all: selected.length == recs.length && recs.isNotEmpty),
            const Divider(height: 1),
            for (final r in recs) _recRow(r),
          ]),
        ),
      ],
      if (widget.approvedIds.isNotEmpty) ...[
        const SizedBox(height: Gap.xl),
        _audit(),
      ],
    ]);
  }

  Widget _bulkBar(List<Recommendation> selected, int units) {
    final all = selected.length == widget.recommendations.length;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected.isEmpty ? AppColors.border : AppColors.primary,
            width: selected.isEmpty ? 1 : 1.5),
      ),
      child: Row(children: [
        Checkbox(
          value: all,
          onChanged: (v) => setState(() {
            _sel.clear();
            if (v == true) _sel.addAll(widget.recommendations.map((r) => r.id));
          }),
        ),
        Expanded(
          child: Text(
            selected.isEmpty
                ? 'Select recommendations to approve in bulk'
                : '${selected.length} selected · $units units to move',
            style: AppText.label,
          ),
        ),
        if (selected.isNotEmpty) ...[
          TextButton(
              onPressed: () => setState(_sel.clear), child: const Text('Clear')),
          const SizedBox(width: Gap.sm),
          FilledButton.icon(
            onPressed: () {
              widget.onApproveMany(selected);
              setState(_sel.clear);
            },
            icon: const Icon(Icons.playlist_add_check, size: 17),
            label: const Text('Approve selected'),
          ),
        ],
      ]),
    );
  }

  Widget _header({required bool all}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(children: [
          // Non-interactive: the real control is the bulk-bar checkbox above.
          ExcludeSemantics(
            child: Checkbox(value: all, onChanged: all ? null : (_) {}),
          ),
          const Expanded(flex: 4, child: Text('MOVE', style: AppText.section)),
          const Expanded(flex: 3, child: Text('DISTANCE', style: AppText.section)),
          const Expanded(flex: 3, child: Text('SEVERITY', style: AppText.section)),
        ]),
      );

  Widget _recRow(Recommendation r) {
    final on = _sel.contains(r.id);
    final dist = (MockData.roster.indexOf(r.fromPhc) -
            MockData.roster.indexOf(r.toPhc))
        .abs();
    return Container(
      decoration: BoxDecoration(
        color: on ? AppColors.primaryLight : Colors.transparent,
        border:
            const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(children: [
        Checkbox(
          value: on,
          onChanged: (v) => setState(() {
            if (v == true) {
              _sel.add(r.id);
            } else {
              _sel.remove(r.id);
            }
          }),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${r.quantity} × ',
                    style: AppText.numeric.copyWith(fontSize: 15)),
                TextSpan(
                    text: Medicine.prettyKey(r.medicine),
                    style: AppText.label.copyWith(fontSize: 14)),
              ])),
              const SizedBox(height: 2),
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
        Expanded(
          flex: 3,
          child: Row(children: [
            Icon(Icons.straighten,
                size: 13,
                color: dist <= 1 ? AppColors.healthy : AppColors.inkFaint),
            const SizedBox(width: 4),
            Text(
              dist == 0 ? 'same' : '$dist PHC${dist > 1 ? 's' : ''}',
              style: AppText.caption.copyWith(
                color: dist <= 1 ? AppColors.healthy : AppColors.inkMuted,
                fontWeight: dist <= 1 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Row(children: [
            const StatusPill('HIGH',
                fg: AppColors.warn, bg: AppColors.warnBg, dense: true),
            const SizedBox(width: Gap.sm),
            OutlinedButton(
              onPressed: () => widget.onApproveOne(r),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Approve'),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Immutable record of what was approved, mirroring the `alertLog` node in
  /// the real RTDB. An approval workflow without an audit trail is not one.
  Widget _audit() => PanelCard(
        title: 'Execution log',
        subtitle: 'Every approval writes an immutable row — mirrored to '
            '`alertLog` in Realtime Database in live mode',
        child: Column(children: [
          for (final id in widget.approvedIds.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 15, color: AppColors.healthy),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(id.replaceAll('mock-', '').replaceAll('-', ' '),
                      style: AppText.mono),
                ),
                Text('executed', style: AppText.caption),
              ]),
            ),
        ]),
      );
}
