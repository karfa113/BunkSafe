import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class StorageService {
  static const _kRoutine = 'routine_v1';
  static const _kAttendance = 'attendance_v1';
  static const _kThreshold = 'threshold_v1';
  static const _kTheme = 'theme_v1';
  static const _kSubjects = 'subjects_v1';
  static const _kExtras = 'extras_v1';
  static const _kEca = 'eca_v1';
  static const _kHolidays = 'holidays_v1';

  final SharedPreferences prefs;
  StorageService(this.prefs);

  static Future<StorageService> create() async {
    final p = await SharedPreferences.getInstance();
    return StorageService(p);
  }

  List<ClassItem> loadRoutine() {
    final raw = prefs.getString(_kRoutine);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ClassItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRoutine(List<ClassItem> routine) async {
    final s = jsonEncode(routine.map((e) => e.toJson()).toList());
    await prefs.setString(_kRoutine, s);
  }

  // attendance key: yyyy-MM-dd|classId -> status code
  Map<String, AttendanceStatus> loadAttendance() {
    final raw = prefs.getString(_kAttendance);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, AttendanceStatusX.fromCode(v as String)),
    );
  }

  Future<void> saveAttendance(Map<String, AttendanceStatus> records) async {
    final m = records.map((k, v) => MapEntry(k, v.code));
    await prefs.setString(_kAttendance, jsonEncode(m));
  }

  double loadThreshold() => prefs.getDouble(_kThreshold) ?? 75.0;
  Future<void> saveThreshold(double v) async =>
      prefs.setDouble(_kThreshold, v);

  int loadEca() => prefs.getInt(_kEca) ?? 0;
  Future<void> saveEca(int v) async => prefs.setInt(_kEca, v);

  String loadTheme() => prefs.getString(_kTheme) ?? 'system';
  Future<void> saveTheme(String t) async => prefs.setString(_kTheme, t);

  List<Subject> loadSubjects() {
    final raw = prefs.getString(_kSubjects);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map<Subject>((e) {
      if (e is String) {
        // Legacy migration: bare strings → Subject with hashed default color.
        return Subject(
          name: e,
          colorValue: _legacyDefaultColor(e),
          teacher: '',
        );
      }
      return Subject.fromJson(e as Map<String, dynamic>);
    }).toList();
  }

  Future<void> saveSubjects(List<Subject> subjects) async {
    await prefs.setString(
      _kSubjects,
      jsonEncode(subjects.map((s) => s.toJson()).toList()),
    );
  }

  // Stable default color for legacy subjects (matches AppTheme palette).
  static int _legacyDefaultColor(String name) {
    const palette = <int>[
      0xFFEF476F,
      0xFFFFD166,
      0xFF06D6A0,
      0xFF118AB2,
      0xFF8338EC,
      0xFFFF7A45,
      0xFF26A69A,
      0xFFEC407A,
    ];
    final idx = name.hashCode.abs() % palette.length;
    return palette[idx];
  }

  List<ExtraClass> loadExtras() {
    final raw = prefs.getString(_kExtras);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ExtraClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveExtras(List<ExtraClass> extras) async {
    final s = jsonEncode(extras.map((e) => e.toJson()).toList());
    await prefs.setString(_kExtras, s);
  }

  List<Holiday> loadHolidays() {
    final raw = prefs.getString(_kHolidays);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHolidays(List<Holiday> holidays) async {
    final s = jsonEncode(holidays.map((h) => h.toJson()).toList());
    await prefs.setString(_kHolidays, s);
  }

  Future<void> clearAll() async {
    await prefs.clear();
  }
}
