import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// Compact attendance-percentage pill for use in AppBar actions.
/// Reads from AppState directly so every screen stays in sync.
class AppBarPercent extends StatelessWidget {
  const AppBarPercent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final value = state.overallPercent();
    final belowTarget = value < state.threshold;
    final color = belowTarget
        ? const Color(0xFFEF476F)
        : const Color(0xFF06D6A0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              belowTarget ? '😟' : '😄',
              style: const TextStyle(fontSize: 14, height: 1.0),
            ),
            const SizedBox(width: 4),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
