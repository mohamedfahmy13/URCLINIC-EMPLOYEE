int _integer(dynamic value) => int.tryParse('$value') ?? 0;
double? _amount(dynamic value) => double.tryParse('$value');

class ClinicPlan {
  final int id;
  final String name;
  final String nameAr;
  final int durationMonths;
  final double? price;
  final String currency;
  final List<ClinicPlanPerk> perks;

  ClinicPlan.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        name = json['name']?.toString() ?? '',
        nameAr = json['name_ar']?.toString() ?? '',
        durationMonths = _integer(json['duration_months']),
        price = _amount(json['price']),
        currency = json['currency_code']?.toString() ?? 'KWD',
        perks = (json['perks'] as List? ?? [])
            .map((e) => ClinicPlanPerk.fromJson(Map<String, dynamic>.from(e)))
            .toList();

  String localizedName(bool arabic) =>
      arabic && nameAr.isNotEmpty ? nameAr : name;
}

class ClinicPlanPerk {
  final String type;
  final int days;
  final int quantity;

  ClinicPlanPerk.fromJson(Map<String, dynamic> json)
      : type = json['addon_type']?.toString() ?? '',
        days = _integer(json['duration_days']),
        quantity = _integer(json['quantity']);
}

class ClinicSubscription {
  final int planId;
  final String name;
  final String nameAr;
  final String startDate;
  final String endDate;
  final int daysRemaining;

  ClinicSubscription.fromJson(Map<String, dynamic> json)
      : planId = _integer(json['plan_id']),
        name = json['plan_name']?.toString() ?? '',
        nameAr = json['plan_name_ar']?.toString() ?? '',
        startDate = json['start_date']?.toString() ?? '',
        endDate = json['end_date']?.toString() ?? '',
        daysRemaining = _integer(json['days_remaining']);

  String localizedName(bool arabic) =>
      arabic && nameAr.isNotEmpty ? nameAr : name;
}

class ClinicSubscriptionState {
  final ClinicSubscription? current;
  final ClinicSubscription? upcoming;
  final List<ClinicBoost> boosts;

  const ClinicSubscriptionState(
      {this.current, this.upcoming, this.boosts = const []});

  factory ClinicSubscriptionState.fromJson(Map<String, dynamic> json) {
    return ClinicSubscriptionState(
      boosts: (json['boosts'] as List? ?? [])
          .map((item) => ClinicBoost.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      current: json['subscription'] is Map
          ? ClinicSubscription.fromJson(
              Map<String, dynamic>.from(json['subscription']))
          : null,
      upcoming: json['upcoming_subscription'] is Map
          ? ClinicSubscription.fromJson(
              Map<String, dynamic>.from(json['upcoming_subscription']))
          : null,
    );
  }
}

class ClinicBoost {
  final int id;
  final String type;
  final String status;
  final String bannerStatus;
  final String startDate;
  final String endDate;
  final int daysRemaining;
  final int durationDays;
  final bool isLive;
  final bool canUpload;
  final String imageUrl;
  final String rejectedReason;

  ClinicBoost.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        type = json['type']?.toString() ?? '',
        status = json['status']?.toString() ?? '',
        bannerStatus = json['banner_status']?.toString() ?? '',
        startDate = json['start_date']?.toString() ?? '',
        endDate = json['end_date']?.toString() ?? '',
        daysRemaining = _integer(json['days_remaining']),
        durationDays = _integer(json['duration_days']),
        isLive = json['is_live'] == true,
        canUpload = json['can_upload'] == true,
        imageUrl = json['meta']?['banner_media_url']?.toString() ?? '',
        rejectedReason = json['meta']?['rejected_reason']?.toString() ?? '';

  bool get isBanner => type == 'banner_ad';
}

class ClinicPayment {
  final int id;
  final String kind;
  final String title;
  final String nameAr;
  final double? amount;
  final String currency;
  final String reference;
  final String status;
  final String createdAt;
  final String? paymentUrl;

  ClinicPayment.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        kind = json['kind']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        nameAr = json['plan_name_ar']?.toString() ?? '',
        amount = _amount(json['amount']),
        currency = json['currency_code']?.toString() ?? 'KWD',
        reference = json['reference']?.toString() ?? '',
        status = json['payment_status']?.toString() ?? 'pending',
        createdAt = json['created_at']?.toString() ?? '',
        paymentUrl = json['payment_url']?.toString();
}

class ClinicPaymentIntent {
  final String chargeId;
  final String paymentUrl;
  final String returnUrl;

  const ClinicPaymentIntent(
      {required this.chargeId,
      required this.paymentUrl,
      required this.returnUrl});

  factory ClinicPaymentIntent.fromJson(Map<String, dynamic> json) {
    return ClinicPaymentIntent(
      chargeId: json['charge_id']?.toString() ?? '',
      paymentUrl: json['payment_url']?.toString() ?? '',
      returnUrl: json['return_url']?.toString() ?? '',
    );
  }
}

int clinicCurrencyDecimals(String currency) =>
    const ['KWD', 'BHD', 'OMR', 'JOD'].contains(currency.toUpperCase()) ? 3 : 2;
