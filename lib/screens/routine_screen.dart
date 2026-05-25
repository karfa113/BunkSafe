import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/routine_pdf.dart';
import '../widgets/add_subject_sheet.dart';
import '../widgets/app_bar_percent.dart';

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  static const _daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _daysLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Group classes by weekday, preserving list order = position.
    final byDay = <int, List<ClassItem>>{
      for (var i = 1; i <= 7; i++) i: state.classesForWeekday(i),
    };
    final teacherById = <String, String>{
      for (final c in state.routine)
        c.id: state.findSubject(c.subject)?.teacher ?? '',
    };
    final maxN = byDay.values
        .fold<int>(0, (a, b) => a > b.length ? a : b.length);
    final hasAny = maxN > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Routine'),
        actions: const [
          AppBarPercent(),
          SizedBox(width: 4),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          onPressed: () => _editClass(context, state, null),
          icon: const Icon(Icons.add),
          label: const Text('Add class'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasAny)
                const _EmptyRoutine()
              else
                _RoutineTable(
                  byDay: byDay,
                  teacherById: teacherById,
                  cols: maxN,
                  onCellTap: (c) => _classMenu(context, state, c),
                ),
              const SizedBox(height: 24),
              _ExportPdfButton(
                enabled: hasAny,
                onTap: () => _exportPdf(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _classMenu(
      BuildContext context, AppState state, ClassItem c) async {
    final action = await showModalBottomSheet<_CellAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CellActionsSheet(item: c),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _CellAction.edit:
        await _editClass(context, state, c);
        break;
      case _CellAction.delete:
        await _confirmDelete(context, state, c);
        break;
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, ClassItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
            'Remove ${c.subject} from ${_daysLong[c.weekday - 1]} and clear its attendance records?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteClass(c.id);
  }

  Future<void> _editClass(
      BuildContext context, AppState state, ClassItem? existing) async {
    final defaultDay =
        existing?.weekday ?? DateTime.now().weekday;
    final result = await showModalBottomSheet<List<ClassItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ClassEditor(initial: existing, defaultWeekday: defaultDay),
    );
    if (result == null || result.isEmpty) return;
    if (existing == null) {
      for (final c in result) {
        await state.addClass(c);
      }
      if (!context.mounted) return;
      final n = result.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1300),
          content: Text(n == 1
              ? 'Added 1 class'
              : 'Added $n classes to ${_daysLong[result.first.weekday - 1]}'),
        ),
      );
    } else {
      await state.updateClass(result.first);
    }
  }

  Future<void> _exportPdf(BuildContext context, AppState state) async {
    if (state.routine.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Generating routine PDF…'),
          ],
        ),
      ),
    );
    try {
      final bytes = await RoutinePdf.build(
        state.routine,
        subjects: state.subjects,
      );
      final dir = await getApplicationDocumentsDirectory();
      final fname =
          'class_routine_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File('${dir.path}${Platform.pathSeparator}$fname');
      await file.writeAsBytes(bytes, flush: true);
      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Class routine',
          text: 'My class routine from BunkSafe.',
        );
      } catch (_) {
        await Printing.sharePdf(bytes: bytes, filename: fname);
      }
      if (!context.mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('Generated $fname')),
      );
    } catch (e) {
      try {
        final bytes = await RoutinePdf.build(
          state.routine,
          subjects: state.subjects,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'class_routine.pdf',
        );
        if (!context.mounted) return;
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('Shared class routine.')),
        );
      } catch (e2) {
        if (!context.mounted) return;
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('Could not export routine: $e2')),
        );
      }
    }
  }
}

class _RoutineTable extends StatelessWidget {
  final Map<int, List<ClassItem>> byDay;
  final Map<String, String> teacherById;
  final int cols;
  final void Function(ClassItem) onCellTap;
  const _RoutineTable({
    required this.byDay,
    required this.teacherById,
    required this.cols,
    required this.onCellTap,
  });

  static const _daysShort = RoutineScreen._daysShort;
  static const _daysLong = RoutineScreen._daysLong;

  @override
  Widget build(BuildContext context) {
    final accent = kSubjectAccent.withValues(alpha: 0.3);

    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(78),
      for (var i = 1; i <= cols; i++) i: const FixedColumnWidth(120),
    };

    final table = Table(
      border: TableBorder.all(color: accent, width: 1.2),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      children: [
        TableRow(
          children: [
            _headCell('DAY'),
            for (var i = 1; i <= cols; i++) _headCell('$i'),
          ],
        ),
        for (var w = 1; w <= 7; w++)
          TableRow(
            children: [
              _dayCell(context, w),
              for (var i = 0; i < cols; i++)
                _classCell(
                  context,
                  i < byDay[w]!.length ? byDay[w]![i] : null,
                ),
            ],
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    );
  }

  Widget _headCell(String text) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: kSubjectAccent.withValues(
                  alpha: cs.brightness == Brightness.dark ? 0.95 : 0.85),
            ),
          ),
        );
      },
    );
  }

  Widget _dayCell(BuildContext context, int weekday) {
    final cs = Theme.of(context).colorScheme;
    final isWeekend = weekday >= 6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _daysShort[weekday - 1],
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isWeekend
                  ? kSubjectAccent
                  : cs.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _daysLong[weekday - 1],
            style: TextStyle(
              fontSize: 9.5,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classCell(BuildContext context, ClassItem? c) {
    final cs = Theme.of(context).colorScheme;
    if (c == null) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        child: Text(
          '—',
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
        ),
      );
    }
    final teacher = (teacherById[c.id] ?? '').trim();
    return InkWell(
      onTap: () => onCellTap(c),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.subject,
              textAlign: TextAlign.center,
              maxLines: teacher.isEmpty ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.92),
                height: 1.15,
              ),
            ),
            if (teacher.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                teacher,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyRoutine extends StatelessWidget {
  const _EmptyRoutine();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = kSubjectAccent.withValues(alpha: 0.3);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_view_week_outlined,
            size: 52,
            color: kSubjectAccent.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          const Text(
            'No classes yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Add class" to build your weekly routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPdfButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ExportPdfButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = kSubjectAccent.withValues(alpha: 0.3);
    final disabled = !enabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  color: kSubjectAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Export routine as PDF',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CellAction { edit, delete }

class _CellActionsSheet extends StatelessWidget {
  final ClassItem item;
  const _CellActionsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1626) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kSubjectAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: kSubjectAccent.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: kSubjectAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          RoutineScreen._daysLong[item.weekday - 1],
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Edit',
                description: 'Change the subject or day.',
                color: cs.primary,
                onTap: () => Navigator.pop(context, _CellAction.edit),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                description:
                    'Remove this class and clear its attendance records.',
                color: const Color(0xFFEF476F),
                onTap: () => Navigator.pop(context, _CellAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color,
                        )),
                    const SizedBox(height: 2),
                    Text(description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassEditor extends StatefulWidget {
  final ClassItem? initial;
  final int defaultWeekday;
  const _ClassEditor({this.initial, required this.defaultWeekday});

  @override
  State<_ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<_ClassEditor> {
  // Ordered list of selected subject names. In add mode users can pick many;
  // in edit mode this is always 0 or 1 long.
  final List<String> _selected = [];
  late int _weekday;
  String? _error;

  bool get _isEdit => widget.initial != null;
  bool get _isMulti => !_isEdit;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _selected.add(widget.initial!.subject);
    }
    _weekday = widget.initial?.weekday ?? widget.defaultWeekday;
  }

  static const _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  int _selectionIndex(String name) {
    final lower = name.toLowerCase();
    return _selected.indexWhere((s) => s.toLowerCase() == lower);
  }

  void _toggle(String name) {
    final idx = _selectionIndex(name);
    setState(() {
      _error = null;
      if (idx >= 0) {
        _selected.removeAt(idx);
        return;
      }
      if (_isEdit) _selected.clear();
      _selected.add(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final subjects = [...state.subjects];
    // Ensure currently-selected subjects appear even if removed from list.
    for (final sel in _selected) {
      if (!subjects.any(
          (s) => s.name.toLowerCase() == sel.toLowerCase())) {
        subjects.insert(
          0,
          Subject(
            name: sel,
            colorValue: state.colorForSubject(sel).toARGB32(),
          ),
        );
      }
    }

    final accent = kSubjectAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1626) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
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
                        colors: [accent, accent.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isEdit
                          ? Icons.edit_rounded
                          : Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit class' : 'Add classes',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isMulti
                              ? 'Tap subjects in the order they happen on the day.'
                              : 'Change the subject or day.',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    _isMulti ? 'Subjects' : 'Subject',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  if (_isMulti && _selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${_selected.length} picked',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
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
                      Icon(Icons.info_outline, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No subjects yet — add one first.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addSubjectDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...subjects.map((s) {
                      final idx = _selectionIndex(s.name);
                      return _SubjectPickChip(
                        name: s.name,
                        subjectColor: s.color,
                        orderNumber: idx >= 0 ? idx + 1 : null,
                        showNumber: _isMulti,
                        onTap: () => _toggle(s.name),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('New'),
                      onPressed: () => _addSubjectDialog(context),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'Day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final w = i + 1;
                  return ChoiceChip(
                    label: Text(_days[i]),
                    selected: _weekday == w,
                    onSelected: (_) => setState(() => _weekday = w),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
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
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_isEdit
                          ? 'Save changes'
                          : (_selected.length <= 1
                              ? 'Add class'
                              : 'Add ${_selected.length} classes')),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
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

  Future<void> _addSubjectDialog(BuildContext context) async {
    final added = await showAddSubjectSheet(context);
    if (added == null || !mounted) return;
    setState(() {
      if (_selectionIndex(added) < 0) {
        if (_isEdit) _selected.clear();
        _selected.add(added);
      }
    });
  }

  void _save() {
    if (_selected.isEmpty) {
      setState(() => _error = _isEdit
          ? 'Pick a subject first.'
          : 'Pick at least one subject.');
      return;
    }
    final existing = widget.initial;
    final baseTs = DateTime.now().microsecondsSinceEpoch;
    final out = <ClassItem>[];
    for (var i = 0; i < _selected.length; i++) {
      final name = _selected[i].trim();
      final id = existing != null ? existing.id : '${baseTs + i}';
      final start = existing?.start ?? const TimeOfDay(hour: 0, minute: 0);
      final end = existing?.end ?? const TimeOfDay(hour: 0, minute: 0);
      final colorValue =
          existing?.colorValue ?? const Color(0xFF118AB2).toARGB32();
      out.add(ClassItem(
        id: id,
        subject: name,
        start: start,
        end: end,
        weekday: _weekday,
        colorValue: colorValue,
      ));
    }
    Navigator.pop(context, out);
  }
}

/// Subject chip used in the class editor. When [showNumber] is true and
/// [orderNumber] is non-null, displays a numeric badge indicating the
/// selection order — supports the multi-select "pick in order" UX.
class _SubjectPickChip extends StatelessWidget {
  final String name;
  final Color subjectColor;
  final int? orderNumber;
  final bool showNumber;
  final VoidCallback onTap;
  const _SubjectPickChip({
    required this.name,
    required this.subjectColor,
    required this.orderNumber,
    required this.showNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = orderNumber != null;
    final accent = kSubjectAccent;
    final borderColor = selected
        ? accent.withValues(alpha: 0.7)
        : cs.outline.withValues(alpha: 0.35);
    final bg = selected
        ? accent.withValues(alpha: 0.12)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Leading(
                selected: selected,
                showNumber: showNumber,
                orderNumber: orderNumber,
                subjectColor: subjectColor,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  final bool selected;
  final bool showNumber;
  final int? orderNumber;
  final Color subjectColor;
  const _Leading({
    required this.selected,
    required this.showNumber,
    required this.orderNumber,
    required this.subjectColor,
  });

  @override
  Widget build(BuildContext context) {
    if (selected && showNumber && orderNumber != null) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kSubjectAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kSubjectAccent.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$orderNumber',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kSubjectAccent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: subjectColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
