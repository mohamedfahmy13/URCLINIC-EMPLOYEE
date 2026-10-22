import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../main.dart';
import 'clinic_checkout_navigation.dart';
import 'clinic_subscription_models.dart';

class ClinicCheckoutScreen extends StatefulWidget {
  final ClinicPaymentIntent intent;
  const ClinicCheckoutScreen({super.key, required this.intent});

  @override
  State<ClinicCheckoutScreen> createState() => _ClinicCheckoutScreenState();
}

class _ClinicCheckoutScreenState extends State<ClinicCheckoutScreen> {
  late final WebViewController _webView;
  int _progress = 0;
  bool _failed = false;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _failed = true);
          }
        },
        onNavigationRequest: (request) {
          // Let the server callback finish before closing the hosted checkout.
          if (request.isMainFrame &&
              isClinicCheckoutReturn(
                request.url,
                widget.intent.returnUrl,
                widget.intent.chargeId,
              )) {
            if (!_returned && mounted) {
              _returned = true;
              Navigator.of(context).pop();
            }
            return NavigationDecision.prevent;
          }
          final uri = Uri.tryParse(request.url);
          return uri?.scheme == 'https' || request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      // No API token or payment credentials are sent to the WebView.
      ..loadRequest(Uri.parse(widget.intent.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(locale.value.clinicSecureCheckout),
        leading: IconButton(
          tooltip: locale.value.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          if (_progress < 100 && !_failed)
            LinearProgressIndicator(value: _progress / 100),
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(locale.value.clinicCheckoutError),
            ),
          Expanded(child: WebViewWidget(controller: _webView)),
        ]),
      ),
    );
  }
}
