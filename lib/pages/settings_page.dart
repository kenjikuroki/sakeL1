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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        children: [
          // Premium Section
          ValueListenableBuilder<bool>(
            valueListenable: PurchaseManager.instance.isPremiumNotifier,
            builder: (context, isPremium, child) {
              if (isPremium) {
                return const SizedBox.shrink(); // Hide if already premium
              }
              return Card(
                margin: const EdgeInsets.all(16),
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        l10n.premiumUnlock,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.premiumDesc),
                      const SizedBox(height: 16),
                      _isLoadingProducts
                          ? const CircularProgressIndicator()
                          : Column(
                              children: [
                                if (_products.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFFA000), Color(0xFFFFC107)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _buyPremium,
                                        borderRadius: BorderRadius.circular(28),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.workspace_premium, color: Colors.white, size: 30),
                                              const SizedBox(width: 12),
                                              Text(
                                                "${l10n.buy} ${_products.first.price}",
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 1.0,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black.withValues(alpha: 0.2),
                                                      offset: const Offset(0, 2),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  Text(l10n.noData, style: const TextStyle(color: Colors.red)), // Using noData as placeholder
                                  const SizedBox(height: 8),
                                  // Debug/Fallback Button
                                  if (kDebugMode)
                                    OutlinedButton(
                                      onPressed: _debugUnlock,
                                      child: const Text("Debug Unlock (Free)"),
                                    ),
                                ]
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // Actions
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.restorePurchases),
            onTap: () async {
              await PurchaseManager.instance.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(l10n.restoreSuccess)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.privacyPolicy),
            onTap: _launchPrivacyPolicy,
          ),
          
          const Divider(),
          
          // Info
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.appVersion),
            trailing: Text(_version),
          ),
        ],
      ),
    );
  }
}
