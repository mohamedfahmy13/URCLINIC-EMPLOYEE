import 'package:flutter/material.dart';
import '../../main.dart';
import '../../utils/colors.dart';
import 'clinic_subscription_models.dart';

class ClinicBoostCard extends StatelessWidget {
  final ClinicBoost boost;
  final bool busy;
  final VoidCallback onUpload;
  const ClinicBoostCard(
      {super.key,
      required this.boost,
      required this.busy,
      required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final awaiting = boost.isBanner && boost.bannerStatus != 'approved';
    final label = !boost.isBanner || !awaiting
        ? (boost.isLive
            ? locale.value.clinicBenefitLive
            : locale.value.clinicBenefitScheduled)
        : switch (boost.bannerStatus) {
            'pending_review' => locale.value.clinicBannerReview,
            'rejected' => locale.value.clinicBannerRejected,
            _ => locale.value.clinicBannerMissing,
          };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(boost.isBanner ? Icons.image_outlined : Icons.trending_up,
                color: appColorPrimary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    boost.isBanner
                        ? locale.value.clinicBannerPerk
                        : locale.value.clinicSearchPerk,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: boost.isLive
                      ? Colors.green
                      : boost.bannerStatus == 'rejected'
                          ? Colors.red
                          : appColorPrimary)),
          const SizedBox(height: 8),
          Text(locale.value.clinicDaysRemaining(boost.daysRemaining)),
          if (boost.startDate.isNotEmpty && boost.endDate.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${boost.startDate} → ${boost.endDate}')),
          if (boost.isBanner) ...[
            if (boost.imageUrl.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                        aspectRatio: 3,
                        child: Image.network(boost.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                    child: Icon(Icons.broken_image_outlined)))),
                  )),
            if (boost.rejectedReason.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(boost.rejectedReason,
                      style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 10),
            Text(locale.value.clinicBannerTimeHint,
                style: Theme.of(context).textTheme.bodySmall),
            if (boost.canUpload) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : onUpload,
                icon: const Icon(Icons.upload_outlined),
                label: Text(boost.imageUrl.isEmpty
                    ? locale.value.clinicUploadBanner
                    : locale.value.clinicReplaceBanner),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}
