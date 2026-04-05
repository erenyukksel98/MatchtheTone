import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/constants.dart';

/// ---------------------------------------------------------------------------
/// RevenueCatService — wraps all subscription / paywall logic.
/// ---------------------------------------------------------------------------
class RevenueCatService {
  RevenueCatService();

  /// Check if the current user has an active premium entitlement.
  Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
    } catch (_) {
      return false;
    }
  }

  /// Get available packages (monthly + annual).
  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return [];
      return current.availablePackages;
    } catch (_) {
      return [];
    }
  }

  /// Purchase a package. Returns true on success.
  Future<bool> purchasePackage(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      return info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — not an error
        return false;
      }
      rethrow;
    }
  }

  /// Restore purchases after reinstall.
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
    } catch (_) {
      return false;
    }
  }

  /// Log in to RevenueCat with a user ID (after Supabase sign-in).
  Future<void> loginUser(String userId) async {
    await Purchases.logIn(userId);
  }

  /// Log out from RevenueCat (on sign-out).
  Future<void> logoutUser() async {
    await Purchases.logOut();
  }

  /// Get CustomerInfo — used to verify entitlements.
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }
}
