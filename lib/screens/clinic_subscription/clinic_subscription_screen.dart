import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../configs.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import 'clinic_checkout_navigation.dart';
import 'clinic_checkout_screen.dart';
import 'clinic_subscription_controller.dart';
import 'clinic_subscription_models.dart';

class ClinicSubscriptionScreen extends StatefulWidget {
  final ClinicSubscriptionController? controller;
  const ClinicSubscriptionScreen({super.key, this.controller});

  @override
  State<ClinicSubscriptionScreen> createState() =>
      _ClinicSubscriptionScreenState();
}

class _ClinicSubscriptionScreenState extends State<ClinicSubscriptionScreen> {
  late final ClinicSubscriptionController _controller;
  bool get _arabic => selectedLanguageCode.value.startsWith('ar');
  bool get _allowed =>
      loginUserData.value.userRole.contains(EmployeeKeyConst.receptionist);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ClinicSubscriptionController();
    if (_allowed) _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _price(double? value, String currency) => value == null
      ? locale.value.clinicPriceUnavailable
      : '${NumberFormat.decimalPatternDigits(locale: _arabic ? 'ar' : 'en', decimalDigits: clinicCurrencyDecimals(currency)).format(value)} $currency';

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify(String reference) async {
    try {
      final status = await _controller.verify(reference, attempts: 3);
      _message(status == 'paid'
          ? locale.value.clinicPaymentSuccess
          : status == 'failed'
              ? locale.value.clinicPaymentFailed
              : locale.value.clinicPaymentPending);
    } catch (_) {
      _message(locale.value.clinicPaymentCheckFailed);
    }
  }

  Future<void> _checkout(ClinicPaymentIntent intent) async {
    if (!mounted) return;
    if (!isMyFatoorahCheckoutUrl(intent.paymentUrl) ||
        intent.chargeId.isEmpty) {
      _message(locale.value.clinicCheckoutError);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ClinicCheckoutScreen(intent: intent),
    ));
    if (mounted) await _verify(intent.chargeId);
  }

  Future<void> _subscribe(ClinicPlan plan) async {
    await _controller.withPayment(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(plan.localizedName(_arabic)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_price(plan.price, plan.currency),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(locale.value.clinicPackageMonths(plan.durationMonths)),
                const SizedBox(height: 16),
                Text(_controller.state.current != null
                    ? locale.value.clinicRenewalHint
                    : locale.value.clinicPackagesHint),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(locale.value.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(locale.value.clinicConfirmPayment)),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        final intent =
            await _controller.api.subscribe(plan.id, _arabic ? 'ar' : 'en');
        await _checkout(intent);
      } catch (e) {
        await _controller.load();
        _message(e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(locale.value.clinicPackages)),
        body: !_allowed
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(locale.value.clinicReceptionistOnly)))
            : _controller.loading && _controller.plans.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      if (!_controller.busy) await _controller.load();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        if (_controller.loading || _controller.busy)
                          const LinearProgressIndicator(),
                        if (_controller.error != null)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(children: [
                                    Text(_controller.error!),
                                    TextButton(
                                        onPressed: _controller.busy
                                            ? null
                                            : _controller.load,
                                        child: Text(locale.value.reload)),
                                  ]))),
                        _intro(),
                        const SizedBox(height: 20),
                        _subscription(_controller.state.current,
                            upcoming: false),
                        if (_controller.state.upcoming != null) ...[
                          const SizedBox(height: 12),
                          _subscription(_controller.state.upcoming,
                              upcoming: true),
                        ],
                        const SizedBox(height: 24),
                        _heading(locale.value.availableClinicPackages),
                        if (_controller.plans.isEmpty && !_controller.loading)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(locale.value.noClinicPackages)),
                        for (final plan in _controller.plans) _planCard(plan),
                        const SizedBox(height: 24),
                        _heading(locale.value.clinicPaymentHistory),
                        if (_controller.history.isEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(locale.value.noClinicPayments)),
                        for (final payment in _controller.history)
                          _paymentCard(payment),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _intro() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appColorPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.workspace_premium_outlined,
              color: Colors.white, size: 36),
          const SizedBox(height: 16),
          Text(locale.value.clinicPackagesIntro,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(locale.value.clinicPackagesHint,
              style: const TextStyle(color: Colors.white, height: 1.6)),
        ]),
      );

  Widget _subscription(ClinicSubscription? subscription,
          {required bool upcoming}) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    upcoming
                        ? Icons.event_available_outlined
                        : Icons.verified_outlined,
                    color: appColorPrimary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        upcoming
                            ? locale.value.upcomingClinicSubscription
                            : locale.value.currentClinicSubscription,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 12),
              Text(
                  subscription?.localizedName(_arabic) ??
                      locale.value.noClinicSubscription,
                  style: const TextStyle(fontSize: 17)),
              if (subscription != null) ...[
                const SizedBox(height: 8),
                Text('${subscription.startDate}  →  ${subscription.endDate}',
                    textDirection: TextDirection.ltr),
                if (!upcoming)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(locale.value
                          .clinicDaysRemaining(subscription.daysRemaining))),
              ],
            ])),
      );

  Widget _planCard(ClinicPlan plan) {
    final available =
        plan.price != null && plan.price! > 0 && plan.durationMonths > 0;
    final canBuy = available &&
        _controller.state.upcoming == null &&
        !_controller.busy &&
        !_controller.loading &&
        _controller.error == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan.localizedName(_arabic),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(locale.value.clinicPackageMonths(plan.durationMonths)),
            const SizedBox(height: 16),
            Text(_price(plan.price, plan.currency),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: appColorPrimary)),
            for (final perk in plan.perks
                .where((p) => p.type == 'banner_ad' || p.type == 'top_search'))
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 20, color: appColorPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                '${perk.type == 'banner_ad' ? locale.value.clinicBannerPerk : locale.value.clinicSearchPerk} · ${locale.value.clinicPackageDays(perk.days)}${perk.quantity > 1 ? ' × ${perk.quantity}' : ''}')),
                      ])),
            const SizedBox(height: 18),
            if (_controller.state.upcoming != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(locale.value.clinicRenewalScheduled)),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canBuy ? () => _subscribe(plan) : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: appColorPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(!available
                      ? locale.value.clinicPriceUnavailable
                      : _controller.state.current == null
                          ? locale.value.subscribeClinicPackage
                          : locale.value.renewClinicPackage),
                )),
          ])),
    );
  }

  Widget _paymentCard(ClinicPayment payment) {
    final paid = payment.status == 'paid';
    final failed = payment.status == 'failed';
    final color = paid
        ? Colors.green
        : failed
            ? Colors.red
            : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(
                      _arabic && payment.nameAr.isNotEmpty
                          ? payment.nameAr
                          : payment.title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Text(
                  paid
                      ? locale.value.paid
                      : failed
                          ? locale.value.failed
                          : locale.value.pending,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            Text(_price(payment.amount, payment.currency)),
            const SizedBox(height: 6),
            Text(payment.createdAt.split('T').first,
                style: Theme.of(context).textTheme.bodySmall),
            if (payment.reference.isNotEmpty)
              Text('#${payment.reference}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall),
            if (!paid && payment.reference.isNotEmpty)
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _controller.busy
                      ? null
                      : () => _controller
                          .withPayment(() => _verify(payment.reference)),
                  label: Text(locale.value.checkClinicPayment),
                ),
                if (payment.paymentUrl?.isNotEmpty == true)
                  TextButton(
                    onPressed: _controller.busy
                        ? null
                        : () => _controller.withPayment(() async {
                              // Recheck before reopening a previous invoice: it may already be paid.
                              try {
                                final status = await _controller.api
                                    .paymentStatus(payment.reference);
                                if (status == 'paid') {
                                  await _verify(payment.reference);
                                } else {
                                  await _checkout(ClinicPaymentIntent(
                                      chargeId: payment.reference,
                                      paymentUrl: payment.paymentUrl!,
                                      returnUrl: '$DOMAIN_URL/payment/return'));
                                }
                              } catch (_) {
                                _message(locale.value.clinicPaymentCheckFailed);
                              }
                            }),
                    child: Text(locale.value.resumeClinicPayment),
                  ),
              ]),
          ])),
    );
  }
}
