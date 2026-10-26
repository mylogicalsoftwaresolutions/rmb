import 'api_client.dart';

class InstallationService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/installation/list.php?limit=&offset=&search=&status=&assigned_technician=
  static Future<Map<String, dynamic>> listInstallations({
    int limit = 20,
    int offset = 0,
    String search = '',
    String status = '',
    String assignedTechnician = '',
  }) async {
    final response =
        await ApiClient.get('installation/list.php', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (assignedTechnician.isNotEmpty)
        'assigned_technician': assignedTechnician,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  
  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/installation/view.php?id=&checklist=1
  static Future<Map<String, dynamic>> viewInstallation(
    String id, {
    bool includeChecklist = false,
  }) async {
    final response =
        await ApiClient.get('installation/view.php', queryParams: {
      'id': id,
      if (includeChecklist) 'checklist': '1',
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/installation/create.php (formdata)
  static Future<Map<String, dynamic>> createInstallation({
    required String customerName,
    required String userId,
    String customerPhone = '',
    String customerEmail = '',
    String customerAddress = '',
    String salesOrderId = '',
    String leadId = '',
    String assignedTechnician = '',
    String installationDate = '',
    String installationTime = '',
    String installationEndDate = '',
    String installationEndTime = '',
    String estimatedDuration = '',
    String notes = '',
  }) async {
    final response =
        await ApiClient.postFormData('installation/create.php', {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'sales_order_id': salesOrderId,
      'lead_id': leadId,
      'assigned_technician': assignedTechnician,
      'installation_date': installationDate,
      'installation_time': installationTime,
      'installation_end_date': installationEndDate,
      'installation_end_time': installationEndTime,
      'estimated_duration': estimatedDuration,
      'notes': notes,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/installation/update.php (formdata)
  static Future<Map<String, dynamic>> updateInstallation({
    required String id,
    required String userId,
    Map<String, String> extraFields = const {},
  }) async {
    final response =
        await ApiClient.postFormData('installation/update.php', {
      'id': id,
      'user_id': userId,
      ...extraFields,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/installation/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteInstallation({
    required String id,
    required String userId,
  }) async {
    final response =
        await ApiClient.postFormData('installation/delete.php', {
      'id': id,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
