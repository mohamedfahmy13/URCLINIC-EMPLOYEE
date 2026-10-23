import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kivicare_clinic_admin/locale/language_ar.dart';
import 'package:kivicare_clinic_admin/locale/language_en.dart';
import 'package:kivicare_clinic_admin/main.dart';
import 'package:kivicare_clinic_admin/screens/auth/model/login_response.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_checkout_navigation.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_subscription_api.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_subscription_controller.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_subscription_models.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_subscription_screen.dart';
import 'package:kivicare_clinic_admin/screens/clinic_subscription/clinic_boost_card.dart';
import 'package:kivicare_clinic_admin/utils/app_common.dart';
import 'package:kivicare_clinic_admin/app_theme.dart';

class FakeSubscriptionApi extends ClinicSubscriptionApi {
  String status = 'pending';
  bool unavailable = false;
  List<ClinicPlan>? catalog;
  List<Map<String, dynamic>> benefits = [];
  List<Map<String, dynamic>> pastBenefits = [];
  Map<String, dynamic>? renewal;
  int currentLoads = 0;
  List<ClinicPayment> payments = [];

  @override
  Future<List<ClinicPlan>> plans() async =>
      catalog ??
      [
        ClinicPlan.fromJson({
          'id': 1,
          'name': 'Quarterly',
          'name_ar': 'ربع سنوية',
          'duration_months': 3,
          'price': '150.001',
          'currency_code': 'KWD',
          'perks': [],
        })
      ];

  @override
  Future<ClinicSubscriptionState> current() async {
    currentLoads++;
    return ClinicSubscriptionState.fromJson({
      'subscription': status == 'paid'
          ? {
              'id': 9,
              'plan_id': 1,
              'plan_name': 'Quarterly',
              'plan_name_ar': 'ربع سنوية',
              'start_date': '2026-10-01',
              'end_date': '2027-01-01',
              'days_remaining': 70
            }
          : null,
      'boosts': benefits,
      'past_boosts': pastBenefits,
      'upcoming_subscription': renewal,
    });
  }

  @override
  Future<List<ClinicPayment>> history() async => payments;

  @override
  Future<String> paymentStatus(String chargeId) async {
    if (unavailable) throw Exception('Gateway unavailable');
    return status;
  }
}

void main() {
  test('server publication state overrides stale live and upload flags', () {
    final expired = ClinicBoost.fromJson({
      'type': 'banner_ad',
      'status': 'active',
      'banner_status': 'approved',
      'publication_status': 'expired',
      'is_live': true,
      'can_upload': true,
    });
    expect(expired.displayStatus, 'expired');
    expect(expired.isLive, isFalse);
    expect(expired.canUpload, isFalse);
    final legacy = ClinicBoost.fromJson({
      'type': 'banner_ad',
      'status': 'pending',
      'banner_status': 'approved',
    });
    expect(legacy.displayStatus, 'awaiting_publication');
    expect(legacy.isLive, isFalse);
    final staleLegacy = ClinicBoost.fromJson({
      'type': 'banner_ad',
      'status': 'cancelled',
      'banner_status': 'approved',
      'is_live': true,
    });
    expect(staleLegacy.isLive, isFalse);
  });

  for (final state in [
    'scheduled',
    'live',
    'pending_review',
    'expired',
    'paused',
    'awaiting_publication'
  ]) {
    testWidgets('banner publication state $state has an accurate explanation',
        (tester) async {
      locale.value = LanguageEn();
      final boost = ClinicBoost.fromJson({
        'id': 1,
        'type': 'banner_ad',
        'banner_status': 'approved',
        'status': state == 'pending_review' ? 'pending' : 'active',
        'publication_status': state,
        'start_date': state == 'awaiting_publication' ? null : '2027-10-22',
        'end_date': state == 'awaiting_publication' ? null : '2027-10-25',
        'days_remaining': state == 'expired' ? 0 : 4,
        'can_upload': true,
        'subscription_id': 10,
        'subscription': {
          'id': 10,
          'phase': 'upcoming',
          'start_date': '2027-10-22',
          'end_date': '2028-10-22'
        },
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.create(Brightness.light, fontFamily: 'Test'),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ClinicBoostCard(
          boost: boost,
          busy: false,
          onUpload: () {},
        ))),
      ));
      final label = switch (state) {
        'scheduled' => locale.value.clinicBannerApprovedScheduled,
        'live' => locale.value.clinicBenefitLive,
        'pending_review' => locale.value.clinicBannerReview,
        'expired' => locale.value.clinicBenefitExpired,
        'paused' => locale.value.clinicBenefitPaused,
        _ => locale.value.clinicBannerAwaitingPublication,
      };
      expect(find.text(label), findsOneWidget);
      expect(find.text(locale.value.clinicBenefitFromRenewal), findsOneWidget);
      expect(find.textContaining('2028'), findsOneWidget,
          reason:
              'The subscription period must include its year to distinguish a future renewal.');
      if (state != 'live') {
        expect(find.text(locale.value.clinicBenefitLive), findsNothing);
      }
      if (state == 'expired') {
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.text(locale.value.clinicDaysRemaining(0)), findsNothing);
      }
      if (state == 'paused') {
        expect(find.text(locale.value.clinicBenefitPausedHint), findsOneWidget);
      }
      if (state == 'awaiting_publication') {
        expect(find.text(locale.value.clinicBannerScheduleMissingHint),
            findsOneWidget);
        expect(find.text(locale.value.clinicBannerApprovedScheduled),
            findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'current benefits, renewal and expired history are distinct in compact Arabic dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    locale.value = LanguageAr();
    selectedLanguageCode.value = 'ar';
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() {
      locale.value = LanguageEn();
      selectedLanguageCode.value = 'en';
      loginUserData.value = UserData();
    });
    final api = FakeSubscriptionApi()
      ..status = 'paid'
      ..renewal = {
        'id': 10,
        'plan_id': 1,
        'plan_name': 'Quarterly',
        'plan_name_ar': 'ربع سنوية',
        'start_date': '2027-01-01',
        'end_date': '2027-04-01',
        'phase': 'upcoming'
      }
      ..benefits = [
        {
          'id': 1,
          'type': 'banner_ad',
          'publication_status': 'live',
          'banner_status': 'approved',
          'subscription': {
            'id': 9,
            'phase': 'current',
            'start_date': '2026-10-01',
            'end_date': '2027-01-01'
          },
          'start_date': '2026-10-22',
          'end_date': '2026-10-25',
          'days_remaining': 4
        },
        {
          'id': 2,
          'type': 'banner_ad',
          'publication_status': 'scheduled',
          'banner_status': 'approved',
          'subscription': {
            'id': 10,
            'phase': 'upcoming',
            'start_date': '2027-01-01',
            'end_date': '2027-04-01'
          },
          'start_date': '2027-01-01',
          'end_date': '2027-01-04',
          'days_remaining': 4
        },
      ]
      ..pastBenefits = [
        {
          'id': 3,
          'type': 'banner_ad',
          'publication_status': 'expired',
          'banner_status': 'approved',
          'can_upload': true,
          'start_date': '2026-10-01',
          'end_date': '2026-10-04'
        },
      ];
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.create(Brightness.dark, fontFamily: 'Test'),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!),
      home: ClinicSubscriptionScreen(controller: controller),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text(locale.value.clinicBenefitFromCurrent), 200);
    expect(find.text(locale.value.clinicBenefitFromCurrent), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text(locale.value.clinicBenefitFromRenewal), 200);
    expect(
        find.text(locale.value.clinicBannerApprovedScheduled), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text(locale.value.clinicPastBenefits), 200);
    await tester.tap(find.text(locale.value.clinicPastBenefits));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text(locale.value.clinicBenefitExpired), 200);
    expect(find.text(locale.value.clinicBenefitExpired), findsOneWidget);
    final historyCard = find.byWidgetPredicate(
        (widget) => widget is ClinicBoostCard && widget.boost.id == 3);
    expect(
        find.descendant(of: historyCard, matching: find.byType(OutlinedButton)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'returning to the subscription screen refreshes publication state',
      (tester) async {
    locale.value = LanguageEn();
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() => loginUserData.value = UserData());
    final api = FakeSubscriptionApi()..status = 'paid';
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        MaterialApp(home: ClinicSubscriptionScreen(controller: controller)));
    await tester.pumpAndSettle();
    final before = api.currentLoads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.currentLoads, before + 1);
    expect(tester.takeException(), isNull);
  });

  test(
      'benefits preserve pending days, moderation feedback and scheduled dates',
      () {
    final state = ClinicSubscriptionState.fromJson({
      'boosts': [
        {
          'id': 7,
          'type': 'banner_ad',
          'status': 'pending',
          'start_date': null,
          'end_date': null,
          'duration_days': 14,
          'days_remaining': 11,
          'banner_status': 'rejected',
          'is_live': false,
          'can_upload': true,
          'meta': {
            'banner_media_url': null,
            'rejected_reason': 'Use a clearer image'
          }
        },
        {
          'id': 8,
          'type': 'top_search',
          'status': 'active',
          'is_live': true,
          'start_date': '2026-10-22',
          'end_date': '2026-10-24',
          'days_remaining': 3
        },
      ],
    });
    expect(state.boosts.first.isBanner, isTrue);
    expect(state.boosts.first.startDate, isEmpty);
    expect(state.boosts.first.daysRemaining, 11);
    expect(state.boosts.first.canUpload, isTrue);
    expect(state.boosts.first.rejectedReason, 'Use a clearer image');
    expect(state.boosts.last.isLive, isTrue);
    expect(state.boosts.last.canUpload, isFalse);
  });

  testWidgets('rejected banner shows Arabic feedback and allows resubmission',
      (tester) async {
    locale.value = LanguageAr();
    addTearDown(() => locale.value = LanguageEn());
    var uploads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: ClinicBoostCard(
        boost: ClinicBoost.fromJson({
          'id': 7,
          'type': 'banner_ad',
          'status': 'pending',
          'banner_status': 'rejected',
          'days_remaining': 14,
          'can_upload': true,
          'meta': {'rejected_reason': 'الصورة غير واضحة'}
        }),
        busy: false,
        onUpload: () => uploads++,
      ),
    ))));
    expect(find.text('مطلوب تعديل البانر'), findsOneWidget);
    expect(find.text('الصورة غير واضحة'), findsOneWidget);
    expect(find.text('متبقي 14 يوم'), findsOneWidget);
    await tester.tap(find.text('رفع صورة البانر'));
    expect(uploads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload button is disabled during another operation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ClinicBoostCard(
      boost: ClinicBoost.fromJson({
        'type': 'banner_ad',
        'status': 'pending',
        'banner_status': 'pending_review',
        'days_remaining': 7,
        'can_upload': true
      }),
      busy: true,
      onUpload: () => fail('Busy uploads must be disabled'),
    ))));
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
  });

  test('only the exact return origin, path and invoice trigger verification',
      () {
    const returnUrl = 'https://clinic.test/payment/return';
    expect(
        isClinicCheckoutReturn(
            '$returnUrl?charge_id=123&result=paid', returnUrl, '123'),
        isTrue);
    expect(
        isClinicCheckoutReturn(
            'https://evil.test/payment/return?charge_id=123&result=paid',
            returnUrl,
            '123'),
        isFalse);
    expect(
        isClinicCheckoutReturn(
            '$returnUrl?charge_id=999&result=paid', returnUrl, '123'),
        isFalse);
    expect(
        isClinicCheckoutReturn(
            'https://clinic.test/payment/myfatoorah/callback?paymentId=123',
            returnUrl,
            '123'),
        isFalse);
    expect(isClinicCheckoutReturn('$returnUrl?charge_id=123', returnUrl, '123'),
        isFalse);
    expect(
        isClinicCheckoutReturn(
            '$returnUrl/other?charge_id=123&result=paid', returnUrl, '123'),
        isFalse);
  });

  test('checkout accepts secure MyFatoorah URLs only', () {
    expect(isMyFatoorahCheckoutUrl('https://demo.MyFatoorah.com/KWT/ie/123'),
        isTrue);
    expect(
        isMyFatoorahCheckoutUrl('https://demo.myfatoorah.com/ie/123'), isTrue);
    expect(isMyFatoorahCheckoutUrl('https://portal.myfatoorah.com/ie/123'),
        isTrue);
    expect(
        isMyFatoorahCheckoutUrl('http://demo.myfatoorah.com/ie/123'), isFalse);
    expect(isMyFatoorahCheckoutUrl('https://myfatoorah.com.evil.test/pay'),
        isFalse);
    expect(isMyFatoorahCheckoutUrl('javascript:alert(1)'), isFalse);
    expect(isMyFatoorahCheckoutUrl('https://demo.myfatoorah.com@evil.test/pay'),
        isFalse);
  });

  test('catalog handles decimal API prices and nullable subscriptions',
      () async {
    final controller = ClinicSubscriptionController(api: FakeSubscriptionApi());
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.error, isNull);
    expect(controller.state.current, isNull);
    expect(controller.plans.single.price, 150.001);
    expect(controller.plans.single.localizedName(true), 'ربع سنوية');
    expect(clinicCurrencyDecimals('KWD'), 3);
    expect(clinicCurrencyDecimals('SAR'), 2);
  });

  test('checkout remains locked until verification finishes', () async {
    final controller = ClinicSubscriptionController(api: FakeSubscriptionApi());
    addTearDown(controller.dispose);
    final checkout = Completer<void>();
    var count = 0;
    final first = controller.withPayment(() async {
      count++;
      await checkout.future;
    });
    await controller.withPayment(() async {
      count++;
    });
    expect(controller.busy, isTrue);
    expect(count, 1);
    checkout.complete();
    await first;
    expect(controller.busy, isFalse);
  });

  test('subscription is refreshed from the API only after verified payment',
      () async {
    final api = FakeSubscriptionApi();
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    expect(await controller.verify('123'), 'pending');
    expect(controller.state.current, isNull);
    api.status = 'paid';
    expect(await controller.verify('123'), 'paid');
    expect(controller.state.current?.planId, 1);
  });

  testWidgets('Arabic packages work on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    locale.value = LanguageAr();
    selectedLanguageCode.value = 'ar';
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() {
      locale.value = LanguageEn();
      selectedLanguageCode.value = 'en';
      loginUserData.value = UserData();
    });
    final controller = ClinicSubscriptionController(api: FakeSubscriptionApi());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: ClinicSubscriptionScreen(controller: controller),
    ));
    await tester.pumpAndSettle();
    expect(find.text('باقات العيادة'), findsOneWidget);
    await tester.tap(find.text('الباقات'));
    await tester.pumpAndSettle();
    expect(find.text('اشترك الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('اشترك الآن'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('المتابعة للدفع'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(locale.value.cancel));
    await tester.pumpAndSettle();
    expect(controller.busy, isFalse);
  });

  test('verification failure is surfaced and checkout lock is released',
      () async {
    final controller = ClinicSubscriptionController(
        api: FakeSubscriptionApi()..unavailable = true);
    addTearDown(controller.dispose);
    await expectLater(controller.withPayment(() => controller.verify('123')),
        throwsException);
    expect(controller.state.current, isNull);
    expect(controller.busy, isFalse);
  });

  testWidgets(
      'overview and payment history stay separate and pending payments block a new purchase',
      (tester) async {
    final api = FakeSubscriptionApi()
      ..status = 'paid'
      ..payments = [
        ClinicPayment.fromJson({
          'id': 12,
          'title': 'Renewal payment',
          'amount': 150.001,
          'currency_code': 'KWD',
          'reference': '123',
          'payment_status': 'pending',
          'created_at': '2026-10-22T12:00:00Z'
        }),
      ];
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() => loginUserData.value = UserData());
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        MaterialApp(home: ClinicSubscriptionScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text(locale.value.currentClinicSubscription), findsOneWidget);
    expect(find.text('Renewal payment'), findsNothing);
    await tester.tap(find.text(locale.value.clinicPlansTab));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.text(locale.value.clinicViewPayment));
    await tester.pumpAndSettle();
    expect(find.text('Renewal payment'), findsOneWidget);
    expect(find.text(locale.value.checkClinicPayment), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'choosing a package updates the fixed checkout bar and payment confirmation',
      (tester) async {
    final api = FakeSubscriptionApi()
      ..catalog = [
        ClinicPlan.fromJson(
            {'id': 1, 'name': 'Quarterly', 'price': 150, 'duration_months': 3}),
        ClinicPlan.fromJson(
            {'id': 2, 'name': 'Annual', 'price': 550, 'duration_months': 12}),
      ];
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() => loginUserData.value = UserData());
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        MaterialApp(home: ClinicSubscriptionScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(locale.value.clinicPlansTab));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annual'));
    await tester.tap(find.text('Annual'));
    await tester.pumpAndSettle();
    expect(find.text('Annual'), findsNWidgets(2));
    await tester.tap(find.text(locale.value.subscribeClinicPackage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('550.000 KWD')),
        findsOneWidget);
    await tester.tap(find.text(locale.value.cancel));
    await tester.pumpAndSettle();
    expect(controller.busy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active Arabic benefits and the checkout footer fit large text in dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    locale.value = LanguageAr();
    selectedLanguageCode.value = 'ar';
    loginUserData.value = UserData(userRole: ['receptionist']);
    addTearDown(() {
      locale.value = LanguageEn();
      selectedLanguageCode.value = 'en';
      loginUserData.value = UserData();
    });
    final api = FakeSubscriptionApi()
      ..status = 'paid'
      ..benefits = [
        {
          'id': 7,
          'type': 'banner_ad',
          'status': 'pending',
          'banner_status': 'missing',
          'days_remaining': 14,
          'can_upload': true
        },
      ];
    final controller = ClinicSubscriptionController(api: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!),
      home: ClinicSubscriptionScreen(controller: controller),
    ));
    await tester.pumpAndSettle();
    expect(find.text(locale.value.clinicActive), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text(locale.value.clinicUploadBanner), 200);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(locale.value.clinicPlansTab));
    await tester.pumpAndSettle();
    expect(find.text(locale.value.renewClinicPackage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
