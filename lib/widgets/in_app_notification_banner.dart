import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Wraps any [child] widget and overlays an animated drop-down notification
/// banner whenever a new (unread) notification arrives from the server.
///
/// The banner slides in from the top, auto-dismisses after 4 seconds, and
/// can also be dismissed by swiping up or tapping the X button.
///
/// Usage - wrap your shell/root widget:
///   InAppNotificationBanner(child: MemberShellScreen(...))
class InAppNotificationBanner extends StatefulWidget {
  final Widget child;

  const InAppNotificationBanner({super.key, required this.child});

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _anim;
  late final Animation<Offset> _slide;

  NotificationModel? _current;
  Timer? _pollTimer;
  Timer? _hideTimer;

  final Set<int> _shown = {};
  int _lastUnread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(seconds: 5), _poll);
    _startTimer();
  }

  void _startTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    _pollTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('user_id') ?? '').isEmpty) return;

    try {
      final result = await NotificationService.getNotifications();
      final List<NotificationModel> notes =
          List<NotificationModel>.from(result['notifications'] ?? []);
      final stats = Map<String, dynamic>.from(result['stats'] ?? {});
      final int unread = (stats['unread'] as num?)?.toInt() ?? 0;

      final unseen = notes.where(
        (n) => n.status == 'unread' && !_shown.contains(n.id),
      );

      if (unseen.isNotEmpty && unread >= _lastUnread) {
        _lastUnread = unread;
        _showBanner(unseen.first);
      } else {
        _lastUnread = unread;
      }
    } catch (_) {}
  }

  void _showBanner(NotificationModel note) {
    if (!mounted) return;
    _shown.add(note.id);
    setState(() => _current = note);

    _anim.forward(from: 0);

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _anim.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null) _buildBanner(context, _current!),
      ],
    );
  }

  Widget _buildBanner(BuildContext context, NotificationModel note) {
    final goldColor = AppColors.secondary;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SlideTransition(
            position: _slide,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2E5A), Color(0xFF1A4A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: goldColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          _iconForType(note.type),
                          color: goldColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6, top: 2),
                                  decoration: BoxDecoration(
                                    color: goldColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: TextStyle(
                                      color: goldColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'referral':
        return Icons.share_outlined;
      case 'r2r':
      case 'r2r_meeting':
        return Icons.handshake_outlined;
      case 'approval':
        return Icons.fact_check_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

