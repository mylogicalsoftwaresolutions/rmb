import 'api_client.dart';

class QuotationService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/quotation/list.php?limit=&offset=&search=&status=
  static Future<Map<String, dynamic>> listQuotations({
    int limit = 20,
    int offset = 0,
    String search = '',
    String status = '',
  }) async {
    final response = await ApiClient.get('quotation/list.php', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/quotation/view.php?id=&items=1
  static Future<Map<String, dynamic>> viewQuotation(
    String id, {
    bool includeItems = true,
  }) async {
    final response =
        await ApiClient.get('quotation/view.php', queryParams: {
      'id': id,
      if (includeItems) 'items': '1',
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/quotation/create.php (formdata)
  /// [items] should be a JSON-encoded string of line items array.
  static Future<Map<String, dynamic>> createQuotation({
    required String customerName,
    required String userId,
    String customerPhone = '',
    String customerEmail = '',
    String customerAddress = '',
    String leadId = '',
    String surveyId = '',
    String priceListId = '',
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
    String paymentTerms = '',
    String deliveryTerms = '',
    String termsConditions = '',
    String validUntil = '',
    String status = '',
    String notes = '',
  }) async {
    final response = await ApiClient.postFormData('quotation/create.php', {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'lead_id': leadId,
      'survey_id': surveyId,
      'price_list_id': priceListId,
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
      'payment_terms': paymentTerms,
      'delivery_terms': deliveryTerms,
      'terms_conditions': termsConditions,
      'valid_until': validUntil,
      'status': status,
      'notes': notes,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

      
  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/quotation/update.php (formdata)
  static Future<Map<String, dynamic>> updateQuotation({
    required String id,
    required String userId,
    String leadId = '',
    String status = '',
    Map<String, String> extraFields = const {},
  }) async {
    final response = await ApiClient.postFormData('quotation/update.php', {
      'id': id,
      'lead_id': leadId,
      'status': status,
      'user_id': userId,
      ...extraFields,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/quotation/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteQuotation({
    required String id,
    required String userId,
  }) async {
    final response = await ApiClient.postFormData('quotation/delete.php', {
      'id': id,
      'user_id': userId,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
