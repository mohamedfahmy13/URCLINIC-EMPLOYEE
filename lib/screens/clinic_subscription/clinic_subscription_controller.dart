import 'package:flutter/foundation.dart';
import 'clinic_subscription_api.dart';
import 'clinic_subscription_models.dart';

class ClinicSubscriptionController extends ChangeNotifier {
  final ClinicSubscriptionApi api;
  bool loading = true;
  bool busy = false;
  String? error;
  bool _disposed = false;
  List<ClinicPlan> plans = [];
  List<ClinicPayment> history = [];
  ClinicSubscriptionState state = const ClinicSubscriptionState();

  ClinicSubscriptionController({ClinicSubscriptionApi? api})
      : api = api ?? ClinicSubscriptionApi();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final result = await Future.wait<dynamic>(
          [api.plans(), api.current(), api.history()]);
      plans = result[0] as List<ClinicPlan>;
      state = result[1] as ClinicSubscriptionState;
      history = result[2] as List<ClinicPayment>;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      _notify();
    }
  }

  // The lock covers checkout and verification as well as invoice creation.
  Future<T?> withPayment<T>(Future<T> Function() action) async {
    if (busy) return null;
    busy = true;
    _notify();
    try {
      return await action();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<String> verify(String chargeId, {int attempts = 1}) async {
    var status = await api.paymentStatus(chargeId);
    for (var attempt = 1;
        attempt < attempts && status == 'pending';
        attempt++) {
      if (_disposed) return status;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_disposed) return status;
      status = await api.paymentStatus(chargeId);
    }
    await load();
    return status;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
