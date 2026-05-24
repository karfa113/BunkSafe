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

  Subject({
    required this.name,
    required this.colorValue,
    this.teacher = '',
  });

  Color get color => kSubjectAccent;

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': colorValue,
        'teacher': teacher,
      };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        name: j['name'] as String,
        colorValue: j['color'] as int,
        teacher: (j['teacher'] as String?) ?? '',
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
