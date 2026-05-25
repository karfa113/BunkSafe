import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/app_bar_percent.dart';
import 'today_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final monthStats = _monthStats(state, _month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Bulk-mark a date range',
            icon: const Icon(Icons.library_add_check_outlined),
            onPressed: () => _bulkMarkRange(context, state),
          ),
          const AppBarPercent(),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
        children: [
          _MonthHeader(
            month: _month,
            onPrev: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1);
            }),
            onNext: () => setState(() {
              _month = DateTime(_month.year, _month.month + 1);
            }),
          ),
          const SizedBox(height: 8),
          _MonthGrid(
            month: _month,
            state: state,
            onPick: (d) => _openDay(d),
          ),
          const SizedBox(height: 14),
          _MonthProgress(stats: monthStats, monthLabel: DateFormat('MMMM y').format(_month)),
          const SizedBox(height: 10),
          _DayLegend(),
        ],
      ),
    );
  }

  void _openDay(DateTime d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TodayScreen(date: d)),
    );
  }

  Future<void> _bulkMarkRange(BuildContext context, AppState state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      helpText: 'Pick a range to bulk-mark',
      saveText: 'Next',
    );
    if (picked == null || !context.mounted) return;
    final status = await showModalBottomSheet<AttendanceStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BulkStatusSheet(
        start: picked.start,
        end: picked.end,
      ),
    );
    if (status == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final (days, marks) =
        await state.bulkSetForRange(picked.start, picked.end, status);
    if (!context.mounted) return;
    messenger.clearSnackBars();
    if (marks == 0) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
          content: Text(
              'No routine classes in this range (or every day was a holiday).'),
        ),
      );
    } else {
      final label = status == AttendanceStatus.none
          ? 'Cleared $marks mark${marks == 1 ? "" : "s"} across $days day${days == 1 ? "" : "s"}'
          : 'Marked $marks class${marks == 1 ? "" : "es"} as ${status.label} across $days day${days == 1 ? "" : "s"}';
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1700),
          content: Text(label),
        ),
      );
    }
  }

  _MonthStats _monthStats(AppState state, DateTime month) {
    final prefix = DateFormat('yyyy-MM').format(month);
    int p = 0, a = 0, o = 0;
    for (final e in state.records.entries) {
      final parts = e.key.split('|');
      if (parts.isEmpty) continue;
      if (!parts.first.startsWith(prefix)) continue;
      switch (e.value) {
        case AttendanceStatus.present:
          p++;
          break;
        case AttendanceStatus.absent:
          a++;
          break;
        case AttendanceStatus.off:
          o++;
          break;
        case AttendanceStatus.none:
          break;
      }
    }
    return _MonthStats(present: p, absent: a, off: o);
  }
}

class _MonthStats {
  final int present;
  final int absent;
  final int off;
  const _MonthStats({
    required this.present,
    required this.absent,
    required this.off,
  });

  int get held => present + absent;
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader(
      {required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Material(
            color: cs.primary.withValues(alpha: 0.10),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPrev,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.chevron_left_rounded, color: cs.primary),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    DateFormat('MMMM').format(month).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 1.4,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    DateFormat('y').format(month),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: cs.primary.withValues(alpha: 0.10),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onNext,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.chevron_right_rounded, color: cs.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: const [
          _LegendDot(color: Color(0xFF06D6A0), label: 'Present'),
          _LegendDot(color: Color(0xFFEF476F), label: 'Absent'),
          _LegendDot(color: Color(0xFFFFD166), label: 'Off'),
          _LegendDot(color: Color(0xFFD9A116), label: 'Holiday'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final AppState state;
  final void Function(DateTime) onPick;

  const _MonthGrid({
    required this.month,
    required this.state,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kSubjectAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              _Wd('Mon'),
              _Wd('Tue'),
              _Wd('Wed'),
              _Wd('Thu'),
              _Wd('Fri'),
              _Wd('Sat', weekend: true),
              _Wd('Sun', weekend: true),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (_, i) {
              final dayNum = i - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final d = DateTime(month.year, month.month, dayNum);
              final isToday = DateUtils.isSameDay(d, DateTime.now());
              final marks = _marksFor(d);
              final isHoliday = state.isHolidayDate(d);
              return _DayCell(
                day: dayNum,
                weekday: d.weekday,
                isToday: isToday,
                isHoliday: isHoliday,
                marks: marks,
                onTap: () => onPick(d),
              );
            },
          ),
        ],
      ),
    );
  }

  List<AttendanceStatus> _marksFor(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    final out = <AttendanceStatus>[];
    for (final e in state.records.entries) {
      if (e.key.startsWith('$key|')) {
        out.add(e.value);
      }
    }
    return out;
  }
}

class _Wd extends StatelessWidget {
  final String d;
  final bool weekend;
  const _Wd(this.d, {this.weekend = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Text(
          d.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: weekend
                ? cs.primary.withValues(alpha: 0.8)
                : cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int weekday;
  final bool isToday;
  final bool isHoliday;
  final List<AttendanceStatus> marks;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.isHoliday,
    required this.marks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWeekend = weekday >= 6;
    const holidayColor = Color(0xFFFFD166);

    final dots = <Color>[];
    for (final s in marks.toSet()) {
      switch (s) {
        case AttendanceStatus.present:
          dots.add(const Color(0xFF06D6A0));
          break;
        case AttendanceStatus.absent:
          dots.add(const Color(0xFFEF476F));
          break;
        case AttendanceStatus.off:
          dots.add(const Color(0xFFFFD166));
          break;
        case AttendanceStatus.none:
          break;
      }
    }

    Color textColor = cs.onSurface;
    if (isWeekend && !isToday) {
      textColor = cs.onSurface.withValues(alpha: 0.75);
    }

    Widget cell;
    if (isToday) {
      cell = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _cellContent(
          context,
          textColor: cs.onPrimary,
          dots: dots,
          dotColor: cs.onPrimary,
        ),
      );
    } else if (isHoliday) {
      cell = Container(
        decoration: BoxDecoration(
          color: holidayColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: holidayColor.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: _cellContent(
          context,
          textColor: textColor,
          dots: dots,
          dotColor: null,
        ),
      );
    } else {
      cell = Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _cellContent(
          context,
          textColor: textColor,
          dots: dots,
          dotColor: null,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Stack(
          children: [
            cell,
            if (isHoliday && !isToday)
              Positioned(
                top: 3,
                right: 4,
                child: Text(
                  'H',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD9A116).withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellContent(BuildContext context,
      {required Color textColor,
      required List<Color> dots,
      Color? dotColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dots
                  .take(3)
                  .map(
                    (c) => Container(
                      width: 4.5,
                      height: 4.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.3),
                      decoration: BoxDecoration(
                        color: dotColor ?? c,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthProgress extends StatelessWidget {
  final _MonthStats stats;
  final String monthLabel;
  const _MonthProgress({required this.stats, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = stats.held == 0
        ? 0.0
        : (stats.present / stats.held) * 100.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kSubjectAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$monthLabel — Progress',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stats.held == 0 ? '—' : '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Present',
                  value: stats.present,
                  color: const Color(0xFF06D6A0),
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Absent',
                  value: stats.absent,
                  color: const Color(0xFFEF476F),
                  icon: Icons.cancel_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Off',
                  value: stats.off,
                  color: const Color(0xFFFFD166),
                  icon: Icons.beach_access_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Held',
                  value: stats.held,
                  color: cs.primary,
                  icon: Icons.event_available_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.65),
                    letterSpacing: 0.4,
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

class _BulkStatusSheet extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  const _BulkStatusSheet({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat('d MMM y');
    final s0 = DateTime(start.year, start.month, start.day);
    final e0 = DateTime(end.year, end.month, end.day);
    final sameDay = s0 == e0;
    final rangeText = sameDay
        ? fmt.format(s0)
        : '${fmt.format(s0)}  →  ${fmt.format(e0)}';
    final days = e0.difference(s0).inDays + 1;

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
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kSubjectAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: kSubjectAccent.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.library_add_check_outlined,
                        color: kSubjectAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mark range',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$rangeText  •  $days day${days == 1 ? "" : "s"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Apply to every routine class in the range (holiday days skipped).',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 14),
              _BulkActionTile(
                icon: Icons.check_rounded,
                label: 'Mark all Present',
                color: const Color(0xFF06D6A0),
                onTap: () =>
                    Navigator.pop(context, AttendanceStatus.present),
              ),
              const SizedBox(height: 8),
              _BulkActionTile(
                icon: Icons.close_rounded,
                label: 'Mark all Absent',
                color: const Color(0xFFEF476F),
                onTap: () =>
                    Navigator.pop(context, AttendanceStatus.absent),
              ),
              const SizedBox(height: 8),
              _BulkActionTile(
                icon: Icons.beach_access_rounded,
                label: 'Mark all Off',
                color: const Color(0xFFFFD166),
                onTap: () => Navigator.pop(context, AttendanceStatus.off),
              ),
              const SizedBox(height: 8),
              _BulkActionTile(
                icon: Icons.refresh_rounded,
                label: 'Clear marks',
                color: cs.onSurface.withValues(alpha: 0.55),
                onTap: () => Navigator.pop(context, AttendanceStatus.none),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkActionTile({
    required this.icon,
    required this.label,
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: color,
                  ),
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
