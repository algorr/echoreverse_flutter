import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RateService {
  static const String _hasRatedKey = 'has_rated';
  static const String _actionCountKey = 'rate_action_count';
  static const String _firstRecordingDoneKey = 'first_recording_done';

  // Singleton
  static final RateService _instance = RateService._internal();
  factory RateService() => _instance;
  RateService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Check if user has already rated
  Future<bool> hasRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRatedKey) ?? false;
  }

  /// Mark user as rated
  Future<void> setRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  /// Check if first recording has been done
  Future<bool> isFirstRecordingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstRecordingDoneKey) ?? false;
  }

  /// Mark first recording as done
  Future<void> setFirstRecordingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRecordingDoneKey, true);
  }

  /// Get current action count
  Future<int> getActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_actionCountKey) ?? 0;
  }

  /// Increment action count
  Future<void> incrementActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_actionCountKey) ?? 0;
    await prefs.setInt(_actionCountKey, current + 1);
  }

  /// Reset action count (after showing rate dialog)
  Future<void> resetActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_actionCountKey, 0);
  }

  /// Should show rate dialog?
  /// Returns true if:
  /// 1. First recording ever (and not rated)
  /// 2. Every 2 actions after that (if not rated)
  Future<bool> shouldShowRateDialog() async {
    // If already rated, never show again
    if (await hasRated()) {
      return false;
    }

    // Check if first recording
    final firstDone = await isFirstRecordingDone();
    if (!firstDone) {
      return true; // Show after first recording
    }

    // Check action count (every 2 actions)
    final count = await getActionCount();
    return count >= 2;
  }

  /// Show rate dialog and handle tracking
  /// Call this after recording/challenge/filter usage
  Future<void> trackActionAndShowRateIfNeeded() async {
    // If already rated, just return
    if (await hasRated()) {
      return;
    }

    // Check if first recording
    final firstDone = await isFirstRecordingDone();

    if (!firstDone) {
      // First recording - mark as done and show dialog
      await setFirstRecordingDone();
      await _showRateDialog();
      return;
    }

    // Increment action count
    await incrementActionCount();

    // Check if should show (every 2 actions)
    final count = await getActionCount();
    if (count >= 2) {
      await resetActionCount();
      await _showRateDialog();
    }
  }

  /// Actually show the rate dialog
  Future<void> _showRateDialog() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        // Note: We can't know if user actually rated
        // iOS only shows the dialog once per year after user rates
        // So we mark as rated after showing
        await setRated();
      }
    } catch (e) {
      // Silently fail - rate dialog is not critical
    }
  }
}
