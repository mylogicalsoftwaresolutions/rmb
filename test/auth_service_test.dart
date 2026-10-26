import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores a saved, unexpired user session', () async {
    SharedPreferences.setMockInitialValues({
      'user_id': '42',
      'user_name': 'Asha',
      'user_role': 'member',
      'login_username': '9999999999',
      'session_expires_at':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    });

    expect(await AuthService.restoreSession(), {
      'name': 'Asha',
      'role': 'member',
      'mobile': '9999999999',
    });
  });

  test('clears an expired session', () async {
    SharedPreferences.setMockInitialValues({
      'user_id': '42',
      'session_expires_at':
          DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    });

    expect(await AuthService.restoreSession(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('user_id'), isFalse);
  });
}
