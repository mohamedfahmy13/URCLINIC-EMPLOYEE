import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kivicare_clinic_admin/locale/language_ar.dart';
import 'package:kivicare_clinic_admin/locale/language_en.dart';
import 'package:kivicare_clinic_admin/main.dart';
import 'package:kivicare_clinic_admin/screens/doctor/doctor_session/doctor_schedule_api.dart';
import 'package:kivicare_clinic_admin/screens/doctor/doctor_session/doctor_schedule_model.dart';
import 'package:kivicare_clinic_admin/screens/doctor/doctor_session/doctor_schedule_screen.dart';

class FakeScheduleApi extends DoctorScheduleApi {
  int? requestedDoctor;
  int? requestedClinic;
  int saves = 0;
  List<Map<String, dynamic>>? savedDays;
  Completer<void>? saving;
  @override
  Future<DoctorSchedule> load(int doctorId, {int? clinicId}) async {
    requestedDoctor = doctorId;
    requestedClinic = clinicId;
    return DoctorSchedule.fromJson({
      'clinic_id': 9,
      'clinic_name': 'عيادة النور',
      'has_saved_schedule': false,
      'data': [
        for (final day in scheduleWeekdays)
          {
            'day': day,
            'is_holiday': day == 'sunday' ? 1 : 0,
            'start_time': '09:00:00',
            'end_time': '18:00:00',
            'breaks': [],
          }
      ],
    });
  }

  @override
  Future<void> save(int doctorId, DoctorSchedule schedule) async {
    expect(doctorId, 10);
    expect(schedule.clinicId, 9);
    saves++;
    savedDays = schedule.days.map((d) => d.toJson()).toList();
    if (saving != null) await saving!.future;
  }
}

void main() {
  test(
      'closed days ignore old hours and breaks; live breaks must fit without overlap',
      () {
    final day = DoctorScheduleDay.fromJson({
      'day': 'monday',
      'is_holiday': '1',
      'start_time': null,
      'end_time': null,
      'breaks': [
        {'start_break': '08:00', 'end_break': '10:00'}
      ],
    });
    expect(day.validationError, isNull);
    expect(day.toJson()['breaks'], isEmpty);
    day.closed = false;
    expect(day.validationError, 'breaks');
    day.breaks
      ..clear()
      ..addAll([
        ScheduleBreak(start: '12:00', end: '13:00'),
        ScheduleBreak(start: '13:00:00', end: '14:00:00'),
      ]);
    expect(day.validationError, isNull);
    day.breaks.last.start = '12:30';
    expect(day.validationError, 'breaks');
    day.start = '25:00:00';
    expect(day.validationError, 'hours');
  });

  testWidgets(
      'receptionist opens the selected doctor without a global clinic and saves all seven days once',
      (tester) async {
    final api = FakeScheduleApi()..saving = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: DoctorScheduleScreen(
            doctorId: 10, doctorName: 'Test doctor', api: api)));
    await tester.pumpAndSettle();
    expect(api.requestedDoctor, 10);
    expect(api.requestedClinic, isNull);
    expect(find.text('عيادة النور'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(locale.value.scheduleSave));
    await tester.pump();
    expect(api.saves, 1);
    expect(api.savedDays, hasLength(7));
    expect(api.savedDays!.first['is_holiday'], 1);
    expect(api.savedDays!.first['start_time'], isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    api.saving!.complete();
    await tester.pumpAndSettle();
    expect(find.text(locale.value.sessionSavedSuccessfully), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Arabic schedule fits a narrow screen and warns before discarding edits',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    locale.value = LanguageAr();
    addTearDown(() => locale.value = LanguageEn());
    final api = FakeScheduleApi();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  child: const Text('Open'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => DoctorScheduleScreen(
                              doctorId: 10,
                              doctorName: 'دكتور عبدالرحمن محمد',
                              api: api)))))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('الاثنين'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(locale.value.scheduleUnsaved), findsOneWidget);
    await tester.tap(find.text(locale.value.cancel));
    await tester.pumpAndSettle();
    expect(find.text('الاثنين'), findsOneWidget);
    expect(api.saves, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(locale.value.scheduleDiscard));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
