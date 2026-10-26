import 'api_client.dart';

class SurveyService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/survey/list.php?limit=&offset=&search=&status=&lead_id=&assigned_employee=
  static Future<Map<String, dynamic>> listSurveys({
    int limit = 20,
    int offset = 0,
    String search = '',
    String status = '',
    String leadId = '',
    String assignedEmployee = '',
  }) async {
    final response = await ApiClient.get('survey/list.php', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (leadId.isNotEmpty) 'lead_id': leadId,
      if (assignedEmployee.isNotEmpty) 'assigned_employee': assignedEmployee,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/survey/view.php?id=
  static Future<Map<String, dynamic>> viewSurvey(String id) async {
    final response =
        await ApiClient.get('survey/view.php', queryParams: {'id': id});
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/survey/create.php (formdata)
  static Future<Map<String, dynamic>> createSurvey({
    required String customerName,
    required String userId,
    String customerPhone = '',
    String customerEmail = '',
    String customerAddress = '',
    String leadId = '',
    String surveyDate = '',
    String surveyTime = '',
    String assignedEmployee = '',
    String gpsAddress = '',
    String latitude = '',
    String longitude = '',
    String requirementAnalysis = '',
    String customerExpectations = '',
    String cameraRequirement = '',
    String cameraPointAnalysis = '',
    String networkingRequirement = '',
    String wiringRequirement = '',
    String powerAvailability = '',
    String biometricRequirement = '',
    String dvrNvrPlacement = '',
    String ladderRequirement = '',
    String civilWorkNotes = '',
    String specialNotes = '',
  }) async {
    final response = await ApiClient.postFormData('survey/create.php', {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'lead_id': leadId,
      'survey_date': surveyDate,
      'survey_time': surveyTime,
      'assigned_employee': assignedEmployee,
      'gps_address': gpsAddress,
      'latitude': latitude,
      'longitude': longitude,
      'requirement_analysis': requirementAnalysis,
      'customer_expectations': customerExpectations,
      'camera_requirement': cameraRequirement,
      'camera_point_analysis': cameraPointAnalysis,
      'networking_requirement': networkingRequirement,
      'wiring_requirement': wiringRequirement,
      'power_availability': powerAvailability,
      'biometric_requirement': biometricRequirement,
      'dvr_nvr_placement': dvrNvrPlacement,
      'ladder_requirement': ladderRequirement,
      'civil_work_notes': civilWorkNotes,
      'special_notes': specialNotes,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/survey/update.php (formdata)
  static Future<Map<String, dynamic>> updateSurvey({
    required String id,
    required String userId,
    Map<String, String> extraFields = const {},
  }) async {
    final response = await ApiClient.postFormData('survey/update.php', {
      'id': id,
      'user_id': userId,
      ...extraFields,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/survey/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteSurvey({
    required String id,
    required String userId,
  }) async {
    final response = await ApiClient.postFormData('survey/delete.php', {
      'id': id,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
