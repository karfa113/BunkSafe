import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../widgets/app_bar_percent.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [
          AppBarPercent(),
          SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 110),
        children: [
          _SectionTitle('Attendance target'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Minimum %',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.threshold.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ThresholdSlider(
                    value: state.threshold,
                    onChanged: (v) => state.setThreshold(v),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When your overall attendance is below this, the app will warn you before marking absent.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('Extra-curricular activities'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('ECA credits',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.ecaCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _EcaStepperButton(
                        icon: Icons.remove_rounded,
                        onPressed: state.ecaCount > 0
                            ? () => state.decrementEca()
                            : null,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${state.ecaCount} ECA',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      _EcaStepperButton(
                        icon: Icons.add_rounded,
                        onPressed:
                            (state.ecaCount < 100 && state.overallPercent() < 100)
                                ? () => state.incrementEca()
                                : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Each ECA adds one attended class without increasing classes held. Disabled at 100%.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('Appearance'),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: state.themeMode,
              onChanged: (v) {
                if (v != null) state.setThemeMode(v);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('System default'),
                    value: ThemeMode.system,
                    secondary: Icon(Icons.brightness_auto),
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Light'),
                    value: ThemeMode.light,
                    secondary: Icon(Icons.light_mode_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                    secondary: Icon(Icons.dark_mode_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFF118AB2)),
                  title: const Text('Get attendance report'),
                  subtitle: const Text(
                      'Generate a PDF with overall and per-subject attendance.'),
                  onTap: () => _exportAttendanceReportPdf(context, state),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined,
                      color: Color(0xFFEF476F)),
                  title: const Text('Clear all attendance'),
                  subtitle: const Text(
                      'Keeps routine; removes all marked entries.'),
                  onTap: () => _clearAttendance(context, state),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded,
                      color: Color(0xFFEF476F)),
                  title: const Text('Factory reset'),
                  subtitle: const Text(
                      'Erase routine, subjects, marks, and settings.'),
                  onTap: () => _factoryReset(context, state),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('About'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('BunkSafe'),
              subtitle: const Text('v1.1.0\nDeveloped by M. Karfa'),
              isThreeLine: true,
              titleAlignment: ListTileTitleAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAttendance(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all attendance?'),
        content: const Text(
            'This will remove every present/absent/off mark you have made. Routine will remain intact.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.clearAttendance();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance cleared.')),
    );
  }

  Future<void> _factoryReset(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory reset?'),
        content: const Text(
            'This will permanently erase your routine, subjects, extras, every attendance mark, and your settings (threshold and theme). This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF476F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
            'Every routine entry, subject, extra class, attendance mark, and setting will be wiped. There is no undo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep my data')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF476F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, erase'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await state.factoryReset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factory reset complete.')),
    );
  }

  Future<void> _exportAttendanceReportPdf(
      BuildContext context, AppState state) async {
    final subjects = state.uniqueSubjects();
    final (overallPresent, overallTotal) = state.overallStats();
    final overallPct = state.overallPercent();
    final threshold = state.threshold;

    if (overallTotal == 0 && subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to report yet.')),
      );
      return;
    }

    final perSubject = <_SubjectReportRow>[];
    for (final s in subjects) {
      final (p, t) = state.statsForSubject(s);
      final pct = t == 0 ? 0.0 : (p / t) * 100.0;
      perSubject.add(_SubjectReportRow(
        name: s,
        attended: p,
        held: t,
        percent: pct,
      ));
    }
    perSubject.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final doc = pw.Document();
    final generatedAt = DateFormat('d MMM y, h:mm a').format(DateTime.now());
    final belowTarget = overallPct < threshold;

    PdfColor goodColor = const PdfColor.fromInt(0xFF06D6A0);
    PdfColor badColor = const PdfColor.fromInt(0xFFEF476F);
    PdfColor mutedColor = const PdfColor.fromInt(0xFF6B6B7A);
    PdfColor accentColor = const PdfColor.fromInt(0xFF6750A4);

    PdfColor pctColor(double pct, bool unmarked) {
      if (unmarked) return mutedColor;
      return pct >= threshold ? goodColor : badColor;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'BunkSafe — Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: mutedColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated $generatedAt',
                style: pw.TextStyle(fontSize: 9, color: mutedColor),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: mutedColor),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'BunkSafe • $generatedAt',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    '${overallPct.toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: belowTarget ? badColor : goodColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Overall',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: mutedColor,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: (belowTarget ? badColor : goodColor),
                width: 1.2,
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                _kv('Classes held', '$overallTotal'),
                _kv('Attended', '$overallPresent'),
                _kv('Missed', '${overallTotal - overallPresent}'),
                _kv('Target', '${threshold.toStringAsFixed(0)}%'),
                _kv(
                  'Status',
                  belowTarget ? 'Below target' : 'On track',
                  color: belowTarget ? badColor : goodColor,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Per-subject breakdown',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: mutedColor,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 6),
          if (perSubject.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: mutedColor, width: 0.6),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'No subjects yet.',
                style: pw.TextStyle(color: mutedColor, fontSize: 11),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFE0E0E6),
                width: 0.6,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.2),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1ECFA),
                  ),
                  children: [
                    _th('Subject'),
                    _th('Held', align: pw.TextAlign.center),
                    _th('Attended', align: pw.TextAlign.center),
                    _th('Percent', align: pw.TextAlign.right),
                  ],
                ),
                ...perSubject.map((r) {
                  final unmarked = r.held == 0;
                  return pw.TableRow(
                    children: [
                      _td(r.name),
                      _td('${r.held}', align: pw.TextAlign.center),
                      _td('${r.attended}', align: pw.TextAlign.center),
                      _td(
                        unmarked ? '—' : '${r.percent.toStringAsFixed(1)}%',
                        align: pw.TextAlign.right,
                        color: pctColor(r.percent, unmarked),
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF5F2FB),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Note: "Held" counts only Present + Absent marks (Off days are excluded). '
              'ECA credits, if any, are reflected only in the overall figure.',
              style: pw.TextStyle(fontSize: 9, color: mutedColor),
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fname =
          'attendance_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File('${dir.path}${Platform.pathSeparator}$fname');
      await file.writeAsBytes(bytes, flush: true);

      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Attendance report',
          text: 'Attendance report from BunkSafe.',
        );
      } catch (_) {
        await Printing.sharePdf(bytes: bytes, filename: fname);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated $fname')),
      );
    } catch (e) {
      try {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'attendance_report.pdf',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared attendance report.')),
        );
      } catch (e2) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create report: $e2')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _EcaStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _EcaStepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = enabled
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.3);
    return Material(
      color: enabled
          ? cs.primary.withValues(alpha: 0.12)
          : cs.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 40,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _ThresholdSlider({required this.value, required this.onChanged});

  // Checkpoint percentages users typically care about.
  static const _checkpoints = <int>[50, 60, 70, 80, 90, 100];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.primary.withValues(alpha: 0.15),
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.18),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 3,
              pressedElevation: 6,
            ),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 22),
            valueIndicatorColor: cs.primary,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            showValueIndicator: ShowValueIndicator.onDrag,
          ),
          child: Slider(
            value: value.clamp(50.0, 100.0),
            min: 50,
            max: 100,
            // Continuous (no divisions) → smooth, fine-grained dragging.
            label: '${value.round()}%',
            onChanged: onChanged,
          ),
        ),
        // Visual checkpoint markers + labels.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 26,
                child: Stack(
                  children: _checkpoints.map((cp) {
                    final t = (cp - 50) / 50.0;
                    // The Slider track has some horizontal padding. We calculate the left 
                    // offset so the label stays within bounds and aligns with the track.
                    final leftPos = 8 + t * (width - 48);
                    final reached = value >= cp;
                    return Positioned(
                      left: leftPos,
                      top: 0,
                      width: 32,
                      child: GestureDetector(
                        onTap: () => onChanged(cp.toDouble()),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: reached
                                    ? cs.primary
                                    : cs.primary.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$cp',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: reached
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SubjectReportRow {
  final String name;
  final int attended;
  final int held;
  final double percent;
  const _SubjectReportRow({
    required this.name,
    required this.attended,
    required this.held,
    required this.percent,
  });
}

pw.Widget _kv(String label, String value, {PdfColor? color}) {
  final muted = const PdfColor.fromInt(0xFF6B6B7A);
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            color: muted,
            letterSpacing: 0.6,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF6750A4),
      ),
    ),
  );
}

pw.Widget _td(
  String text, {
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor? color,
  bool bold = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 10,
        color: color ?? PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

