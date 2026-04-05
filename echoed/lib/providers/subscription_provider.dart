import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

// ── Offerings ─────────────────────────────────────────────────────────────────

/// Fetches RevenueCat offerings (monthly + annual packages).
final offeringsProvider = FutureProvider<List<Package>>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  return service.getOfferings();
});

// ── Purchase Notifier ─────────────────────────────────────────────────────────

class PurchaseNotifier extends StateNotifier<AsyncValue<bool?>> {
  PurchaseNotifier(this._service) : super(const AsyncValue.data(null));

  final RevenueCatService _service;

  Future<void> purchase(Package package) async {
    state = const AsyncValue.loading();
    try {
      final success = await _service.purchasePackage(package);
      state = AsyncValue.data(success);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restore() async {
    state = const AsyncValue.loading();
    try {
      final success = await _service.restorePurchases();
      state = AsyncValue.data(success);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final purchaseNotifierProvider =
    StateNotifierProvider<PurchaseNotifier, AsyncValue<bool?>>((ref) {
  return PurchaseNotifier(ref.watch(revenueCatServiceProvider));
});
