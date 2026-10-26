import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/activity_model.dart';
import 'activity_service.dart';
import 'api_client.dart';

class MemberService {
  static const String _cachedMembersKey = 'cached_directory_members_json';

  /// GET directory.php?user_id=X
  static Future<Map<String, dynamic>> getMembers({
    String query = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    dynamic response;
    try {
      response = await ApiClient.get(
        'directory.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );
    } catch (e) {
      // If network or server encounters an issue, fallback to persistent disk cache
      final cached = await _loadFromDiskCache();
      if (cached.isNotEmpty) {
        return {
          'members': cached,
          'stats': {'total': cached.length},
        };
      }
      rethrow;
    }

    List<dynamic> rawList = [];
    Map<String, dynamic> stats = {'total': 0};
    // Distinguishes "the directory is empty" from "we could not find a list in
    // the response at all".
    bool sawList = false;

    if (response is Map && response['data'] is Map) {
      final dataMap = Map<String, dynamic>.from(response['data'] as Map);
      final members = dataMap['members'];
      if (members is List) {
        rawList = members;
        sawList = true;
      }
      stats = {'total': rawList.length};
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List<dynamic>;
      sawList = true;
      stats = {'total': rawList.length};
    } else if (response is Map && response['members'] is List) {
      rawList = response['members'] as List<dynamic>;
      sawList = true;
      stats = response['stats'] is Map
          ? Map<String, dynamic>.from(response['stats'])
          : {'total': rawList.length};
    }

    // A response with no recognisable list is not an empty directory.
    // Collapsing the two left every member dropdown in the app blank with no
    // error and nothing to retry, so the shape mismatch is reported instead.
    if (!sawList) {
      final cached = await _loadFromDiskCache();
      if (cached.isNotEmpty) {
        return {
          'members': cached,
          'stats': {'total': cached.length},
        };
      }
      throw ApiException(
          'The member list could not be read from the server response.');
    }

    final members = rawList
        .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();

    // Persist to disk cache so member dropdowns stay functional even offline
    if (rawList.isNotEmpty) {
      try {
        await prefs.setString(_cachedMembersKey, jsonEncode(rawList));
      } catch (_) {}
    }

    return {'members': members, 'stats': stats};
  }

  /// Loads the complete directory and caches it per session.
  static List<UserModel>? _allMembersCache;
  static Future<List<UserModel>>? _fetchFuture;

  /// Returns cached members from memory or disk cache immediately if available.
  static Future<List<UserModel>> getCachedMembers() async {
    if (_allMembersCache != null && _allMembersCache!.isNotEmpty) {
      return _allMembersCache!;
    }
    final disk = await _loadFromDiskCache();
    if (disk.isNotEmpty) {
      _allMembersCache = disk;
      return disk;
    }
    return [];
  }

  static Future<List<UserModel>> _loadFromDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cachedMembersKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final list = decoded
              .map((m) =>
                  UserModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList();
          list.sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<UserModel>> getAllMembers({bool refresh = false}) {
    if (_allMembersCache != null && !refresh) {
      return Future.value(_allMembersCache!);
    }
    if (_fetchFuture != null && !refresh) {
      return _fetchFuture!;
    }
    _fetchFuture = _doGetAllMembers();
    return _fetchFuture!;
  }

  static Future<List<UserModel>> _doGetAllMembers() async {
    try {
      final res = await getMembers();
      final members = List<UserModel>.from(res['members'] as List);

      members
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (members.isNotEmpty) {
        _allMembersCache = members;
      }
      return members;
    } catch (e) {
      // Fallback to disk cache if available
      final disk = await _loadFromDiskCache();
      if (disk.isNotEmpty) {
        _allMembersCache = disk;
        return disk;
      }
      rethrow;
    } finally {
      _fetchFuture = null;
    }
  }

  /// Finds one member from the directory response.
  ///
  /// directory.php currently ignores an `id` filter and always returns the whole
  /// directory, so the id is sent anyway (harmless today, correct if that
  /// changes) and the row is then located in the returned list. Ids outside the
  /// returned page are genuinely unresolvable, which is what the throw below
  static final Map<int, Map<String, dynamic>> _memberDetailCache = {};
  static final Set<int> _notFoundMemberIds = {};

  /// Finds one member from the directory response.
  ///
  /// Checks memory cache first to prevent redundant network calls.
  static Future<Map<String, dynamic>> getMemberDetail(int id) async {
    if (_memberDetailCache.containsKey(id)) {
      return _memberDetailCache[id]!;
    }
    if (_notFoundMemberIds.contains(id)) {
      throw ApiException('Member not found');
    }

    // Check if the member is already present in the loaded directory cache
    if (_allMembersCache != null) {
      for (final m in _allMembersCache!) {
        if (m.id == id) {
          final mapped = {
            'id': m.id,
            'name': m.name,
            'chapter': m.chapterName,
            'chapter_name': m.chapterName,
            'company': m.companyName,
            'company_name': m.companyName,
            'category': m.businessCategory,
            'business_category': m.businessCategory,
            'mobile': m.mobile,
            'email': m.email,
            'avatar': m.avatar,
            'give': m.give,
            'gives': m.give,
            'what_i_give': m.give,
            'ask': m.ask,
            'asks': m.ask,
            'what_i_ask': m.ask,
            if (m.rawJson != null) ...m.rawJson!,
          };

          // Try to enrich with profile.php for DOB / Anniversary
          if (mapped['dob'] == null || mapped['dob'].toString().trim().isEmpty) {
            try {
              final pRes = await ApiClient.get(
                'profile.php',
                queryParams: {'user_id': '$id'},
                baseOverride: ApiClient.flutterBaseUrl,
              );
              if (pRes is Map) {
                final pData = pRes['data'] is Map ? pRes['data'] as Map : pRes;
                final pUser = pData['user'] is Map ? pData['user'] as Map : pData;
                for (final k in [
                  'dob', 'birth_date', 'birthday', 'date_of_birth', 'birthdate',
                  'anniversary', 'anniversary_date', 'wedding_anniversary', 'spouse_name'
                ]) {
                  if (pUser[k] != null &&
                      pUser[k].toString().trim().isNotEmpty &&
                      pUser[k].toString().trim() != '0000-00-00') {
                    mapped[k] = pUser[k].toString().trim();
                  }
                }
              }
            } catch (_) {}
          }

          _memberDetailCache[id] = mapped;
          return mapped;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final response = await ApiClient.get(
      'directory.php',
      queryParams: {'user_id': userId, 'id': '$id'},
      baseOverride: ApiClient.flutterBaseUrl,
    );

    final directory = response['data'];
    final data = directory is Map ? directory['members'] : directory;
    if (data is List) {
      for (final row in data) {
        if (row is Map && row['id']?.toString() == id.toString()) {
          final res = Map<String, dynamic>.from(row);

          // Enrich with profile.php
          try {
            final pRes = await ApiClient.get(
              'profile.php',
              queryParams: {'user_id': '$id'},
              baseOverride: ApiClient.flutterBaseUrl,
            );
            if (pRes is Map) {
              final pData = pRes['data'] is Map ? pRes['data'] as Map : pRes;
              final pUser = pData['user'] is Map ? pData['user'] as Map : pData;
              for (final k in [
                'dob', 'birth_date', 'birthday', 'date_of_birth', 'birthdate',
                'anniversary', 'anniversary_date', 'wedding_anniversary', 'spouse_name'
              ]) {
                if (pUser[k] != null &&
                    pUser[k].toString().trim().isNotEmpty &&
                    pUser[k].toString().trim() != '0000-00-00') {
                  res[k] = pUser[k].toString().trim();
                }
              }
            }
          } catch (_) {}

          _memberDetailCache[id] = res;
          return res;
        }
      }
      _notFoundMemberIds.add(id);
      throw ApiException('Member not found in directory response');
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);

      final rawMobile = m['mobile']?.toString() ?? '';
      final digits = rawMobile.replaceAll(RegExp(r'[^0-9]'), '');
      if (rawMobile.contains('://') || digits.length < 10) {
        m.remove('mobile');
      }

      m['city'] ??= m['office_city'];
      m['company_name'] ??= m['company'];
      m['business_category'] ??= m['category'];
      m['chapter_name'] ??= m['chapter'];
      m['member_code'] ??= m['rmb_id'];

      // Enrich with profile.php
      try {
        final pRes = await ApiClient.get(
          'profile.php',
          queryParams: {'user_id': '$id'},
          baseOverride: ApiClient.flutterBaseUrl,
        );
        if (pRes is Map) {
          final pData = pRes['data'] is Map ? pRes['data'] as Map : pRes;
          final pUser = pData['user'] is Map ? pData['user'] as Map : pData;
          for (final k in [
            'dob', 'birth_date', 'birthday', 'date_of_birth', 'birthdate',
            'anniversary', 'anniversary_date', 'wedding_anniversary', 'spouse_name'
          ]) {
            if (pUser[k] != null &&
                pUser[k].toString().trim().isNotEmpty &&
                pUser[k].toString().trim() != '0000-00-00') {
              m[k] = pUser[k].toString().trim();
            }
          }
        }
      } catch (_) {}

      _memberDetailCache[id] = m;
      return m;
    }

    if (response['id'] != null ||
        response['name'] != null ||
        response['display_name'] != null) {
      final res = Map<String, dynamic>.from(response);
      _memberDetailCache[id] = res;
      return res;
    }
    _notFoundMemberIds.add(id);
    throw ApiException('Member not found');
  }

  static final Map<int, Map<String, String>> _giveAskCache = {};
  static Future<void>? _giveAskFetchFuture;

  /// Returns latest give & ask strings for a member, checking cache or give_ask.php.
  static Future<Map<String, String>?> getMemberGiveAsk(int memberId) async {
    if (_giveAskCache.containsKey(memberId)) {
      return _giveAskCache[memberId];
    }
    try {
      _giveAskFetchFuture ??= _fetchGiveAskCache();
      await _giveAskFetchFuture;
      return _giveAskCache[memberId];
    } catch (_) {
      return null;
    } finally {
      _giveAskFetchFuture = null;
    }
  }

  static Future<void> _fetchGiveAskCache() async {
    try {
      final res = await ActivityService.getActivities('give_ask.php', 'giveask');
      final list = List<ActivityModel>.from(res['activities'] ?? []);
      for (final item in list) {
        final raw = item.rawJson;
        final uidStr = (raw['user_id'] ??
                raw['member_id'] ??
                raw['given_by'] ??
                raw['created_by'])
            ?.toString();
        final uid = int.tryParse(uidStr ?? '');
        if (uid != null) {
          final give = (raw['gives'] ?? raw['give'] ?? raw['what_i_give'] ?? '')
              .toString()
              .trim();
          final ask = (raw['asks'] ?? raw['ask'] ?? raw['what_i_ask'] ?? '')
              .toString()
              .trim();
          if (!_giveAskCache.containsKey(uid) ||
              ((_giveAskCache[uid]?['give']?.isEmpty ?? true) &&
                  give.isNotEmpty) ||
              ((_giveAskCache[uid]?['ask']?.isEmpty ?? true) &&
                  ask.isNotEmpty)) {
            _giveAskCache[uid] = {
              'give':
                  give.isNotEmpty ? give : (_giveAskCache[uid]?['give'] ?? ''),
              'ask': ask.isNotEmpty ? ask : (_giveAskCache[uid]?['ask'] ?? ''),
            };
          }
        }
      }
    } catch (_) {}
  }
}

