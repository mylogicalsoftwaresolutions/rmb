import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isActive;

  const NotificationsScreen({super.key, this.isActive = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showAll = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationModel> _apiList = [];
  Map<String, dynamic> _stats = {};
  Timer? _refreshTimer;
  int _lastUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    _refreshTimer?.cancel();
    if (widget.isActive) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (mounted && widget.isActive) _fetchNotifications(isBackground: true);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _startTimerIfNeeded();
      unawaited(_fetchNotifications(isBackground: _apiList.isNotEmpty));
    } else if (oldWidget.isActive && !widget.isActive) {
      _refreshTimer?.cancel();
    }
  }

  Future<void> _fetchNotifications({bool isBackground = false}) async {
    if (!isBackground && mounted && _apiList.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final data = await NotificationService.getNotifications();
      if (mounted) {
        final newStats = Map<String, dynamic>.from(data['stats'] ?? {});
        final unreadCount = int.tryParse(newStats['unread']?.toString() ?? '0') ?? 0;

        // Play sound only when a genuinely new unread notification arrives
        if (unreadCount > _lastUnreadCount && _lastUnreadCount > 0 && !kIsWeb) {
          try {
            await FlutterRingtonePlayer().playNotification();
          } catch (_) {}
        }
        _lastUnreadCount = unreadCount;

        setState(() {
          _apiList = List<NotificationModel>.from(data['notifications'] ?? []);
          _stats = newStats;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_apiList.isEmpty) {
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      setState(() {
        _apiList = _apiList
            .map((item) => NotificationModel(
                  id: item.id,
                  title: item.title,
                  message: item.message,
                  status: 'read',
                  createdAt: item.createdAt,
                  type: item.type,
                  link: item.link,
                ))
            .toList();
        _stats['unread'] = 0;
      });
      await NotificationService.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _fetchNotifications(isBackground: true);
      }
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    setState(() {
      _apiList.removeWhere((item) => item.id.toString() == id);
      final unread = _apiList.where((item) => item.status == 'unread').length;
      _stats['unread'] = unread;
      _stats['total'] = _apiList.length;
    });

    try {
      await NotificationService.deleteNotification(id);
    } catch (e) {
      debugPrint('Delete action error: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openNotification(NotificationModel item) {
    if (item.status == 'unread') {
      setState(() {
        final index = _apiList.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _apiList[index] = NotificationModel(
            id: item.id,
            title: item.title,
            message: item.message,
            status: 'read',
            createdAt: item.createdAt,
            type: item.type,
            link: item.link,
          );
          final unread = _apiList.where((n) => n.status == 'unread').length;
          _stats['unread'] = unread;
        }
      });
      NotificationService.markAsRead(item.id.toString());
    }

    final hasLink = item.link.trim().isNotEmpty;
    final displayMsg = item.message.trim().isNotEmpty
        ? item.message.trim()
        : (item.title.trim().isNotEmpty ? item.title.trim() : 'Notification details');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppUI.pageBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(_iconForType(item.type), color: AppColors.secondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: AppUI.headingText(size: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.displayDateTime.isNotEmpty) ...[
              Text(
                item.displayDateTime,
                style: AppUI.mutedText(size: 11),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              displayMsg,
              style: AppUI.bodyText(size: 14),
            ),
          ],
        ),
        actions: [
          if (hasLink)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final uri = Uri.tryParse(item.link.trim());
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View Link'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppUI.muted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final unreadCount = int.tryParse(_stats['unread']?.toString() ?? '0') ?? 0;
    final filteredList = _apiList.where((item) {
      if (_showAll) return true;
      return item.status == 'unread';
    }).toList();

    return Scaffold(
      backgroundColor: AppUI.pageBg,
      body: RefreshIndicator(
        color: goldColor,
        onRefresh: _fetchNotifications,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$unreadCount unread notifications",
                    style: AppUI.bodyText(size: 13, weight: FontWeight.w600),
                  ),
                  if (_apiList.isNotEmpty && unreadCount > 0)
                    InkWell(
                      onTap: _markAllRead,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: goldColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: goldColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "Mark All Read",
                              style: TextStyle(
                                color: goldColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Toggle Tabs
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showAll = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showAll ? goldColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _showAll ? goldColor : AppColors.border),
                      ),
                      child: Text(
                        "All (${_apiList.length})",
                        style: TextStyle(
                          color: _showAll ? Colors.white : AppUI.body,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showAll = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showAll ? goldColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: !_showAll ? goldColor : AppColors.border),
                      ),
                      child: Text(
                        "Unread ($unreadCount)",
                        style: TextStyle(
                          color: !_showAll ? Colors.white : AppUI.body,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notifications List Body
              if (_isLoading && _apiList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: CircularProgressIndicator(color: goldColor),
                  ),
                )
              else if (_errorMessage != null && _apiList.isEmpty)
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: goldColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _fetchNotifications(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_apiList.isEmpty)
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications found.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: goldColor,
                            side: BorderSide(color: goldColor),
                          ),
                          onPressed: () => _fetchNotifications(),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredList.isEmpty)
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.mark_email_read_outlined, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No unread notifications.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: goldColor,
                            side: BorderSide(color: goldColor),
                          ),
                          onPressed: () => setState(() => _showAll = true),
                          child: const Text('View All Notifications'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildNotificationCard(
                      item: item,
                      onDelete: () => _deleteNotification(item.id.toString()),
                      onOpen: () => _openNotification(item),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final lower = type.toLowerCase();
    switch (lower) {
      case 'birthday':
        return Icons.cake;
      case 'anniversary':
      case 'wedding_anniversary':
        return Icons.favorite;
      case 'referral':
        return Icons.share_outlined;
      case 'r2r':
      case 'r2r_meeting':
        return Icons.handshake_outlined;
      case 'approval':
        return Icons.fact_check_outlined;
      case 'meeting_reminder':
      case 'meeting':
        return Icons.calendar_today_outlined;
      case 'upcoming_event':
      case 'event':
        return Icons.event_outlined;
      case 'cnotes':
      case 'cnote':
        return Icons.receipt_long;
      case 'testimonial':
        return Icons.record_voice_over_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Widget _buildNotificationCard({
    required NotificationModel item,
    required VoidCallback onDelete,
    required VoidCallback onOpen,
  }) {
    final isUnread = item.status == 'unread';
    final title = item.title.trim().isNotEmpty ? item.title.trim() : 'Notification';
    final time = item.displayDateTime;
    // Always provide a non-empty message so notifications data and message text show reliably
    final message = item.message.trim().isNotEmpty
        ? item.message.trim()
        : (item.title.trim().isNotEmpty ? item.title.trim() : 'Notification details');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          border: Border.all(
            color: isUnread ? AppColors.secondary : AppColors.border,
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: AppUI.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isUnread ? AppColors.secondary : AppColors.textMuted).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(item.type),
                color: isUnread ? AppColors.secondary : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppUI.headingText(size: 13),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            time,
                            style: AppUI.mutedText(size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: isUnread
                        ? AppUI.bodyText(size: 12, weight: FontWeight.w500)
                        : AppUI.mutedText(size: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onOpen,
                        child: Text(
                          item.link.isNotEmpty ? "View Details" : "Open",
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.lightBlueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("•", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.redAccent,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
