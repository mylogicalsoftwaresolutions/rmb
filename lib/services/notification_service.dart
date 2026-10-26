import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  static const String _localPushKey = 'local_push_notifications';
  static const String _cachedRemoteKey = 'cached_remote_notifications_json';

  static Future<String> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.get('user_id') ??
        prefs.get('id') ??
        prefs.get('member_id') ??
        prefs.get('login_user_id');
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    return (await ApiClient.getUserId()).trim();
  }

  static String _formatNow() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Saves an incoming FCM push notification to local device storage so it
  /// is always visible on the Notifications screen even if the backend database
  /// has not received or inserted the row.
  static Future<void> saveLocalNotification({
    required String title,
    required String message,
    String type = 'push',
    String link = '',
  }) async {
    final cleanTitle = title.trim();
    final cleanMessage = message.trim();
    if (cleanTitle.isEmpty && cleanMessage.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localPushKey) ?? [];
      final list = <Map<String, dynamic>>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) list.add(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }

      // De-duplicate if the most recent item is identical
      if (list.isNotEmpty) {
        final first = list.first;
        if (first['title'] == cleanTitle && first['message'] == cleanMessage) {
          return;
        }
      }

      final newItem = {
        'id': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'title': cleanTitle.isNotEmpty ? cleanTitle : 'Notification',
        'message': cleanMessage.isNotEmpty ? cleanMessage : cleanTitle,
        'status': 'unread',
        'created_at': _formatNow(),
        'type': type,
        'link': link,
        'is_read': 0,
      };

      list.insert(0, newItem);
      // Keep up to 50 notifications in local history
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }

      final encoded = list.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(_localPushKey, encoded);
      debugPrint('[NotificationService] Saved push notification locally: $cleanTitle');
    } catch (e) {
      debugPrint('[NotificationService] Error saving local notification: $e');
    }
  }

  /// Retrieves notifications stored locally on device.
  static Future<List<NotificationModel>> getLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localPushKey) ?? [];
      final result = <NotificationModel>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            result.add(NotificationModel.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {}
      }
      return result;
    } catch (e) {
      debugPrint('[NotificationService] Error loading local notifications: $e');
      return [];
    }
  }

  /// Retrieves cached remote notifications from device storage so notifications
  /// are available instantly without delay or network errors.
  static Future<List<NotificationModel>> getCachedRemoteNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedRemoteKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[NotificationService] Error loading cached remote notifications: $e');
      return [];
    }
  }

  static Future<void> _cacheRemoteNotifications(List<NotificationModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((n) => n.toJson()).toList();
      await prefs.setString(_cachedRemoteKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[NotificationService] Error caching remote notifications: $e');
    }
  }

  /// Deployed notifications.php versions wrap the records differently
  /// (`data`, `notifications`, or a map keyed by notification id). The unread
  /// count can still be returned correctly in those responses, which used to
  /// play a sound while leaving the on-screen list empty.
  static List<dynamic> _notificationRows(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is! Map) return const [];

    final map = Map<String, dynamic>.from(value);
    const collectionKeys = [
      'notifications',
      'notification',
      'notification_list',
      'notification_data',
      'items',
      'list',
      'results',
      'data',
    ];
    for (final key in collectionKeys) {
      final rows = _notificationRows(map[key]);
      if (rows.isNotEmpty) return rows;
    }

    if (map['id'] != null ||
        map['notification_id'] != null ||
        map['title'] != null ||
        map['notification_title'] != null ||
        map['message'] != null ||
        map['notification_message'] != null) {
      return [map];
    }

    final mapRows = map.values.whereType<Map>().toList();
    if (mapRows.isNotEmpty &&
        mapRows.every((row) =>
            row['id'] != null ||
            row['notification_id'] != null ||
            row['title'] != null ||
            row['notification_title'] != null ||
            row['message'] != null ||
            row['notification_message'] != null)) {
      return mapRows;
    }
    return const [];
  }

  /// Fetches notifications from backend API and combines them with locally
  /// stored push notifications so device push messages and server updates
  /// are always present and visible.
  static Future<Map<String, dynamic>> getNotifications() async {
    final localList = await getLocalNotifications();
    final cachedRemote = await getCachedRemoteNotifications();
    final userId = await _userId();

    List<NotificationModel> apiNotifications = List.from(cachedRemote);

    if (userId.isNotEmpty) {
      dynamic response;
      try {
        response = await ApiClient.get(
          'notifications.php',
          queryParams: {'user_id': userId},
          baseOverride: ApiClient.flutterBaseUrl,
        );
      } catch (e) {
        debugPrint('[NotificationService] flutterBaseUrl fetch failed: $e, trying standard baseUrl');
        try {
          response = await ApiClient.get(
            'notifications.php',
            queryParams: {'user_id': userId},
            baseOverride: ApiClient.baseUrl,
          );
        } catch (e2) {
          debugPrint('[NotificationService] Remote notifications fetch failed on both bases: $e2');
        }
      }

      if (response != null) {
        List<dynamic> rawList = [];
        if (response is Map && response['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(response['data'] as Map);
          rawList = _notificationRows(dataMap);
        } else if (response is Map && response['data'] is List) {
          rawList = List<dynamic>.from(response['data'] as List);
        } else if (response is Map) {
          rawList = _notificationRows(response);
        }

        final freshList = <NotificationModel>[];
        for (final json in rawList) {
          if (json is! Map) continue;
          try {
            final row = Map<String, dynamic>.from(json);
            final nested = row['notification'];
            if (nested is Map) {
              row.addAll(Map<String, dynamic>.from(nested));
            }
            freshList.add(NotificationModel.fromJson(row));
          } catch (_) {}
        }

        if (freshList.isNotEmpty) {
          apiNotifications = freshList;
          unawaited(_cacheRemoteNotifications(freshList));
        }
      }
    }

    // Merge API and local notifications, de-duplicating by unique ID or matching content
    final combined = <NotificationModel>[...localList];
    for (final apiItem in apiNotifications) {
      final alreadyPresent = combined.any((item) {
        if (item.id != 0 && apiItem.id != 0) {
          return item.id == apiItem.id;
        }
        return item.title.trim().toLowerCase() == apiItem.title.trim().toLowerCase() &&
            item.message.trim().toLowerCase() == apiItem.message.trim().toLowerCase() &&
            item.createdAt.trim() == apiItem.createdAt.trim();
      });
      if (!alreadyPresent) {
        combined.add(apiItem);
      }
    }

    // Sort newest first
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final total = combined.length;
    final unread = combined.where((n) => n.status == 'unread').length;

    return {
      'notifications': combined,
      'stats': {'total': total, 'unread': unread},
    };
  }

  /// Marks all notifications as read both locally and on the server.
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localPushKey) ?? [];
      final updated = <String>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            map['status'] = 'read';
            map['is_read'] = 1;
            updated.add(jsonEncode(map));
          }
        } catch (_) {}
      }
      await prefs.setStringList(_localPushKey, updated);
    } catch (_) {}

    final userId = await _userId();
    if (userId.isNotEmpty) {
      try {
        await ApiClient.postFormData('notifications.php', {
          'action': 'mark_read',
          'user_id': userId,
        }, baseOverride: ApiClient.flutterBaseUrl);
      } catch (_) {}
    }
  }

  /// Marks a specific notification as read both locally and on the server.
  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localPushKey) ?? [];
      final updated = <String>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            if (map['id'].toString() == id) {
              map['status'] = 'read';
              map['is_read'] = 1;
            }
            updated.add(jsonEncode(map));
          }
        } catch (_) {}
      }
      await prefs.setStringList(_localPushKey, updated);
    } catch (_) {}

    final userId = await _userId();
    if (userId.isNotEmpty) {
      try {
        await ApiClient.postFormData('notifications.php', {
          'action': 'mark_read',
          'user_id': userId,
          'notification_id': id,
        }, baseOverride: ApiClient.flutterBaseUrl);
      } catch (_) {}
    }
  }

  /// Deletes a notification both locally and from the server.
  static Future<void> deleteNotification(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localPushKey) ?? [];
      final updated = <String>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            if (map['id'].toString() != id) {
              updated.add(jsonEncode(map));
            }
          }
        } catch (_) {}
      }
      await prefs.setStringList(_localPushKey, updated);
    } catch (_) {}

    final userId = await _userId();
    if (userId.isNotEmpty) {
      try {
        await ApiClient.postFormData('notifications.php', {
          'action': 'delete',
          'user_id': userId,
          'notification_id': id,
        }, baseOverride: ApiClient.flutterBaseUrl);
      } catch (_) {}
    }
  }

  /// Asks the trusted API to deliver a referral notification to exactly one
  /// member. FCM credentials and device tokens must remain on the server: a
  /// client-side broadcast could expose those credentials and cannot reliably
  /// target a terminated app.
  ///
  static Future<void> sendReferralToRecipient({
    required String referralId,
    required String recipientUserId,
    required String senderUserId,
    String senderName = '',
  }) async {
    final recipient = recipientUserId.trim();
    final sender = senderUserId.trim();
    if (referralId.trim().isEmpty ||
        recipient.isEmpty ||
        sender.isEmpty ||
        recipient == sender) {
      return;
    }

    final payload = {
      'action': 'send_referral',
      'referral_id': referralId,
      'user_id': sender,
      'recipient_user_id': recipient,
      'sender_user_id': sender,
      if (senderName.isNotEmpty) 'sender_name': senderName,
    };

    try {
      final response = await ApiClient.postFormData(
        'notifications.php',
        payload,
        baseOverride: ApiClient.flutterBaseUrl,
      );
      debugPrint('[push] referral notification sent via flutterBaseUrl: $response');
    } catch (e) {
      debugPrint('[push] referral notification via flutterBaseUrl failed: $e, trying standard baseUrl');
      try {
        final response2 = await ApiClient.postFormData(
          'notifications.php',
          payload,
          baseOverride: ApiClient.baseUrl,
        );
        debugPrint('[push] referral notification sent via standard baseUrl: $response2');
      } catch (e2) {
        debugPrint('[push] referral push notification on standard baseUrl failed: $e2');
      }
    }

    final sName = senderName.trim();
    final message = sName.isNotEmpty
        ? '$sName gave you a new referral.'
        : 'You have received a new referral.';

    await createNotification(
      recipientUserId: recipient,
      senderUserId: sender,
      senderName: sName,
      title: 'New Referral',
      message: message,
      type: 'referral',
      link: 'referrals',
    );

    final currentUserId = await _userId();
    if (currentUserId == recipient) {
      await saveLocalNotification(
        title: 'New Referral',
        message: message,
        type: 'referral',
        link: 'referrals',
      );
    }
  }

  /// Directly creates and persists a notification row to the backend database
  /// with dual fallback (flutterBaseUrl and baseUrl) so it is immediately
  /// visible on both Web and Mobile platforms.
  static Future<void> createNotification({
    required String recipientUserId,
    required String title,
    required String message,
    String senderUserId = '',
    String senderName = '',
    String type = 'r2r',
    String link = '',
  }) async {
    final recipient = recipientUserId.trim();
    if (recipient.isEmpty) return;

    final payload = <String, String>{
      'action': 'create',
      'user_id': recipient,
      'member_id': recipient,
      'recipient_user_id': recipient,
      'title': title,
      'message': message,
      'type': type,
      'link': link,
      'status': 'unread',
      'is_read': '0',
      if (senderUserId.isNotEmpty) 'sender_user_id': senderUserId,
      if (senderUserId.isNotEmpty) 'created_by': senderUserId,
      if (senderName.isNotEmpty) 'sender_name': senderName,
    };

    try {
      await ApiClient.postFormData('notifications.php', payload,
          baseOverride: ApiClient.flutterBaseUrl);
    } catch (_) {
      try {
        await ApiClient.postFormData('notifications.php', payload,
            baseOverride: ApiClient.baseUrl);
      } catch (_) {
        try {
          await ApiClient.postFormData('notifications.php', {
            ...payload,
            'action': 'add',
          }, baseOverride: ApiClient.flutterBaseUrl);
        } catch (_) {}
      }
    }
  }

  /// Asks the trusted API to deliver an R2R meeting push notification to the
  /// partner member with whom the R2R meeting took place, and guarantees
  /// that a persistent notification row is stored in the shared database
  /// so it appears on both Web and Mobile.
  static Future<void> sendR2RToPartner({
    required String r2rId,
    required String partnerUserId,
    required String senderUserId,
    String? senderName,
    String? meetingDate,
    String? location,
    String? topic,
  }) async {
    final recipient = partnerUserId.trim();
    final sender = senderUserId.trim();
    if (recipient.isEmpty || sender.isEmpty || recipient == sender) {
      return;
    }

    final sName = senderName?.trim() ?? '';
    const title = 'New R2R Meeting';
    final descText = (topic != null && topic.trim().isNotEmpty) ? ' Topic: ${topic.trim()}.' : '';
    final locText = (location != null && location.trim().isNotEmpty) ? ' Location: ${location.trim()}.' : '';
    final dateText = (meetingDate != null && meetingDate.trim().isNotEmpty) ? ' Date: ${meetingDate.trim()}.' : '';
    final message = sName.isNotEmpty
        ? '$sName has logged an R2R meeting with you.$dateText$locText$descText'
        : 'A new R2R meeting has been logged with you.$dateText$locText$descText';

    // 1. Deliver FCM notification via action: send_r2r with dual base fallback
    try {
      final response = await ApiClient.postFormData('notifications.php', {
        'action': 'send_r2r',
        'r2r_id': r2rId,
        'user_id': sender,
        'recipient_user_id': recipient,
        'partner_user_id': recipient,
        'sender_user_id': sender,
        if (sName.isNotEmpty) 'sender_name': sName,
        if (meetingDate != null && meetingDate.isNotEmpty) 'date': meetingDate,
        if (location != null && location.isNotEmpty) 'location': location,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        'title': title,
        'message': message,
      }, baseOverride: ApiClient.flutterBaseUrl);

      debugPrint('[push] R2R notification response from flutterBaseUrl: $response');
    } catch (e) {
      debugPrint('[push] R2R push notification to flutterBaseUrl failed: $e, trying standard baseUrl');
      try {
        final response2 = await ApiClient.postFormData('notifications.php', {
          'action': 'send_r2r',
          'r2r_id': r2rId,
          'user_id': sender,
          'recipient_user_id': recipient,
          'partner_user_id': recipient,
          'sender_user_id': sender,
          if (sName.isNotEmpty) 'sender_name': sName,
          if (meetingDate != null && meetingDate.isNotEmpty) 'date': meetingDate,
          if (location != null && location.isNotEmpty) 'location': location,
          if (topic != null && topic.isNotEmpty) 'topic': topic,
          'title': title,
          'message': message,
        }, baseOverride: ApiClient.baseUrl);
        debugPrint('[push] R2R notification response from standard baseUrl: $response2');
      } catch (e2) {
        debugPrint('[push] R2R push notification on standard baseUrl failed: $e2');
      }
    }

    // 2. Guarantee that a persistent notification row exists in the database
    // for the partner member on both Web and Mobile.
    await createNotification(
      recipientUserId: recipient,
      senderUserId: sender,
      senderName: sName,
      title: title,
      message: message,
      type: 'r2r',
      link: 'r2r',
    );

    // 3. Cache locally on device if current user is the recipient
    final currentUserId = await _userId();
    if (currentUserId == recipient) {
      await saveLocalNotification(
        title: title,
        message: message,
        type: 'r2r',
        link: 'r2r',
      );
    }
  }

  /// Delivers a C-Note push notification to the receiving member and ensures
  /// a persistent notification is saved in the database for both Web and Mobile.
  static Future<void> sendCNoteToRecipient({
    required String cnoteId,
    required String recipientUserId,
    required String senderUserId,
    String? senderName,
    String? amount,
    String? company,
  }) async {
    final recipient = recipientUserId.trim();
    final sender = senderUserId.trim();
    if (recipient.isEmpty || sender.isEmpty || recipient == sender) {
      return;
    }

    final sName = senderName?.trim() ?? '';
    const title = 'New Business C-Note';
    final amt = amount?.trim() ?? '';
    final amtText = amt.isNotEmpty ? ' of Rs $amt' : '';
    final comp = company?.trim() ?? '';
    final compText = comp.isNotEmpty ? ' ($comp)' : '';

    final message = sName.isNotEmpty
        ? '$sName gave you a C-Note$amtText$compText.'
        : 'You received a new C-Note$amtText$compText.';

    final effectiveCNoteId = cnoteId.trim().isNotEmpty ? cnoteId.trim() : '0';

    final payload = <String, String>{
      'action': 'send_cnote',
      'cnote_id': effectiveCNoteId,
      'user_id': sender,
      'recipient_user_id': recipient,
      'received_by': recipient,
      'to_member_id': recipient,
      'sender_user_id': sender,
      if (sName.isNotEmpty) 'sender_name': sName,
      if (amt.isNotEmpty) 'amount': amt,
      if (comp.isNotEmpty) 'company': comp,
      'title': title,
      'message': message,
    };

    // 1. Deliver FCM notification via action: send_cnote with dual base fallback
    try {
      final response = await ApiClient.postFormData(
        'notifications.php',
        payload,
        baseOverride: ApiClient.flutterBaseUrl,
      );
      debugPrint('[push] C-Note notification response from flutterBaseUrl: $response');
    } catch (e) {
      debugPrint('[push] C-Note push to flutterBaseUrl failed: $e, trying standard baseUrl');
      try {
        final response2 = await ApiClient.postFormData(
          'notifications.php',
          payload,
          baseOverride: ApiClient.baseUrl,
        );
        debugPrint('[push] C-Note notification response from standard baseUrl: $response2');
      } catch (e2) {
        debugPrint('[push] C-Note push notification on standard baseUrl failed: $e2');
      }
    }

    // 2. Guarantee database record for Web and Mobile notifications screen
    await createNotification(
      recipientUserId: recipient,
      senderUserId: sender,
      senderName: sName,
      title: title,
      message: message,
      type: 'cnote',
      link: 'cnotes',
    );

    // 3. Cache locally on device if current user is the recipient
    final currentUserId = await _userId();
    if (currentUserId == recipient) {
      await saveLocalNotification(
        title: title,
        message: message,
        type: 'cnote',
        link: 'cnotes',
      );
    }
  }

  /// Delivers a Testimonial push notification to the receiving member and ensures
  /// a persistent notification is saved in the database for both Web and Mobile.
  static Future<void> sendTestimonialToRecipient({
    required String testimonialId,
    required String recipientUserId,
    required String senderUserId,
    String? senderName,
    String? testimonialTitle,
  }) async {
    final recipient = recipientUserId.trim();
    final sender = senderUserId.trim();
    if (recipient.isEmpty || sender.isEmpty || recipient == sender) {
      return;
    }

    final sName = senderName?.trim() ?? '';
    const title = 'New Testimonial';
    final tTitle = testimonialTitle?.trim() ?? '';
    final tTitleText = tTitle.isNotEmpty ? ': "$tTitle"' : '.';

    final message = sName.isNotEmpty
        ? '$sName gave you a testimonial$tTitleText'
        : 'You have received a new testimonial$tTitleText';

    // 1. Deliver FCM notification via action: send_testimonial with dual base fallback
    try {
      final response = await ApiClient.postFormData('notifications.php', {
        'action': 'send_testimonial',
        'testimonial_id': testimonialId,
        'user_id': sender,
        'recipient_user_id': recipient,
        'received_by': recipient,
        'to_member_id': recipient,
        'sender_user_id': sender,
        if (sName.isNotEmpty) 'sender_name': sName,
        if (tTitle.isNotEmpty) 'title': tTitle,
        'notification_title': title,
        'message': message,
      }, baseOverride: ApiClient.flutterBaseUrl);

      debugPrint('[push] Testimonial notification response from flutterBaseUrl: $response');
    } catch (e) {
      debugPrint('[push] Testimonial push to flutterBaseUrl failed: $e, trying standard baseUrl');
      try {
        final response2 = await ApiClient.postFormData('notifications.php', {
          'action': 'send_testimonial',
          'testimonial_id': testimonialId,
          'user_id': sender,
          'recipient_user_id': recipient,
          'received_by': recipient,
          'to_member_id': recipient,
          'sender_user_id': sender,
          if (sName.isNotEmpty) 'sender_name': sName,
          if (tTitle.isNotEmpty) 'title': tTitle,
          'notification_title': title,
          'message': message,
        }, baseOverride: ApiClient.baseUrl);
        debugPrint('[push] Testimonial notification response from standard baseUrl: $response2');
      } catch (e2) {
        debugPrint('[push] Testimonial push notification on standard baseUrl failed: $e2');
      }
    }

    // 2. Guarantee database record for Web and Mobile notifications screen
    await createNotification(
      recipientUserId: recipient,
      senderUserId: sender,
      senderName: sName,
      title: title,
      message: message,
      type: 'testimonial',
      link: 'testimonials',
    );

    // 3. Cache locally on device if current user is the recipient
    final currentUserId = await _userId();
    if (currentUserId == recipient) {
      await saveLocalNotification(
        title: title,
        message: message,
        type: 'testimonial',
        link: 'testimonials',
      );
    }
  }
}
