import 'package:flutter/material.dart';
import '../models.dart';

class ClassCard extends StatelessWidget {
  final ClassItem item;
  final AttendanceStatus status;
  final void Function(AttendanceStatus) onSet;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool isExtra;
  final bool showTime;
  final Color? accentColor;
  final String? teacher;

  const ClassCard({
    super.key,
    required this.item,
    required this.status,
    required this.onSet,
    this.onTap,
    this.onLongPress,
    this.compact = false,
    this.isExtra = false,
    this.showTime = true,
    this.accentColor,
    this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? item.color;
    final borderColor = color.withValues(alpha: 0.3);
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onSurface;
    final fgMuted = cs.onSurface.withValues(alpha: 0.65);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.subject,
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isExtra) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'EXTRA',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (showTime ||
                                (teacher != null && teacher!.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              if (showTime)
                                Row(
                                  children: [
                                    Icon(Icons.schedule_rounded,
                                        size: 12, color: fgMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${fmtTime(item.start)}  →  ${fmtTime(item.end)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: fgMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              if (teacher != null && teacher!.isNotEmpty) ...[
                                if (showTime) const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded,
                                        size: 12, color: fgMuted),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        teacher!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: fgMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: 'Present',
                            icon: Icons.check_rounded,
                            color: const Color(0xFF06D6A0),
                            selected: status == AttendanceStatus.present,
                            onTap: () => onSet(AttendanceStatus.present),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ActionBtn(
                            label: 'Absent',
                            icon: Icons.close_rounded,
                            color: const Color(0xFFEF476F),
                            selected: status == AttendanceStatus.absent,
                            onTap: () => onSet(AttendanceStatus.absent),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ActionBtn(
                            label: 'Off',
                            icon: Icons.beach_access_rounded,
                            color: const Color(0xFFFFD166),
                            selected: status == AttendanceStatus.off,
                            onTap: () => onSet(AttendanceStatus.off),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ActionBtn(
                            label: 'Clear',
                            icon: Icons.refresh_rounded,
                            color: fgMuted,
                            selected: false,
                            onTap: () => onSet(AttendanceStatus.none),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : Colors.transparent;
    final fg = selected ? Colors.white : color;
    final border = selected ? color : color.withValues(alpha: 0.5);
    return Tooltip(
      message: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AttendanceStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    IconData i;
    switch (status) {
      case AttendanceStatus.present:
        c = const Color(0xFF06D6A0);
        i = Icons.check_circle_rounded;
        break;
      case AttendanceStatus.absent:
        c = const Color(0xFFEF476F);
        i = Icons.cancel_rounded;
        break;
      case AttendanceStatus.off:
        c = const Color(0xFFFFD166);
        i = Icons.beach_access_rounded;
        break;
      case AttendanceStatus.none:
        c = Colors.white.withValues(alpha: 0.6);
        i = Icons.radio_button_unchecked_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 13, color: c),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
