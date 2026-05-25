import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/app_bar_percent.dart';

class HolidaysScreen extends StatelessWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final holidays = state.holidays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holidays'),
        actions: const [
          AppBarPercent(),
          SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHoliday(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add holiday'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kSubjectAccent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: kSubjectAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dates inside a holiday range are skipped from attendance '
                    'stats — they don\'t count as held or unmarked.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (holidays.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.beach_access_outlined,
                      size: 52,
                      color: kSubjectAccent.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No holidays added',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a range so semester breaks don\'t drag your %.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...holidays.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HolidayTile(
                  holiday: h,
                  onDelete: () => _confirmDelete(context, state, h),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addHoliday(BuildContext context, AppState state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: today, end: today),
      helpText: 'Pick holiday dates',
      saveText: 'Next',
    );
    if (picked == null || !context.mounted) return;
    final label = await _askLabel(context);
    if (!context.mounted) return;
    await state.addHoliday(
      start: picked.start,
      end: picked.end,
      label: label ?? '',
    );
    if (!context.mounted) return;
    final startD = DateTime(picked.start.year, picked.start.month, picked.start.day);
    final endD = DateTime(picked.end.year, picked.end.month, picked.end.day);
    final days = endD.difference(startD).inDays + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        content: Text(
            'Added $days holiday day${days == 1 ? "" : "s"}'),
      ),
    );
  }

  Future<String?> _askLabel(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _LabelDialog(),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, Holiday h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove holiday?'),
        content: Text(
            'Those ${h.days} day${h.days == 1 ? "" : "s"} will count toward attendance again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await state.deleteHoliday(h.id);
  }
}

class _HolidayTile extends StatelessWidget {
  final Holiday holiday;
  final VoidCallback onDelete;
  const _HolidayTile({required this.holiday, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM y');
    final sameDay = holiday.start.year == holiday.end.year &&
        holiday.start.month == holiday.end.month &&
        holiday.start.day == holiday.end.day;
    final rangeText = sameDay
        ? dateFmt.format(holiday.start)
        : '${dateFmt.format(holiday.start)} → ${dateFmt.format(holiday.end)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kSubjectAccent.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD166).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD166).withValues(alpha: 0.55),
              ),
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              color: Color(0xFFD9A116),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.label.isEmpty ? 'Holiday' : holiday.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14.5),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$rangeText  •  ${holiday.days} day${holiday.days == 1 ? "" : "s"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF476F)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog();

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Label (optional)'),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Diwali break',
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
