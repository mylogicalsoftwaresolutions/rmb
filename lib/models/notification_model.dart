class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String status;
  final String createdAt;
  final String type;
  final String link;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    this.type = '',
    this.link = '',
  });

  static String _firstText(
    Iterable<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return fallback;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final sources = <Map<String, dynamic>>[json];
    for (final key in ['notification', 'data', 'payload', 'item', 'row', 'result']) {
      final nested = json[key];
      if (nested is Map) {
        sources.add(Map<String, dynamic>.from(nested));
      }
    }

    final rawIsRead = json['is_read'] ?? json['read_status'] ?? json['isRead'];
    final rawStatus = (json['status'] ?? json['read_state'])?.toString().trim().toLowerCase();
    final bool isRead = rawIsRead == 1 ||
        rawIsRead == true ||
        rawIsRead == '1' ||
        rawStatus == 'read' ||
        rawStatus == '1';
    final status = isRead ? 'read' : 'unread';

    final resolvedTitle = _firstText(sources, [
      'title',
      'notification_title',
      'subject',
      'heading',
      'name',
    ], fallback: 'Notification');

    final resolvedMessage = _firstText(sources, [
      'message',
      'notification_message',
      'notification_body',
      'message_body',
      'message_text',
      'body',
      'content',
      'description',
      'details',
      'text',
      'msg',
      'note',
      'notes',
      'alert',
      'remark',
      'remarks',
      'comment',
      'comments',
      'info',
      'reason',
    ], fallback: '');

    return NotificationModel(
      id: int.tryParse((json['id'] ?? json['notification_id'] ?? 0).toString()) ??
          0,
      title: resolvedTitle,
      // If the message field is blank or missing, fall back to the title
      // so a message is always visible on the Notification page.
      message: resolvedMessage.isNotEmpty ? resolvedMessage : resolvedTitle,
      status: status,
      createdAt: _firstText(sources, [
        'created_at',
        'notification_date',
        'date',
        'sent_at',
        'timestamp',
        'time',
      ]),
      type: _firstText(sources, ['type', 'notification_type', 'category']),
      link: _firstText(sources, ['link', 'url', 'action_url']),
    );
  }

  /// A database timestamp is not useful as raw text in the notification list.
  /// Naive MySQL values are treated as the device's local time; ISO/UTC values
  /// are converted to local time before display.
  String get displayDateTime {
    final source = createdAt.trim();
    if (source.isEmpty) return 'Recent';
    final parsed = DateTime.tryParse(source.replaceFirst(' ', 'T'));
    if (parsed == null) return source;
    final date = parsed.isUtc ? parsed.toLocal() : parsed;
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} '
        '${date.year}, $hour:$minute $amPm';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'status': status,
    'created_at': createdAt,
    'type': type,
    'link': link,
    'is_read': status == 'read' ? 1 : 0,
  };
}
