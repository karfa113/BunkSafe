import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/add_subject_sheet.dart';
import '../widgets/app_bar_percent.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int _selected = DateTime.now().weekday;

  static const _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

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
    final classes = state.classesForWeekday(_selected);
    final cs = Theme.of(context).colorScheme;

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
          label: Text('Add to ${_days[_selected - 1]}'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final w = i + 1;
                  final sel = w == _selected;
                  final isWeekend = w >= 6;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _DayPill(
                      label: _days[i],
                      day: w,
                      selected: sel,
                      isWeekend: isWeekend,
                      onTap: () => setState(() => _selected = w),
                    ),
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.15), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _daysLong[_selected - 1],
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${classes.length} class${classes.length == 1 ? "" : "es"}',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (classes.length >= 2) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.drag_indicator_rounded,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.55)),
                        const SizedBox(width: 4),
                        Text(
                          'Long-press a class to drag and reorder',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: classes.isEmpty
                ? _Empty(day: _daysLong[_selected - 1])
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 160),
                    itemCount: classes.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      state.reorderClassesForDay(
                          _selected, oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (_, _) {
                          final t =
                              Curves.easeInOut.transform(animation.value);
                          return Transform.scale(
                            scale: 1 + 0.03 * t,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 10 * t,
                              shadowColor:
                                  cs.primary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(18),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemBuilder: (_, i) {
                      final c = classes[i];
                      final subject = state.findSubject(c.subject);
                      final color = subject?.color ??
                          state.colorForSubject(c.subject);
                      return Padding(
                        key: ValueKey(c.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReorderableDelayedDragStartListener(
                          index: i,
                          child: _RoutineTile(
                            item: c,
                            accent: color,
                            teacher: subject?.teacher ?? '',
                            position: i + 1,
                            onEdit: () => _editClass(context, state, c),
                            onDelete: () => _confirmDelete(state, c),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AppState state, ClassItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
            'Remove ${c.subject} and all its attendance records?'),
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
    final result = await showModalBottomSheet<ClassItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ClassEditor(initial: existing, defaultWeekday: _selected),
    );
    if (result == null) return;
    if (existing == null) {
      await state.addClass(result);
    } else {
      await state.updateClass(result);
    }
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final int day;
  final bool selected;
  final bool isWeekend;
  final VoidCallback onTap;

  const _DayPill({
    required this.label,
    required this.day,
    required this.selected,
    required this.isWeekend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = selected
        ? null
        : (isDark
            ? cs.surfaceContainerHigh
            : cs.surfaceContainerHighest.withValues(alpha: 0.55));

    final labelColor = selected
        ? Colors.white
        : (isWeekend
            ? cs.primary
            : cs.onSurface.withValues(alpha: 0.75));

    final numberColor = selected
        ? Colors.white
        : cs.onSurface.withValues(alpha: 0.9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primary.withValues(alpha: 0.7),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.outline.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final ClassItem item;
  final Color accent;
  final String teacher;
  final int position;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoutineTile({
    required this.item,
    required this.accent,
    required this.teacher,
    required this.position,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHigh.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: accent.withValues(alpha: 0.28), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withValues(alpha: 0.55)],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.45), width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$position',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (teacher.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 13,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  teacher,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      _TileIconButton(
                        icon: Icons.edit_outlined,
                        color: cs.primary,
                        tooltip: 'Edit',
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 4),
                      _TileIconButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF476F),
                        tooltip: 'Delete',
                        onTap: onDelete,
                      ),
                    ],
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

class _TileIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _TileIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String day;
  const _Empty({required this.day});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Text('No classes on $day',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Tap the button below to add a class.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65)),
            ),
          ],
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
  String? _subject;
  late int _weekday;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = widget.initial?.subject;
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final subjects = [...state.subjects];
    // Ensure currently-selected subject appears even if removed from list.
    if (_subject != null &&
        _subject!.isNotEmpty &&
        !subjects
            .any((s) => s.name.toLowerCase() == _subject!.toLowerCase())) {
      subjects.insert(
        0,
        Subject(
          name: _subject!,
          colorValue: state.colorForSubject(_subject!).toARGB32(),
        ),
      );
    }

    final accent = _subject == null
        ? cs.primary
        : state.colorForSubject(_subject!);

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
                      widget.initial == null
                          ? Icons.add_circle_outline_rounded
                          : Icons.edit_rounded,
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
                          widget.initial == null
                              ? 'Add class'
                              : 'Edit class',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a subject and day.',
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
                      label: Text(widget.initial == null
                          ? 'Add class'
                          : 'Save changes'),
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
    setState(() => _subject = added);
  }

  void _save() {
    if (_subject == null || _subject!.trim().isEmpty) {
      setState(() => _error = 'Pick a subject first.');
      return;
    }
    final id = widget.initial?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    // ClassItem still carries start/end/color for backward compat, but we no
    // longer expose them in the UI — keep defaults.
    final existing = widget.initial;
    final start = existing?.start ?? const TimeOfDay(hour: 0, minute: 0);
    final end = existing?.end ?? const TimeOfDay(hour: 0, minute: 0);
    final colorValue =
        existing?.colorValue ?? const Color(0xFF118AB2).toARGB32();
    Navigator.pop(
      context,
      ClassItem(
        id: id,
        subject: _subject!.trim(),
        start: start,
        end: end,
        weekday: _weekday,
        colorValue: colorValue,
      ),
    );
  }
}
