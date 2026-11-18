import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_state.dart';
import 'models.dart';
import 'pricing.dart';

/// Google Play Billing. Products (created in Play Console):
///  - nestkeep_pro_monthly  $4.99/mo
///  - nestkeep_pro_yearly   $29.99/yr with 14-day free trial (hero plan)
///  - nestkeep_lifetime     $79.99 one-time
/// There is no server of ours, so entitlement is read from the Play purchase
/// stream on this device and re-checked on every app start via restore.
class Billing {
  static const monthlyId = 'nestkeep_pro_monthly';
  static const yearlyId = 'nestkeep_pro_yearly';
  static const lifetimeId = 'nestkeep_lifetime';
  static const productIds = {monthlyId, yearlyId, lifetimeId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = [];
  bool available = false;

  Future<void> init(AppState state) async {
    available = await _iap.isAvailable();
    if (!available) return;
    _sub = _iap.purchaseStream.listen(
      (purchases) => _onPurchases(state, purchases),
      onError: (_) {},
    );
    final response = await _iap.queryProductDetails(productIds);
    products = response.productDetails;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(
      AppState state, List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _applyEntitlement(state, purchase);
      } else if (purchase.status == PurchaseStatus.canceled ||
          purchase.status == PurchaseStatus.error) {
        // If nothing valid remains, the stream sends nothing else; the
        // paywall stays honest and free features keep working.
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _applyEntitlement(AppState state, PurchaseDetails p) async {
    final when = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(p.transactionDate ?? '') ??
            DateTime.now().millisecondsSinceEpoch);
    switch (p.productID) {
      case monthlyId:
        await state.setEntitlement(Entitlement(
          isPro: true,
          source: EntitlementSource.monthly,
          expiry: when.add(const Duration(days: 31)),
        ));
        break;
      case yearlyId:
        await state.setEntitlement(Entitlement(
          isPro: true,
          source: EntitlementSource.yearly,
          expiry: when.add(const Duration(days: 366)),
        ));
        break;
      case lifetimeId:
        await state.setEntitlement(const Entitlement(
          isPro: true,
          source: EntitlementSource.lifetime,
        ));
        break;
    }
  }

  ProductDetails? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The price the paywall should print for a product: the base
  /// recurring price for a subscription (never a free-trial or intro
  /// phase's price), the plain price for the one-time product. Null
  /// until Play has answered, so callers can fall back to list prices.
  DisplayPrice? displayPrice(String id) {
    final details = product(id);
    if (details == null) return null;
    return displayPriceOf(details);
  }

  Future<void> buy(String id) async {
    final details = product(id);
    if (details == null) return;
    final param = PurchaseParam(productDetails: details);
    if (id == lifetimeId) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  void dispose() {
    _sub?.cancel();
  }
}
