import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'image_viewer.dart';

/// Profile picture with a graceful fall back to the generic person glyph.
///
/// The header used to draw a hard-coded [Icons.person], so a member who had
/// uploaded a photo still saw the placeholder everywhere except the profile
/// page itself. This reads the same `avatar` value the profile screen loads
/// from `getProfile()`, and normalises it through [ImageViewer.resolveUrl] so
/// a bare stored filename resolves to a real absolute URL instead of failing
/// silently against the app's own origin.
///
/// The lookup is cached in SharedPreferences *and* de-duplicated in memory by
/// [_inflight], so putting this on a screen that rebuilds often - or in more
/// than one place at once - still results in a single profile request.
class UserAvatar extends StatefulWidget {
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  /// When set, tapping opens the full-size photo. Left null the avatar is
  /// decorative, which is what the bottom nav wants.
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.size = 28,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  static const String _cacheKey = 'cached_avatar_url';

  /// De-duplicates concurrent lookups across every mounted [UserAvatar].
  static Future<String>? _inflight;

  /// Cached for the session so a rebuild never re-hits the network.
  static String? _memo;
  static String? _memoUserId;

  /// Drops the session cache. Call after the member changes their photo,
  /// otherwise the old picture sticks until the next cold start.
  static void invalidate() {
    _memo = null;
    _memoUserId = null;
    _inflight = null;
  }

  static Future<String> _resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (_memo != null && _memo!.isNotEmpty && _memoUserId == userId) {
      return _memo!;
    }
    final cached = prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _memo = cached;
      _memoUserId = userId;
      return cached;
    }

    // Another avatar is already asking; wait on it rather than issuing a
    // second identical request.
    if (_inflight != null) return _inflight!;

    final future = _fetchAndCache();
    _inflight = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight, future)) _inflight = null;
    }
  }

  static Future<String> _fetchAndCache() async {
    try {
      // Keep the avatar call fast: prefer the cached profile URL if one exists,
      // and only request the full profile when we truly need to refresh it.
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _memo = cached;
        _memoUserId = prefs.getString('user_id') ?? '';
        return cached;
      }

      final data = await AuthService.getProfile();
      final raw = (data['avatar'] ?? '').toString().trim();
      if (raw.isEmpty) return '';
      await prefs.setString(_cacheKey, raw);
      _memo = raw;
      _memoUserId = prefs.getString('user_id') ?? '';
      return raw;
    } catch (e) {
      // A missing photo must never take down the header. Fall back to the
      // glyph and let the next mount try again.
      debugPrint('UserAvatar: could not load profile photo - $e');
      return '';
    }
  }

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String _url = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await UserAvatar._resolve();
    if (!mounted) return;
    setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    final resolved =
        _url.isEmpty ? '' : ImageViewer.resolveUrl(_url);

    final Widget avatar = ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: resolved.isNotEmpty
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                // A photo that 404s or is not an image falls back to the same
                // glyph as "no photo at all", so the avatar never renders as a
                // broken box.
                errorBuilder: (_, __, ___) => _glyph(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _glyph();
                },
              )
            : _glyph(),
      ),
    );

    if (widget.onTap == null) return avatar;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }

  Widget _glyph() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: widget.backgroundColor,
      child: Icon(
        Icons.person,
        size: widget.size * 0.6,
        color: widget.iconColor ?? AppColors.primaryLight,
      ),
    );
  }
}
