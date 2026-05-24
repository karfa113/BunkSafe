import 'package:flutter/material.dart';
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

class _AddSubjectSheetState extends State<_AddSubjectSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _teacherCtl;
  String? _error;
  bool _busy = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.edit?.name ?? '');
    _teacherCtl = TextEditingController(text: widget.edit?.teacher ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _teacherCtl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    final name = _nameCtl.text.trim();
    final teacher = _teacherCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a subject name.');
      return;
    }
    setState(() => _busy = true);

    if (_isEdit) {
      // Editing existing subject.
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
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(state),
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
