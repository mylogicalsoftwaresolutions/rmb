import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/services/report_service.dart';

void main() {
  group('ReportService.parseChapterLeaderboard', () {
    test('accepts every supported API response envelope', () {
      const row = {'user_id': 7, 'display_name': 'Asha', 'score': 4};
      final responses = [
        {'leaderboard': [row]},
        {'data': [row]},
        {
          'data': {'leaderboard': [row]}
        },
      ];

      for (final response in responses) {
        final rows = ReportService.parseChapterLeaderboard(response);
        expect(rows, hasLength(1));
        expect(rows.single['display_name'], 'Asha');
        expect(rows.single['id'], 7);
      }
    });

    test('normalises metric-specific values into score', () {
      final rows = ReportService.parseChapterLeaderboard({
        'data': [
          {'member_id': 12, 'business_given_amount': '2500.00'}
        ]
      });

      expect(rows.single['id'], 12);
      expect(rows.single['score'], '2500.00');
    });

    test('uses directory members from the signed-in chapter as fallback', () {
      final rows = ReportService.parseDirectoryMembers({
        'data': {
          'members': [
            {'id': 7, 'display_name': 'Asha', 'chapter_name': 'RMB Salem'},
            {'id': 8, 'display_name': 'Bala', 'chapter_name': 'RMB Salem'},
            {'id': 9, 'display_name': 'Chitra', 'chapter_name': 'RMB Bright'},
          ],
        },
      }, userId: '7');

      expect(rows.map((row) => row['id']), [7, 8]);
      expect(rows.every((row) => row['score'] == 0), isTrue);
    });
  });
}
