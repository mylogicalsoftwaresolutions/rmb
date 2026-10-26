class MeetingModel {
  final int id;
  final String title;
  final String date;
  final String time;
  final String location;
  final String status;
  final int attendees;

  MeetingModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.status,
    required this.attendees,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['meeting_title'] ?? json['event_name'] ?? 'Untitled',
      date: json['date'] ?? json['meeting_date'] ?? json['event_date'] ?? '',
      time: json['time'] ??
          json['meeting_time'] ??
          json['event_time'] ??
          json['start_time'] ??
          '',
      location: json['location'] ?? json['venue'] ?? '',
      status: json['status'] ?? '',
      attendees: json['attendees'] ?? 0,
    );
  }
}
