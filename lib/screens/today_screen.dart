import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/class_card.dart';
import '../widgets/add_extra_class_sheet.dart';
import '../widgets/app_bar_percent.dart';

class TodayScreen extends StatelessWidget {
  final DateTime? date;
  const TodayScreen({super.key, this.date});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = date != null
        ? DateUtils.dateOnly(date!)
        : DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(selected, DateTime.now());
    final holiday = state.holidayFor(selected);
    // On a holiday, classes / extras are intentionally hidden so the centred
    // holiday card stands alone. Short-circuit here so nothing downstream can
    // accidentally re-introduce them.
    final classes = holiday != null
        ? const <ClassItem>[]
        : state.classesForWeekday(selected.weekday);
    final extras = holiday != null
        ? const <ExtraClass>[]
        : state.extrasForDate(selected);

    final hasAny = classes.isNotEmpty || extras.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isToday
              ? 'Today'
              : DateFormat('EEEE, d MMM').format(selected),
        ),
        actions: [
          const AppBarPercent(),
          IconButton(
            tooltip: isToday
                ? 'Add extra class'
                : 'Add extra class on this day',
            icon: const Icon(Icons.add_alarm_rounded),
            onPressed: () => _addExtra(context, selected),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: _DayHero(date: selected, isToday: isToday),
            ),
          ),
          if (holiday != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
                child: Center(
                  child: _HolidayCenterCard(holiday: holiday),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: _SafeBunkBanner(state: state),
              ),
            ),
            if (!hasAny)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDay(),
              )
            else ...[
              if (classes.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeaderWithActions(
                    icon: Icons.event_note_rounded,
                    text: 'Scheduled',
                    onMarkAll: (s) =>
                        _bulkMark(context, state, selected, classes, extras, s),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  sliver: SliverList.separated(
                    itemCount: classes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = classes[i];
                      final subject = state.findSubject(c.subject);
                      final color = subject?.color ??
                          state.colorForSubject(c.subject);
                      return _swipeable(
                        context: context,
                        state: state,
                        date: selected,
                        classItem: c,
                        keyPrefix: 'sched',
                        child: ClassCard(
                          item: c,
                          status: state.statusFor(selected, c.id),
                          accentColor: color,
                          teacher: subject?.teacher,
                          showTime: false,
                          onSet: (s) => _onSet(context, state, selected, c, s),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (extras.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: classes.isEmpty
                      ? _SectionHeaderWithActions(
                          icon: Icons.add_alarm_rounded,
                          text: 'Extra',
                          onMarkAll: (s) =>
                              _bulkMark(context, state, selected, classes, extras, s),
                        )
                      : const _SectionLabel(
                          icon: Icons.add_alarm_rounded,
                          text: 'Extra',
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  sliver: SliverList.separated(
                    itemCount: extras.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = extras[i];
                      final subject = state.findSubject(e.subject);
                      final color = subject?.color ??
                          state.colorForSubject(e.subject);
                      final c = ClassItem(
                        id: e.id,
                        subject: e.subject,
                        start: e.start,
                        end: e.end,
                        weekday: selected.weekday,
                        colorValue: e.colorValue,
                      );
                      return _swipeable(
                        context: context,
                        state: state,
                        date: selected,
                        classItem: c,
                        keyPrefix: 'extra',
                        child: ClassCard(
                          item: c,
                          status: state.statusFor(selected, e.id),
                          isExtra: true,
                          accentColor: color,
                          teacher: subject?.teacher,
                          showTime: false,
                          onSet: (s) => _onSet(context, state, selected, c, s),
                          onLongPress: () =>
                              _confirmDeleteExtra(context, state, e),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: _SwipeHint()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _swipeable({
    required BuildContext context,
    required AppState state,
    required DateTime date,
    required ClassItem classItem,
    required String keyPrefix,
    required Widget child,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _SwipeToMark(
      key: ValueKey('${keyPrefix}_${dateStr}_${classItem.id}'),
      onPresent: () =>
          _onSet(context, state, date, classItem, AttendanceStatus.present),
      onAbsent: () =>
          _onSet(context, state, date, classItem, AttendanceStatus.absent),
      child: child,
    );
  }

  Future<void> _bulkMark(
    BuildContext context,
    AppState state,
    DateTime today,
    List<ClassItem> classes,
    List<ExtraClass> extras,
    AttendanceStatus s,
  ) async {
    final ids = <String>{
      ...classes.map((c) => c.id),
      ...extras.map((e) => e.id),
    };
    if (ids.isEmpty) return;
    await state.setStatusForAll(today, ids, s);
    if (!context.mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    final label = s == AttendanceStatus.none
        ? 'Cleared marks for ${ids.length} class${ids.length == 1 ? "" : "es"}'
        : 'Marked ${ids.length} class${ids.length == 1 ? "" : "es"} as ${s.label}';
    m.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
        content: Text(label),
      ),
    );
  }

  Future<void> _addExtra(BuildContext context, DateTime date) async {
    final extra = await showAddExtraClassSheet(context, date: date);
    if (extra == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
        content: Text('Added extra class: ${extra.subject}'),
      ),
    );
  }

  Future<void> _confirmDeleteExtra(
      BuildContext context, AppState state, ExtraClass e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove extra class?'),
        content: Text(
            '${e.subject} and its attendance mark will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteExtraClass(e.id);
  }

  Future<void> _onSet(BuildContext context, AppState state, DateTime date,
      ClassItem c, AttendanceStatus s) async {
    await state.setStatus(date, c.id, s);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1100),
        content: Text('${c.subject}: ${s.label}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderWithActions extends StatelessWidget {
  final IconData icon;
  final String text;
  final void Function(AttendanceStatus) onMarkAll;
  const _SectionHeaderWithActions({
    required this.icon,
    required this.text,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          _BulkBtn(
            icon: Icons.check_rounded,
            color: const Color(0xFF06D6A0),
            tooltip: 'Mark all Present',
            onTap: () => onMarkAll(AttendanceStatus.present),
          ),
          const SizedBox(width: 6),
          _BulkBtn(
            icon: Icons.close_rounded,
            color: const Color(0xFFEF476F),
            tooltip: 'Mark all Absent',
            onTap: () => onMarkAll(AttendanceStatus.absent),
          ),
          const SizedBox(width: 6),
          _BulkBtn(
            icon: Icons.beach_access_rounded,
            color: const Color(0xFFFFD166),
            tooltip: 'Mark all Off',
            onTap: () => onMarkAll(AttendanceStatus.off),
          ),
          const SizedBox(width: 6),
          _BulkBtn(
            icon: Icons.refresh_rounded,
            color: cs.onSurface.withValues(alpha: 0.5),
            tooltip: 'Clear all',
            onTap: () => onMarkAll(AttendanceStatus.none),
          ),
        ],
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _BulkBtn({
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
        color: color.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _DayHero extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  const _DayHero({required this.date, required this.isToday});

  static const _palette = <int, _DayStyle>{
    1: _DayStyle(
      label: 'Monday',
      tagline: 'Fresh start. One step at a time.',
      icon: Icons.local_cafe_rounded,
      gradient: [Color(0xFF3A1C71), Color(0xFFD76D77)],
    ),
    2: _DayStyle(
      label: 'Tuesday',
      tagline: 'Stay in the groove.',
      icon: Icons.menu_book_rounded,
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)],
    ),
    3: _DayStyle(
      label: 'Wednesday',
      tagline: 'Halfway there — keep going.',
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFF373B44), Color(0xFFFFAF7B)],
    ),
    4: _DayStyle(
      label: 'Thursday',
      tagline: 'Almost weekend. Push through.',
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFF1F4068), Color(0xFF1B1B2F)],
    ),
    5: _DayStyle(
      label: 'Friday',
      tagline: 'Finish strong, celebrate later.',
      icon: Icons.celebration_rounded,
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
    6: _DayStyle(
      label: 'Saturday',
      tagline: 'Catch up. Recharge.',
      icon: Icons.wb_sunny_rounded,
      gradient: [Color(0xFFCB356B), Color(0xFFBD3F32)],
    ),
    7: _DayStyle(
      label: 'Sunday',
      tagline: 'Slow morning. Plan ahead.',
      icon: Icons.nights_stay_rounded,
      gradient: [Color(0xFF232526), Color(0xFF414345)],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _palette[date.weekday]!;
    final fullDate = DateFormat('d MMMM y').format(date);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: style.gradient.last.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isToday ? 'TODAY' : 'DAY VIEW',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullDate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        style.tagline,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    style.icon,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStyle {
  final String label;
  final String tagline;
  final IconData icon;
  final List<Color> gradient;
  const _DayStyle({
    required this.label,
    required this.tagline,
    required this.icon,
    required this.gradient,
  });
}

class _HolidayCenterCard extends StatelessWidget {
  final Holiday holiday;
  const _HolidayCenterCard({required this.holiday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFD9A116);
    final fmt = DateFormat('d MMM y');
    final sameDay = holiday.start.year == holiday.end.year &&
        holiday.start.month == holiday.end.month &&
        holiday.start.day == holiday.end.day;
    final rangeText = sameDay
        ? fmt.format(holiday.start)
        : '${fmt.format(holiday.start)}  →  ${fmt.format(holiday.end)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.18),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.6),
                width: 1.6,
              ),
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              color: accent,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            holiday.label.isEmpty ? 'Holiday' : holiday.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rangeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
              ),
            ),
            child: const Text(
              'No classes today',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                color: accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'These days are skipped from your attendance %.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
class _SwipeToMark extends StatefulWidget {
  const _SwipeToMark({
    super.key,
    required this.child,
    required this.onPresent,
    required this.onAbsent,
  });

  final Widget child;
  final Future<void> Function() onPresent;
  final Future<void> Function() onAbsent;

  @override
  State<_SwipeToMark> createState() => _SwipeToMarkState();
}

class _SwipeToMarkState extends State<_SwipeToMark>
    with SingleTickerProviderStateMixin {
  static const double _maxFrac = 0.3;
  static const double _triggerFrac = 0.3;
  static const Color _presentColor = Color(0xFF06D6A0);
  static const Color _absentColor = Color(0xFFEF476F);

  double _dx = 0;
  late final AnimationController _ctrl;
  Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_anim != null && mounted) {
          setState(() => _dx = _anim!.value);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _settle({VoidCallback? then}) {
    _ctrl.stop();
    _anim = Tween<double>(begin: _dx, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward(from: 0).whenComplete(() {
      if (then != null) then();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxDx = width * _maxFrac;
        final triggered = _dx.abs() >= width * _triggerFrac;
        final showRight = _dx > 0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _ctrl.stop(),
          onHorizontalDragUpdate: (d) {
            setState(() {
              _dx = (_dx + d.delta.dx).clamp(-maxDx, maxDx);
            });
          },
          onHorizontalDragEnd: (_) {
            if (triggered) {
              final goRight = _dx > 0;
              _settle(then: () {
                if (goRight) {
                  widget.onPresent();
                } else {
                  widget.onAbsent();
                }
              });
            } else {
              _settle();
            }
          },
          onHorizontalDragCancel: () => _settle(),
          child: Stack(
            children: [
              if (_dx != 0)
                Positioned.fill(
                  child: _swipeBg(
                    color: showRight ? _presentColor : _absentColor,
                    icon: showRight ? Icons.check_rounded : Icons.close_rounded,
                    label: showRight ? 'Present' : 'Absent',
                    alignLeft: showRight,
                    intensity: triggered ? 1.0 : 0.7,
                  ),
                ),
              Transform.translate(
                offset: Offset(_dx, 0),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _swipeBg({
  required Color color,
  required IconData icon,
  required String label,
  required bool alignLeft,
  required double intensity,
}) {
  return Container(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16 + 0.10 * intensity),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.40 + 0.25 * intensity)),
    ),
    alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: alignLeft
          ? [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ]
          : [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: color, size: 24),
            ],
    ),
  );
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_rounded, size: 13, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Swipe right to mark Present, left to mark Absent',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          const Text(
            'No classes scheduled for today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the alarm icon to add an extra class for today,\nor add a weekly class from the Routine tab.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows, prominently, how many classes the user can safely skip while
/// still staying at or above their attendance target — or, when they're
/// below target, how many they need to attend in a row to climb back.
class _SafeBunkBanner extends StatelessWidget {
  final AppState state;
  const _SafeBunkBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = state.overallPercent();
    final threshold = state.threshold;
    final (_, held) = state.overallStats();

    // Nothing meaningful to show until the user has at least one held class.
    if (held == 0) return const SizedBox.shrink();

    final belowTarget = percent < threshold;
    final safeBunk = state.safeBunkCount();
    final toReach = state.classesToReachThreshold();

    final Color accent;
    final IconData icon;
    final String headline;
    final String body;

    if (belowTarget) {
      accent = const Color(0xFFEF476F);
      icon = Icons.priority_high_rounded;
      if (toReach > 0 && toReach <= 9999) {
        headline = 'Catch up — attend $toReach in a row';
        body =
            'Mark Present for $toReach more class${toReach == 1 ? "" : "es"} '
            'to climb back to ${threshold.toStringAsFixed(0)}%.';
      } else {
        headline = 'Below target';
        body = 'Currently at ${percent.toStringAsFixed(1)}%. '
            'Target is ${threshold.toStringAsFixed(0)}%.';
      }
    } else {
      accent = const Color(0xFF06D6A0);
      icon = Icons.shield_outlined;
      if (safeBunk > 0) {
        headline = 'Safe to skip $safeBunk more';
        body =
            'You can miss $safeBunk more class${safeBunk == 1 ? "" : "es"} '
            'and still stay at ${threshold.toStringAsFixed(0)}%.';
      } else {
        headline = 'Right at the target';
        body = 'Skipping the next class would drop you below '
            '${threshold.toStringAsFixed(0)}%.';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: accent,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
