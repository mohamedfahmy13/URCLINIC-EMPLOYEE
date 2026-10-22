import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final awaiting = boost.isBanner && boost.bannerStatus != 'approved';
    final rejected = boost.bannerStatus == 'rejected';
    final label = !awaiting
        ? (boost.isLive
            ? locale.value.clinicBenefitLive
            : locale.value.clinicBenefitScheduled)
        : switch (boost.bannerStatus) {
            'pending_review' => locale.value.clinicBannerReview,
            'rejected' => locale.value.clinicBannerRejected,
            _ => locale.value.clinicBannerMissing,
          };
    final color = rejected
        ? Theme.of(context).colorScheme.error
        : boost.isLive
            ? context.themeSuccess
            : boost.bannerStatus == 'pending_review'
                ? context.themeWarning
                : appColorPrimary;
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
          const SizedBox(height: 16),
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
          if (boost.startDate.isNotEmpty && boost.endDate.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${boost.startDate} → ${boost.endDate}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall)),
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
            if (awaiting)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(locale.value.clinicBannerTimeHint,
                      style: Theme.of(context).textTheme.bodySmall)),
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
