import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:nb_utils/nb_utils.dart';
import '../../network/network_utils.dart';
import '../../main.dart';
import 'clinic_subscription_models.dart';

class ClinicSubscriptionApi {
  Future<void> uploadBanner(
      int boostId, Uint8List bytes, String filename) async {
    Future<http.MultipartRequest> makeRequest() async {
      final request = await getMultiPartRequest('subscription/banner-creative');
      request.fields['boost_id'] = '$boostId';
      request.files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: filename));
      request.headers.addAll(buildHeaderTokens()..remove('content-type'));
      return request;
    }

    await sendMultiPartRequest(
      await makeRequest(),
      requestFactory: makeRequest,
      toastValidationError: false,
      onSuccess: (raw) {
        final body = jsonDecode(raw as String);
        if (body['status'] != true) {
          throw body['message'] ?? locale.value.somethingWentWrong;
        }
      },
      onError: (error) => throw error ?? locale.value.somethingWentWrong,
    ).timeout(const Duration(seconds: 60),
        onTimeout: () => throw locale.value.serviceUnavailable);
  }

  Future<dynamic> _request(String path, {Map<String, dynamic>? body}) async {
    final response = await handleResponse(await buildHttpResponse(
      'subscription/$path',
      method: body == null ? HttpMethodType.GET : HttpMethodType.POST,
      request: body,
    ).timeout(const Duration(seconds: 45),
        onTimeout: () => throw locale.value.serviceUnavailable));
    return response['data'];
  }

  Future<List<ClinicPlan>> plans() async => (await _request('plans') as List)
      .map((e) => ClinicPlan.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<ClinicSubscriptionState> current() async =>
      ClinicSubscriptionState.fromJson(
          Map<String, dynamic>.from(await _request('current')));

  Future<List<ClinicPayment>> history() async =>
      (await _request('history') as List)
          .map((e) => ClinicPayment.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  Future<ClinicPaymentIntent> subscribe(int planId, String language) async =>
      ClinicPaymentIntent.fromJson(Map<String, dynamic>.from(await _request(
        'subscribe',
        body: {'plan_id': planId, 'language': language},
      )));

  Future<String> paymentStatus(String chargeId) async =>
      (await _request('payment/${Uri.encodeComponent(chargeId)}'))['status']
          ?.toString() ??
      'pending';
}
