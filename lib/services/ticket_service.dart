import 'api_client.dart';

/// Service Ticket (mapped to /apis/service/*.php)
class TicketService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/service/list.php?limit=&page=&search=&status=
  static Future<Map<String, dynamic>> listTickets({
    int limit = 20,
    int page = 1,
    String search = '',
    String status = '',
  }) async {
    final response = await ApiClient.get('service/list.php', queryParams: {
      'limit': limit.toString(),
      'page': page.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/service/view.php?id=&updates=1
  static Future<Map<String, dynamic>> viewTicket(
    String id, {
    bool includeUpdates = true,
  }) async {
    final response = await ApiClient.get('service/view.php', queryParams: {
      'id': id,
      if (includeUpdates) 'updates': '1',
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/service/create.php (formdata)
  static Future<Map<String, dynamic>> createTicket({
    required String createdBy,
    String customerId = '',
    String customerName = '',
    String customerPhone = '',
    String customerEmail = '',
    String customerAddress = '',
    String deviceId = '',
    String productName = '',
    String serialNumber = '',
    String issueType = '',
    String issueDescription = '',
    String priority = '',
    String assignedTechnician = '',
    String amcContractId = '',
    String isExistingCustomer = '',
    String isUnderWarranty = '',
    String isUnderAmc = '',
  }) async {
    final response = await ApiClient.postFormData('service/create.php', {
      'created_by': createdBy,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'device_id': deviceId,
      'product_name': productName,
      'serial_number': serialNumber,
      'issue_type': issueType,
      'issue_description': issueDescription,
      'priority': priority,
      'assigned_technician': assignedTechnician,
      'amc_contract_id': amcContractId,
      'is_existing_customer': isExistingCustomer,
      'is_under_warranty': isUnderWarranty,
      'is_under_amc': isUnderAmc,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/service/update.php (formdata)
  static Future<Map<String, dynamic>> updateTicket({
    required String ticketId,
    required String updatedBy,
    String status = '',
    String assignedTechnician = '',
    String priority = '',
  }) async {
    final response = await ApiClient.postFormData('service/update.php', {
      'ticket_id': ticketId,
      'updated_by': updatedBy,
      'status': status,
      'assigned_technician': assignedTechnician,
      'priority': priority,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/service/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteTicket({
    required String ticketId,
    required String deletedBy,
  }) async {
    final response = await ApiClient.postFormData('service/delete.php', {
      'ticket_id': ticketId,
      'deleted_by': deletedBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
