import 'api_client.dart';

class AttendanceService {
  /// POST /attendance/checkin
  /// Body: { token: "QR_TOKEN_VALUE" }
  /// Expected: { success: true, message: "Checked in successfully" }
  static Future<void> checkIn(String token) async {
    await ApiClient.post('attendance/checkin', {'token': token});
  }
}
