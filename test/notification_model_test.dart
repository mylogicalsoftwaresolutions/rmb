import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/models/notification_model.dart';

void main() {
  test('formats a database timestamp as a readable date and time', () {
    final notification = NotificationModel.fromJson({
      'id': 1,
      'title': 'R2R meeting logged',
      'message': 'A meeting was logged.',
      'created_at': '2026-09-26 05:31:11',
    });

    expect(notification.displayDateTime, '26 Sep 2026, 5:31 AM');
  });

  test('uses the populated message field when the preferred field is blank', () {
    final notification = NotificationModel.fromJson({
      'message': '',
      'notification_message': 'A referral was received.',
    });

    expect(notification.message, 'A referral was received.');
  });

  test('reads notification text nested in an FCM data payload', () {
    final notification = NotificationModel.fromJson({
      'data': {
        'notification_title': 'New Referral',
        'notification_body': 'You have received a new referral.',
      },
    });

    expect(notification.title, 'New Referral');
    expect(notification.message, 'You have received a new referral.');
  });

  test('falls back to title when message is completely blank', () {
    final notification = NotificationModel.fromJson({
      'title': 'Chapter Meeting Update',
      'message': '',
    });

    expect(notification.message, 'Chapter Meeting Update');
  });

  test('normalizes read status and parses link correctly', () {
    final notification = NotificationModel.fromJson({
      'id': 123,
      'title': 'New Meeting',
      'message': 'Weekly meeting scheduled',
      'is_read': 0,
      'link': 'https://rmbconnect.in/member/meetings.php',
    });

    expect(notification.status, 'unread');
    expect(notification.link, 'https://rmbconnect.in/member/meetings.php');
  });
}
