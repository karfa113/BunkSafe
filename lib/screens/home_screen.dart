import 'package:flutter/material.dart';
import 'today_screen.dart';
import 'routine_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _screens = const [
    TodayScreen(),
    RoutineScreen(),
    CalendarScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  static const _items = <_NavItem>[
    _NavItem(Icons.today_outlined, Icons.today, 'Today'),
    _NavItem(Icons.event_note_outlined, Icons.event_note, 'Routine'),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
    _NavItem(Icons.insert_chart_outlined, Icons.insert_chart, 'Stats'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _FloatingNavBar(
        index: _index,
        items: _items,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onChanged;

  const _FloatingNavBar({
    required this.index,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final bg = isDark
        ? const Color(0xFF1E1A26).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final selected = i == index;
                  final it = items[i];
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onChanged(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? it.selectedIcon : it.icon,
                              size: 22,
                              color: selected
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
