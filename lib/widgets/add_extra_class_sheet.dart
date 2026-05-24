import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import 'add_subject_sheet.dart';

/// Bottom-sheet for adding an ad-hoc extra class on a specific date.
/// Returns the new ExtraClass added, or null if cancelled.
Future<ExtraClass?> showAddExtraClassSheet(
  BuildContext context, {
  required DateTime date,
}) async {
  return showModalBottomSheet<ExtraClass?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddExtraSheet(date: date),
  );
}

class _AddExtraSheet extends StatefulWidget {
  final DateTime date;
  const _AddExtraSheet({required this.date});

  @override
  State<_AddExtraSheet> createState() => _AddExtraSheetState();
}

class _AddExtraSheetState extends State<_AddExtraSheet> {
  String? _subject;
  String? _error;
  bool _busy = false;

  Future<void> _save(AppState state) async {
    if (_busy) return;
    if (_subject == null || _subject!.trim().isEmpty) {
      setState(() => _error = 'Pick a subject first.');
      return;
    }
    setState(() => _busy = true);
    final colorValue = state.colorForSubject(_subject!.trim()).toARGB32();
    final extra = ExtraClass(
      id: 'x_${DateTime.now().microsecondsSinceEpoch}',
      subject: _subject!.trim(),
      start: const TimeOfDay(hour: 0, minute: 0),
      end: const TimeOfDay(hour: 0, minute: 0),
      date: DateTime(widget.date.year, widget.date.month, widget.date.day),
      colorValue: colorValue,
    );
    await state.addExtraClass(extra);
    if (!mounted) return;
    Navigator.of(context).pop(extra);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final subjects = state.subjects;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1626) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8338EC),
                          const Color(0xFFEF476F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF8338EC).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_alarm_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Extra class',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add a one-off lecture for this day.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Subject',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No subjects yet — add one first.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final added = await showAddSubjectSheet(context);
                          if (added != null) {
                            setState(() => _subject = added);
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...subjects.map((s) {
                      final sel = (_subject ?? '').toLowerCase() ==
                          s.name.toLowerCase();
                      return ChoiceChip(
                        avatar: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(s.name),
                        selected: sel,
                        onSelected: (_) => setState(() {
                          _subject = s.name;
                          _error = null;
                        }),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('New'),
                      onPressed: () async {
                        final added = await showAddSubjectSheet(context);
                        if (added != null) {
                          setState(() => _subject = added);
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _save(state),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_busy ? 'Adding…' : 'Add class'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
