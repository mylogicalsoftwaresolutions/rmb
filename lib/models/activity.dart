class ActivityItem {
  final int id;
  final String category; // 'referrals', 'cNotes', 'r2r', 'testimonials', 'visitors', 'profileUpdates'
  final String title;
  final String from;
  final String to;
  final String details;
  final double? amount;
  final String date;
  String status; // 'Pending', 'Approved', 'Rejected'

  ActivityItem({
    required this.id,
    required this.category,
    required this.title,
    required this.from,
    required this.to,
    required this.details,
    this.amount,
    required this.date,
    this.status = 'Pending',
  });

  /// Builds an item from any of the activity endpoints. Each one names its
  /// date and description columns differently, so the fallbacks below cover
  /// referrals, C-Notes, R2R, testimonials and visitors alike.
  factory ActivityItem.fromJson(Map<String, dynamic> json, String category) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return null;
    }

    return ActivityItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      category: category,
      title: pick(['type', 'title', 'referral_type', 'topic']) ?? 'Activity',
      from: pick(['given_by_name', 'from_name', 'display_name']) ?? 'Unknown',
      to: pick(['received_by_name', 'to_name', 'external_name', 'visitor_name']) ??
          'Unknown',
      details: pick(['description', 'notes', 'content', 'details', 'company']) ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0'),
      date: pick([
            'date',
            'cnote_date',
            'referral_date',
            'testimonial_date',
            'entry_date',
            'meeting_date',
            'visit_date',
            'created_at',
          ]) ??
          '',
      // The API sends lowercase ('approved'); the UI compares against 'Approved'.
      status: _titleCase(json['status']?.toString()) ?? 'Pending',
    );
  }

  static String? _titleCase(String? v) {
    if (v == null || v.isEmpty) return null;
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }
}

final List<ActivityItem> initialActivities = [
  ActivityItem(
    id: 101,
    category: 'referrals',
    title: 'Inside Referral',
    from: 'Rahul A',
    to: 'Priya B',
    details: 'Client: Suresh Kumar (+91 98400 12345) - Tax Advisory',
    date: '2026-08-10',
    status: 'Approved',
  ),
  ActivityItem(
    id: 201,
    category: 'cNotes',
    title: 'Closed Business',
    from: 'Priya B',
    to: 'Rahul A',
    details: 'Web App Portal Development',
    amount: 450000.0,
    date: '2026-08-11',
    status: 'Approved',
  ),
  ActivityItem(
    id: 301,
    category: 'r2r',
    title: '1-on-1 Meeting',
    from: 'Rahul A',
    to: 'Praveen',
    details: 'Location: Grand Hotel Cafe - Synergy Setup',
    date: '2026-08-09',
    status: 'Approved',
  ),
  ActivityItem(
    id: 401,
    category: 'testimonials',
    title: '5-Star Feedback',
    from: 'Praveen',
    to: 'Priya B',
    details: 'Outstanding corporate tax audit guidance!',
    date: '2026-08-08',
    status: 'Approved',
  ),
  ActivityItem(
    id: 501,
    category: 'visitors',
    title: 'Chapter Guest',
    from: 'Rahul A',
    to: 'RMB BRIGHT',
    details: 'Visitor: Karthik Raja (Solar Power Solutions)',
    date: '2026-08-12',
    status: 'Pending',
  ),
];
