import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services/notification_service.dart';
import 'services/widget_sync.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  final StorageService storage;

  List<ClassItem> _routine = [];
  Map<String, AttendanceStatus> _records = {};
  double _threshold = 75;
  ThemeMode _themeMode = ThemeMode.system;
  List<Subject> _subjects = [];
  List<ExtraClass> _extras = [];
  List<Holiday> _holidays = [];
  Set<String> _holidayDateCache = {};
  int _ecaCount = 0;

  AppState(this.storage) {
    _routine = storage.loadRoutine();
    _records = storage.loadAttendance();
    _threshold = storage.loadThreshold();
    _themeMode = _parseTheme(storage.loadTheme());
    _subjects = storage.loadSubjects();
    _extras = storage.loadExtras();
    _holidays = storage.loadHolidays();
    _rebuildHolidayCache();
    _ecaCount = storage.loadEca();
    // One-time migration: pull subjects from existing routine/extras into the
    // saved subjects list, so they survive class deletions.
    var migrated = false;
    void seed(String name) {
      final s = name.trim();
      if (s.isEmpty) return;
      if (_subjects.any((e) => e.name.toLowerCase() == s.toLowerCase())) return;
      _subjects.add(Subject(name: s, colorValue: _defaultColorFor(s)));
      migrated = true;
    }
    for (final c in _routine) {
      seed(c.subject);
    }
    for (final e in _extras) {
      seed(e.subject);
    }
    if (migrated) {
      storage.saveSubjects(_subjects);
    }
    // Fire-and-forget: arm today's 6 PM reminder based on current state.
    _refreshTodayReminder();
    // Prime the home-screen widget (if it's on a home screen).
    WidgetSync.refresh(this);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Best-effort: keep the Android home-screen widget in sync after every
    // state mutation. WidgetSync swallows its own errors and is a no-op on
    // non-Android platforms.
    WidgetSync.refresh(this);
  }

  void _refreshTodayReminder() {
    NotificationService.instance
        .rescheduleTodayReminder(hasMarkForToday: hasAnyMarkForToday());
  }

  bool hasAnyMarkForToday() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final k in _records.keys) {
      if (k.startsWith('$today|')) return true;
    }
    return false;
  }

  List<ClassItem> get routine => List.unmodifiable(_routine);
  Map<String, AttendanceStatus> get records => Map.unmodifiable(_records);
  double get threshold => _threshold;
  ThemeMode get themeMode => _themeMode;
  List<ExtraClass> get extras => List.unmodifiable(_extras);
  List<Holiday> get holidays {
    final list = [..._holidays]..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(list);
  }
  int get ecaCount => _ecaCount;

  void _rebuildHolidayCache() {
    final set = <String>{};
    for (final h in _holidays) {
      var d = DateTime(h.start.year, h.start.month, h.start.day);
      final end = DateTime(h.end.year, h.end.month, h.end.day);
      while (!d.isAfter(end)) {
        set.add(DateFormat('yyyy-MM-dd').format(d));
        d = d.add(const Duration(days: 1));
      }
    }
    _holidayDateCache = set;
  }

  bool isHolidayDate(DateTime date) {
    return _holidayDateCache.contains(DateFormat('yyyy-MM-dd').format(date));
  }

  Holiday? holidayFor(DateTime date) {
    for (final h in _holidays) {
      if (h.contains(date)) return h;
    }
    return null;
  }

  Future<void> addHoliday({
    required DateTime start,
    required DateTime end,
    String label = '',
  }) async {
    final s = DateTime(start.year, start.month, start.day);
    final e0 = DateTime(end.year, end.month, end.day);
    final e = e0.isBefore(s) ? s : e0;
    _holidays.add(Holiday(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      start: s,
      end: e,
      label: label.trim(),
    ));
    _rebuildHolidayCache();
    await storage.saveHolidays(_holidays);
    notifyListeners();
  }

  Future<void> deleteHoliday(String id) async {
    _holidays.removeWhere((h) => h.id == id);
    _rebuildHolidayCache();
    await storage.saveHolidays(_holidays);
    notifyListeners();
  }

  List<Subject> get subjects {
    final list = [..._subjects]..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  List<String> get subjectNames =>
      subjects.map((s) => s.name).toList(growable: false);

  Subject? findSubject(String name) {
    for (final s in _subjects) {
      if (s.name.toLowerCase() == name.toLowerCase()) return s;
    }
    return null;
  }

  Color colorForSubject(String name) => kSubjectAccent;

  int _defaultColorFor(String name) => kSubjectAccent.toARGB32();

  ThemeMode _parseTheme(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // ------- Routine -------
  List<ClassItem> classesForWeekday(int weekday) {
    return _routine.where((c) => c.weekday == weekday).toList();
  }

  Future<void> addClass(ClassItem c) async {
    _routine.add(c);
    final s = c.subject.trim();
    if (s.isNotEmpty &&
        !_subjects.any((e) => e.name.toLowerCase() == s.toLowerCase())) {
      _subjects.add(Subject(name: s, colorValue: _defaultColorFor(s)));
      await storage.saveSubjects(_subjects);
    }
    await storage.saveRoutine(_routine);
    notifyListeners();
  }

  Future<void> updateClass(ClassItem c) async {
    final idx = _routine.indexWhere((x) => x.id == c.id);
    if (idx < 0) return;
    _routine[idx] = c;
    await storage.saveRoutine(_routine);
    notifyListeners();
  }

  Future<void> deleteClass(String id) async {
    _routine.removeWhere((x) => x.id == id);
    _records.removeWhere((k, _) => k.endsWith('|$id'));
    await storage.saveRoutine(_routine);
    await storage.saveAttendance(_records);
    notifyListeners();
  }

  /// Reorder a class within its weekday. `oldIndex` and `newIndex` are
  /// positions in the filtered list returned by [classesForWeekday], using the
  /// `ReorderableListView.onReorderItem` convention where `newIndex` is the
  /// final destination after the item is removed (no extra adjustment needed).
  Future<void> reorderClassesForDay(
    int weekday,
    int oldIndex,
    int newIndex,
  ) async {
    final dayClasses =
        _routine.where((c) => c.weekday == weekday).toList(growable: true);
    if (oldIndex < 0 || oldIndex >= dayClasses.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= dayClasses.length) newIndex = dayClasses.length - 1;
    if (newIndex == oldIndex) return;
    final moved = dayClasses.removeAt(oldIndex);
    dayClasses.insert(newIndex, moved);
    // Stitch the reordered weekday entries back into _routine in place, keeping
    // all other days' entries at their original positions.
    final iter = dayClasses.iterator;
    final next = <ClassItem>[];
    for (final c in _routine) {
      if (c.weekday == weekday) {
        iter.moveNext();
        next.add(iter.current);
      } else {
        next.add(c);
      }
    }
    _routine = next;
    await storage.saveRoutine(_routine);
    notifyListeners();
  }

  // ------- Attendance -------
  static String keyFor(DateTime date, String classId) {
    final d = DateFormat('yyyy-MM-dd').format(date);
    return '$d|$classId';
  }

  AttendanceStatus statusFor(DateTime date, String classId) {
    return _records[keyFor(date, classId)] ?? AttendanceStatus.none;
  }

  Future<void> setStatus(
      DateTime date, String classId, AttendanceStatus s) async {
    final k = keyFor(date, classId);
    if (s == AttendanceStatus.none) {
      _records.remove(k);
    } else {
      _records[k] = s;
    }
    await storage.saveAttendance(_records);
    _refreshTodayReminder();
    notifyListeners();
  }

  /// Bulk-mark every class id for the given date with the given status.
  Future<void> setStatusForAll(
    DateTime date,
    Iterable<String> classIds,
    AttendanceStatus s,
  ) async {
    for (final id in classIds) {
      final k = keyFor(date, id);
      if (s == AttendanceStatus.none) {
        _records.remove(k);
      } else {
        _records[k] = s;
      }
    }
    await storage.saveAttendance(_records);
    _refreshTodayReminder();
    notifyListeners();
  }

  /// Wipe every attendance mark in a single write. Routine, subjects, and
  /// settings are preserved.
  Future<void> clearAttendance() async {
    if (_records.isEmpty) return;
    _records = {};
    await storage.saveAttendance(_records);
    _refreshTodayReminder();
    notifyListeners();
  }

  /// Apply [status] to every routine class for every date in
  /// `[start, end]` (inclusive). Dates that fall inside a holiday range are
  /// skipped. Returns `(daysProcessed, classesAffected)` so callers can show
  /// a useful confirmation.
  Future<(int, int)> bulkSetForRange(
    DateTime start,
    DateTime end,
    AttendanceStatus status,
  ) async {
    var s = DateTime(start.year, start.month, start.day);
    var e = DateTime(end.year, end.month, end.day);
    if (e.isBefore(s)) {
      final t = s;
      s = e;
      e = t;
    }
    int days = 0;
    int marks = 0;
    var d = s;
    while (!d.isAfter(e)) {
      if (!isHolidayDate(d)) {
        final ids = _routine
            .where((c) => c.weekday == d.weekday)
            .map((c) => c.id)
            .toList();
        if (ids.isNotEmpty) {
          for (final id in ids) {
            final k = keyFor(d, id);
            if (status == AttendanceStatus.none) {
              _records.remove(k);
            } else {
              _records[k] = status;
            }
          }
          days++;
          marks += ids.length;
        }
      }
      d = d.add(const Duration(days: 1));
    }
    if (marks > 0) {
      await storage.saveAttendance(_records);
      _refreshTodayReminder();
      notifyListeners();
    }
    return (days, marks);
  }

  // ------- Stats -------
  Map<String, String> _allClassSubjects() {
    final map = <String, String>{};
    for (final c in _routine) {
      map[c.id] = c.subject;
    }
    for (final e in _extras) {
      map[e.id] = e.subject;
    }
    return map;
  }

  (int, int) statsForSubject(String subject) {
    int p = 0;
    int t = 0;
    final subjects = _allClassSubjects();
    final ids = subjects.entries
        .where((e) => e.value.toLowerCase() == subject.toLowerCase())
        .map((e) => e.key)
        .toSet();
    for (final entry in _records.entries) {
      final parts = entry.key.split('|');
      if (parts.length < 2) continue;
      if (_holidayDateCache.contains(parts.first)) continue;
      final classId = parts.last;
      if (!ids.contains(classId)) continue;
      switch (entry.value) {
        case AttendanceStatus.present:
          p++;
          t++;
          break;
        case AttendanceStatus.absent:
          t++;
          break;
        case AttendanceStatus.off:
        case AttendanceStatus.none:
          break;
      }
    }
    final s = findSubject(subject);
    if (s != null) {
      p += s.priorPresent;
      t += s.priorHeld;
    }
    return (p, t);
  }

  (int, int) overallStats() {
    int p = 0;
    int t = 0;
    for (final entry in _records.entries) {
      final parts = entry.key.split('|');
      if (parts.isEmpty) continue;
      if (_holidayDateCache.contains(parts.first)) continue;
      final v = entry.value;
      if (v == AttendanceStatus.present) {
        p++;
        t++;
      } else if (v == AttendanceStatus.absent) {
        t++;
      }
    }
    for (final s in _subjects) {
      p += s.priorPresent;
      t += s.priorHeld;
    }
    // Each ECA counts as one attended class, but does not add to classes held.
    // Cap attended at held so the overall percentage can never exceed 100%.
    p += _ecaCount;
    if (p > t) p = t;
    return (p, t);
  }

  double overallPercent() {
    final (p, t) = overallStats();
    if (t == 0) return 0;
    return (p / t) * 100;
  }

  double subjectPercent(String subject) {
    final (p, t) = statsForSubject(subject);
    if (t == 0) return 0;
    return (p / t) * 100;
  }

  /// Returns the per-subject target threshold (% as 50..100). Falls back to
  /// the global threshold when the subject has no override or the subject
  /// isn't known.
  double effectiveThreshold(String subject) {
    final s = findSubject(subject);
    final c = s?.customThreshold;
    if (c == null) return _threshold;
    return c.toDouble();
  }

  /// Per-subject safe-bunk count: how many additional held classes a student
  /// can miss and still stay at or above the effective threshold.
  /// Returns -1 if the subject is already below threshold.
  int safeBunkForSubject(String subject) {
    final pct = subjectPercent(subject);
    final target = effectiveThreshold(subject);
    if (pct < target) return -1;
    final (p, t) = statsForSubject(subject);
    int n = 0;
    int held = t;
    while (true) {
      held++;
      final newPct = (p / held) * 100;
      if (newPct < target) break;
      n++;
      if (n > 999) break;
    }
    return n;
  }

  /// Classes the student must attend in a row to climb the subject back to its
  /// effective threshold. Returns 0 when already at/above target.
  int classesToReachThresholdForSubject(String subject) {
    final pct = subjectPercent(subject);
    final target = effectiveThreshold(subject);
    if (pct >= target) return 0;
    var (p, t) = statsForSubject(subject);
    int n = 0;
    while (true) {
      p++;
      t++;
      n++;
      final newPct = (p / t) * 100;
      if (newPct >= target) return n;
      if (n > 9999) return n;
    }
  }

  List<String> uniqueSubjects() {
    final set = <String>{};
    for (final c in _routine) {
      set.add(c.subject);
    }
    for (final e in _extras) {
      set.add(e.subject);
    }
    final list = set.toList()..sort();
    return list;
  }

  double predictIfAbsent() {
    final (p, t) = overallStats();
    final nt = t + 1;
    return (p / nt) * 100;
  }

  double predictIfPresent() {
    final (p, t) = overallStats();
    return ((p + 1) / (t + 1)) * 100;
  }

  /// Counts only raw Present/Absent marks (no ECA boost).
  (int, int) _rawHeldStats() {
    int p = 0;
    int t = 0;
    for (final entry in _records.entries) {
      final parts = entry.key.split('|');
      if (parts.isEmpty) continue;
      if (_holidayDateCache.contains(parts.first)) continue;
      final v = entry.value;
      if (v == AttendanceStatus.present) {
        p++;
        t++;
      } else if (v == AttendanceStatus.absent) {
        t++;
      }
    }
    for (final s in _subjects) {
      p += s.priorPresent;
      t += s.priorHeld;
    }
    return (p, t);
  }

  int safeBunkCount() {
    if (overallPercent() < _threshold) return -1;
    final (rawP, rawT) = _rawHeldStats();
    int n = 0;
    int t = rawT;
    while (true) {
      t++;
      int p = rawP + _ecaCount;
      if (p > t) p = t;
      final pct = (p / t) * 100;
      if (pct < _threshold) break;
      n++;
      if (n > 999) break;
    }
    return n;
  }

  int classesToReachThreshold() {
    if (overallPercent() >= _threshold) return 0;
    var (rawP, rawT) = _rawHeldStats();
    int n = 0;
    while (true) {
      rawP++;
      rawT++;
      n++;
      int p = rawP + _ecaCount;
      if (p > rawT) p = rawT;
      final pct = (p / rawT) * 100;
      if (pct >= _threshold) return n;
      if (n > 9999) return n;
    }
  }

  // ------- Settings -------
  Future<void> setThreshold(double v) async {
    _threshold = v;
    await storage.saveThreshold(v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await storage.saveTheme(_themeToString(m));
    notifyListeners();
  }

  Future<void> setEcaCount(int v) async {
    final next = v < 0 ? 0 : (v > 100 ? 100 : v);
    if (next == _ecaCount) return;
    _ecaCount = next;
    await storage.saveEca(_ecaCount);
    notifyListeners();
  }

  Future<void> incrementEca() => setEcaCount(_ecaCount + 1);
  Future<void> decrementEca() => setEcaCount(_ecaCount - 1);

  Future<void> factoryReset() async {
    _routine = [];
    _records = {};
    _subjects = [];
    _extras = [];
    _holidays = [];
    _holidayDateCache = {};
    _threshold = 75;
    _themeMode = ThemeMode.system;
    _ecaCount = 0;
    await storage.clearAll();
    _refreshTodayReminder();
    notifyListeners();
  }

  // ------- Subjects -------
  Future<bool> addSubject(
    String name, {
    int? colorValue,
    String teacher = '',
    int priorPresent = 0,
    int priorAbsent = 0,
    int? customThreshold,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return false;
    if (_subjects.any((s) => s.name.toLowerCase() == n.toLowerCase())) {
      return false;
    }
    _subjects.add(Subject(
      name: n,
      colorValue: colorValue ?? _defaultColorFor(n),
      teacher: teacher.trim(),
      priorPresent: priorPresent < 0 ? 0 : priorPresent,
      priorAbsent: priorAbsent < 0 ? 0 : priorAbsent,
      customThreshold: customThreshold,
    ));
    await storage.saveSubjects(_subjects);
    notifyListeners();
    return true;
  }

  Future<void> updateSubject(
    String oldName, {
    String? newName,
    int? colorValue,
    String? teacher,
    int? priorPresent,
    int? priorAbsent,
    int? customThreshold,
    bool clearCustomThreshold = false,
  }) async {
    final idx = _subjects
        .indexWhere((s) => s.name.toLowerCase() == oldName.toLowerCase());
    if (idx < 0) return;
    final old = _subjects[idx];
    final newNameTrim = (newName ?? old.name).trim();
    if (newNameTrim.isEmpty) return;
    // If renaming to a name that collides with another subject, refuse.
    if (newNameTrim.toLowerCase() != old.name.toLowerCase() &&
        _subjects.any((s) =>
            s.name.toLowerCase() == newNameTrim.toLowerCase())) {
      return;
    }
    final replacement = Subject(
      name: newNameTrim,
      colorValue: colorValue ?? old.colorValue,
      teacher: (teacher ?? old.teacher).trim(),
      priorPresent: (priorPresent ?? old.priorPresent) < 0
          ? 0
          : (priorPresent ?? old.priorPresent),
      priorAbsent: (priorAbsent ?? old.priorAbsent) < 0
          ? 0
          : (priorAbsent ?? old.priorAbsent),
      customThreshold: clearCustomThreshold
          ? null
          : (customThreshold ?? old.customThreshold),
    );
    _subjects[idx] = replacement;
    // Cascade rename across routine + extras.
    if (newNameTrim.toLowerCase() != old.name.toLowerCase()) {
      for (final c in _routine) {
        if (c.subject.toLowerCase() == old.name.toLowerCase()) {
          c.subject = newNameTrim;
        }
      }
      for (final e in _extras) {
        if (e.subject.toLowerCase() == old.name.toLowerCase()) {
          e.subject = newNameTrim;
        }
      }
      await storage.saveRoutine(_routine);
      await storage.saveExtras(_extras);
    }
    await storage.saveSubjects(_subjects);
    notifyListeners();
  }

  Future<void> deleteSubject(String name) async {
    _subjects.removeWhere((s) => s.name.toLowerCase() == name.toLowerCase());
    
    final removedIds = <String>{};
    
    _routine.removeWhere((c) {
      if (c.subject.toLowerCase() == name.toLowerCase()) {
        removedIds.add(c.id);
        return true;
      }
      return false;
    });
    
    _extras.removeWhere((e) {
      if (e.subject.toLowerCase() == name.toLowerCase()) {
        removedIds.add(e.id);
        return true;
      }
      return false;
    });
    
    if (removedIds.isNotEmpty) {
      _records.removeWhere((k, _) {
        final classId = k.split('|').last;
        return removedIds.contains(classId);
      });
      await storage.saveAttendance(_records);
    }
    
    await storage.saveSubjects(_subjects);
    await storage.saveRoutine(_routine);
    await storage.saveExtras(_extras);
    notifyListeners();
  }

  // ------- Extra (ad-hoc) classes -------
  List<ExtraClass> extrasForDate(DateTime date) {
    final list = _extras
        .where((e) => DateUtils.isSameDay(e.date, date))
        .toList()
      ..sort((a, b) =>
          timeToMinutes(a.start).compareTo(timeToMinutes(b.start)));
    return list;
  }

  Future<void> addExtraClass(ExtraClass e) async {
    _extras.add(e);
    final s = e.subject.trim();
    if (s.isNotEmpty &&
        !_subjects.any((x) => x.name.toLowerCase() == s.toLowerCase())) {
      _subjects.add(Subject(name: s, colorValue: _defaultColorFor(s)));
      await storage.saveSubjects(_subjects);
    }
    await storage.saveExtras(_extras);
    notifyListeners();
  }

  Future<void> deleteExtraClass(String id) async {
    _extras.removeWhere((e) => e.id == id);
    _records.removeWhere((k, _) => k.endsWith('|$id'));
    await storage.saveExtras(_extras);
    await storage.saveAttendance(_records);
    notifyListeners();
  }
}
