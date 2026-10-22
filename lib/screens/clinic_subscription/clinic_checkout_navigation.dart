/// A return URL is only a trigger for an authenticated API check.
/// Never treat query parameters as proof that a payment succeeded.
bool isClinicCheckoutReturn(String url, String returnUrl, String chargeId) {
  final uri = Uri.tryParse(url);
  final expected = Uri.tryParse(returnUrl);
  return uri != null &&
      expected != null &&
      expected.hasAuthority &&
      uri.scheme == expected.scheme &&
      uri.host == expected.host &&
      uri.port == expected.port &&
      uri.path == expected.path &&
      uri.queryParameters['charge_id'] == chargeId &&
      uri.queryParameters.containsKey('result');
}

bool isMyFatoorahCheckoutUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      (uri.host == 'myfatoorah.com' || uri.host.endsWith('.myfatoorah.com'));
}
