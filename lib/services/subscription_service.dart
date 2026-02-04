import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _studioRecordCountKey = 'studio_record_count';
  static const String _challengePlayCountKey = 'challenge_play_count';
  static const String _entitlementId = 'EchoReverse';

  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Cache subscription status
  bool? _isSubscribed;
  DateTime? _lastCheck;

  /// Check if user has active subscription
  Future<bool> isSubscribed() async {
    // Use cached value if checked within last 5 minutes
    if (_isSubscribed != null && _lastCheck != null) {
      final diff = DateTime.now().difference(_lastCheck!);
      if (diff.inMinutes < 5) {
        return _isSubscribed!;
      }
    }

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      _isSubscribed = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      _lastCheck = DateTime.now();
      return _isSubscribed!;
    } catch (e) {
      // If error, assume not subscribed
      return false;
    }
  }

  /// Get studio record count
  Future<int> getStudioRecordCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_studioRecordCountKey) ?? 0;
  }

  /// Increment studio record count
  Future<void> incrementStudioRecordCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_studioRecordCountKey) ?? 0;
    await prefs.setInt(_studioRecordCountKey, current + 1);
  }

  /// Get challenge play count
  Future<int> getChallengePlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_challengePlayCountKey) ?? 0;
  }

  /// Increment challenge play count
  Future<void> incrementChallengePlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_challengePlayCountKey) ?? 0;
    await prefs.setInt(_challengePlayCountKey, current + 1);
  }

  /// Check if user can record (first time free, then needs subscription)
  /// Returns: true = can record, false = show paywall
  Future<bool> canRecord() async {
    final count = await getStudioRecordCount();

    // First recording is free
    if (count == 0) {
      return true;
    }

    // Subsequent recordings need subscription
    return await isSubscribed();
  }

  /// Check if user can play challenge (first time free, then needs subscription)
  /// Returns: true = can play, false = show paywall
  Future<bool> canPlayChallenge() async {
    final count = await getChallengePlayCount();

    // First challenge is free
    if (count == 0) {
      return true;
    }

    // Subsequent challenges need subscription
    return await isSubscribed();
  }

  /// Reset cached subscription status (call after purchase/restore)
  void resetCache() {
    _isSubscribed = null;
    _lastCheck = null;
  }
}
