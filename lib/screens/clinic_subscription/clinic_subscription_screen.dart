import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import '../../configs.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import 'clinic_checkout_navigation.dart';
import 'clinic_checkout_screen.dart';
import 'clinic_subscription_controller.dart';
import 'clinic_subscription_models.dart';
import 'clinic_boost_card.dart';

class ClinicSubscriptionScreen extends StatefulWidget {
  final ClinicSubscriptionController? controller;
  const ClinicSubscriptionScreen({super.key, this.controller});

  @override
  State<ClinicSubscriptionScreen> createState() =>
      _ClinicSubscriptionScreenState();
}

class _ClinicSubscriptionScreenState extends State<ClinicSubscriptionScreen>
    with WidgetsBindingObserver {
  late final ClinicSubscriptionController _controller;
  int _section = 0;
  int? _selectedPlanId;
  bool get _arabic => selectedLanguageCode.value.startsWith('ar');
  bool get _allowed =>
      loginUserData.value.userRole.contains(EmployeeKeyConst.receptionist);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? ClinicSubscriptionController();
    if (_allowed) _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _allowed &&
        !_controller.loading &&
        !_controller.busy) {
      _controller.load();
    }
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

  Future<void> _uploadBanner(ClinicBoost boost) async {
    await _controller.withPayment(() async {
      try {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (file == null || !mounted) return;
        final bytes = await file.readAsBytes();
        if (!RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false)
                .hasMatch(file.name) ||
            bytes.length > 4 * 1024 * 1024) {
          _message(locale.value.clinicBannerInvalidImage);
          return;
        }
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final valid = frame.image.width >= 600 && frame.image.height >= 200;
        frame.image.dispose();
        codec.dispose();
        if (!valid) {
          _message(locale.value.clinicBannerInvalidImage);
          return;
        }
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(locale.value.clinicUploadBanner),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AspectRatio(
                        aspectRatio: 3,
                        child: Image.memory(bytes, fit: BoxFit.cover)),
                    const SizedBox(height: 16),
                    Text(boost.bannerStatus == 'approved'
                        ? locale.value.clinicBannerReplaceHint
                        : locale.value.clinicBannerTimeHint),
                    const SizedBox(height: 8),
                    Text(locale.value.clinicBannerUploadHint),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(locale.value.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(locale.value.clinicSubmitBanner)),
                  ],
                ));
        if (confirmed != true || !mounted) return;
        await _controller.api.uploadBanner(boost.id, bytes, file.name);
        await _controller.load();
        _message(locale.value.clinicBannerUploaded);
      } catch (error) {
        _message(
            error is String ? error : locale.value.clinicBannerUploadFailed);
      }
    });
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
                    ? locale.value.clinicRenewalStartsOn(
                        _date(_controller.state.current!.endDate))
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

  ClinicPlan? get _selectedPlan {
    final available = _controller.plans
        .where((p) => p.price != null && p.price! > 0 && p.durationMonths > 0)
        .toList();
    if (available.isEmpty) return null;
    return available.firstWhere((p) => p.id == _selectedPlanId,
        orElse: () => available.first);
  }

  bool get _hasPending => _controller.history.any((p) => p.status == 'pending');
  bool get _canBuy =>
      _selectedPlan != null &&
      !_hasPending &&
      _controller.state.upcoming == null &&
      !_controller.busy &&
      !_controller.loading &&
      _controller.error == null;

  String _date(String value) {
    try {
      return DateFormat.yMMMd(_arabic ? 'ar' : 'en')
          .format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  void _selectSection(int value) => setState(() => _section = value);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(locale.value.clinicPackages,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                  tooltip: locale.value.reload,
                  onPressed: _controller.busy || _controller.loading
                      ? null
                      : _controller.load,
                  icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: !_allowed
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(locale.value.clinicReceptionistOnly)))
              : Column(children: [
                  if (_controller.busy ||
                      (_controller.loading && _controller.plans.isNotEmpty))
                    const LinearProgressIndicator(minHeight: 2),
                  _navigation(),
                  Expanded(
                      child: _controller.loading && _controller.plans.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                              onRefresh: () async {
                                if (!_controller.busy) await _controller.load();
                              },
                              child: ListView(
                                key: ValueKey('package-section-$_section'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 20, 16, 24),
                                children: [
                                  if (_controller.error != null) _errorCard(),
                                  if (_section == 0) ..._overview(),
                                  if (_section == 1) ...[
                                    _heading(
                                        locale.value.availableClinicPackages,
                                        locale.value.clinicChoosePlan),
                                    if (_hasPending) _pendingPayment(),
                                    if (_controller.state.upcoming != null)
                                      _notice(
                                          locale.value.clinicRenewalScheduled,
                                          Icons.event_available_outlined),
                                    if (_controller.state.current != null &&
                                        _controller.state.upcoming == null)
                                      _notice(locale.value.clinicRenewalHint,
                                          Icons.update),
                                    if (_controller.plans.isEmpty)
                                      _empty(Icons.inventory_2_outlined,
                                          locale.value.noClinicPackages),
                                    for (final plan in _controller.plans)
                                      _planCard(plan),
                                  ],
                                  if (_section == 2) ...[
                                    _heading(locale.value.clinicPaymentHistory),
                                    if (_controller.history.isEmpty)
                                      _empty(Icons.receipt_long_outlined,
                                          locale.value.noClinicPayments),
                                    for (final payment in _controller.history)
                                      _paymentCard(payment),
                                  ],
                                ],
                              ),
                            )),
                ]),
          bottomNavigationBar: !_allowed ||
                  _section != 1 ||
                  _selectedPlan == null ||
                  _controller.loading ||
                  _controller.error != null
              ? null
              : _checkoutBar(),
        ),
      );

  Widget _navigation() {
    final labels = [
      locale.value.clinicOverview,
      locale.value.clinicPlansTab,
      locale.value.clinicPaymentsTab
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              selected: _section == i,
              button: true,
              child: Material(
                color: _section == i
                    ? appColorPrimary
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectSection(i),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Text(labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _section == i ? Colors.white : null)),
                  ),
                ),
              ),
            ),
          )),
      ]),
    );
  }

  Widget _heading(String text, [String? subtitle]) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      );

  List<Widget> _overview() => [
        _subscriptionSummary(),
        const SizedBox(height: 16),
        if (_controller.state.upcoming != null) ...[
          _upcoming(_controller.state.upcoming!),
          const SizedBox(height: 16),
        ],
        if (_hasPending) _pendingPayment(),
        const SizedBox(height: 8),
        _heading(locale.value.clinicBenefits, locale.value.clinicBenefitsHint),
        if (_controller.state.boosts.isEmpty)
          _empty(Icons.auto_awesome_outlined, locale.value.clinicNoBenefits),
        ..._benefits(),
      ];

  List<Widget> _benefits() {
    final current = _controller.state.boosts
        .where((boost) => boost.subscriptionPhase != 'upcoming')
        .toList();
    final upcoming = _controller.state.boosts
        .where((boost) => boost.subscriptionPhase == 'upcoming')
        .toList();
    Widget card(ClinicBoost boost) => ClinicBoostCard(
        boost: boost,
        busy: _controller.busy || _controller.loading,
        onUpload: () => _uploadBanner(boost));
    return [
      if (current.isNotEmpty) ...[
        _heading(locale.value.clinicCurrentBenefits),
        ...current.map(card),
      ],
      if (upcoming.isNotEmpty) ...[
        const SizedBox(height: 8),
        _heading(locale.value.clinicUpcomingBenefits,
            locale.value.clinicRenewalNotStarted),
        ...upcoming.map(card),
      ],
      if (_controller.state.pastBoosts.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          title: Text(locale.value.clinicPastBenefits),
          trailing: const Icon(Icons.expand_more),
          children: _controller.state.pastBoosts.map(card).toList(),
        ),
    ];
  }

  Widget _subscriptionSummary() {
    final sub = _controller.state.current;
    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.workspace_premium_outlined,
              color: context.themePrimary, size: 36),
          const SizedBox(height: 18),
          Text(locale.value.noClinicSubscription,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(locale.value.clinicPackagesHint),
          const SizedBox(height: 20),
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: appColorPrimary),
              onPressed: () => _selectSection(1),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(locale.value.clinicBrowsePlans)),
        ]),
      );
    }
    final start = DateTime.tryParse(sub.startDate);
    final end = DateTime.tryParse(sub.endDate);
    final total =
        start != null && end != null ? end.difference(start).inDays : 0;
    final remaining = total > 0
        ? (sub.daysRemaining / total).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appColorSecondary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.verified_outlined,
                  color: Colors.white, size: 20),
              Text(locale.value.currentClinicSubscription,
                  style: const TextStyle(color: Colors.white70)),
              _badge(locale.value.clinicActive, const Color(0xFFACF1CE),
                  dark: true),
            ]),
        const SizedBox(height: 20),
        Text(sub.localizedName(_arabic),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(locale.value.clinicDaysRemaining(sub.daysRemaining),
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 16),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: remaining,
                minHeight: 6,
                backgroundColor: Colors.white24,
                color: const Color(0xFF7AD8CB))),
        const SizedBox(height: 16),
        Text('${locale.value.clinicStarts}  ${_date(sub.startDate)}',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text('${locale.value.clinicExpires}  ${_date(sub.endDate)}',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Colors.white, padding: EdgeInsets.zero),
            onPressed: () => _selectSection(1),
            child: Text(locale.value.renewClinicPackage)),
      ]),
    );
  }

  Widget _upcoming(ClinicSubscription sub) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.event_available_outlined, color: context.themePrimary),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(locale.value.upcomingClinicSubscription,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(sub.localizedName(_arabic)),
                    const SizedBox(height: 6),
                    Text(
                        '${locale.value.clinicStarts}  ${_date(sub.startDate)}'),
                    const SizedBox(height: 4),
                    Text(
                        '${locale.value.clinicExpires}  ${_date(sub.endDate)}'),
                    const SizedBox(height: 10),
                    Text(locale.value.clinicRenewalNotStarted,
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
            ])),
      );

  Widget _badge(String label, Color color, {bool dark = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? .16 : .10),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );

  Widget _notice(String text, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: appColorPrimary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: context.themePrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );

  Widget _pendingPayment() => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(locale.value.clinicPendingPaymentHint),
              TextButton(
                  onPressed: () => _selectSection(2),
                  child: Text(locale.value.clinicViewPayment)),
            ])),
      );

  Widget _empty(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(children: [
          Icon(icon,
              size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ]),
      );

  Widget _errorCard() => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.errorContainer,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_controller.error!),
              TextButton(
                  onPressed: _controller.busy ? null : _controller.load,
                  child: Text(locale.value.reload)),
            ])),
      );

  Widget _planCard(ClinicPlan plan) {
    final available =
        plan.price != null && plan.price! > 0 && plan.durationMonths > 0;
    final selected = available && _selectedPlan?.id == plan.id;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected
                  ? appColorPrimary
                  : Theme.of(context).dividerColor.withValues(alpha: .25),
              width: selected ? 2 : 1)),
      child: InkWell(
        onTap: !available || _controller.busy
            ? null
            : () => setState(() => _selectedPlanId = plan.id),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(plan.localizedName(_arabic),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? context.themePrimary
                        : Theme.of(context).disabledColor),
              ]),
              const SizedBox(height: 6),
              Text(locale.value.clinicPackageMonths(plan.durationMonths),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(_price(plan.price, plan.currency),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: context.themePrimary)),
              if (_controller.state.current?.planId == plan.id) ...[
                const SizedBox(height: 8),
                _badge(locale.value.currentClinicSubscription, appColorPrimary),
              ],
              for (final perk in plan.perks.where(
                  (p) => p.type == 'banner_ad' || p.type == 'top_search'))
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                              perk.type == 'banner_ad'
                                  ? Icons.image_outlined
                                  : Icons.trending_up,
                              size: 20,
                              color: context.themePrimary),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  '${perk.type == 'banner_ad' ? locale.value.clinicBannerPerk : locale.value.clinicSearchPerk} · ${locale.value.clinicPackageDays(perk.days * (perk.quantity > 0 ? perk.quantity : 1))}')),
                        ])),
            ])),
      ),
    );
  }

  Widget _checkoutBar() {
    final plan = _selectedPlan!;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
              top: BorderSide(
                  color:
                      Theme.of(context).dividerColor.withValues(alpha: .15)))),
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(plan.localizedName(_arabic),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(_price(plan.price, plan.currency),
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: context.themePrimary,
                                fontWeight: FontWeight.bold)),
                      ]),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _canBuy ? () => _subscribe(plan) : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: appColorPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: _controller.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_outline, size: 18),
                    label: Text(_controller.state.current == null
                        ? locale.value.subscribeClinicPackage
                        : locale.value.renewClinicPackage),
                  ),
                  const SizedBox(height: 6),
                  Text(locale.value.clinicPackagesHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
          )),
    );
  }

  Widget _paymentCard(ClinicPayment payment) {
    final paid = payment.status == 'paid';
    final failed = payment.status == 'failed';
    final color = paid
        ? context.themeSuccess
        : failed
            ? context.themeDanger
            : context.themeWarning;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: !paid,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _arabic && payment.nameAr.isNotEmpty
                  ? payment.nameAr
                  : payment.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_price(payment.amount, payment.currency),
                    textDirection: TextDirection.ltr),
                _badge(
                    paid
                        ? locale.value.paid
                        : failed
                            ? locale.value.failed
                            : locale.value.pending,
                    color),
              ]),
        ]),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_date(payment.createdAt.split('T').first))),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (payment.reference.isNotEmpty)
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('#${payment.reference}',
                    textDirection: TextDirection.ltr)),
          if (!paid && payment.reference.isNotEmpty)
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _controller.busy
                      ? null
                      : () => _controller
                          .withPayment(() => _verify(payment.reference)),
                  label: Text(locale.value.checkClinicPayment)),
              if (payment.paymentUrl?.isNotEmpty == true)
                TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: _controller.busy
                        ? null
                        : () => _controller.withPayment(() async {
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
                    label: Text(locale.value.resumeClinicPayment)),
            ]),
        ],
      ),
    );
  }
}
