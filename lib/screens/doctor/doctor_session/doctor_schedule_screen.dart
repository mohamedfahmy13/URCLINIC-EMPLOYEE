import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../utils/colors.dart';
import 'doctor_schedule_api.dart';
import 'doctor_schedule_model.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final int doctorId;
  final String doctorName;
  final int? clinicId;
  final DoctorScheduleApi? api;
  const DoctorScheduleScreen(
      {super.key,
      required this.doctorId,
      required this.doctorName,
      this.clinicId,
      this.api});
  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  late final DoctorScheduleApi _api = widget.api ?? DoctorScheduleApi();
  DoctorSchedule? _schedule;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _hasSaved = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schedule =
          await _api.load(widget.doctorId, clinicId: widget.clinicId);
      if (schedule.clinicId <= 0 ||
          schedule.days.length != 7 ||
          schedule.days.map((d) => d.day).toSet().length != 7 ||
          schedule.days.any((d) => !scheduleWeekdays.contains(d.day))) {
        throw locale.value.somethingWentWrong;
      }
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _hasSaved = schedule.hasSavedSchedule;
          _dirty = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(String value) {
    final minutes = scheduleMinutes(value) ?? 9 * 60;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  Future<String?> _pick(String value) async {
    final minutes = scheduleMinutes(value) ?? 9 * 60;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _editBreak(DoctorScheduleDay day,
      [ScheduleBreak? interval]) async {
    var start = interval?.start ?? day.start;
    var end = interval?.end ?? day.end;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  title: Text(interval == null
                      ? locale.value.addBreak
                      : locale.value.editBreak),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(locale.value.scheduleStart),
                        trailing: Text(_time(start)),
                        onTap: () async {
                          final picked = await _pick(start);
                          if (picked != null && dialogContext.mounted) {
                            update(() => start = picked);
                          }
                        }),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(locale.value.scheduleEnd),
                        trailing: Text(_time(end)),
                        onTap: () async {
                          final picked = await _pick(end);
                          if (picked != null && dialogContext.mounted) {
                            update(() => end = picked);
                          }
                        }),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(locale.value.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(locale.value.save)),
                  ],
                )));
    if (confirmed != true || !mounted) return;
    final candidate = ScheduleBreak(start: start, end: end);
    final previous = [...day.breaks];
    if (interval != null) day.breaks.remove(interval);
    day.breaks.add(candidate);
    if (day.validationError != null) {
      day.breaks
        ..clear()
        ..addAll(previous);
      _message(locale.value.scheduleInvalidBreaks);
      return;
    }
    day.breaks.sort((a, b) => a.start.compareTo(b.start));
    setState(() => _dirty = true);
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_saving || _schedule == null) return;
    for (final day in _schedule!.days) {
      final error = day.validationError;
      if (error != null) {
        _message(
            '${locale.value.scheduleDay(day.day)}: ${error == 'hours' ? locale.value.scheduleInvalidHours : locale.value.scheduleInvalidBreaks}');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await _api.save(widget.doctorId, _schedule!);
      if (mounted) {
        setState(() {
          _dirty = false;
          _hasSaved = true;
        });
        _message(locale.value.sessionSavedSuccessfully);
      }
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: Text(locale.value.scheduleUnsaved), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(locale.value.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(locale.value.scheduleDiscard)),
            ]));
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(locale.value.scheduleTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cloud_off_outlined, size: 40),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                                onPressed: _load,
                                child: Text(locale.value.reload)),
                          ])))
                  : AbsorbPointer(
                      absorbing: _saving,
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color:
                                        appColorPrimary.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.doctorName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(_schedule!.clinicName,
                                          style: const TextStyle(
                                              color: appColorPrimary)),
                                      const SizedBox(height: 12),
                                      Text(locale.value.scheduleHint),
                                    ])),
                            const SizedBox(height: 16),
                            for (final day in _schedule!.days) _dayCard(day),
                          ])),
          bottomNavigationBar: _schedule == null || _loading || _error != null
              ? null
              : SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton.icon(
                        onPressed:
                            _saving || (!_dirty && _hasSaved) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(locale.value.scheduleSave),
                        style: FilledButton.styleFrom(
                            backgroundColor: appColorPrimary,
                            padding: const EdgeInsets.all(16)),
                      ))),
        ),
      );

  Widget _dayCard(DoctorScheduleDay day) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: .12))),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey(day.day),
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: day.day == 'monday',
          title: Text(locale.value.scheduleDay(day.day),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(day.closed
              ? locale.value.closed
              : '${_time(day.start)} – ${_time(day.end)}'),
          leading: Switch.adaptive(
              value: !day.closed,
              onChanged: (open) => setState(() {
                    day.closed = !open;
                    _dirty = true;
                  })),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: day.closed
              ? [Text(locale.value.closed)]
              : [
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(
                            '${locale.value.scheduleStart}\n${_time(day.start)}'),
                        onPressed: () async {
                          final value = await _pick(day.start);
                          if (value != null && mounted) {
                            setState(() {
                              day.start = value;
                              _dirty = true;
                            });
                          }
                        }),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(
                            '${locale.value.scheduleEnd}\n${_time(day.end)}'),
                        onPressed: () async {
                          final value = await _pick(day.end);
                          if (value != null && mounted) {
                            setState(() {
                              day.end = value;
                              _dirty = true;
                            });
                          }
                        }),
                  ]),
                  if (day.validationError != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                            day.validationError == 'hours'
                                ? locale.value.scheduleInvalidHours
                                : locale.value.scheduleInvalidBreaks,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 8),
                  for (final interval in day.breaks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.free_breakfast_outlined, size: 20),
                      title: Text(
                          '${_time(interval.start)} – ${_time(interval.end)}'),
                      onTap: () => _editBreak(day, interval),
                      trailing: IconButton(
                          tooltip: locale.value.delete,
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() {
                                day.breaks.remove(interval);
                                _dirty = true;
                              })),
                    ),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                          onPressed: day.breaks.length >= 12
                              ? null
                              : () => _editBreak(day),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(locale.value.addBreak))),
                ],
        ),
      );
}
