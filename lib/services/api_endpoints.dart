/// Central catalogue of every HTTP endpoint used by the application.
///
/// Query values such as `user_id`, `period`, `id`, and `status` are deliberately
/// not embedded here: each authenticated request supplies its own current
/// values through [ApiClient.get], [ApiClient.post], or [ApiClient.postFormData].
class ApiEndpoints {
  ApiEndpoints._();

  static const String apiBaseUrl = 'https://rmbconnect.in/api';
  static const String flutterApiBaseUrl = 'https://rmbconnect.in/api_flutter';

  // Member / Flutter API endpoints.
  static const String login = 'login.php';
  static const String auth = 'auth.php';
  static const String profile = 'profile.php';
  static const String dashboard = 'dashboard.php';
  static const String reports = 'reports.php';
  static const String referrals = 'referrals.php';
  static const String cnotes = 'cnotes.php';
  static const String r2r = 'r2r.php';
  static const String testimonials = 'testimonials.php';
  static const String visitors = 'visitors.php';
  static const String giveAsk = 'give_ask.php';
  static const String directory = 'directory.php';
  static const String meetings = 'meetings.php';
  static const String events = 'events.php';
  static const String notifications = 'notifications.php';
  static const String deviceToken = 'device_token.php';
  static const String leaderboard = 'leaderboard.php';

  // Main API endpoints.
  static const String employeeList = 'employee/list.php';
  static const String employeeView = 'employee/view.php';
  static const String employeeCreate = 'employee/create.php';
  static const String employeeUpdate = 'employee/update.php';
  static const String employeeDelete = 'employee/delete.php';
  static const String customerList = 'customer/list.php';
  static const String customerView = 'customer/view.php';
  static const String customerCreate = 'customer/create.php';
  static const String customerUpdate = 'customer/update.php';
  static const String customerDelete = 'customer/delete.php';
  static const String leadList = 'lead/list.php';
  static const String leadView = 'lead/view.php';
  static const String leadCreate = 'lead/create.php';
  static const String leadUpdate = 'lead/update.php';
  static const String leadDelete = 'lead/delete.php';
  static const String quotationList = 'quotation/list.php';
  static const String quotationView = 'quotation/view.php';
  static const String quotationCreate = 'quotation/create.php';
  static const String quotationUpdate = 'quotation/update.php';
  static const String quotationDelete = 'quotation/delete.php';
  static const String salesOrderList = 'sales_order/list.php';
  static const String salesOrderView = 'sales_order/view.php';
  static const String salesOrderCreate = 'sales_order/create.php';
  static const String salesOrderUpdate = 'sales_order/update.php';
  static const String salesOrderDelete = 'sales_order/delete.php';
  static const String surveyList = 'survey/list.php';
  static const String surveyView = 'survey/view.php';
  static const String surveyCreate = 'survey/create.php';
  static const String surveyUpdate = 'survey/update.php';
  static const String surveyDelete = 'survey/delete.php';
  static const String installationList = 'installation/list.php';
  static const String installationView = 'installation/view.php';
  static const String installationCreate = 'installation/create.php';
  static const String installationUpdate = 'installation/update.php';
  static const String installationDelete = 'installation/delete.php';
  static const String serviceTicketList = 'service/list.php';
  static const String serviceTicketView = 'service/view.php';
  static const String serviceTicketCreate = 'service/create.php';
  static const String serviceTicketUpdate = 'service/update.php';
  static const String serviceTicketDelete = 'service/delete.php';

  static String flutterUrl(String endpoint) => '$flutterApiBaseUrl/$endpoint';
  static String apiUrl(String endpoint) => '$apiBaseUrl/$endpoint';
}
