import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

/// Polished bottom-sheet for adding (or editing) a Subject.
/// Returns the trimmed name on success, or null if cancelled / duplicate.
Future<String?> showAddSubjectSheet(
  BuildContext context, {
  Subject? edit,
}) async {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddSubjectSheet(edit: edit),
  );
}

class _AddSubjectSheet extends StatefulWidget {
  final Subject? edit;
  const _AddSubjectSheet({this.edit});

  @override
  State<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

enum _ManualSide { present, absent }

class _AddSubjectSheetState extends State<_AddSubjectSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _teacherCtl;
  late final TextEditingController _heldCtl;
  late final TextEditingController _presentCtl;
  late final TextEditingController _absentCtl;
  late final FocusNode _heldFocus;
  late final FocusNode _presentFocus;
  late final FocusNode _absentFocus;
  // Which of {present, absent} the user is treating as the manual input.
  // The other one is auto-computed from Held - manual.
  _ManualSide _manualSide = _ManualSide.present;
  // Per-subject target. null = use global threshold.
  bool _customThresholdOn = false;
  double _customThreshold = 75;
  String? _error;
  bool _busy = false;
  bool _suppressAuto = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.edit?.name ?? '');
    _teacherCtl = TextEditingController(text: widget.edit?.teacher ?? '');

    final priorP = widget.edit?.priorPresent ?? 0;
    final priorA = widget.edit?.priorAbsent ?? 0;
    final priorH = priorP + priorA;
    _heldCtl =
        TextEditingController(text: priorH > 0 ? priorH.toString() : '');
    _presentCtl =
        TextEditingController(text: priorP > 0 ? priorP.toString() : '');
    _absentCtl =
        TextEditingController(text: priorA > 0 ? priorA.toString() : '');

    _heldFocus = FocusNode()
      ..addListener(() {
        if (_heldFocus.hasFocus) _selectAll(_heldCtl);
      });
    _presentFocus = FocusNode()
      ..addListener(() {
        if (_presentFocus.hasFocus) {
          _selectAll(_presentCtl);
          setState(() => _manualSide = _ManualSide.present);
        }
      });
    _absentFocus = FocusNode()
      ..addListener(() {
        if (_absentFocus.hasFocus) {
          _selectAll(_absentCtl);
          setState(() => _manualSide = _ManualSide.absent);
        }
      });

    final ct = widget.edit?.customThreshold;
    if (ct != null) {
      _customThresholdOn = true;
      _customThreshold = ct.toDouble().clamp(50.0, 95.0);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _teacherCtl.dispose();
    _heldCtl.dispose();
    _presentCtl.dispose();
    _absentCtl.dispose();
    _heldFocus.dispose();
    _presentFocus.dispose();
    _absentFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _selectAll(TextEditingController c) {
    if (c.text.isEmpty) return;
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  void _setNumber(TextEditingController c, int value) {
    final s = value.toString();
    if (c.text == s) return;
    c.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  void _onHeldChanged(String _) {
    _clearError();
    final held = int.tryParse(_heldCtl.text.trim()) ?? 0;
    if (held > 0) {
      // Reducing Held below the manual side: clamp the manual value down so
      // Present + Absent can never exceed Held.
      if (_manualSide == _ManualSide.present) {
        final p = int.tryParse(_presentCtl.text.trim()) ?? 0;
        if (p > held) _setNumber(_presentCtl, held);
      } else {
        final a = int.tryParse(_absentCtl.text.trim()) ?? 0;
        if (a > held) _setNumber(_absentCtl, held);
      }
    }
    _recomputeAuto();
  }

  void _onPresentChanged(String _) {
    _clearError();
    if (_suppressAuto) return;
    final held = int.tryParse(_heldCtl.text.trim()) ?? 0;
    if (held > 0) {
      final p = int.tryParse(_presentCtl.text.trim()) ?? 0;
      if (p > held) _setNumber(_presentCtl, held);
    }
    _recomputeAuto();
  }

  void _onAbsentChanged(String _) {
    _clearError();
    if (_suppressAuto) return;
    final held = int.tryParse(_heldCtl.text.trim()) ?? 0;
    if (held > 0) {
      final a = int.tryParse(_absentCtl.text.trim()) ?? 0;
      if (a > held) _setNumber(_absentCtl, held);
    }
    _recomputeAuto();
  }

  void _recomputeAuto() {
    final held = int.tryParse(_heldCtl.text.trim()) ?? 0;
    if (held <= 0) return;
    _suppressAuto = true;
    if (_manualSide == _ManualSide.present) {
      final p = int.tryParse(_presentCtl.text.trim()) ?? 0;
      final a = (held - p).clamp(0, held);
      final next = a.toString();
      if (_absentCtl.text != next) _absentCtl.text = next;
    } else {
      final a = int.tryParse(_absentCtl.text.trim()) ?? 0;
      final p = (held - a).clamp(0, held);
      final next = p.toString();
      if (_presentCtl.text != next) _presentCtl.text = next;
    }
    _suppressAuto = false;
  }

  Future<void> _submit(AppState state) async {
    final name = _nameCtl.text.trim();
    final teacher = _teacherCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a subject name.');
      return;
    }

    final held = int.tryParse(_heldCtl.text.trim()) ?? 0;
    final present = int.tryParse(_presentCtl.text.trim()) ?? 0;
    final absent = int.tryParse(_absentCtl.text.trim()) ?? 0;
    if (held < 0 || present < 0 || absent < 0) {
      setState(() => _error = 'Counts cannot be negative.');
      return;
    }
    if (held > 0 && present + absent > held) {
      setState(() =>
          _error = 'Present + Absent cannot exceed Classes held.');
      return;
    }
    // Derive the saved pair so priorPresent + priorAbsent == held when Held
    // was entered. The manually-typed side wins; the other is derived.
    int savePresent;
    int saveAbsent;
    if (held > 0) {
      if (_manualSide == _ManualSide.present) {
        savePresent = present.clamp(0, held);
        saveAbsent = held - savePresent;
      } else {
        saveAbsent = absent.clamp(0, held);
        savePresent = held - saveAbsent;
      }
    } else {
      // No Held entered — accept what user typed (usually 0/0).
      savePresent = present;
      saveAbsent = absent;
    }

    setState(() => _busy = true);

    if (_isEdit) {
      if (name.toLowerCase() != widget.edit!.name.toLowerCase() &&
          state.subjects
              .any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        setState(() {
          _busy = false;
          _error = '"$name" already exists.';
        });
        return;
      }
      await state.updateSubject(
        widget.edit!.name,
        newName: name,
        colorValue: kSubjectAccent.toARGB32(),
        teacher: teacher,
        priorPresent: savePresent,
        priorAbsent: saveAbsent,
        customThreshold:
            _customThresholdOn ? _customThreshold.round() : null,
        clearCustomThreshold: !_customThresholdOn,
      );
      if (!mounted) return;
      Navigator.of(context).pop(name);
      return;
    }

    if (state.subjects
        .any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      setState(() {
        _busy = false;
        _error = '"$name" already exists.';
      });
      return;
    }
    final ok = await state.addSubject(
      name,
      colorValue: kSubjectAccent.toARGB32(),
      teacher: teacher,
      priorPresent: savePresent,
      priorAbsent: saveAbsent,
      customThreshold:
          _customThresholdOn ? _customThreshold.round() : null,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Could not save this subject.';
      });
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final accent = kSubjectAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1626) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isEdit
                          ? Icons.edit_rounded
                          : Icons.bookmark_add_rounded,
                      color: const Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit subject' : 'New subject',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEdit
                              ? 'Change the details.'
                              : 'Add something you\'re studying.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtl,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                decoration: InputDecoration(
                  labelText: 'Subject name',
                  hintText: 'e.g. Discrete Mathematics',
                  prefixIcon:
                      Icon(Icons.menu_book_rounded, color: accent),
                  errorText: _error,
                  filled: true,
                  fillColor: accent.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _teacherCtl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Teacher name',
                  hintText: 'e.g. Dr. Sharma',
                  prefixIcon:
                      Icon(Icons.person_outline, color: accent),
                  filled: true,
                  fillColor: accent.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PriorAttendanceSection(
                accent: accent,
                heldCtl: _heldCtl,
                presentCtl: _presentCtl,
                absentCtl: _absentCtl,
                heldFocus: _heldFocus,
                presentFocus: _presentFocus,
                absentFocus: _absentFocus,
                manualSide: _manualSide,
                onHeldChanged: _onHeldChanged,
                onPresentChanged: _onPresentChanged,
                onAbsentChanged: _onAbsentChanged,
              ),
              const SizedBox(height: 14),
              _CustomThresholdSection(
                accent: accent,
                enabled: _customThresholdOn,
                value: _customThreshold,
                globalDefault: state.threshold,
                onEnabledChanged: (v) =>
                    setState(() => _customThresholdOn = v),
                onValueChanged: (v) =>
                    setState(() => _customThreshold = v),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _submit(state),
                      icon: Icon(_isEdit
                          ? Icons.check_rounded
                          : Icons.add_rounded),
                      label: Text(_busy
                          ? 'Saving…'
                          : (_isEdit ? 'Save changes' : 'Add subject')),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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

class _PriorAttendanceSection extends StatelessWidget {
  final Color accent;
  final TextEditingController heldCtl;
  final TextEditingController presentCtl;
  final TextEditingController absentCtl;
  final FocusNode heldFocus;
  final FocusNode presentFocus;
  final FocusNode absentFocus;
  final _ManualSide manualSide;
  final ValueChanged<String> onHeldChanged;
  final ValueChanged<String> onPresentChanged;
  final ValueChanged<String> onAbsentChanged;

  const _PriorAttendanceSection({
    required this.accent,
    required this.heldCtl,
    required this.presentCtl,
    required this.absentCtl,
    required this.heldFocus,
    required this.presentFocus,
    required this.absentFocus,
    required this.manualSide,
    required this.onHeldChanged,
    required this.onPresentChanged,
    required this.onAbsentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final autoPresent = manualSide == _ManualSide.absent;
    final autoAbsent = manualSide == _ManualSide.present;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              const Text(
                'Already attended some classes?',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optional — handy when you join mid-semester. Type any two; '
            'the third fills in.',
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PriorField(
                  controller: heldCtl,
                  focusNode: heldFocus,
                  accent: accent,
                  label: 'Held',
                  onChanged: onHeldChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorField(
                  controller: presentCtl,
                  focusNode: presentFocus,
                  accent: accent,
                  label: 'Present',
                  isAuto: autoPresent,
                  onChanged: onPresentChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorField(
                  controller: absentCtl,
                  focusNode: absentFocus,
                  accent: accent,
                  label: 'Absent',
                  isAuto: autoAbsent,
                  onChanged: onAbsentChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Color accent;
  final String label;
  final bool isAuto;
  final ValueChanged<String> onChanged;

  const _PriorField({
    required this.controller,
    this.focusNode,
    required this.accent,
    required this.label,
    this.isAuto = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textAlign: TextAlign.center,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: cs.onSurface.withValues(alpha: 0.7),
        ),
        hintText: '0',
        helperText: isAuto ? 'auto' : ' ',
        helperStyle: TextStyle(
          fontSize: 10.5,
          color: accent.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
    );
  }
}

class _CustomThresholdSection extends StatelessWidget {
  final Color accent;
  final bool enabled;
  final double value;
  final double globalDefault;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<double> onValueChanged;
  const _CustomThresholdSection({
    required this.accent,
    required this.enabled,
    required this.value,
    required this.globalDefault,
    required this.onEnabledChanged,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Custom attendance target',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: accent,
                onChanged: onEnabledChanged,
              ),
            ],
          ),
          Text(
            enabled
                ? 'This subject targets ${value.round()}%.'
                : 'Uses the global target (${globalDefault.toStringAsFixed(0)}%). Turn on to override.',
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accent,
                inactiveTrackColor: accent.withValues(alpha: 0.18),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.16),
                valueIndicatorColor: accent,
              ),
              child: Slider(
                value: value.clamp(50.0, 95.0),
                min: 50,
                max: 95,
                divisions: 45,
                label: '${value.round()}%',
                onChanged: onValueChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
