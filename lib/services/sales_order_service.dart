import 'api_client.dart';

class SalesOrderService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/sales_order/list.php?limit=&offset=&search=&status=&payment_status=
  static Future<Map<String, dynamic>> listSalesOrders({
    int limit = 20,
    int offset = 0,
    String search = '',
    String status = '',
    String paymentStatus = '',
  }) async {
    final response =
        await ApiClient.get('sales_order/list.php', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/sales_order/view.php?id=&items=1
  static Future<Map<String, dynamic>> viewSalesOrder(
    String id, {
    bool includeItems = true,
  }) async {
    final response =
        await ApiClient.get('sales_order/view.php', queryParams: {
      'id': id,
      if (includeItems) 'items': '1',
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/sales_order/create.php (formdata)
  /// [items] should be a JSON-encoded string of line items.
  static Future<Map<String, dynamic>> createSalesOrder({
    required String customerName,
    required String userId,
    String id = '',
    String customerPhone = '',
    String customerEmail = '',
    String customerAddress = '',
    String leadId = '',
    String quotationId = '',
    String productId = '',
    String productName = '',
    String brand = '',
    String model = '',
    String quantity = '',
    String unitPrice = '',
    String totalPrice = '',
    String discountPercent = '',
    String discountType = '',
    String gstPercent = '',
    String shippingCharges = '',
    String surveyExpenseAmount = '',
    String items = '',
    String advanceAmount = '',
    String advancePaidDate = '',
    String advancePaymentMethod = '',
    String advanceReference = '',
    String currentStock = '',
    String orderDate = '',
    String deliveryDate = '',
    String status = '',
    String notes = '',
  }) async {
    final response = await ApiClient.postFormData('sales_order/create.php', {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'lead_id': leadId,
      'quotation_id': quotationId,
      'product_id': productId,
      'product_name': productName,
      'brand': brand,
      'model': model,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'discount_percent': discountPercent,
      'discount_type': discountType,
      'gst_percent': gstPercent,
      'shipping_charges': shippingCharges,
      'survey_expense_amount': surveyExpenseAmount,
      'items': items,
      'advance_amount': advanceAmount,
      'advance_paid_date': advancePaidDate,
      'advance_payment_method': advancePaymentMethod,
      'advance_reference': advanceReference,
      'current_stock': currentStock,
      'order_date': orderDate,
      'delivery_date': deliveryDate,
      'status': status,
      'notes': notes,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/sales_order/update.php (formdata)
  static Future<Map<String, dynamic>> updateSalesOrder({
    required String id,
    required String userId,
    Map<String, String> extraFields = const {},
  }) async {
    final response = await ApiClient.postFormData('sales_order/update.php', {
      'id': id,
      'user_id': userId,
      ...extraFields,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/sales_order/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteSalesOrder({
    required String id,
    required String userId,
  }) async {
    final response = await ApiClient.postFormData('sales_order/delete.php', {
      'id': id,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
