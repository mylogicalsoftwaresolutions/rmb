import 'api_client.dart';

class EmployeeService {
  // ─── List ──────────────────────────────────────────────────────────────────

  /// GET /apis/employee/list.php?limit=&page=&search=&role=
  static Future<Map<String, dynamic>> listEmployees({
    int limit = 20,
    int page = 1,
    String search = '',
    String role = '',
  }) async {
    final response = await ApiClient.get('employee/list.php', queryParams: {
      'limit': limit.toString(),
      'page': page.toString(),
      if (search.isNotEmpty) 'search': search,
      if (role.isNotEmpty) 'role': role,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── View ──────────────────────────────────────────────────────────────────

  /// GET /apis/employee/view.php?id=
  static Future<Map<String, dynamic>> viewEmployee(String id) async {
    final response =
        await ApiClient.get('employee/view.php', queryParams: {'id': id});
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  /// POST /apis/employee/create.php (formdata)
  static Future<Map<String, dynamic>> createEmployee({
    required String firstName,
    required String phone,
    required String createdBy,
    String lastName = '',
    String email = '',
    String alternatePhone = '',
    String address = '',
    String city = '',
    String state = '',
    String pincode = '',
    String designation = '',
    String departmentId = '',
    String roleType = '',
    String salary = '',
    String joiningDate = '',
    String leaveStatus = '',
    String loginUsername = '',
    String loginPassword = '',
    String createLogin = '',
    String panNumber = '',
    String aadharNumber = '',
    String bankName = '',
    String bankAccount = '',
    String ifscCode = '',
    String emergencyContactName = '',
    String emergencyContactPhone = '',
  }) async {
    final response = await ApiClient.postFormData('employee/create.php', {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'alternate_phone': alternatePhone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'designation': designation,
      'department_id': departmentId,
      'role_type': roleType,
      'salary': salary,
      'joining_date': joiningDate,
      'leave_status': leaveStatus,
      'login_username': loginUsername,
      'login_password': loginPassword,
      'create_login': createLogin,
      'pan_number': panNumber,
      'aadhar_number': aadharNumber,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'ifsc_code': ifscCode,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'created_by': createdBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// POST /apis/employee/update.php (formdata)
  static Future<Map<String, dynamic>> updateEmployee({
    required String employeeId,
    required String updatedBy,
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String alternatePhone = '',
    String address = '',
    String city = '',
    String state = '',
    String pincode = '',
    String designation = '',
    String departmentId = '',
    String roleType = '',
    String salary = '',
    String joiningDate = '',
    String leaveStatus = '',
    String loginUsername = '',
    String loginPassword = '',
    String createLogin = '',
    String panNumber = '',
    String aadharNumber = '',
    String bankName = '',
    String bankAccount = '',
    String ifscCode = '',
    String emergencyContactName = '',
    String emergencyContactPhone = '',
  }) async {
    final response = await ApiClient.postFormData('employee/update.php', {
      'employee_id': employeeId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'designation': designation,
      'department_id': departmentId,
      'role_type': roleType,
      'salary': salary,
      'joining_date': joiningDate,
      'leave_status': leaveStatus,
      'login_username': loginUsername,
      'login_password': loginPassword,
      'create_login': createLogin,
      'pan_number': panNumber,
      'aadhar_number': aadharNumber,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'ifsc_code': ifscCode,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'updated_by': updatedBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// POST /apis/employee/delete.php (formdata)
  static Future<Map<String, dynamic>> deleteEmployee({
    required String employeeId,
    required String deletedBy,
  }) async {
    final response = await ApiClient.postFormData('employee/delete.php', {
      'employee_id': employeeId,
      'deleted_by': deletedBy,
    });
    return response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
  }
}
