import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/add_subject_sheet.dart';
import '../widgets/app_bar_percent.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final routineSubjects = state.uniqueSubjects();
    final savedSubjects = state.subjects;
    final overall = state.overallPercent();
    final (oPresent, oTotal) = state.overallStats();
    final belowTarget = overall < state.threshold;

    // Merge: every saved subject + every subject derived from routine/extras
    // that isn't yet saved.
    final displayed = <String>[
      ...savedSubjects.map((s) => s.name),
      ...routineSubjects.where((s) => !savedSubjects
          .any((x) => x.name.toLowerCase() == s.toLowerCase())),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: const [
          AppBarPercent(),
          SizedBox(width: 4),
        ],
      ),
      // Lift the FAB above the floating bottom nav-bar.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          onPressed: () => _addSubjectDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add subject'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 160),
        children: [
          _OverallCard(
            percent: overall,
            present: oPresent,
            total: oTotal,
            threshold: state.threshold,
            belowTarget: belowTarget,
            safeBunk: state.safeBunkCount(),
            toReach: state.classesToReachThreshold(),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Text('Subjects',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 8),
                Text('${displayed.length} total',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (displayed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bookmark_add_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    const Text(
                      'No subjects yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the "+ Add subject" button below.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayed.map((s) {
              final pct = state.subjectPercent(s);
              final (p, t) = state.statsForSubject(s);
              final subj = state.findSubject(s);
              final color = subj?.color ?? state.colorForSubject(s);
              final effThreshold = state.effectiveThreshold(s);
              final hasCustom = subj?.customThreshold != null;
              final safeSkip = t == 0 ? 0 : state.safeBunkForSubject(s);
              final attendMore =
                  t == 0 ? 0 : state.classesToReachThresholdForSubject(s);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SubjectCard(
                  subject: s,
                  teacher: subj?.teacher ?? '',
                  accent: color,
                  percent: pct,
                  present: p,
                  total: t,
                  threshold: effThreshold,
                  isCustomThreshold: hasCustom,
                  safeSkip: safeSkip,
                  attendMore: attendMore,
                  onTap: () => _openSubjectActions(context, state, s),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _addSubjectDialog(BuildContext context) async {
    final added = await showAddSubjectSheet(context);
    if (added == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Added "$added"'),
      ),
    );
  }

  Future<void> _openSubjectActions(
      BuildContext context, AppState state, String subject) async {
    final action = await showModalBottomSheet<_SubjectAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubjectActionsSheet(subject: subject),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _SubjectAction.rename:
        await _editSubject(context, state, subject);
        break;
      case _SubjectAction.delete:
        await _confirmDeleteSubject(context, state, subject);
        break;
    }
  }

  Future<void> _editSubject(
      BuildContext context, AppState state, String subject) async {
    final existing = state.findSubject(subject);
    if (existing == null) {
      // Not in saved subjects yet — add it. Treat the action as "create".
      final added = await showAddSubjectSheet(context);
      if (added == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Added "$added"'),
        ),
      );
      return;
    }
    final saved = await showAddSubjectSheet(context, edit: existing);
    if (saved == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Updated "$saved"'),
      ),
    );
  }

  Future<void> _confirmDeleteSubject(
      BuildContext context, AppState state, String name) async {
    final inUse = state.routine
            .any((c) => c.subject.toLowerCase() == name.toLowerCase()) ||
        state.extras
            .any((e) => e.subject.toLowerCase() == name.toLowerCase());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: Text(inUse
            ? 'This subject is used by classes in your routine or extras. Removing it will ALSO DELETE all those classes and their associated attendance records.'
            : 'Remove "$name" from your subject list?'),
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
    if (ok == true) {
      await state.deleteSubject(name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Removed "$name"'),
        ),
      );
    }
  }
}

enum _SubjectAction { rename, delete }

class _SubjectActionsSheet extends StatelessWidget {
  final String subject;
  const _SubjectActionsSheet({required this.subject});

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
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose what to do.',
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
                description: 'Change the name, color or teacher.',
                color: cs.primary,
                onTap: () => Navigator.pop(context, _SubjectAction.rename),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                description: 'Remove this subject from the saved list.',
                color: const Color(0xFFEF476F),
                onTap: () => Navigator.pop(context, _SubjectAction.delete),
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

class _OverallCard extends StatelessWidget {
  final double percent;
  final int present;
  final int total;
  final double threshold;
  final bool belowTarget;
  final int safeBunk;
  final int toReach;

  const _OverallCard({
    required this.percent,
    required this.present,
    required this.total,
    required this.threshold,
    required this.belowTarget,
    required this.safeBunk,
    required this.toReach,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = belowTarget
        ? const Color(0xFFEF476F)
        : const Color(0xFF06D6A0);
    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RingPercent(value: percent, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall attendance',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        total == 0
                            ? 'No marked classes yet'
                            : '$present of $total classes attended',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Target ${threshold.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: belowTarget
                    ? const Color(0xFFEF476F).withValues(alpha: 0.10)
                    : const Color(0xFF06D6A0).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    belowTarget
                        ? Icons.warning_amber_rounded
                        : Icons.thumb_up_alt_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      belowTarget
                          ? toReach > 0 && toReach <= 9999
                              ? 'Attend $toReach more class${toReach == 1 ? "" : "es"} in a row to reach ${threshold.toStringAsFixed(0)}%.'
                              : 'Below target.'
                          : safeBunk > 0
                              ? 'Safe to skip up to $safeBunk more class${safeBunk == 1 ? "" : "es"} and stay at ${threshold.toStringAsFixed(0)}%.'
                              : 'Right at the target — skipping the next class would drop you below ${threshold.toStringAsFixed(0)}%.',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPercent extends StatelessWidget {
  final double value;
  final Color color;
  const _RingPercent({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              strokeWidth: 7,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String subject;
  final String teacher;
  final Color accent;
  final double percent;
  final int present;
  final int total;
  final double threshold;
  final bool isCustomThreshold;
  final int safeSkip;
  final int attendMore;
  final VoidCallback onTap;
  const _SubjectCard({
    required this.subject,
    required this.teacher,
    required this.accent,
    required this.percent,
    required this.present,
    required this.total,
    required this.threshold,
    required this.isCustomThreshold,
    required this.safeSkip,
    required this.attendMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unmarked = total == 0;
    final below = !unmarked && percent < threshold;
    final neutral = cs.onSurface.withValues(alpha: 0.55);
    final statusColor = unmarked
        ? neutral
        : below
            ? const Color(0xFFEF476F)
            : const Color(0xFF06D6A0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: accent.withValues(alpha: 0.3), width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (teacher.isNotEmpty) ...[
                              Icon(Icons.person_outline,
                                  size: 12,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.55)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  teacher,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              total == 0
                                  ? 'No marks yet'
                                  : '$present / $total counted',
                              style: TextStyle(
                                fontSize: 11.5,
                                color:
                                    cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      unmarked ? '—' : '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: unmarked ? 0.0 : (percent / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: accent.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Tag(
                    icon: isCustomThreshold
                        ? Icons.flag_rounded
                        : Icons.flag_outlined,
                    text: 'Target ${threshold.toStringAsFixed(0)}%'
                        '${isCustomThreshold ? " (custom)" : ""}',
                    color: isCustomThreshold
                        ? accent
                        : cs.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _Tag(
                      icon: unmarked
                          ? Icons.hourglass_empty_rounded
                          : below
                              ? Icons.trending_up_rounded
                              : Icons.shield_outlined,
                      text: unmarked
                          ? 'Not counted yet'
                          : below
                              ? (attendMore > 0 && attendMore <= 9999
                                  ? 'Attend $attendMore more'
                                  : 'Below target')
                              : (safeSkip > 0
                                  ? 'Safe to skip $safeSkip'
                                  : 'Right at target'),
                      color: statusColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.45),
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

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Tag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
