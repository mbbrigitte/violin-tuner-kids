import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewHelper {
  static Future<void> incrementAndMaybeAskReview() async {
    final prefs = await SharedPreferences.getInstance();
    final hasReviewed = prefs.getBool('has_reviewed') ?? false;
    if (hasReviewed) return;

    final count = (prefs.getInt('use_count') ?? 0) + 1;
    await prefs.setInt('use_count', count);

    if (count == 3 || count == 10) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool('has_reviewed', true);
      }
    }
  }
}