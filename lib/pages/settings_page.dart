import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // import foundation for kDebugMode
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../l10n/app_localizations.dart';
import '../utils/purchase_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  List<ProductDetails> _products = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadProducts();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await PurchaseManager.instance.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading products: $e");
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://note.com/dapper_flax6182/n/nf18b0b71bba4');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _buyPremium() async {
    if (_products.isEmpty) return;
    // Assuming only 1 product for now
    await PurchaseManager.instance.buyPremium(_products.first);
  }

  Future<void> _debugUnlock() async {
    await PurchaseManager.instance.debugUnlock();
  }

  Future<void> _restorePurchases() async {
    try {
      await PurchaseManager.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.restoreSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.restoreFail)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PurchaseManager.instance.isPremiumNotifier,
            builder: (context, isPremium, child) {
              if (isPremium) return const SizedBox.shrink();
              return _buildPremiumCard(l10n);
            },
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(
              l10n.restorePurchases,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: _restorePurchases,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(
              l10n.privacyPolicy,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: _launchPrivacyPolicy,
          ),
          
          const Divider(height: 1),
          
          // Info
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(
              l10n.appVersion,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Text(_version),
          ),
          

        ],
      ),
    );
  }

  Widget _buildPremiumCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.removeAds,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFB300), // Vibrant Amber/Yellow
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.removeAdsDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black.withOpacity(0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _buyPremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300), // Vibrant Amber/Yellow
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 0,
              ),
              child: _isLoadingProducts 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    l10n.buy,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
