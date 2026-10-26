import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// True when the server rejected the request as unauthenticated, either via
  /// a 401 or a body that says so. `api_flutter` endpoints authorise on the
  /// `user_id` field, so this is the signal that a call went out without a
  /// usable signed-in id - the caller can prompt for a fresh sign-in instead of
  /// showing a bare "Unauthorized" the member can do nothing about.
  final bool isUnauthorized;

  ApiException(this.message, {this.statusCode, this.isUnauthorized = false});
  @override
  String toString() => message;
}

/// True when a response is the server refusing an unauthenticated request.
bool _looksUnauthorized(int statusCode, String body) {
  if (statusCode == 401 || statusCode == 403) return true;
  final text = body.toLowerCase();
  if (text.contains('unauthorized') || text.contains('user_id is missing')) {
    return true;
  }
  // When a PHP session expires, requests redirect to login.php which renders the login HTML
  if (text.contains('csrf-token') ||
      text.contains('modules/auth/login.php') ||
      (text.contains('<!doctype html') &&
          (text.contains('sign in') || text.contains('login') || text.contains('password')))) {
    return true;
  }
  return false;
}

class ApiClient {
  /// Base URL for the CCTV ERP API.
  /// On web builds a local CORS proxy is used to avoid browser CORS restrictions.
  ///
  /// All API endpoints are served from the live `/api` path.
  static const String _remoteBase = ApiEndpoints.apiBaseUrl;
  static String get baseUrl => _remoteBase;

  /// Kept as a separate override for callers that need to bypass auth.
  static const String noAuthBase = ApiEndpoints.apiBaseUrl;
  static const String flutterBaseUrl = ApiEndpoints.flutterApiBaseUrl;

  // ─── Stored user info helpers ──────────────────────────────────────────────

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('login_username') ?? '';
  }

  /// Per-attempt timeout. Kept short on purpose: the retry ladder below can run
  /// this three times for a read, and at 20s a single dead endpoint held a
  /// screen's loading state for a full minute before anything was reported.
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxAttempts = 3;

  /// Hard ceiling on the *total* time one call may spend across every attempt,
  /// backoff included.
  ///
  /// [_timeout] only bounds a single attempt, so the ladder could still hold a
  /// screen's spinner for 3 x [_timeout] plus backoff before anything was
  /// reported. Every API-backed screen routes through here, so that ceiling was
  /// the shared cause of the app-wide "still loading" spinner: one slow or
  /// dropped connection left the member staring at a spinner with no feedback
  /// and no way forward. This budget makes the wait bounded and finite, so a
  /// real error surfaces while the member can still act on it.
  static const Duration _retryBudget = Duration(seconds: 20);

  /// Runs [request], retrying transient failures.
  ///
  /// [idempotent] must be false for anything that writes. A write that times
  /// out, or that comes back 5xx, may still have been committed by the server
  /// before the connection broke - replaying it wrote the same record twice,
  /// which is how referrals were duplicating. A failure that provably never
  /// reached the server is safe to replay even for a write, so that case is
  /// still retried. Reads keep the full ladder.
  ///
  /// Connection detection deliberately goes through package:http rather than
  /// dart:io's SocketException, which does not exist on the web build.
  static Future<T> _withRetry<T>(Future<T> Function() request,
      {bool idempotent = true}) async {
    final started = DateTime.now();
    for (var attempt = 1;; attempt++) {
      try {
        return await request();
      } catch (e) {
        final serverRetryable = e is ApiException &&
            (e.statusCode == 408 ||
                e.statusCode == 429 ||
                (e.statusCode != null && e.statusCode! >= 500));
        final neverReached = e is http.ClientException &&
            _connectionHints.any(e.message.toLowerCase().contains);
        final retryable = idempotent
            ? (e is TimeoutException || serverRetryable || neverReached)
            : neverReached;
        if (!retryable || attempt >= _maxAttempts) rethrow;
        // Never open an attempt, or sit in a backoff, that would push the whole
        // call past [_retryBudget]. Past that point another round trip is not
        // worth the member staring at a spinner.
        final elapsed = DateTime.now().difference(started);
        final backoff = Duration(milliseconds: 400 * (1 << (attempt - 1)));
        if (elapsed + backoff >= _retryBudget) rethrow;
        await Future<void>.delayed(backoff);
      }
    }
  }

  /// Substrings that mark a transport failure as "the request never arrived",
  /// as opposed to a response that came back broken.
  static const List<String> _connectionHints = [
    'connection',
    'failed to fetch',
    'socket',
    'network is unreachable',
    'no route to host',
  ];

  /// Turns transport failures into something a member can act on, rather
  /// than surfacing raw TimeoutException / ClientException text.
  static ApiException _networkError(Object e) {
    if (e is TimeoutException) {
      return ApiException(
          'Server is not responding. Please check your internet connection and try again.');
    }
    final text = e.toString().toLowerCase();
    if (text.contains('failed to fetch') ||
        text.contains('clientexception') ||
        text.contains('socketexception') ||
        text.contains('connection') ||
        text.contains('xmlhttprequest')) {
      return ApiException(
          'Could not reach the server. Please check your internet connection and try again.');
    }
    return ApiException('Network error: $e');
  }

  /// The PHP session cookie, mirrored the way a browser would.
  ///
  /// On web the browser stores RMBCONNECT_SESS automatically, so the API
  /// authorises even when a request carries no user_id. package:http has no
  /// cookie jar, so on Android every call arrived without the session and the
  /// server answered 401 Unauthorized - the app opened but every API-backed
  /// section came up empty. Persisting the cookie here makes the phone behave
  /// like the browser.
  static String? _cookie;
  static bool _cookieLoaded = false;

  static Future<void> _loadCookie() async {
    if (_cookieLoaded) return;
    _cookieLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('session_cookie');
    if (stored != null && stored.isNotEmpty) _cookie = stored;
  }

  /// Records the session cookie from any response that sets one.
  static Future<void> _captureCookie(http.Response response) async {
    // Never capture cookies from unauthorized responses, login redirects, or login pages.
    // Doing so would overwrite the authenticated session cookie with an anonymous/guest cookie.
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        (response.request?.url.path.contains('login.php') == true &&
            response.statusCode == 302) ||
        _looksUnauthorized(response.statusCode, response.body)) {
      return;
    }
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    // Keep only the name=value pair, dropping Path/Expires/HttpOnly attributes.
    final pair = raw.split(';').first.trim();
    if (pair.isEmpty || !pair.contains('=')) return;
    if (pair == _cookie) return;
    _cookie = pair;
    _cookieLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', pair);
  }

  /// Clears the stored session, used on sign-out.
  static Future<void> clearSession() async {
    _cookie = null;
    _cookieLoaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
  }

  static Future<Map<String, String>> _authHeaders() async {
    await _loadCookie();
    final headers = {'Accept': 'application/json'};
    final cookie = _cookie;
    // Browsers reject manually setting the Cookie request header. Web calls
    // authenticate with the user_id fields already included by each service.
    if (!kIsWeb && cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // ─── GET ───────────────────────────────────────────────────────────────────

  static Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams, String? baseOverride}) async {
    try {
      return await _withRetry(() async {
        final headers = await _authHeaders();
        Uri url = Uri.parse('${baseOverride ?? baseUrl}/$endpoint');
        if (queryParams != null && queryParams.isNotEmpty) {
          final filtered = Map<String, String>.fromEntries(
              queryParams.entries.where((e) => e.value.isNotEmpty));
          url = url
              .replace(queryParameters: {...url.queryParameters, ...filtered});
        }
        final response =
            await http.get(url, headers: headers).timeout(_timeout);
        await _captureCookie(response);
        return _processResponse(response);
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _networkError(e);
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────────────────

  /// Performs a DELETE request to [endpoint] (relative to baseUrl).
  /// Not retried on timeout: a timed-out delete may already have been applied
  /// and replaying it is not safe.
  static Future<dynamic> delete(String endpoint,
      {Map<String, String>? queryParams, String? baseOverride}) async {
    try {
      return await _withRetry(() async {
        final headers = await _authHeaders();
        Uri url = Uri.parse('${baseOverride ?? baseUrl}/$endpoint');
        if (queryParams != null && queryParams.isNotEmpty) {
          final filtered = Map<String, String>.fromEntries(
              queryParams.entries.where((e) => e.value.isNotEmpty));
          url = url
              .replace(queryParameters: {...url.queryParameters, ...filtered});
        }
        final response =
            await http.delete(url, headers: headers).timeout(_timeout);
        await _captureCookie(response);
        return _processResponse(response);
      }, idempotent: false);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _networkError(e);
    }
  }

  // ─── POST formdata ─────────────────────────────────────────────────────────

  /// Performs a POST with multipart/form-data to [endpoint].
  /// Empty-string values are omitted from the request to keep payloads clean.
  /// [files] can be attached for file-upload fields.
  ///
  /// Not retried on timeout. A create that times out on the client may already
  /// have been committed server-side, and replaying it wrote the record twice.
  static Future<dynamic> postFormData(
    String endpoint,
    Map<String, String> fields, {
    List<http.MultipartFile>? files,
    bool skipEmpty = true,
    String? baseOverride,
  }) async {
    try {
      return await _withRetry(() async {
        final headers = await _authHeaders();
        final url = Uri.parse('${baseOverride ?? baseUrl}/$endpoint');
        final fieldsToSend = skipEmpty
            ? Map<String, String>.fromEntries(
                fields.entries.where((e) => e.value.isNotEmpty))
            : fields;

        if (files == null || files.isEmpty) {
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
          final body = fieldsToSend.entries
              .map((e) =>
                  '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
              .join('&');
          final response = await http
              .post(url, headers: headers, body: body)
              .timeout(_timeout);
          await _captureCookie(response);
          return _processResponse(response);
        }

        final request = http.MultipartRequest('POST', url);
        request.headers.addAll(headers);
        request.fields.addAll(fieldsToSend);
        request.files.addAll(files);
        final streamedResponse = await request.send().timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);
        await _captureCookie(response);
        return _processResponse(response);
      }, idempotent: false);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _networkError(e);
    }
  }

  /// Convenience JSON POST — used for APIs that accept JSON body (kept for compatibility).
  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? baseOverride,
  }) async {
    try {
      return await _withRetry(() async {
        final headers = await _authHeaders();
        headers['Content-Type'] = 'application/json';
        final url = Uri.parse('${baseOverride ?? baseUrl}/$endpoint');
        final response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(_timeout);
        await _captureCookie(response);
        return _processResponse(response);
      }, idempotent: false);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _networkError(e);
    }
  }

  // ─── Response processor ────────────────────────────────────────────────────

  /// Several endpoints answer a failed INSERT/DELETE with **HTTP 200** and a
  /// raw PDO error page instead of a JSON error body, so a genuine failure
  /// reaches the member as a generic "database error" with no way to act on
  /// it. referrals.php is the worst case: a `received_by` that is not a real
  /// `users.id` trips `fk_ref_received` and the referral is never written, yet
  /// nothing in the response says so.
  ///
  /// Returns null when [raw] is not a server crash page, so the caller can fall
  /// through to its own handling.
  static String? _sqlErrorMessage(String raw) {
    final looksLikeCrash = raw.contains('SQLSTATE') ||
        raw.contains('<pre') ||
        raw.contains('Fatal error') ||
        raw.contains('Warning:') ||
        raw.contains('<br');
    if (!looksLikeCrash) return null;

    final text = raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.contains('foreign key constraint fails')) {
      return 'The member you selected is no longer in the directory. '
          'Reload the member list and choose someone else.';
    }
    if (text.contains('Incorrect date value') ||
        text.contains('Invalid datetime format')) {
      return 'The server rejected the date. Please pick the date again.';
    }
    if (text.contains('Duplicate entry')) {
      return 'This record already exists.';
    }
    if (text.contains('cannot be null')) {
      // visitors.php needs the caller's chapter, which it currently only takes
      // from the PHP session - so an insert from the app (authenticated by
      // user_id, not a session) always fails this way and nothing is stored.
      return 'The server needs your chapter before it can save this. '
          'Please report this to your administrator.';
    }
    if (text.contains('Column') && text.contains("doesn't have a default value")) {
      return 'The server needs more information than was sent. '
          'Please report this to your administrator.';
    }
    return 'The server could not save this record (database error). '
        'Please report this to your administrator.';
  }

  static dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) return {'success': true};
      try {
        final json = jsonDecode(response.body);
        // Accept any of these success signals
        if (json is Map) {
          // An explicit failure has to be checked first. These endpoints
          // answer 200 with {"success":false,"message":...} for a rejected
          // write, and the "message != null" success signal below was enough
          // to let that through as a success.
          final failed = json['success'] == false ||
              json['status'] == 'error' ||
              json['error'] == true;
          if (failed) {
            final message = json['message']?.toString() ??
                json['error']?.toString() ??
                'Request failed';
            throw ApiException(
              message,
              statusCode: response.statusCode,
              isUnauthorized: _looksUnauthorized(response.statusCode, message),
            );
          }
          final ok = json['success'] == true ||
              json['status'] == 'success' ||
              json['status'] == true ||
              json['status'] == 1 ||
              json['error'] == false ||
              json['data'] != null ||
              json['message'] != null;
          if (ok) return json;
          // Explicit failure signals
          final errMsg = json['message']?.toString() ??
              json['error']?.toString() ??
              'Request failed';
          throw ApiException(errMsg);
        }
        // If array or other type, return as-is
        return json;
      } catch (e) {
        if (e is ApiException) rethrow;

        // Check if the response was an unauthenticated / session expired HTML page
        if (_looksUnauthorized(response.statusCode, response.body)) {
          unawaited(clearSession());
          throw ApiException(
            'Your session has expired. Please sign in again.',
            statusCode: 401,
            isUnauthorized: true,
          );
        }

        // A 200 that isn't JSON means the endpoint crashed and returned an
        // HTML error page. Surface something actionable instead of the dump.
        final sqlError = _sqlErrorMessage(response.body);
        if (sqlError != null) throw ApiException(sqlError);

        // Never dump raw HTML tags / DOCTYPE / meta tags to the user!
        if (response.body.contains('<!DOCTYPE') ||
            response.body.contains('<html') ||
            response.body.contains('<head')) {
          throw ApiException(
            'The server returned an unexpected response. Please try again.',
            statusCode: response.statusCode,
          );
        }

        String snippet =
            response.body.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
        if (snippet.length > 120) snippet = '${snippet.substring(0, 120)}...';
        throw ApiException(snippet.isNotEmpty
            ? 'Server error: $snippet'
            : 'Unexpected response from server');
      }
    } else if (response.statusCode == 204) {
      return {'success': true};
    } else {
      String errorMsg = 'Server error: ${response.statusCode}';
      try {
        final json = jsonDecode(response.body);
        if (json is Map) {
          errorMsg = json['message']?.toString() ??
              json['error']?.toString() ??
              errorMsg;
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          if (response.body.contains('<!DOCTYPE') ||
              response.body.contains('<html') ||
              response.body.contains('<head')) {
            errorMsg =
                'Server error (${response.statusCode}). Please try again later.';
          } else {
            final bodyText = response.body
                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            errorMsg =
                'Error ${response.statusCode}: ${bodyText.length > 120 ? '${bodyText.substring(0, 120)}...' : bodyText}';
          }
        }
      }
      throw ApiException(
        errorMsg,
        statusCode: response.statusCode,
        isUnauthorized:
            _looksUnauthorized(response.statusCode, response.body),
      );
    }
  }
}
