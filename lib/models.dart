import 'package:flutter/material.dart';

const Color kSubjectAccent = Color(0xFF43A047);

enum AttendanceStatus { present, absent, off, none }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.off:
        return 'Off';
      case AttendanceStatus.none:
        return 'Unmarked';
    }
  }

  String get code {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.off:
        return 'O';
      case AttendanceStatus.none:
        return '-';
    }
  }

  static AttendanceStatus fromCode(String c) {
    switch (c) {
      case 'P':
        return AttendanceStatus.present;
      case 'A':
        return AttendanceStatus.absent;
      case 'O':
        return AttendanceStatus.off;
      default:
        return AttendanceStatus.none;
    }
  }
}

class ClassItem {
  final String id;
  String subject;
  TimeOfDay start;
  TimeOfDay end;
  int weekday; // 1 = Monday ... 7 = Sunday
  int colorValue;

  ClassItem({
    required this.id,
    required this.subject,
    required this.start,
    required this.end,
    required this.weekday,
    required this.colorValue,
  });

  Color get color => kSubjectAccent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'startH': start.hour,
        'startM': start.minute,
        'endH': end.hour,
        'endM': end.minute,
        'weekday': weekday,
        'color': colorValue,
      };

  factory ClassItem.fromJson(Map<String, dynamic> j) => ClassItem(
        id: j['id'] as String,
        subject: j['subject'] as String,
        start: TimeOfDay(hour: j['startH'] as int, minute: j['startM'] as int),
        end: TimeOfDay(hour: j['endH'] as int, minute: j['endM'] as int),
        weekday: j['weekday'] as int,
        colorValue: j['color'] as int,
      );
}

String fmtTime(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

int timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

/// A subject the student tracks. Carries display color and teacher name
/// alongside the subject name, so classes/extras can derive their visuals
/// from a single source.
class Subject {
  final String name;
  int colorValue;
  String teacher;
  // Baseline counts entered when a student joins the app mid-semester.
  // Folded into stats so they don't have to back-fill the calendar day by day.
  int priorPresent;
  int priorAbsent;
  // Per-subject attendance target. Null = use global threshold.
  int? customThreshold;

  Subject({
    required this.name,
    required this.colorValue,
    this.teacher = '',
    this.priorPresent = 0,
    this.priorAbsent = 0,
    this.customThreshold,
  });

  Color get color => kSubjectAccent;

  int get priorHeld => priorPresent + priorAbsent;

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': colorValue,
        'teacher': teacher,
        'priorPresent': priorPresent,
        'priorAbsent': priorAbsent,
        if (customThreshold != null) 'customThreshold': customThreshold,
      };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        name: j['name'] as String,
        colorValue: j['color'] as int,
        teacher: (j['teacher'] as String?) ?? '',
        priorPresent: (j['priorPresent'] as int?) ?? 0,
        priorAbsent: (j['priorAbsent'] as int?) ?? 0,
        customThreshold: j['customThreshold'] as int?,
      );
}

/// A range of dates the student should not be marked against (semester
/// breaks, public holidays, etc.). Held / unmarked counts on these days are
/// skipped in stats math.
class Holiday {
  final String id;
  DateTime start; // y/m/d only
  DateTime end;   // y/m/d only, inclusive
  String label;

  Holiday({
    required this.id,
    required this.start,
    required this.end,
    this.label = '',
  });

  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  int get days =>
      DateTime(end.year, end.month, end.day)
          .difference(DateTime(start.year, start.month, start.day))
          .inDays +
      1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sy': start.year,
        'sm': start.month,
        'sd': start.day,
        'ey': end.year,
        'em': end.month,
        'ed': end.day,
        'label': label,
      };

  factory Holiday.fromJson(Map<String, dynamic> j) => Holiday(
        id: j['id'] as String,
        start: DateTime(j['sy'] as int, j['sm'] as int, j['sd'] as int),
        end: DateTime(j['ey'] as int, j['em'] as int, j['ed'] as int),
        label: (j['label'] as String?) ?? '',
      );
}

/// An ad-hoc class for a specific date (e.g. makeup lecture, extra session).
/// Lives outside the weekly routine.
class ExtraClass {
  final String id;
  String subject;
  TimeOfDay start;
  TimeOfDay end;
  DateTime date; // y/m/d only (time ignored)
  int colorValue;

  ExtraClass({
    required this.id,
    required this.subject,
    required this.start,
    required this.end,
    required this.date,
    required this.colorValue,
  });

  Color get color => kSubjectAccent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'startH': start.hour,
        'startM': start.minute,
        'endH': end.hour,
        'endM': end.minute,
        'y': date.year,
        'm': date.month,
        'd': date.day,
        'color': colorValue,
      };

  factory ExtraClass.fromJson(Map<String, dynamic> j) => ExtraClass(
        id: j['id'] as String,
        subject: j['subject'] as String,
        start: TimeOfDay(hour: j['startH'] as int, minute: j['startM'] as int),
        end: TimeOfDay(hour: j['endH'] as int, minute: j['endM'] as int),
        date: DateTime(j['y'] as int, j['m'] as int, j['d'] as int),
        colorValue: j['color'] as int,
      );
}
