class ActivityModel {
  final int id;
  final String type; // 'referral', 'cnote', 'r2r', 'testimonial', 'visitor', 'giveask'
  final String date;
  final String status;
  final String description;
  final String counterpartName;
  final double amount;
  
  // Specific fields can go here, or we can use subclasses. Keeping it flat for simplicity.
  final Map<String, dynamic> rawJson;

  ActivityModel({
    required this.id,
    required this.type,
    required this.date,
    required this.status,
    required this.description,
    required this.counterpartName,
    required this.amount,
    required this.rawJson,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json, String type) {
    return ActivityModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      type: type,
      date: (json['date'] ??
              json['referral_date'] ??
              json['cnote_date'] ??
              json['testimonial_date'] ??
              json['meeting_date'] ??
              json['visit_date'] ??
              json['entry_date'] ??
              json['created_at'] ??
              '')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      description: (json['topics_discussed'] ?? json['details'] ?? json['content'] ?? json['topic'] ?? json['category'] ?? json['description'] ?? '').toString(),
      counterpartName: (json['partner_name'] ?? json['met_with_name'] ?? json['received_by_name'] ?? json['to_member_name'] ?? json['client_name'] ?? json['visitor_name'] ?? json['member_name'] ?? '').toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      rawJson: json,
    );
  }
}
