import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';

/// Pushes today's class list + safe-bunk count to the Android home-screen
/// widget. Called from AppState whenever relevant data changes. iOS / web /
/// desktop are no-ops.
class WidgetSync {
  static const _androidWidgetName = 'BunkSafeWidgetProvider';
  static const _payloadKey = 'widget_payload';
  // Coalesce bursts of state changes (e.g. bulk-mark, cascading rename) into
  // a single widget update so we don't write SharedPreferences N times per
  // tick. The home screen widget can lag ~150ms behind without anyone noticing.
  static const _debounce = Duration(milliseconds: 250);
  static Timer? _pending;
  static AppState? _latest;

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Schedule a debounced widget refresh. Subsequent calls within the
  /// debounce window all collapse into one update against the latest state.
  /// Fire-and-forget — exceptions are swallowed (widget is best-effort).
  static void refresh(AppState state) {
    if (!_supported) return;
    _latest = state;
    _pending?.cancel();
    _pending = Timer(_debounce, _flush);
  }

  static Future<void> _flush() async {
    final state = _latest;
    _pending = null;
    if (state == null) return;
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final dateLabel = DateFormat('EEE, d MMM').format(today);
      final pct = state.overallPercent();
      final (_, held) = state.overallStats();
      final pctText = held == 0 ? '—' : '${pct.toStringAsFixed(0)}%';
      final holiday = state.holidayFor(today);

      String footer;
      List<Map<String, String>> classList;
      bool isHoliday;
      String holidayLabel;
      if (holiday != null) {
        isHoliday = true;
        holidayLabel = holiday.label.isEmpty ? 'Holiday' : holiday.label;
        classList = const [];
        footer = 'Skipped from stats';
      } else {
        isHoliday = false;
        holidayLabel = '';
        final classes = state.classesForWeekday(today.weekday);
        classList = classes.map((c) {
          final t = state.findSubject(c.subject)?.teacher ?? '';
          final s = state.statusFor(today, c.id);
          return {
            'subject': c.subject,
            'teacher': t,
            'status': s.code,
          };
        }).toList();
        if (held == 0) {
          footer = 'No marks yet';
        } else if (pct < state.threshold) {
          final n = state.classesToReachThreshold();
          footer = n > 0 && n <= 9999 ? 'Attend $n in a row' : 'Below target';
        } else {
          final safe = state.safeBunkCount();
          footer = safe > 0 ? 'Safe to skip $safe' : 'Right at target';
        }
      }

      final payload = jsonEncode({
        'date': dateLabel,
        'pct': pctText,
        'footer': footer,
        'isHoliday': isHoliday,
        'holidayLabel': holidayLabel,
        'classes': classList,
      });

      await HomeWidget.saveWidgetData<String>(_payloadKey, payload);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WidgetSync.refresh failed: $e');
      }
    }
  }
}
