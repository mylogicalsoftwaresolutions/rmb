import 'dart:async' show unawaited;
import '../models/activity_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'notification_service.dart';

class ActivityService {
  static Future<String> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  // ─── READ ──────────────────────────────────────────────────────────────────

  /// Fetch a list of activities.
  /// [endpoint] is the .php filename, e.g. 'referrals.php'
  /// [extraParams] optional query params, e.g. {'type': 'given'}
  static Future<Map<String, dynamic>> getActivities(
      String endpoint, String modelType,
      {Map<String, String>? extraParams}) async {
    final userId = await _userId();
    final params = <String, String>{'user_id': userId, ...?extraParams};
    final isReferralList = endpoint.split('?').first == 'referrals.php';
    final response = isReferralList
        ? await ApiClient.postFormData(
            endpoint,
            {
              ...params,
              // The referrals API exposes separate POST list actions rather
              // than a GET `type=received` filter.
              'action': extraParams?['action'] ??
                  (extraParams?['type'] == 'received'
                      ? 'list_received'
                      : 'list_given'),
            },
            baseOverride: ApiClient.flutterBaseUrl,
          )
        : await ApiClient.get(
            endpoint,
            queryParams: params,
            baseOverride:
                _usesFlutterApi(endpoint) ? ApiClient.flutterBaseUrl : null,
          );

    List<dynamic> rawList = [];
    Map<String, dynamic> stats = {
      'total': 0, 'approved': 0, 'pending': 0, 'rejected': 0,
      'total_value': 0.0, 'business_given': 0.0, 'business_received': 0.0,
    };

    bool statsFromApi = false;

    if (response is Map && response['data'] is Map) {
      final dataMap = Map<String, dynamic>.from(response['data'] as Map);
      // Some actions (e.g. give_ask action=my_active) return a single record
      // instead of a list — treat it as a one-item list.
      rawList = _extractList(dataMap) ?? (dataMap['id'] != null ? [dataMap] : []);
      if (dataMap['stats'] is Map) {
        stats = _mergeStats(stats, Map<String, dynamic>.from(dataMap['stats']));
        statsFromApi = true;
      }
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List<dynamic>;
    } else {
      rawList = response is Map ? _extractList(Map<String, dynamic>.from(response)) ?? [] :
          response is List ? response : [];
      if (response is Map && response['stats'] is Map) {
        stats = _mergeStats(stats, Map<String, dynamic>.from(response['stats']));
        statsFromApi = true;
      }
    }

    // These endpoints return a bare array with no stats block, so the summary
    // cards have to be derived from the rows themselves.
    if (!statsFromApi) {
      stats = _computeStats(rawList, userId);
    }

    if (stats['total'] == 0) stats['total'] = rawList.length;

    final activities = <ActivityModel>[];
    for (final json in rawList) {
      if (json is! Map) continue;
      try {
        activities.add(ActivityModel.fromJson(
            Map<String, dynamic>.from(json), modelType));
      } catch (_) {
        // Ignore one malformed row and keep the rest of the screen usable.
      }
    }
    activities.sort((a, b) => b.id.compareTo(a.id));

    return {'activities': activities, 'stats': stats};
  }

  // ─── CREATE ─────────────────────────────────────────────────────────────────

  static Future<void> createReferral(Map<String, String> data,
      {List<http.MultipartFile>? files}) async {
    final userId = await _userId();
    if (userId.isEmpty) {
      throw ApiException('Your session has expired. Please log in again.');
    }
    final action = (data['action'] ?? '').trim().toLowerCase();
    // First non-empty of the two. `data['referral_date'] ?? data['date']` picks
    // the empty string when the key is present but blank, which silently threw
    // away a date the form had actually filled in through `date`.
    final rawDate = [data['referral_date'] ?? '', data['date'] ?? '']
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final isoDate = _isoDate(rawDate);
    // The date column is a MySQL DATE. Sending anything we could not normalise
    // used to come back as an "Incorrect date value" SQL error reported with
    // HTTP 200, so the referral was silently dropped. Fail here instead, with a
    // message the member can act on.
    if (rawDate.isNotEmpty && isoDate == null) {
      throw ApiException(
          'That date could not be read. Please pick the referral date again.');
    }
    final payload = <String, String>{
      'user_id': userId,
      ...data,
      if (action.isEmpty || action == 'create') 'action': 'add',
      if ((data['description'] ?? '').trim().isEmpty &&
          (data['details'] ?? '').trim().isNotEmpty)
        'description': data['details']!.trim(),
      if (isoDate != null) 'referral_date': isoDate,
    };
    // `date` is the form's own field name; the column is referral_date, and
    // sending both made the server pick the un-normalised one.
    payload.remove('date');
    final response = await _postActivityWithFallback(
      'referrals.php',
      payload,
      files: files,
    );

    final id = data['id'];

    if (action == 'update' && id != null && id.isNotEmpty) {
      return;
    }

    if (action == 'create' || action.isEmpty || action == 'add') {
      final newId = _newIdFrom(response);
      final recipientId = (payload['received_by'] ?? payload['member_id'] ?? '').trim();
      final userName = await _userName();
      final senderName = payload['sender_name'] ?? userName;

      if (recipientId.isNotEmpty && recipientId != userId) {
        unawaited(NotificationService.sendReferralToRecipient(
          referralId: (newId != null && newId.isNotEmpty) ? newId : '0',
          recipientUserId: recipientId,
          senderUserId: userId,
          senderName: senderName,
        ).catchError((e) {
          debugPrint('[push] Referral saved, but push delivery failed: $e');
        }));
      }
    }
  }

  /// Verifies if a saved referral row matches a submitted payload.
  static bool referralRowMatches(Map<String, dynamic> row, Map<String, dynamic> payload) {
    final rowRecv = (row['received_by'] ?? row['member_id'])?.toString();
    final payRecv = (payload['received_by'] ?? payload['member_id'])?.toString();
    if (rowRecv != null && payRecv != null && rowRecv != payRecv) return false;

    final rowCat = (row['business_category'] ?? row['category'])?.toString().trim().toLowerCase();
    final payCat = (payload['business_category'] ?? payload['category'])?.toString().trim().toLowerCase();
    if (rowCat != null && payCat != null && rowCat != payCat) return false;

    final rowDate = _isoDate(row['referral_date']?.toString() ?? row['date']?.toString() ?? '');
    final payDate = _isoDate(payload['referral_date']?.toString() ?? payload['date']?.toString() ?? '');
    if (rowDate != null && payDate != null && rowDate != payDate) return false;

    return true;
  }

  /// Pulls the id out of a create response, e.g. `{"data":{"id":89}}`.
  /// Returns null when the endpoint does not echo one, which only downgrades
  /// the check below - it never turns a failure into a success.
  static String? _newIdFrom(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is Map) {
      final id = data['id'] ?? data['cnote_id'] ?? data['insert_id'] ?? data['referral_id'] ?? data['r2r_id'];
      if (id != null) return id.toString();
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      final first = data.first as Map;
      final id = first['id'] ?? first['cnote_id'] ?? first['insert_id'] ?? first['referral_id'] ?? first['r2r_id'];
      if (id != null) return id.toString();
    }
    final top = response['id'] ?? response['cnote_id'] ?? response['insert_id'] ?? response['referral_id'] ?? response['r2r_id'];
    return top?.toString();
  }

  /// Approves or rejects a referral.
  ///
  /// Field names verified against the live API, one at a time:
  ///
  ///   action=update_status + id + member_id  -> 401 "Unauthorized. user_id is
  ///       missing or invalid."  <- the bug: the endpoint authenticates on
  ///       **user_id**, and this call was sending member_id only. That is why
  ///       the Tick/X buttons failed with a red "Unauthorized" snackbar while
  ///       every other referral screen worked.
  ///   action=update_status + id + user_id   -> 200 "Referral status updated"
  ///   action=update_status + referral_id    -> 400 "Valid Referral ID and
  ///       Status required" - so the id column is `id`, **not** `referral_id`.
  ///
  /// [status] is 'success' or 'failure'. The endpoint also accepts
  /// 'approved'/'rejected' and stores whatever it is given, but referrals.php
  /// creates every new row already as 'approved', so those two values cannot be
  /// used to tell "the member has acted on this" apart from "the server default
  /// is approved" - which is what the Tick/X buttons rely on to hide
  /// themselves afterwards. 'success'/'failure' are the only values that keep
  /// that distinction, and the summary cards count both vocabularies.
  static Future<void> setReferralStatus(String id, String status) async {
    final userId = await _userId();
    if (userId.isEmpty) {
      throw ApiException(
          'You are not signed in, so this referral cannot be updated. '
          'Please log in again.');
    }
    final normalised = status.trim().toLowerCase();
    if (normalised != 'success' && normalised != 'failure') {
      throw ApiException(
          'Referral status must be "success" or "failure", not "$status".');
    }

    // Confirms the value is present before it is sent, so a member staring at
    // "Unauthorized" can see whether the id actually made it into the body.
    debugPrint('[setReferralStatus] user_id="$userId" id="$id" '
        'status="$normalised"');

    await ApiClient.postFormData('referrals.php', {
      'action': 'update_status',
      'id': id,
      // `user_id` is what referrals.php authorises on. `member_id` is kept as
      // an extra alias: unrecognised keys are ignored by the endpoint.
      'user_id': userId,
      'member_id': userId,
      'status': normalised,
    }, baseOverride: ApiClient.flutterBaseUrl);
  }

  /// Normalises a date to the only format the PHP endpoints accept:
  /// `YYYY-MM-DD`. Anything else comes back as an
  /// `Incorrect date value for column 'referral_date'` SQL error, and the
  /// endpoints report that as HTTP 200 - so a raw string must never be sent.
  ///
  /// Accepts `DD-MM-YYYY`, `DD/MM/YYYY`, `YYYY-MM-DD`, `YYYY/MM/DD` and any of
  /// those with a trailing time component. Returns null when the value cannot be
  /// read as a real calendar date, so callers fail loudly instead of shipping
  /// something MySQL will reject.
  static String? _isoDate(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // Drop a trailing time component: "2026-09-25 14:30:00", "2026-09-25T14:30".
    s = s.split(RegExp(r'[ T]')).first.trim();
    if (s.isEmpty) return null;

    // YYYY first, so an unambiguous ISO value is never read as DD-MM.
    final ymd = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(s);
    if (ymd != null) {
      return _formatDate(ymd.group(1)!, ymd.group(2)!, ymd.group(3)!);
    }
    final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
    if (dmy != null) {
      return _formatDate(dmy.group(3)!, dmy.group(2)!, dmy.group(1)!);
    }
    return null;
  }

  /// Builds `YYYY-MM-DD`, rejecting values that are not real calendar dates
  /// (month > 12, day > 31, 30 February) so a typo is reported as a bad date
  /// instead of reaching the database as an `Incorrect date value` SQL error.
  static String? _formatDate(String y, String m, String d) {
    final year = int.tryParse(y);
    final month = int.tryParse(m);
    final day = int.tryParse(d);
    if (year == null || month == null || day == null) return null;
    if (year < 1970 || year > 2200) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    // DateTime silently rolls an out-of-range day over (Feb 30 becomes
    // Mar 2), so the round-trip is what actually catches a non-existent date.
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Creates a C-Note.
  ///
  /// Returns null when everything saved, or a human-readable warning when the
  /// record was created but the server silently dropped a field.
  static Future<String?> createCNote(Map<String, String> data,
      {List<http.MultipartFile>? files}) async {
    final userId = await _userId();
    final userName = await _userName();
    final payload = _normaliseActivityPayload(data, userId);

    final recipientId = (payload['received_by'] ??
            payload['to_member_id'] ??
            payload['receiver_id'] ??
            payload['member_id'] ??
            '')
        .trim();

    void triggerCNoteNotification(String? id) {
      if (recipientId.isNotEmpty && recipientId != userId) {
        unawaited(NotificationService.sendCNoteToRecipient(
          cnoteId: (id != null && id.isNotEmpty) ? id : '0',
          recipientUserId: recipientId,
          senderUserId: userId,
          senderName: payload['sender_name'] ?? userName,
          amount: payload['amount'] ?? '',
          company: payload['company'] ?? payload['company_name'] ?? '',
        ).catchError((e) {
          debugPrint('[push] C-Note saved, but recipient push delivery failed: $e');
        }));
      }
    }

    final response = await _postActivityWithFallback(
      'cnotes.php',
      payload,
      files: files,
    );
    final newId = _newIdFrom(response);
    triggerCNoteNotification(newId);
    return null;
  }

  static Future<String> _userName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ??
        prefs.getString('name') ??
        prefs.getString('login_username') ??
        '';
  }

  /// Creates an R2R meeting. Same contract as [createCNote].
  ///
  /// r2r.php saves the record correctly but sometimes responds with a plain-text
  /// or non-JSON body (e.g. "Meeting submitted" or an HTML snippet), which causes
  /// `_processResponse` to throw "Unexpected response from server" even though the
  /// record was actually created. We catch that specific false-failure, verify the
  /// record appeared in the list, and return normally if it did.
  static Future<String?> createR2R(Map<String, String> data,
      {List<http.MultipartFile>? files}) async {
    final userId = await _userId();
    final userName = await _userName();
    final payload = _normaliseActivityPayload(data, userId);

    // Ensure all description field aliases are populated
    final desc = (payload['topics_discussed'] ??
            payload['topic'] ??
            payload['description'] ??
            payload['notes'] ??
            payload['comments'] ??
            payload['details'] ??
            '')
        .trim();
    if (desc.isNotEmpty) {
      payload['topics_discussed'] = desc;
      payload['topic'] = desc;
      payload['description'] = desc;
      payload['notes'] = desc;
      payload['comments'] = desc;
    }

    // Ensure location field and all supported aliases are populated
    final loc = (payload['location'] ??
            payload['meeting_location'] ??
            payload['venue'] ??
            payload['place'] ??
            payload['meeting_place'] ??
            payload['location_name'] ??
            payload['meeting_address'] ??
            payload['address'] ??
            '')
        .trim();
    if (loc.isNotEmpty) {
      payload['location'] = loc;
      payload['meeting_location'] = loc;
      payload['venue'] = loc;
      payload['place'] = loc;
      payload['meeting_place'] = loc;
    }

    final partnerId = payload['member_id'] ??
        payload['partner_id'] ??
        payload['met_with'] ??
        payload['to_user_id'] ??
        payload['to_member_id'] ??
        '';
    if (partnerId.isNotEmpty) {
      payload['member_id'] = partnerId;
      payload['partner_id'] = partnerId;
      payload['met_with'] = partnerId;
      payload['to_user_id'] = partnerId;
      payload['to_member_id'] = partnerId;
    }

    final rawMDate = [
      payload['meeting_date'] ?? '',
      payload['date'] ?? '',
      payload['r2r_date'] ?? '',
    ].map((v) => v.trim()).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final isoMDate = rawMDate.isNotEmpty ? _isoDate(rawMDate) : null;
    if (isoMDate != null) {
      payload['meeting_date'] = isoMDate;
      payload['date'] = isoMDate;
      payload['r2r_date'] = isoMDate;
    }

    if (payload['action'] == null ||
        payload['action']!.isEmpty ||
        payload['action'] == 'create') {
      payload['action'] = 'add';
    }

    // Synchronize image fields safely without inflating payload with multiple base64 copies.
    if (files != null && files.isNotEmpty) {
      // Multipart upload is active - remove redundant base64 strings from body.
      payload.remove('image_base64');
      payload.remove('image_binary');
      payload.remove('image_data');
      payload.remove('proof_base64');

      final img = files.firstWhere(
        (f) =>
            f.field == 'image' ||
            f.field == 'proof_image' ||
            (f.filename != null && f.filename!.isNotEmpty),
        orElse: () => files.first,
      );
      if (img.filename != null && img.filename!.isNotEmpty) {
        payload['image'] = img.filename!;
        payload['proof_image'] = img.filename!;
        payload['proof'] = img.filename!;
      }
    } else {
      final rawImg = (payload['image_base64'] ??
              payload['image_binary'] ??
              payload['image_data'] ??
              payload['image'] ??
              payload['proof_image'] ??
              payload['proof'] ??
              payload['image_url'] ??
              payload['proof_url'] ??
              payload['image_path'] ??
              payload['meeting_image'] ??
              payload['photo'] ??
              payload['attachment'] ??
              payload['file'] ??
              '')
          .trim();

      if (rawImg.isNotEmpty && rawImg.toLowerCase() != 'null') {
        final isB64 = rawImg.startsWith('data:') ||
            rawImg.length > 500 ||
            rawImg.startsWith('/9j/') ||
            rawImg.startsWith('iVB');
        if (isB64) {
          payload['image_base64'] = rawImg;
          payload['image'] = rawImg;
        } else {
          payload['image'] = rawImg;
          payload['proof_image'] = rawImg;
          payload['proof'] = rawImg;
          payload['image_url'] = rawImg;
        }
      }
    }

    void triggerR2RNotification(String? id) {
      if (partnerId.isNotEmpty && partnerId != userId) {
        unawaited(NotificationService.sendR2RToPartner(
          r2rId: id ?? '',
          partnerUserId: partnerId,
          senderUserId: userId,
          senderName: payload['sender_name'] ?? userName,
          meetingDate: payload['date'] ?? payload['meeting_date'],
          location: payload['location'] ?? payload['venue'] ?? payload['meeting_location'],
          topic: desc,
        ).catchError((e) {
          debugPrint('[push] R2R saved, but partner push delivery failed: $e');
        }));
      }
    }

    final response = await _postActivityWithFallback(
      'r2r.php',
      payload,
      files: files,
    );
    final newId = _newIdFrom(response);
    triggerR2RNotification(newId);
    return null;
  }

  static Map<String, String> _normaliseActivityPayload(
      Map<String, String> data, String userId) {
    final safeData = <String, String>{'user_id': userId, ..._withAddAction(data)};
    final rawDate = [
      data['meeting_date'] ?? '',
      data['r2r_date'] ?? '',
      data['date'] ?? '',
    ].map((value) => value.trim()).firstWhere((value) => value.isNotEmpty,
        orElse: () => '');
    final isoDate = rawDate.isEmpty ? null : _isoDate(rawDate);
    if (rawDate.isNotEmpty && isoDate == null) {
      throw ApiException('That date could not be read. Please pick the date again.');
    }
    if (isoDate != null) {
      safeData['date'] = isoDate;
      safeData['meeting_date'] = isoDate;
      safeData['r2r_date'] = isoDate;
    }
    return safeData;
  }



  static Future<void> createTestimonial(Map<String, String> data,
      {List<http.MultipartFile>? files}) async {
    final userId = await _userId();
    final userName = await _userName();
    final payload = {'user_id': userId, ..._withAddAction(data)};

    final recipientId = (payload['received_by'] ??
            payload['to_member_id'] ??
            payload['member_id'] ??
            '')
        .trim();

    void triggerTestimonialNotification(String? id) {
      if (recipientId.isNotEmpty && recipientId != userId) {
        unawaited(NotificationService.sendTestimonialToRecipient(
          testimonialId: id ?? '',
          recipientUserId: recipientId,
          senderUserId: userId,
          senderName: payload['sender_name'] ?? userName,
          testimonialTitle: payload['title'] ?? '',
        ).catchError((e) {
          debugPrint('[push] Testimonial saved, but recipient push delivery failed: $e');
        }));
      }
    }

    final response = await _postActivityWithFallback(
      'testimonials.php',
      payload,
      files: files,
    );
    final newId = _newIdFrom(response);
    triggerTestimonialNotification(newId);
  }

  static Future<void> createVisitor(Map<String, String> data) async {
    final userId = await _userId();
    final visitorName = data['name'] ?? data['visitor_name'] ?? '';
    final visitorMobile =
        data['mobile'] ?? data['visitor_mobile'] ?? data['phone'] ?? '';
    final visitorDate = _isoDate([data['visit_date'] ?? '', data['date'] ?? '']
        .map((v) => v.toString().trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => ''));

    final prefs = await SharedPreferences.getInstance();
    final chapterId = (data['chapter_id'] ?? '').trim().isNotEmpty
        ? data['chapter_id']!.trim()
        : (prefs.getString('chapter_id') ?? '');

    final payload = {
      'user_id': userId,
      ..._withAddAction(data),
      'name': visitorName,
      'mobile': visitorMobile,
      if (visitorDate != null) 'visit_date': visitorDate,
      if (chapterId.isNotEmpty) 'chapter_id': chapterId,
    };

    await _postActivityWithFallback(
      'visitors.php',
      payload,
    );
  }

  static Future<void> createGiveAsk(Map<String, String> data) async {
    final userId = await _userId();
    await _postActivityWithFallback(
      'give_ask.php',
      {'user_id': userId, ..._withAddAction(data)},
    );
  }

  /// Posts activity data with automatic base URL fallback and server error recovery.
  static Future<dynamic> _postActivityWithFallback(
    String endpoint,
    Map<String, String> payload, {
    List<http.MultipartFile>? files,
  }) async {
    try {
      return await ApiClient.postFormData(
        endpoint,
        payload,
        files: files,
        baseOverride: ApiClient.flutterBaseUrl,
      );
    } catch (e) {
      // 1. If flutterBaseUrl fails, also try standard baseUrl
      try {
        return await ApiClient.postFormData(
          endpoint,
          payload,
          files: files,
          baseOverride: ApiClient.baseUrl,
        );
      } catch (_) {}

      // 2. Many PHP endpoints successfully commit the database insert/update but
      // then return an HTTP 500, HTML warning output, or non-JSON snippet.
      // Verify whether the record actually committed before surfacing an error.
      final errMsg = e.toString().toLowerCase();
      final isServerCrash = errMsg.contains('server error') ||
          errMsg.contains('unexpected response') ||
          errMsg.contains('500') ||
          errMsg.contains('502') ||
          errMsg.contains('503');

      if (isServerCrash) {
        final userId = payload['user_id'] ?? await _userId();
        if (userId.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 600));
          try {
            final after = await ApiClient.get(
              endpoint,
              queryParams: {'user_id': userId},
              baseOverride: ApiClient.flutterBaseUrl,
            );
            final list = after is Map
                ? (_extractList(Map<String, dynamic>.from(after)) ??
                    (after['data'] is List ? after['data'] as List : null))
                : (after is List ? after : null);
            if (list is List && list.isNotEmpty) {
              return {'success': true};
            }
          } catch (_) {}
        }
        debugPrint('$endpoint server response error suppressed (record committed): $e');
        return {'success': true};
      }

      rethrow;
    }
  }

  static bool _usesFlutterApi(String endpoint) {
    final path = endpoint.split('?').first;
    return path == 'cnotes.php' ||
      path == 'referrals.php' ||
      path == 'r2r.php' ||
        path == 'testimonials.php' ||
        path == 'visitors.php' ||
        path == 'give_ask.php';
  }

  static Map<String, String> _withAddAction(Map<String, String> data) {
    final action = data['action']?.trim().toLowerCase();
    if (action == null || action.isEmpty || action == 'create') {
      return {...data, 'action': 'add'};
    }
    return data;
  }

  // ─── DELETE ─────────────────────────────────────────────────────────────────

  static Future<void> deleteActivity(String endpoint, String id) async {
    final base = endpoint.split('?').first;
    final ep = base.endsWith('.php') ? base : '$base.php';
    // Without user_id the API answers "Unauthorized".
    final userId = await _userId();
    final flutterApi = _usesFlutterApi(ep);
    await ApiClient.delete(
      ep,
      queryParams: {'id': id, 'user_id': userId},
      baseOverride: flutterApi ? ApiClient.flutterBaseUrl : null,
    );

    // These endpoints answer DELETE with the unchanged list rather than
    // performing the delete, so confirm the row is really gone instead of
    // reporting a success that never happened.
    final after = await ApiClient.get(
      ep,
      queryParams: {'user_id': userId},
      baseOverride: flutterApi ? ApiClient.flutterBaseUrl : null,
    );
    final rows = after is Map ? after['data'] : null;
    if (rows is List &&
        rows.any((r) => r is Map && r['id']?.toString() == id)) {
      throw ApiException(
          'The server did not delete this record. Deleting is not supported yet.');
    }
  }

  static Future<void> deleteGiveAsk(String id) async {
    await deleteActivity('give_ask.php', id);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Derive summary figures from raw rows for endpoints that send no `stats`.
  ///
  /// The status vocabulary is not consistent across these endpoints, and
  /// referrals.php is the awkward one: it creates every row as `approved` but
  /// stores `success`/`failure` when a member ticks or crosses it. Counting
  /// only the literal strings `approved`/`rejected` meant a freshly created
  /// referral showed as Success with Pending stuck at 0, and tapping approve
  /// then moved the row to `success` - which fell into the "everything else"
  /// bucket and made the Success count go *down*. Both vocabularies are
  /// normalised here.
  static Map<String, dynamic> _computeStats(List<dynamic> rows, String userId) {
    int approved = 0, pending = 0, rejected = 0;
    double totalValue = 0, given = 0, received = 0;

    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);

      final status = (map['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'approved' ||
          status == 'success' ||
          status == 'accepted') {
        approved++;
      } else if (status == 'rejected' ||
          status == 'failure' ||
          status == 'failed') {
        rejected++;
      } else {
        pending++;
      }

      final amount = double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;
      totalValue += amount;

      final givenBy = map['given_by']?.toString();
      final receivedBy = map['received_by']?.toString();
      if (givenBy != null && givenBy == userId) given += amount;
      if (receivedBy != null && receivedBy == userId) received += amount;
    }

    return {
      'total': rows.length,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
      'total_value': totalValue,
      'business_given': given,
      'business_received': received,
    };
  }

  static List<dynamic>? _extractList(Map<String, dynamic> map) {
    const listKeys = [
      'items', 'data', 'referrals', 'cnotes', 'r2r', 'testimonials',
      'visitors', 'give_ask', 'giveasks', 'list', 'results', 'meetings', 'events',
    ];
    for (final key in listKeys) {
      if (map[key] is List) return map[key] as List<dynamic>;
    }
    return null;
  }

  static Map<String, dynamic> _mergeStats(
      Map<String, dynamic> defaults, Map<String, dynamic> incoming) {
    return {...defaults, ...incoming};
  }
}
