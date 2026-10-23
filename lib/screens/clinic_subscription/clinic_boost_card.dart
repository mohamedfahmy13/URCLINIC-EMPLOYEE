import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../main.dart';
import '../../utils/colors.dart';
import 'clinic_subscription_models.dart';

class ClinicBoostCard extends StatelessWidget {
  final ClinicBoost boost;
  final bool busy;
  final VoidCallback onUpload;
  const ClinicBoostCard({
    super.key,
    required this.boost,
    required this.busy,
    required this.onUpload,
  });

  String _date(BuildContext context, String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    try {
      return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
          .format(date);
    } catch (_) {
      return MaterialLocalizations.of(context).formatShortDate(date);
    }
  }

  String? _message(BuildContext context, String status) => switch (status) {
        'scheduled' => locale.value.clinicBenefitScheduledHint(
            _date(context, boost.startDate), _date(context, boost.endDate)),
        'live' => boost.isBanner ? locale.value.clinicBannerLiveHint : null,
        'expired' => locale.value.clinicBenefitExpiredHint,
        'cancelled' => locale.value.clinicBenefitCancelledHint,
        'paused' => locale.value.clinicBenefitPausedHint,
        'awaiting_publication' => locale.value.clinicBannerScheduleMissingHint,
        'missing' ||
        'pending_review' ||
        'rejected' =>
          locale.value.clinicBannerTimeHint,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final status = boost.displayStatus;
    final label = switch (status) {
      'live' => locale.value.clinicBenefitLive,
      'scheduled' => boost.isBanner
          ? locale.value.clinicBannerApprovedScheduled
          : locale.value.clinicBenefitScheduled,
      'pending_review' => locale.value.clinicBannerReview,
      'rejected' => locale.value.clinicBannerRejected,
      'missing' => locale.value.clinicBannerMissing,
      'expired' => locale.value.clinicBenefitExpired,
      'cancelled' => locale.value.clinicBenefitCancelled,
      'paused' => locale.value.clinicBenefitPaused,
      _ => locale.value.clinicBannerAwaitingPublication,
    };
    final color = switch (status) {
      'live' => context.themeSuccess,
      'rejected' || 'cancelled' => context.themeDanger,
      'pending_review' || 'paused' => context.themeWarning,
      'expired' => context.themeMuted,
      _ => context.themePrimary,
    };
    final contextLabel = switch (boost.subscriptionPhase) {
      'current' => locale.value.clinicBenefitFromCurrent,
      'upcoming' => locale.value.clinicBenefitFromRenewal,
      'expired' || 'cancelled' => locale.value.clinicBenefitFromPrevious,
      _ => boost.source == 'purchased'
          ? locale.value.clinicBenefitAdditional
          : null,
    };
    final message = _message(context, status);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: .18))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    boost.isBanner ? Icons.image_outlined : Icons.trending_up,
                    color: color,
                    size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      boost.isBanner
                          ? locale.value.clinicBannerPerk
                          : locale.value.clinicSearchPerk,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ])),
          ]),
          if (contextLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.themeSubtleSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contextLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.themeMuted,
                            fontWeight: FontWeight.w600)),
                    if (boost.subscriptionStartDate.isNotEmpty &&
                        boost.subscriptionEndDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${_date(context, boost.subscriptionStartDate)} — ${_date(context, boost.subscriptionEndDate)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ]),
            ),
          ],
          const SizedBox(height: 16),
          if (!boost.isEnded)
            Text(locale.value.clinicDaysRemaining(boost.daysRemaining),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          if (boost.isLive && boost.durationDays > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    minHeight: 4,
                    value: (boost.daysRemaining / boost.durationDays)
                        .clamp(0.0, 1.0),
                    color: color,
                    backgroundColor: color.withValues(alpha: .08))),
          ],
          if (status != 'scheduled' &&
              boost.startDate.isNotEmpty &&
              boost.endDate.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${_date(context, boost.startDate)} — ${_date(context, boost.endDate)}',
                    style: Theme.of(context).textTheme.bodySmall)),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.themeMuted)),
            ),
          if (boost.isBanner) ...[
            if (boost.imageUrl.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                          aspectRatio: 3,
                          child: Image.network(boost.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                      child: Icon(
                                          Icons.broken_image_outlined)))))),
            if (boost.rejectedReason.isNotEmpty)
              Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(boost.rejectedReason,
                      style: TextStyle(color: color))),
            if (boost.canUpload) ...[
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onUpload,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(boost.imageUrl.isEmpty
                        ? locale.value.clinicUploadBanner
                        : locale.value.clinicReplaceBanner),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
            ],
          ],
        ]),
      ),
    );
  }
}
