const scheduleWeekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday'
];

int? scheduleMinutes(String time) {
  final match = RegExp(r'^(\d{2}):(\d{2})(?::00)?$').firstMatch(time);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  return hour < 24 && minute < 60 ? hour * 60 + minute : null;
}

class ScheduleBreak {
  String start;
  String end;
  ScheduleBreak({required this.start, required this.end});
  Map<String, dynamic> toJson() => {'start_break': start, 'end_break': end};
}

class DoctorScheduleDay {
  final String day;
  bool closed;
  String start;
  String end;
  final List<ScheduleBreak> breaks;

  DoctorScheduleDay.fromJson(Map<String, dynamic> json)
      : day = json['day']?.toString() ?? '',
        closed =
            json['is_holiday'] == true || json['is_holiday']?.toString() == '1',
        start = (json['start_time'] as String?)?.isNotEmpty == true
            ? json['start_time']
            : '09:00:00',
        end = (json['end_time'] as String?)?.isNotEmpty == true
            ? json['end_time']
            : '18:00:00',
        breaks = (json['breaks'] as List? ?? [])
            .map((b) => ScheduleBreak(
                start: b['start_break'] ?? '', end: b['end_break'] ?? ''))
            .toList();

  String? get validationError {
    if (closed) return null;
    final from = scheduleMinutes(start);
    final to = scheduleMinutes(end);
    if (from == null || to == null || from >= to) return 'hours';
    final ordered = [...breaks]..sort((a, b) => (scheduleMinutes(a.start) ?? -1)
        .compareTo(scheduleMinutes(b.start) ?? -1));
    var previousEnd = from;
    for (final interval in ordered) {
      final a = scheduleMinutes(interval.start);
      final b = scheduleMinutes(interval.end);
      if (a == null ||
          b == null ||
          a < from ||
          b > to ||
          a >= b ||
          a < previousEnd) {
        return 'breaks';
      }
      previousEnd = b;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'is_holiday': closed ? 1 : 0,
        'start_time': closed ? null : start,
        'end_time': closed ? null : end,
        'breaks': closed
            ? <Map<String, dynamic>>[]
            : breaks.map((b) => b.toJson()).toList(),
      };
}

class DoctorSchedule {
  final int clinicId;
  final String clinicName;
  final bool hasSavedSchedule;
  final List<DoctorScheduleDay> days;
  DoctorSchedule.fromJson(Map<String, dynamic> json)
      : clinicId = int.tryParse(json['clinic_id'].toString()) ?? 0,
        hasSavedSchedule = json['has_saved_schedule'] == true,
        clinicName = json['clinic_name']?.toString() ?? '',
        days = (json['data'] as List? ?? [])
            .map(
                (d) => DoctorScheduleDay.fromJson(Map<String, dynamic>.from(d)))
            .toList()
          ..sort((a, b) => scheduleWeekdays
              .indexOf(a.day)
              .compareTo(scheduleWeekdays.indexOf(b.day)));
}
