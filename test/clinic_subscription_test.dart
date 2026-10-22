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
import 'package:kivicare_clinic_admin/utils/app_common.dart';

class FakeSubscriptionApi extends ClinicSubscriptionApi {
  String status = 'pending';
  bool unavailable = false;

  @override
  Future<List<ClinicPlan>> plans() async => [
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
  Future<ClinicSubscriptionState> current() async =>
      ClinicSubscriptionState.fromJson({
        'subscription':
            status == 'paid' ? {'plan_id': 1, 'plan_name': 'Quarterly'} : null,
      });

  @override
  Future<List<ClinicPayment>> history() async => [];

  @override
  Future<String> paymentStatus(String chargeId) async {
    if (unavailable) throw Exception('Gateway unavailable');
    return status;
  }
}

void main() {
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
    await tester.scrollUntilVisible(find.text('اشترك الآن'), 250);
    await tester.ensureVisible(find.text('اشترك الآن'));
    await tester.pumpAndSettle();
    expect(find.text('اشترك الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('اشترك الآن'));
    await tester.pumpAndSettle();
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
}
