import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'member_service.dart';

class AuthService {
  // ─── Login ─────────────────────────────────────────────────────────────────

  /// POST login.php  { mobile, password }
  static Future<Map<String, dynamic>> login(String mobile, String password) async {
    final response = await ApiClient.postFormData(
      'login.php',
      {'mobile': mobile, 'password': password},
      baseOverride: ApiClient.flutterBaseUrl,
    );
    // ignore: avoid_print
    print('[AuthService.login] $response');
    final data = _m(response);
    final inner = _m(data['data']);
    final user = _m(data['user'] ?? inner['user']);

    // The login payload has moved between shapes on this API, and an id that
    // lands empty is invisible: ApiClient drops empty query values, so the
    // request goes out with no user_id at all and the server answers 401.
    // Try every shape it has used rather than silently storing ''.
    final resolvedId = [
      data['user_id'],
      inner['user_id'],
      user['id'],
      user['user_id'],
      inner['id'],
      data['id'],
    ].firstWhere(
      (v) => v != null && v.toString().trim().isNotEmpty,
      orElse: () => '',
    ).toString();

    // Every api_flutter endpoint authorises on `user_id`, so storing an empty
    // one means every later call 401s with "Unauthorized. user_id is missing
    // or invalid." Refuse the sign-in instead, while there is still a login
    // screen on screen to show the message on.
    if (resolvedId.isEmpty) {
      throw ApiException(
        'Sign-in succeeded but the server did not return a user id, so this '
        'account cannot be used yet. Please try again or contact your '
        'administrator.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', resolvedId);
    await prefs.setString('login_username', mobile);
    await prefs.setString(
      'user_role', (user['role_name'] ?? user['role'] ?? '').toString());
    await prefs.setString(
      'user_name', (user['display_name'] ?? user['name'] ?? '').toString());
    await prefs.setString('chapter_id', user['chapter_id']?.toString() ?? '');
    // The API returns the chapter under `chapter`; store the name so the
    // directory can default to the member's own chapter.
    await prefs.setString(
        'chapter_name',
        (user['chapter_name'] ?? user['chapter'] ?? '').toString());

    // Save address fields from login response if present
    final loginAddr = [
      user['address_line_1'],
      user['address'],
      user['address_1'],
      user['address1'],
      user['street'],
      user['street_address'],
      inner['address_line_1'],
      inner['address'],
      data['address'],
    ].firstWhere((v) => v != null && v.toString().trim().isNotEmpty, orElse: () => null);
    if (loginAddr != null) {
      await prefs.setString('user_address_1', loginAddr.toString().trim());
      await prefs.setString('user_address', loginAddr.toString().trim());
    }
    final loginCity = user['city'] ?? inner['city'] ?? data['city'];
    if (loginCity != null && loginCity.toString().trim().isNotEmpty) {
      await prefs.setString('user_city', loginCity.toString().trim());
    }
    final loginState = user['state'] ?? inner['state'] ?? data['state'];
    if (loginState != null && loginState.toString().trim().isNotEmpty) {
      await prefs.setString('user_state', loginState.toString().trim());
    }
    final loginPin = user['pincode'] ?? user['pin_code'] ?? user['zip'] ?? inner['pincode'] ?? data['pincode'];
    if (loginPin != null && loginPin.toString().trim().isNotEmpty) {
      await prefs.setString('user_pincode', loginPin.toString().trim());
    }

    // Make the signed-in member's photo available to the app bar immediately.
    // Clear the previous session's value first: without this, signing in as a
    // different member could briefly show the former member's profile photo.
    final avatar = (user['profile_photo'] ??
            user['avatar'] ??
            inner['profile_photo'] ??
            inner['avatar'] ??
            data['profile_photo'] ??
            data['avatar'] ??
            '')
        .toString()
        .trim();
    await prefs.remove('cached_avatar_url');
    if (avatar.isNotEmpty) {
      await prefs.setString('avatar', avatar);
      await prefs.setString('cached_avatar_url', avatar);
    } else {
      await prefs.remove('avatar');
    }
    // A successful login is all that is required to restore this account on a
    // later launch.  The API session cookie is persisted by ApiClient; never
    // persist the password to implement "remember me".
    await prefs.setInt(
      'session_started_at',
      DateTime.now().millisecondsSinceEpoch,
    );
    final expiresAt = _sessionExpiry(data, inner, user);
    if (expiresAt == null) {
      await prefs.remove('session_expires_at');
    } else {
      await prefs.setInt('session_expires_at', expiresAt.millisecondsSinceEpoch);
    }
    // Remove credentials saved by older versions of the app.
    await prefs.remove('saved_password');
    await prefs.remove('saved_mobile');
    return data;
  }

  // ─── Get Profile ───────────────────────────────────────────────────────────

  /// GET profile.php?user_id=X
  /// Response: { success, data: { user: {...}, sponsor, categories } }
  static Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return {};

    final cachedAddr1 = prefs.getString('user_address_1') ?? prefs.getString('user_address') ?? '';
    final cachedCity = prefs.getString('user_city') ?? '';
    final cachedState = prefs.getString('user_state') ?? '';
    final cachedPin = prefs.getString('user_pincode') ?? prefs.getString('user_pin') ?? '';
    final cachedDob = prefs.getString('user_dob') ?? prefs.getString('user_birthday') ?? '';
    final cachedAnniversary = prefs.getString('user_anniversary') ?? prefs.getString('user_anniversary_date') ?? '';

    try {
      dynamic response;
      try {
        response = await ApiClient.get(
          'profile.php',
          queryParams: {'user_id': userId},
          baseOverride: ApiClient.flutterBaseUrl,
        );
      } catch (_) {
        response = await ApiClient.get(
          'profile.php',
          queryParams: {'user_id': userId},
        );
      }

      // ignore: avoid_print
      print('[AuthService.getProfile] $response');
      final data = _m(response);
      final profileData = _m(data['data']);
      final user = _m(profileData['user']).isNotEmpty
          ? _m(profileData['user'])
          : (_m(data['user']).isNotEmpty
              ? _m(data['user'])
              : (profileData.isNotEmpty ? profileData : data));

      // Collect address from profileData['address'], user['address'], or profileData
      final rawAddress = profileData['address'] ?? user['address'] ?? profileData['user_address'];
      Map<String, dynamic> addrMap = {};
      String addrStr = '';
      if (rawAddress is Map) {
        addrMap = _m(rawAddress);
      } else if (rawAddress is List && rawAddress.isNotEmpty && rawAddress.first is Map) {
        addrMap = _m(rawAddress.first);
      } else if (rawAddress != null && rawAddress is! Map && rawAddress is! List) {
        addrStr = rawAddress.toString().trim();
      }

      var addr1 = addrMap['address_line_1'] ??
          addrMap['address_1'] ??
          addrMap['address1'] ??
          addrMap['line1'] ??
          addrMap['street'] ??
          addrMap['address'] ??
          (addrStr.isNotEmpty ? addrStr : null) ??
          user['address_line_1'] ??
          user['address'] ??
          user['street'] ??
          user['street_address'] ??
          user['location'] ??
          profileData['address_line_1'] ??
          profileData['address'] ??
          (cachedAddr1.isNotEmpty ? cachedAddr1 : null);
      var city = addrMap['city'] ??
          user['city'] ??
          profileData['city'] ??
          (cachedCity.isNotEmpty ? cachedCity : null);
      var state = addrMap['state'] ??
          user['state'] ??
          profileData['state'] ??
          (cachedState.isNotEmpty ? cachedState : null);
      var pincode = addrMap['pincode'] ??
          addrMap['pin_code'] ??
          addrMap['postal_code'] ??
          addrMap['zip'] ??
          user['pincode'] ??
          user['pin_code'] ??
          profileData['pincode'] ??
          (cachedPin.isNotEmpty ? cachedPin : null);

      final rawDob = [
        user['dob'],
        user['birth_date'],
        user['birthday'],
        user['date_of_birth'],
        user['birthdate'],
        user['bday'],
        user['dob_date'],
        user['dateOfBirth'],
        profileData['dob'],
        profileData['birth_date'],
        profileData['birthday'],
        profileData['date_of_birth'],
        profileData['birthdate'],
        profileData['bday'],
        profileData['dob_date'],
        data['dob'],
        data['birth_date'],
        data['birthday'],
        data['date_of_birth'],
        data['birthdate'],
      ].firstWhere(
        (v) => v != null && v.toString().trim().isNotEmpty && v.toString().trim() != '0000-00-00' && v.toString().trim() != 'null',
        orElse: () => cachedDob.isNotEmpty ? cachedDob : null,
      );

      final rawAnniversary = [
        user['anniversary'],
        user['anniversary_date'],
        user['wedding_anniversary'],
        user['anniversary_day'],
        profileData['anniversary'],
        profileData['anniversary_date'],
        profileData['wedding_anniversary'],
        profileData['anniversary_day'],
        data['anniversary'],
        data['anniversary_date'],
      ].firstWhere(
        (v) => v != null && v.toString().trim().isNotEmpty && v.toString().trim() != '0000-00-00' && v.toString().trim() != 'null',
        orElse: () => cachedAnniversary.isNotEmpty ? cachedAnniversary : null,
      );

      String? resolvedDob = rawDob?.toString();
      String? resolvedAnniversary = rawAnniversary?.toString();
      if (resolvedDob == null || resolvedAnniversary == null || addr1 == null || city == null || state == null || pincode == null) {
        try {
          final members = await MemberService.getAllMembers();
          for (final m in members) {
            if (m.id.toString() == userId) {
              final raw = m.rawJson ?? {};
              if (resolvedDob == null) {
                final mDob = raw['dob'] ?? raw['birth_date'] ?? raw['birthday'];
                if (mDob != null && mDob.toString().trim().isNotEmpty && mDob.toString().trim() != '0000-00-00') {
                  resolvedDob = mDob.toString().trim();
                }
              }
              if (resolvedAnniversary == null) {
                final mAnn = raw['anniversary'] ?? raw['anniversary_date'] ?? raw['wedding_anniversary'];
                if (mAnn != null && mAnn.toString().trim().isNotEmpty && mAnn.toString().trim() != '0000-00-00') {
                  resolvedAnniversary = mAnn.toString().trim();
                }
              }
              if (addr1 == null || addr1.toString().trim().isEmpty) {
                final mAddr = raw['address'] ??
                    raw['address_line_1'] ??
                    raw['address_1'] ??
                    raw['address1'] ??
                    raw['street'] ??
                    raw['street_address'] ??
                    raw['location'] ??
                    raw['office_address'] ??
                    raw['company_address'] ??
                    raw['business_address'];
                if (mAddr != null && mAddr.toString().trim().isNotEmpty) {
                  addr1 = mAddr.toString().trim();
                }
              }
              if (city == null || city.toString().trim().isEmpty) {
                if (m.city.isNotEmpty) {
                  city = m.city;
                } else if (raw['city'] != null && raw['city'].toString().trim().isNotEmpty) {
                  city = raw['city'].toString().trim();
                }
              }
              if (state == null || state.toString().trim().isEmpty) {
                final mState = raw['state'] ?? raw['region'];
                if (mState != null && mState.toString().trim().isNotEmpty) {
                  state = mState.toString().trim();
                }
              }
              if (pincode == null || pincode.toString().trim().isEmpty) {
                final mPin = raw['pincode'] ?? raw['pin_code'] ?? raw['zip'] ?? raw['postal_code'];
                if (mPin != null && mPin.toString().trim().isNotEmpty) {
                  pincode = mPin.toString().trim();
                }
              }
              break;
            }
          }
        } catch (_) {}
      }

      final merged = <String, dynamic>{
        ...profileData,
        ...user,
        if (addr1 != null && addr1.toString().isNotEmpty) ...{
          'address_line_1': addr1.toString(),
          'address': addr1.toString(),
          'address1': addr1.toString(),
        },
        if (city != null && city.toString().isNotEmpty) 'city': city.toString(),
        if (state != null && state.toString().isNotEmpty) 'state': state.toString(),
        if (pincode != null && pincode.toString().isNotEmpty) ...{
          'pincode': pincode.toString(),
          'pin_code': pincode.toString(),
        },
        if (resolvedDob != null && resolvedDob.isNotEmpty) ...{
          'dob': resolvedDob,
          'birth_date': resolvedDob,
          'birthday': resolvedDob,
          'date_of_birth': resolvedDob,
        },
        if (resolvedAnniversary != null && resolvedAnniversary.isNotEmpty) ...{
          'anniversary': resolvedAnniversary,
          'anniversary_date': resolvedAnniversary,
          'wedding_anniversary': resolvedAnniversary,
        },
      };

      // Persist address, birthday, anniversary to SharedPreferences
      if (addr1 != null && addr1.toString().isNotEmpty) {
        await prefs.setString('user_address_1', addr1.toString());
        await prefs.setString('user_address', addr1.toString());
      }
      if (city != null && city.toString().isNotEmpty) {
        await prefs.setString('user_city', city.toString());
      }
      if (state != null && state.toString().isNotEmpty) {
        await prefs.setString('user_state', state.toString());
      }
      if (pincode != null && pincode.toString().isNotEmpty) {
        await prefs.setString('user_pincode', pincode.toString());
      }
      if (resolvedDob != null && resolvedDob.isNotEmpty) {
        await prefs.setString('user_dob', resolvedDob);
        await prefs.setString('user_birthday', resolvedDob);
      }
      if (resolvedAnniversary != null && resolvedAnniversary.isNotEmpty) {
        await prefs.setString('user_anniversary', resolvedAnniversary);
        await prefs.setString('user_anniversary_date', resolvedAnniversary);
      }

      return _withLegacyAliases(merged);
    } catch (e) {
      // ignore: avoid_print
      print('[AuthService.getProfile] error: $e');
      return {
        'id': userId,
        'name': prefs.getString('user_name') ?? '',
        'role': prefs.getString('user_role') ?? '',
        'mobile': prefs.getString('login_username') ?? '',
        'address_line_1': cachedAddr1,
        'address': cachedAddr1,
        'city': cachedCity,
        'state': cachedState,
        'pincode': cachedPin,
        'dob': cachedDob,
        'birthday': cachedDob,
        'birth_date': cachedDob,
        'anniversary': cachedAnniversary,
        'anniversary_date': cachedAnniversary,
      };
    }
  }

  // ─── Update Profile ────────────────────────────────────────────────────────

  /// POST profile.php  { user_id, email, dob, gender, blood_group,
  ///   company_name, business_category, business_description, gst_number,
  ///   website, linkedin, facebook, instagram, twitter,
  ///   spouse_name, anniversary_date,
  ///   residential_address, residential_city, residential_state,
  ///   residential_pincode, residential_lat, residential_lng,
  ///   office_address, office_city, office_state, office_pincode,
  ///   office_lat, office_lng, aadhar_number, pan_number, ... }
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data, {
    List<http.MultipartFile>? files,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    // Build the profile.php payload with all supported fields.
    final fields = <String, String>{
      if (userId.isNotEmpty) 'user_id': userId,
    };

    // Helper: add a field only when it has a real value.
    void add(String key, dynamic val) {
      if (val != null && val.toString().trim().isNotEmpty) {
        fields[key] = val.toString().trim();
      }
    }

    // Helper: convert any date string to YYYY-MM-DD for MySQL
    String? toIsoDate(dynamic raw) {
      if (raw == null) return null;
      var s = raw.toString().trim();
      if (s.isEmpty || s == '0000-00-00') return null;
      s = s.split(RegExp(r'[ T]')).first.trim();
      if (s.isEmpty) return null;
      final ymd = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(s);
      if (ymd != null) {
        return '${ymd.group(1)}-${ymd.group(2)!.padLeft(2, '0')}-${ymd.group(3)!.padLeft(2, '0')}';
      }
      final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
      if (dmy != null) {
        return '${dmy.group(3)}-${dmy.group(2)!.padLeft(2, '0')}-${dmy.group(1)!.padLeft(2, '0')}';
      }
      try {
        final dt = DateTime.tryParse(s);
        if (dt != null) {
          return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
      return null;
    }

    // ── Personal ─────────────────────────────────────────────────────────────
    add('email', data['email']);
    final isoDob = toIsoDate(
      data['birth_date'] ?? data['birthday'] ?? data['date_of_birth'] ?? data['dob'],
    );
    if (isoDob != null) {
      fields['dob'] = isoDob;
      fields['birth_date'] = isoDob;
    }
    add('gender',      data['gender']);
    add('blood_group', data['blood_group']);

    // Name fields (kept for backward compat with screens that still pass them)
    add('first_name',    data['first_name']);
    add('last_name',     data['last_name']);
    add('display_name',  data['display_name']);

    // ── Business ──────────────────────────────────────────────────────────────
    add('company_name',          data['company_name'] ?? data['company']);
    add('business_category',     data['business_category'] ?? data['classification'] ?? data['category']);
    add('business_description',  data['business_description'] ?? data['products'] ?? data['services']);
    add('gst_number',            data['gst_number'] ?? data['gst']);
    add('website',               data['website']);
    add('experience',            data['experience']);

    // ── Social links ──────────────────────────────────────────────────────────
    add('linkedin',   data['linkedin']);
    add('facebook',   data['facebook']);
    add('instagram',  data['instagram']);
    add('twitter',    data['twitter']);

    // ── Family ────────────────────────────────────────────────────────────────
    add('spouse_name',      data['spouse_name']);
    final isoAnn = toIsoDate(
      data['anniversary_date'] ?? data['anniversary'] ?? data['wedding_anniversary'],
    );
    if (isoAnn != null) {
      fields['anniversary_date'] = isoAnn;
    }

    // ── Residential address ───────────────────────────────────────────────────
    final resAddr = data['residential_address'] ?? data['address_line_1'] ?? data['address'] ?? data['address1'];
    add('residential_address', resAddr);
    add('residential_city',    data['residential_city'] ?? data['city']);
    add('residential_state',   data['residential_state'] ?? data['state']);
    final resPin = data['residential_pincode'] ?? data['pincode'] ?? data['pin_code'] ?? data['zip'];
    add('residential_pincode', resPin);
    add('residential_lat', data['residential_lat']);
    add('residential_lng', data['residential_lng']);

    // ── Office address ────────────────────────────────────────────────────────
    add('office_address', data['office_address']);
    add('office_city',    data['office_city']);
    add('office_state',   data['office_state']);
    add('office_pincode', data['office_pincode']);
    add('office_lat',     data['office_lat']);
    add('office_lng',     data['office_lng']);

    // ── KYC ───────────────────────────────────────────────────────────────────
    add('aadhar_number',       data['aadhar_number'] ?? data['aadhar']);
    add('pan_number',          data['pan_number'] ?? data['pan']);
    add('aadhar_card_file',    data['aadhar_card_file']);
    add('pan_card_file',       data['pan_card_file']);
    add('gst_certificate_file', data['gst_certificate_file']);
    add('visiting_card_file',  data['visiting_card_file']);
    add('profile_photo',       data['profile_photo']);

    // ── Persist locally ───────────────────────────────────────────────────────
    if (resAddr != null && resAddr.toString().isNotEmpty) {
      await prefs.setString('user_address_1', resAddr.toString());
      await prefs.setString('user_address',   resAddr.toString());
    }
    final cityVal = data['residential_city'] ?? data['city'];
    if (cityVal != null && cityVal.toString().isNotEmpty) {
      await prefs.setString('user_city', cityVal.toString());
    }
    final stateVal = data['residential_state'] ?? data['state'];
    if (stateVal != null && stateVal.toString().isNotEmpty) {
      await prefs.setString('user_state', stateVal.toString());
    }
    if (resPin != null && resPin.toString().isNotEmpty) {
      await prefs.setString('user_pincode', resPin.toString());
    }
    if (isoDob != null) {
      await prefs.setString('user_dob',      isoDob);
      await prefs.setString('user_birthday', isoDob);
    }
    if (isoAnn != null) {
      await prefs.setString('user_anniversary',      isoAnn);
      await prefs.setString('user_anniversary_date', isoAnn);
    }

    // POST to profile.php (flutter base URL).
    try {
      final response = await ApiClient.postFormData(
        'profile.php',
        fields,
        files: files,
        baseOverride: ApiClient.flutterBaseUrl,
      );
      return _m(response);
    } catch (_) {
      // Fallback to auth.php for servers that have not yet deployed profile.php.
      final fallback = <String, String>{
        'action': 'update_profile',
        ...fields,
      };
      final response = await ApiClient.postFormData(
        'auth.php',
        fallback,
        files: files,
      );
      return _m(response);
    }
  }

  // ─── Change Password ───────────────────────────────────────────────────────

  /// POST auth.php  { action: change_password, user_id, current_password, new_password }
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final response = await ApiClient.postFormData('auth.php', {
      'action': 'change_password',
      'user_id': userId,
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return _m(response);
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  /// POST auth.php - Logout endpoint
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await ApiClient.postFormData('auth.php', {});
    } catch (_) {}
    // Drop the session cookie too, or the next sign-in reuses this one.
    await ApiClient.clearSession();
    await _clearStoredSession(prefs);
  }

  /// Restores the locally persisted session for app startup.
  ///
  /// The user id and the API cookie are the credentials used by the current
  /// API flow.  A server supplied expiry is honoured when available.  Network
  /// reachability is intentionally not used to reject a session here, so an
  /// offline launch does not unnecessarily sign a member out.
  static Future<Map<String, String>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('user_id') ?? '').trim();
    final expiresAt = prefs.getInt('session_expires_at');
    final isExpired = expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch >= expiresAt;
    if (userId.isEmpty || isExpired) {
      await ApiClient.clearSession();
      await _clearStoredSession(prefs);
      return null;
    }

    return {
      'name': prefs.getString('user_name') ?? 'Member',
      'role': prefs.getString('user_role') ?? 'member',
      'mobile': prefs.getString('login_username') ?? '',
    };
  }

  static Future<void> _clearStoredSession(SharedPreferences prefs) async {
    // Clear all stored user data.  The password keys are included solely to
    // clean up insecure data written by older app versions.
    await prefs.remove('user_id');
    await prefs.remove('login_username');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    await prefs.remove('chapter_id');
    await prefs.remove('chapter_name');
    await prefs.remove('avatar');
    await prefs.remove('cached_avatar_url');
    await prefs.remove('session_started_at');
    await prefs.remove('session_expires_at');
    await prefs.remove('saved_mobile');
    await prefs.remove('saved_password');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static Future<bool> isLoggedIn() async {
    return (await restoreSession()) != null;
  }

  static Future<Map<String, String>> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id') ?? '',
      'login_username': prefs.getString('login_username') ?? '',
      'user_role': prefs.getString('user_role') ?? '',
      'user_name': prefs.getString('user_name') ?? '',
      'chapter_id': prefs.getString('chapter_id') ?? '',
    };
  }

  static Map<String, dynamic> _m(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  static Map<String, dynamic> _withLegacyAliases(Map<String, dynamic> user) {
    final dob = user['dob'] ?? user['birth_date'] ?? user['birthday'] ?? user['date_of_birth'] ?? '';
    final ann = user['anniversary'] ?? user['anniversary_date'] ?? user['wedding_anniversary'] ?? '';
    return {
      ...user,
      'name': user['display_name'] ?? user['first_name'] ?? '',
      'role': user['role_name'] ?? user['role_slug'] ?? '',
      'chapter': user['chapter_name'] ?? '',
      'company': user['company_name'] ?? '',
      'avatar': user['profile_photo'] ?? '',
      if (dob.toString().isNotEmpty) ...{
        'dob': dob,
        'birth_date': dob,
        'birthday': dob,
        'date_of_birth': dob,
      },
      if (ann.toString().isNotEmpty) ...{
        'anniversary': ann,
        'anniversary_date': ann,
        'wedding_anniversary': ann,
      },
    };
  }

  static DateTime? _sessionExpiry(
    Map<String, dynamic> data,
    Map<String, dynamic> inner,
    Map<String, dynamic> user,
  ) {
    final value = [
      data['expires_at'],
      data['session_expires_at'],
      inner['expires_at'],
      inner['session_expires_at'],
      user['expires_at'],
    ].firstWhere((item) => item != null && item.toString().isNotEmpty,
        orElse: () => null);
    if (value == null) return null;
    if (value is num) {
      final milliseconds = value > 1000000000000
          ? value.toInt()
          : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
