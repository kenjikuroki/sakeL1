import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../main.dart'; // import PrefsHelper

class PurchaseManager {
  static final PurchaseManager instance = PurchaseManager._internal();
  PurchaseManager._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Product ID for premium unlock
  static const String productIdPremium = 'sake_l1_premium_content'; 
  // TODO: Replace with actual product ID dynamically if needed or keep static

  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier(false);

  Future<void> initialize() async {
    // Check local pref first
    isPremiumNotifier.value = await PrefsHelper.isPremium();

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("IAP Error: $error");
    });
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<List<ProductDetails>> getProducts() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        return [];
      }
      const Set<String> _kIds = <String>{productIdPremium};
      final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("Products not found: ${response.notFoundIDs}");
      }
      return response.productDetails;
    } catch (e) {
      debugPrint("Error fetching products: $e");
      return [];
    }
  }

  Future<void> debugUnlock() async {
    await PrefsHelper.setPremium(true);
    isPremiumNotifier.value = true;
  }

  Future<void> buyPremium(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Pending
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          if (purchaseDetails.productID == productIdPremium) {
            await _deliverProduct(purchaseDetails);
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    await PrefsHelper.setPremium(true);
    isPremiumNotifier.value = true;
  }
}
