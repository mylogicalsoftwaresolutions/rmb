import 'api_client.dart';

class LeadService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/lead/list.php?limit=&offset=&search=&status=&source=
  static Future<Map<String, dynamic>> listLeads({
    int limit = 20,
    int offset = 0,
    String search = '',
    String status = '',
    String source = '',
  }) async {
    final response = await ApiClient.get('lead/list.php', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (source.isNotEmpty) 'source': source,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/lead/view.php?id=
  static Future<Map<String, dynamic>> viewLead(String id) async {
    final response =
        await ApiClient.get('lead/view.php', queryParams: {'id': id});
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/lead/create.php (formdata)
  static Future<Map<String, dynamic>> createLead({
    required String customerName,
    required String phone,
    required String userId,
    String alternatePhone = '',
    String email = '',
    String address = '',
    String city = '',
    String state = '',
    String pincode = '',
    String companyName = '',
    String source = '',
    String sourceDetails = '',
    String requirement = '',
    String budgetRange = '',
    String priority = '',
    String assignedSalesExecutive = '',
    String assignedTelecaller = '',
    String followUpDate = '',
    String followUpTime = '',
    String locationLink = '',
    String notes = '',
  }) async {
    final response = await ApiClient.postFormData('lead/create.php', {
      'customer_name': customerName,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'company_name': companyName,
      'source': source,
      'source_details': sourceDetails,
      'requirement': requirement,
      'budget_range': budgetRange,
      'priority': priority,
      'assigned_sales_executive': assignedSalesExecutive,
      'assigned_telecaller': assignedTelecaller,
      'follow_up_date': followUpDate,
      'follow_up_time': followUpTime,
      'location_link': locationLink,
      'notes': notes,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/lead/update.php (formdata)
  /// Pass only the fields you want to update alongside id and user_id.
  static Future<Map<String, dynamic>> updateLead({
    required String id,
    required String userId,
    Map<String, String> extraFields = const {},
  }) async {
    final response = await ApiClient.postFormData('lead/update.php', {
      'id': id,
      'user_id': userId,
      ...extraFields,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/lead/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteLead({
    required String id,
    required String userId,
  }) async {
    final response = await ApiClient.postFormData('lead/delete.php', {
      'id': id,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
