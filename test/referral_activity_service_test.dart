import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/services/activity_service.dart';

void main() {
  test('referral payload matcher accepts a saved row with the same member and date', () {
    final payload = {
      'received_by': '42',
      'business_category': 'Marketing',
      'referral_date': '20-08-2026',
    };

    final row = {
      'received_by': 42,
      'business_category': 'Marketing',
      'referral_date': '2026-08-20',
    };

    expect(ActivityService.referralRowMatches(row, payload), isTrue);
  });

  test('referral payload matcher rejects a different category or member', () {
    final payload = {
      'received_by': '42',
      'business_category': 'Marketing',
    };

    final row = {
      'received_by': '99',
      'business_category': 'Consulting',
    };

    expect(ActivityService.referralRowMatches(row, payload), isFalse);
  });
}
