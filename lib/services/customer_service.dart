import 'api_client.dart';

class CustomerService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/customer/list.php?limit=&page=&search=
  static Future<Map<String, dynamic>> listCustomers({
    int limit = 20,
    int page = 1,
    String search = '',
  }) async {
    final response = await ApiClient.get('customer/list.php', queryParams: {
      'limit': limit.toString(),
      'page': page.toString(),
      if (search.isNotEmpty) 'search': search,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/customer/view.php?id=&amc_contracts=1&devices=1
  static Future<Map<String, dynamic>> viewCustomer(
    String id, {
    bool includeAmcContracts = false,
    bool includeDevices = false,
    String? loginPassword,
  }) async {
    final response = await ApiClient.get('customer/view.php', queryParams: {
      'id': id,
      if (includeAmcContracts) 'amc_contracts': '1',
      if (includeDevices) 'devices': '1',
      if (loginPassword != null && loginPassword.isNotEmpty)
        'login_password': loginPassword,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/customer/create.php (formdata)
  static Future<Map<String, dynamic>> createCustomer({
    required String firstName,
    required String phone,
    required String createdBy,
    String lastName = '',
    String email = '',
    String address = '',
    String city = '',
    String state = '',
    String pincode = '',
    String alternatePhone = '',
    String companyName = '',
    String gstNumber = '',
    String panNumber = '',
    String billingAddress = '',
    String siteAddress = '',
    String loginUsername = '',
    String loginPassword = '',
    String installationDate = '',
    String warrantyEndDate = '',
    String brand = '',
    String model = '',
    String productName = '',
    String products = '',
    String serialNumber = '',
    String networkingDetails = '',
    String wiringDetails = '',
    String powerDetails = '',
    String deviceAccessDetails = '',
    String biometricDetails = '',
    String personalFamilyDetails = '',
    String otherSiteDetails = '',
    String notes = '',
  }) async {
    final response = await ApiClient.postFormData('customer/create.php', {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'alternate_phone': alternatePhone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'company_name': companyName,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'billing_address': billingAddress,
      'site_address': siteAddress,
      'login_username': loginUsername,
      'login_password': loginPassword,
      'installation_date': installationDate,
      'warranty_end_date': warrantyEndDate,
      'brand': brand,
      'model': model,
      'product_name': productName,
      'products': products,
      'serial_number': serialNumber,
      'networking_details': networkingDetails,
      'wiring_details': wiringDetails,
      'power_details': powerDetails,
      'device_access_details': deviceAccessDetails,
      'biometric_details': biometricDetails,
      'personal_family_details': personalFamilyDetails,
      'other_site_details': otherSiteDetails,
      'notes': notes,
      'created_by': createdBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/customer/update.php (formdata)
  static Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String updatedBy,
    String id = '',
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String alternatePhone = '',
    String address = '',
    String city = '',
    String state = '',
    String pincode = '',
    String companyName = '',
    String gstNumber = '',
    String panNumber = '',
    String billingAddress = '',
    String siteAddress = '',
    String loginUsername = '',
    String loginPassword = '',
    String networkingDetails = '',
    String wiringDetails = '',
    String powerDetails = '',
    String deviceAccessDetails = '',
    String biometricDetails = '',
    String personalFamilyDetails = '',
    String otherSiteDetails = '',
    String notes = '',
  }) async {
    final response = await ApiClient.postFormData('customer/update.php', {
      'customer_id': customerId,
      'id': id.isNotEmpty ? id : customerId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'company_name': companyName,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'billing_address': billingAddress,
      'site_address': siteAddress,
      'login_username': loginUsername,
      'login_password': loginPassword,
      'networking_details': networkingDetails,
      'wiring_details': wiringDetails,
      'power_details': powerDetails,
      'device_access_details': deviceAccessDetails,
      'biometric_details': biometricDetails,
      'personal_family_details': personalFamilyDetails,
      'other_site_details': otherSiteDetails,
      'notes': notes,
      'updated_by': updatedBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/customer/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteCustomer({
    required String customerId,
    required String deletedBy,
    String loginUsername = '',
  }) async {
    final response = await ApiClient.postFormData('customer/delete.php', {
      'customer_id': customerId,
      'deleted_by': deletedBy,
      'login_username': loginUsername,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
