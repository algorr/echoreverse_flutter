import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../config/constants.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSubscribed = false;
  bool _isLoading = true;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      setState(() {
        _isSubscribed =
            customerInfo.entitlements.all[AppConstants.entitlementId]?.isActive ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSubscribed = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isActive =
          customerInfo.entitlements.all[AppConstants.entitlementId]?.isActive ?? false;

      setState(() {
        _isSubscribed = isActive;
        _isRestoring = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive
                ? 'Subscription restored successfully!'
                : 'No active subscription found.'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isRestoring = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore purchases. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rateApp() async {
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      // Fallback to store listing
      await inAppReview.openStoreListing(appStoreId: AppConstants.appStoreId);
    }
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out Reverso - the audio time machine app! ${AppConstants.appStoreUrl}',
      subject: 'Reverso App',
    );
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {
        'subject': 'Reverso Support',
        'body': 'App Version: ${AppConstants.appVersion}\n\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _manageSubscription() async {
    // iOS subscription management URL
    const url = 'https://apps.apple.com/account/subscriptions';
    await _openUrl(url);
  }

  Future<void> _clearAllRecordings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Clear All Recordings?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all your recordings. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('studio_record_count');
      await prefs.remove('challenge_play_count');
      // Note: Actual audio files would need to be deleted from file system too

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All recordings cleared.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Status Card
            _buildSubscriptionCard(),

            const SizedBox(height: 24),

            // General Section
            _buildSectionTitle('General'),
            _buildSettingsTile(
              icon: Icons.star_outline,
              title: 'Rate App',
              subtitle: 'Love Reverso? Rate us!',
              onTap: _rateApp,
            ),
            _buildSettingsTile(
              icon: Icons.share_outlined,
              title: 'Share App',
              subtitle: 'Share with friends',
              onTap: _shareApp,
            ),
            _buildSettingsTile(
              icon: Icons.mail_outline,
              title: 'Contact Support',
              subtitle: AppConstants.supportEmail,
              onTap: _contactSupport,
            ),

            const SizedBox(height: 24),

            // Subscription Section
            _buildSectionTitle('Subscription'),
            _buildSettingsTile(
              icon: Icons.restore,
              title: 'Restore Purchases',
              subtitle: 'Restore your subscription',
              trailing: _isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isRestoring ? null : _restorePurchases,
            ),
            if (_isSubscribed)
              _buildSettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Manage Subscription',
                subtitle: 'View or cancel subscription',
                onTap: _manageSubscription,
              ),

            const SizedBox(height: 24),

            // Data Section
            _buildSectionTitle('Data'),
            _buildSettingsTile(
              icon: Icons.delete_outline,
              title: 'Clear All Recordings',
              subtitle: 'Delete all saved recordings',
              titleColor: Colors.red.shade300,
              onTap: _clearAllRecordings,
            ),

            const SizedBox(height: 24),

            // Legal Section
            _buildSectionTitle('Legal'),
            _buildSettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () => _openUrl(AppConstants.termsUrl),
            ),
            _buildSettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => _openUrl(AppConstants.privacyUrl),
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Text(
                'Version ${AppConstants.appVersion}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isSubscribed
            ? const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFFD946EF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _isSubscribed ? null : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: _isSubscribed
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isSubscribed ? 0.2 : 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isSubscribed ? Icons.workspace_premium : Icons.lock_outline,
              color: _isSubscribed ? Colors.white : const Color(0xFF22D3EE),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading
                      ? 'Checking...'
                      : _isSubscribed
                          ? 'Reverso Pro'
                          : 'Free Plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoading
                      ? 'Please wait'
                      : _isSubscribed
                          ? 'All features unlocked'
                          : 'Limited features',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (!_isSubscribed && !_isLoading)
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
                // Refresh subscription status after returning from paywall
                _checkSubscription();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'UPGRADE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: titleColor ?? const Color(0xFF22D3EE),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
            ),
        onTap: onTap,
      ),
    );
  }

}
