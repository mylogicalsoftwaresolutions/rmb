import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/activity_service.dart';
import '../models/user_model.dart';
import '../services/member_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/activity_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'testimonial_certificate_screen.dart';
import '../widgets/app_error_view.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/image_viewer.dart';

Color goldColor = AppColors.secondary;
final Color cardBgColor = AppColors.card;
Color darkCardColor = AppColors.card;

/// Error state for a list screen, with a retry.
///
/// These screens used to render the failure as a bare red line of text, which
/// left a member staring at a dead screen with no way back other than leaving
/// and re-entering. Reuses [AppErrorView] so it matches the rest of the app.
class _ListErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ListErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: AppErrorView(message: message, onRetry: () => onRetry()),
    );
  }
}

/// Given by Me / Received by Me tab.
/// Blue label by default, gold on hover, gold fill when active.
/// "No records found" panel: white card with a blue outline on the white
/// theme, blue card with a yellow outline on the blue theme.
class _NoRecordsCard extends StatelessWidget {
  final String message;
  const _NoRecordsCard() : message = 'No records found.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: AppColors.accentBorder, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onCard,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatefulWidget {
  final String label;
  final bool isActive;
  final BorderRadius radius;
  final bool whiteTheme;
  final VoidCallback onTap;

  const _ToggleTab(
      {required this.label,
      required this.isActive,
      required this.radius,
      this.whiteTheme = false,
      required this.onTap});

  @override
  State<_ToggleTab> createState() => _ToggleTabState();
}

class _ToggleTabState extends State<_ToggleTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.whiteTheme
        ? widget.isActive
            ? Colors.white
            : _hovered
                ? AppColors.secondary
                : AppColors.primary
        : widget.isActive
            ? Colors.white
            : _hovered
                ? AppColors.secondary
                : AppColors.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive ? AppColors.primary : Colors.white,
            borderRadius: widget.radius,
            border: Border.all(
              color: widget.isActive
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.3),
              width: widget.isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: widget.isActive ? 0.18 : 0.06),
                blurRadius: widget.isActive ? 10 : 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color iconColor;
  final IconData icon;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.iconColor,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: 1),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: TextStyle(
                            color: AppColors.cardHeading,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: TextStyle(
                            color: AppColors.onCard,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.cardHeading, size: 20),
          ),
        ],
      ),
    );
  }
}

/// A single Edit button, styled like the old "Actions" pill.
///
/// Delete used to live here too, but referrals.php and r2r.php both ignore
/// the DELETE verb and answer success anyway - so it looked like it worked
/// and never actually removed anything server-side. Offering a button that
/// cannot do what it says is worse than not offering it; removed until the
/// API implements delete for real.
///
/// Referrals get Approve/Reject buttons here instead of Edit. R2R has no
/// action at all now - editing an R2R meeting was removed on request.
Widget _buildItemActions(BuildContext context, ActivityModel item,
    {VoidCallback? onActionComplete, Function(ActivityModel)? onEdit}) {
  if (item.type == 'referral') {
    return _ReferralApprovalButtons(
        item: item, onActionComplete: onActionComplete);
  }
  if (item.type == 'r2r') {
    return const SizedBox.shrink();
  }
  // visitors.php only implements create + list: an update POST comes back
  // 400 "Invalid action", so an Edit button here could never do anything
  // but fail. Hidden until the server supports updating an invite.
  if (item.type == 'visitor') {
    return const SizedBox.shrink();
  }

  return GestureDetector(
    onTap: () {
      if (onEdit != null) {
        onEdit(item);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Edit action not fully implemented for this type'),
            backgroundColor: Colors.blueAccent));
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, color: AppColors.navAccent, size: 16),
          const SizedBox(width: 6),
          Text('Edit',
              style: TextStyle(
                  color: AppColors.navAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

/// Tick to approve / cross to reject a referral, with an honest
/// success-or-failure message rather than assuming the write took effect -
/// referrals.php has already been caught once accepting a write and not
/// applying it, so ActivityService.setReferralStatus re-checks before this
/// reports success.
class _ReferralApprovalButtons extends StatefulWidget {
  final ActivityModel item;
  final VoidCallback? onActionComplete;

  const _ReferralApprovalButtons({required this.item, this.onActionComplete});

  @override
  State<_ReferralApprovalButtons> createState() =>
      _ReferralApprovalButtonsState();
}

class _ReferralApprovalButtonsState extends State<_ReferralApprovalButtons> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ActivityService.setReferralStatus(
          widget.item.id.toString(), status);
      final label = status == 'success' ? 'Successful' : 'Failed';
      messenger.showSnackBar(SnackBar(
        content: Text('Referral marked as $label.'),
        backgroundColor: Colors.green,
      ));
      widget.onActionComplete?.call();
    } catch (e) {
      // The endpoint answers 401 "Unauthorized. user_id is missing or
      // invalid." when the signed-in id never made it into the body. That is
      // a session problem, not something the member can retry away, so say
      // what to do instead of echoing the raw server text back at them.
      final reason = e is ApiException
          ? (e.isUnauthorized
              ? 'Your session has expired. Please log in again to update '
                  'this referral.'
              : e.message.trim())
          : e.toString().replaceAll('Exception: ', '');
      messenger.showSnackBar(SnackBar(
        content: Text(
          reason.isEmpty ? 'Could not update this referral.' : reason,
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _circle(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.2),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Once a referral has been marked success or failure, the outcome is
    // already shown by the card's status badge - leaving the tick/cross
    // here would let a member "approve" an already-rejected referral (or
    // vice versa) with no indication anything had already happened.
    //
    // Only success/failure hide the buttons. referrals.php creates every new
    // row already as 'approved', so treating 'approved' as a decided outcome
    // would hide the buttons on every freshly created referral and leave the
    // member with no way to action it at all.
    final status =
        (widget.item.rawJson['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'success' || status == 'failure') {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(Icons.check, Colors.green, () => _setStatus('success')),
        const SizedBox(width: 10),
        _circle(Icons.close, Colors.redAccent, () => _setStatus('failure')),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yellow on blue, matching the bottom bar's accent.
            Icon(Icons.add, color: AppColors.navAccent, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: AppColors.navAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class ReferralsScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;
  final bool initialGivenByMe;
  final bool givenOnly;
  final bool receivedOnly;
  /// Dashboard referral views use the normal two-list data source but show
  /// only the list and its Given/Received selector.
  final bool listOnly;
  const ReferralsScreen(
      {super.key,
      required this.onOpenSubmit,
      this.onEditItem,
      this.initialGivenByMe = true,
      this.givenOnly = false,
      this.receivedOnly = false,
      this.listOnly = false});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  String _searchQuery = '';
  String _selectedPeriod = 'This week';
  late bool _givenByMe;
  bool _isLoading = true;
  String? _errorMessage;

  List<ActivityModel> _givenList = [];
  List<ActivityModel> _receivedList = [];

  /// referrals.php carries no name or category — only `received_by` as an id.
  /// members.php has both, so resolve through it.
  Map<String, UserModel> _memberById = {};

  DateTime? _parseActivityDate(String raw) {
    if (raw.trim().isEmpty || raw.trim() == 'null' || raw.trim() == '—') {
      return null;
    }
    final value = raw.trim().split(RegExp(r'[ T]')).first;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(value);
    if (dmy == null) return null;
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  DateTime? _itemDate(ActivityModel record) {
    final created = record.rawJson['created_at'] ??
        record.rawJson['createdAt'] ??
        record.rawJson['referral_date'] ??
        record.rawJson['entry_date'] ??
        record.date;
    return _parseActivityDate(created?.toString() ?? '');
  }

  bool _matchesPeriod(ActivityModel item) {
    if (_selectedPeriod == 'All') return true;
    final date = _itemDate(item);
    if (date == null) return true;

    final now = DateTime.now();
    if (_selectedPeriod == 'This week') {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 7));
      return !date.isBefore(start) && date.isBefore(end);
    } else if (_selectedPeriod == 'This month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      return !date.isBefore(start) && date.isBefore(end);
    }
    return true;
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isDense: true,
          dropdownColor: AppColors.card,
          style: TextStyle(color: AppColors.onCard, fontSize: 12),
          icon: Icon(Icons.keyboard_arrow_down, color: goldColor, size: 18),
          items: const [
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'All', child: Text('All')),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _selectedPeriod = value);
            }
          },
        ),
      ),
    );
  }

  UserModel? _memberFor(ActivityModel item) {
    final id = (item.rawJson['received_by'] ??
            item.rawJson['member_id'] ??
            item.rawJson['to_user_id'] ??
            item.rawJson['to_member_id'] ??
            item.rawJson['recipient_id'] ??
            item.rawJson['receiver_id'])
        ?.toString();
    if (id == null || id.isEmpty || id == 'null') return null;
    return _memberById[id];
  }

  UserModel? _giverMemberFor(ActivityModel item) {
    final id = (item.rawJson['given_by'] ??
            item.rawJson['from_user_id'] ??
            item.rawJson['from_member_id'] ??
            item.rawJson['sender_id'] ??
            item.rawJson['giver_id'] ??
            item.rawJson['user_id'])
        ?.toString();
    if (id == null || id.isEmpty || id == 'null') return null;
    return _memberById[id];
  }

  List<ActivityModel> get _currentList {
    final list = _givenByMe ? _givenList : _receivedList;
    final periodFiltered = list.where(_matchesPeriod).toList();
    if (_searchQuery.isEmpty) return periodFiltered;
    return periodFiltered
        .where((item) => item.rawJson
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  bool _sameUser(dynamic value, String userId) {
    final left = value?.toString().trim() ?? '';
    final right = userId.trim();
    if (left.isEmpty || right.isEmpty || left == 'null') return false;
    return left == right ||
        (int.tryParse(left) != null && int.tryParse(right) != null &&
            int.parse(left) == int.parse(right));
  }

  String _dateOnly(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '—';
    return raw.split(RegExp(r'[ T]')).first;
  }

  /// Keep the summary cards tied to the active tab. The API summary belongs to
  /// its default (given) response, so reusing it for Received by Me made a
  /// successful tab switch appear not to change anything.
  Map<String, int> get _currentStats {
    var pending = 0;
    var success = 0;
    var failure = 0;
    for (final item in _currentList) {
      // A newly-created referral is `approved` on this API, but that means it
      // is awaiting the receiver's success/failure decision, so it is Pending
      // in the member-facing summary. Handle legacy spelling variants too.
      switch ((item.rawJson['status'] ?? item.status)
          .toString()
          .trim()
          .toLowerCase()) {
        case 'success':
        case 'successful':
          success++;
          break;
        case 'rejected':
        case 'failure':
        case 'failed':
        case 'declined':
        case 'cancelled':
        case 'canceled':
          failure++;
          break;
        default:
          pending++;
      }
    }
    return {
      'total': _currentList.length,
      'pending': pending,
      'success': success,
      'failure': failure,
    };
  }

  void _selectView(bool givenByMe) {
    if (_givenByMe == givenByMe) return;
    setState(() {
      _givenByMe = givenByMe;
      _searchQuery = '';
    });
  }

  @override
  void initState() {
    super.initState();
    _givenByMe = widget.initialGivenByMe;
    _fetchData();
  }

  Future<void> _fetchData() async {
    // These are also called straight after `await widget.onOpenSubmit()`, so
    // the screen can already be gone by the time this runs - calling setState
    // then throws "setState() called after dispose()". The shell also rebuilds
    // this screen with a new ValueKey on every refresh, which disposes it.
    if (!mounted) return;
    if (_givenList.isEmpty && _receivedList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final givenData = await ActivityService.getActivities(
        'referrals.php',
        'referral',
        extraParams: const {'action': 'list_given'},
      );
      final givenResponse =
          List<ActivityModel>.from(givenData['activities'] ?? []);
      final myUserId = await ApiClient.getUserId();
      final receivedData = await ActivityService.getActivities(
        'referrals.php',
        'referral',
        extraParams: const {'action': 'list_received'},
      );
      final receivedResponses =
          List<ActivityModel>.from(receivedData['activities'] ?? []);

      // Do not rely only on the API query parameter: older deployments have
      // returned the same response for both requests.  A referral belongs in
      // exactly one tab based on its stored sender/recipient IDs.
      final allResponses = <int, ActivityModel>{};
      for (final item in [...givenResponse, ...receivedResponses]) {
        allResponses[item.id] = item;
      }
      final allReferrals = allResponses.values.toList();
      // Legacy referrals view: the list contains both given and received
      // referrals; there is no client-side tab split in this mode.
      final given = widget.givenOnly
          ? givenResponse.where((item) {
              final sender = item.rawJson['given_by'];
              return sender == null || _sameUser(sender, myUserId);
            }).toList()
          : widget.receivedOnly
              ? allReferrals.where((item) => _sameUser(
                  item.rawJson['received_by'] ??
                      item.rawJson['member_id'] ??
                      item.rawJson['to_user_id'] ??
                      item.rawJson['to_member_id'] ??
                      item.rawJson['recipient_id'] ??
                      item.rawJson['receiver_id'],
                  myUserId)).toList()
              : givenResponse;
      final received = allReferrals
          .where((item) => _sameUser(
              item.rawJson['received_by'] ??
                  item.rawJson['member_id'] ??
                  item.rawJson['to_user_id'] ??
                  item.rawJson['to_member_id'] ??
                  item.rawJson['recipient_id'] ??
                  item.rawJson['receiver_id'],
              myUserId))
          .toList();
      try {
        final members = await MemberService.getAllMembers();
        _memberById = {for (final m in members) m.id.toString(): m};
      } catch (_) {
        // Leave the map empty; the row falls back to the raw values.
      }

      // members.php is hard-capped at 50 rows org-wide, so a receiving
      // member outside that window never resolves through the bulk map
      // above and "To" is left blank. members.php?id=<id> bypasses the cap
      // for a single known id - the same fallback already used for R2R's
      // partner name.
      final missingIds = allReferrals
          .expand((a) => [
                a.rawJson['received_by'],
                a.rawJson['member_id'],
                a.rawJson['to_user_id'],
                a.rawJson['to_member_id'],
                a.rawJson['recipient_id'],
                a.rawJson['receiver_id'],
                a.rawJson['given_by'],
                a.rawJson['from_user_id'],
                a.rawJson['from_member_id'],
                a.rawJson['sender_id'],
                a.rawJson['giver_id'],
                a.rawJson['user_id'],
              ])
          .map((id) => id?.toString())
          .whereType<String>()
          .where((id) =>
              id.isNotEmpty && id != 'null' && !_memberById.containsKey(id))
          .toSet();
      if (missingIds.isNotEmpty) {
        final fetched = await Future.wait(missingIds.map((id) async {
          try {
            final detail = await MemberService.getMemberDetail(int.parse(id));
            return MapEntry(id, UserModel.fromJson(detail));
          } catch (_) {
            return null;
          }
        }));
        for (final entry in fetched) {
          if (entry != null) _memberById[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() {
          _givenList = given;
          _receivedList = received;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonLoader();
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.listOnly && !widget.givenOnly) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.receivedOnly ? 'Received Referrals' : 'Referrals',
                            style: TextStyle(
                                color: AppColors.cardHeading,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            widget.receivedOnly
                                ? 'Only referrals received by you'
                                : "Submit and track referrals you've given to fellow members",
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodDropdown(),
                ],
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                  label: 'New Referral',
                  onTap: () => widget.onOpenSubmit()),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: 1.25,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(title: 'Total', value: '${_currentStats['total']}', iconColor: Colors.orange, icon: Icons.share),
                  _StatCard(title: 'Pending', value: '${_currentStats['pending']}', iconColor: Colors.amber, icon: Icons.hourglass_empty),
                  _StatCard(title: 'Success', value: '${_currentStats['success']}', iconColor: Colors.greenAccent, icon: Icons.check_circle),
                  _StatCard(title: 'Failure', value: '${_currentStats['failure']}', iconColor: Colors.redAccent, icon: Icons.cancel),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (widget.listOnly) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.receivedOnly ? 'Received Referrals' : 'Referrals',
                    style: TextStyle(
                      color: AppColors.cardHeading,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPeriodDropdown(),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.receivedOnly) ...[
              Row(
                children: [
                  Expanded(
                    child: _ToggleTab(
                      label: 'Given by Me',
                      isActive: _givenByMe,
                      whiteTheme: true,
                      radius: const BorderRadius.horizontal(
                          left: Radius.circular(8)),
                      onTap: () => _selectView(true),
                    ),
                  ),
                  Expanded(
                    child: _ToggleTab(
                      label: 'Received by Me',
                      isActive: !_givenByMe,
                      whiteTheme: true,
                      radius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                      onTap: () => _selectView(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.searchBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Show ",
                              style: TextStyle(
                                  color: AppColors.onCardMuted, fontSize: 11)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: AppColors.searchBorder)),
                            child: Text("${_currentList.length}",
                                style: TextStyle(
                                    color: AppColors.onCard, fontSize: 11)),
                          ),
                        ],
                      ),
                      Container(
                        width: 120,
                        height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.searchBorder)),
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style:
                              TextStyle(color: AppColors.onCard, fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Search records...',
                            hintStyle: TextStyle(
                                color: AppColors.onCardLabel, fontSize: 10),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _ListErrorRetry(
                        message: _errorMessage!, onRetry: _fetchData)
                  else if (_currentList.isEmpty && !_isLoading)
                    const _NoRecordsCard()
                  else if (!_isLoading)
                    ..._currentList.map((item) {
                      // Resolve the recipient and giver through the member list; the
                      // referral row itself only carries an id.
                      final recipientMember = _memberFor(item);
                      final giverMember = _giverMemberFor(item);
                      final activeMember =
                          _givenByMe ? recipientMember : (giverMember ?? recipientMember);
                      final partyLabel = _givenByMe ? 'To' : 'From';

                      // "To" is the fellow member the referral was handed to -
                      // it must never fall back to external_name (the
                      // prospect's own name, shown separately below as
                      // "Referral"), or the card would show the wrong name in
                      // the member's slot whenever the member fails to resolve.
                      final to = (item.rawJson['to_member_name'] ??
                              item.rawJson['received_by_name'] ??
                              item.rawJson['member_name'] ??
                              recipientMember?.name ??
                              '')
                          .toString();
                      final from = (item.rawJson['from_member_name'] ??
                              item.rawJson['given_by_name'] ??
                              item.rawJson['sender_name'] ??
                              giverMember?.name ??
                              '')
                          .toString();
                      final memberDisplayName = _givenByMe
                          ? (to.trim().isNotEmpty ? to : '—')
                          : (from.trim().isNotEmpty
                              ? from
                              : (to.trim().isNotEmpty ? to : '—'));

                      // User phone intentionally hidden per request (only referral phone shown)
                      final _ = (activeMember?.mobile.isNotEmpty == true &&
                                  activeMember?.mobile != 'N/A'
                              ? activeMember!.mobile
                              : (_givenByMe
                                  ? (item.rawJson['to_member_mobile'] ??
                                      item.rawJson['to_member_phone'] ??
                                      item.rawJson['receiver_mobile'] ??
                                      item.rawJson['receiver_phone'] ??
                                      item.rawJson['member_mobile'] ??
                                      item.rawJson['member_phone'] ??
                                      item.rawJson['mobile'] ??
                                      '')
                                  : (item.rawJson['from_member_mobile'] ??
                                      item.rawJson['from_member_phone'] ??
                                      item.rawJson['giver_mobile'] ??
                                      item.rawJson['giver_phone'] ??
                                      item.rawJson['sender_mobile'] ??
                                      item.rawJson['sender_phone'] ??
                                      item.rawJson['member_mobile'] ??
                                      item.rawJson['member_phone'] ??
                                      item.rawJson['mobile'] ??
                                      '')))
                          .toString()
                          .trim();

                      final category = (item.rawJson['business_category'] ??
                              item.rawJson['category'] ??
                              activeMember?.businessCategory ??
                              '')
                          .toString();
                      final rawType = (item.rawJson['referral_type'] ??
                              item.rawJson['type'] ??
                              '')
                          .toString()
                          .trim()
                          .toLowerCase();
                      final type = (rawType.contains('ext') ||
                              rawType.contains('other'))
                          ? 'Other Chapter'
                          : 'Same Chapter';
                      final date = _dateOnly(item.rawJson['referral_date'] ??
                          item.rawJson['entry_date'] ??
                          item.rawJson['created_at'] ??
                          item.date);
                      // The prospect/client the referral is actually for -
                      // separate from "To" above, which is the fellow member
                      // it was handed to.
                      final referralName = (item.rawJson['external_name'] ??
                              item.rawJson['client_name'] ??
                              item.rawJson['referral_name'] ??
                              item.rawJson['visitor_name'] ??
                              '')
                          .toString();

                      final referralPhone = (item.rawJson['external_mobile'] ??
                              item.rawJson['external_phone'] ??
                              item.rawJson['referral_phone'] ??
                              item.rawJson['phone'] ??
                              '')
                          .toString()
                          .trim();
                      final description = (item.rawJson['description'] ??
                              item.rawJson['details'] ??
                              item.rawJson['comments'] ??
                              item.rawJson['notes'] ??
                              item.rawJson['referral_description'] ??
                              item.description ??
                              '')
                          .toString()
                          .trim();
                      // The badge used to hardcode "Approved" regardless of the
                      // record's actual status, so a pending/failed referral
                      // still looked accepted. The live API uses
                      // "success"/"failure" for this field, not
                      // "approved"/"rejected" - confirmed directly against
                      // referrals.php action=update_status.
                      final rawStatus = (item.rawJson['status'] ?? 'pending')
                          .toString()
                          .trim()
                          .toLowerCase();
                      // referrals.php creates a new row as `approved`, but
                      // the receiver still has to mark it Success or Failure.
                      // Treat that server default as Pending in the member UI.
                      final statusLabel = rawStatus.isEmpty || rawStatus == 'approved'
                          ? 'Pending'
                          : rawStatus[0].toUpperCase() + rawStatus.substring(1);
                      final statusColor = rawStatus == 'success'
                          ? Colors.lightGreen
                          : rawStatus == 'failure' || rawStatus == 'rejected'
                              ? Colors.redAccent
                              : Colors.amber;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // Record rows: white on the white theme, blue on the blue theme.
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accentBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                                spreadRadius: 1),
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(date,
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(statusLabel,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                  color: AppColors.onRecordCardDivider,
                                  height: 1),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.person,
                                    color: AppColors.onRecordCardLabel,
                                    size: 16),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 80,
                                    child: Text(partyLabel,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            memberDisplayName.trim().isEmpty
                                                ? '—'
                                                : memberDisplayName,
                                            style: TextStyle(
                                                color: AppColors.onRecordCard,
                                                fontSize: 16)),
                                      ],
                                    )),
                              ],
                            ),
                            if (referralName.trim().isNotEmpty ||
                                (referralPhone.isNotEmpty &&
                                    referralPhone != 'null' &&
                                    referralPhone != 'N/A')) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.badge_outlined,
                                      color: AppColors.onRecordCardLabel,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 80,
                                      child: Text('Referral',
                                          style: TextStyle(
                                              color:
                                                  AppColors.onRecordCardLabel,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600))),
                                  Text(":",
                                      style: TextStyle(
                                          color: AppColors.onRecordCardLabel,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (referralName.trim().isNotEmpty)
                                            Text(referralName,
                                                style: TextStyle(
                                                    color: AppColors.onRecordCard,
                                                    fontSize: 16)),
                                          if (referralPhone.isNotEmpty &&
                                              referralPhone != 'null' &&
                                              referralPhone != 'N/A') ...[
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: () async {
                                                final digits =
                                                    referralPhone.replaceAll(
                                                        RegExp(r'[^0-9+]'), '');
                                                if (digits.isNotEmpty) {
                                                  final uri =
                                                      Uri.parse('tel:$digits');
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(uri,
                                                        mode: LaunchMode
                                                            .externalApplication);
                                                  }
                                                }
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.phone,
                                                      size: 13,
                                                      color:
                                                          AppColors.secondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    referralPhone,
                                                    style: TextStyle(
                                                        color: AppColors
                                                            .onRecordCardMuted,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      )),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.category,
                                    color: AppColors.onRecordCardLabel,
                                    size: 16),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 80,
                                    child: Text('Category',
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        category.trim().isEmpty
                                            ? '—'
                                            : category,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 16))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.compare_arrows,
                                    color: AppColors.onRecordCardLabel,
                                    size: 16),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 80,
                                    child: Text('Type',
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(type,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 16))),
                              ],
                            ),
                            if (description.isNotEmpty &&
                                description != 'null' &&
                                description != '—') ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.description_outlined,
                                      color: AppColors.onRecordCardLabel,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 80,
                                      child: Text('Description',
                                          style: TextStyle(
                                              color:
                                                  AppColors.onRecordCardLabel,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600))),
                                  Text(":",
                                      style: TextStyle(
                                          color: AppColors.onRecordCardLabel,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(description,
                                          style: TextStyle(
                                              color: AppColors.onRecordCard,
                                              fontSize: 15),
                                          softWrap: true)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildItemActions(context, item, onEdit: (act) {
                                  if (widget.onEditItem != null) {
                                    widget.onEditItem!(act);
                                  }
                                }, onActionComplete: _fetchData),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Center(
                      child: Text("Showing ${_currentList.length} records",
                          style: TextStyle(
                              color: AppColors.onCardLabel, fontSize: 11))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(4))),
                        child: Icon(Icons.chevron_left,
                            color: AppColors.onCard, size: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: const Color(0xFF0D6EFD),
                        child: const Text("1",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4))),
                        child: Icon(Icons.chevron_right,
                            color: AppColors.onCard, size: 14),
                      ),
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

class CNotesScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;
  final bool initialGivenByMe;
  /// Dashboard business cards open the compact list page, matching referrals.
  final bool listOnly;
  const CNotesScreen(
      {super.key,
      required this.onOpenSubmit,
      this.onEditItem,
      this.initialGivenByMe = true,
      this.listOnly = false});

  @override
  State<CNotesScreen> createState() => _CNotesScreenState();
}

class _CNotesScreenState extends State<CNotesScreen> {
  String _searchQuery = '';
  String _selectedPeriod = 'This week';
  late bool _givenByMe;
  bool _isLoading = true;
  String? _errorMessage;

  List<ActivityModel> _givenList = [];
  List<ActivityModel> _receivedList = [];
  Map<String, dynamic> _stats = {};

  /// id -> member, so the card shows a name instead of the raw id.
  Map<String, UserModel> _memberById = {};
  String _myUserId = '';

  DateTime? _parseActivityDate(String raw) {
    if (raw.trim().isEmpty || raw.trim() == 'null' || raw.trim() == '—') {
      return null;
    }
    final value = raw.trim().split(RegExp(r'[ T]')).first;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(value);
    if (dmy == null) return null;
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  DateTime? _itemDate(ActivityModel record) {
    final created = record.rawJson['created_at'] ??
        record.rawJson['createdAt'] ??
        record.rawJson['meeting_date'] ??
        record.rawJson['cnote_date'] ??
        record.rawJson['entry_date'] ??
        record.date;
    return _parseActivityDate(created?.toString() ?? '');
  }

  bool _matchesPeriod(ActivityModel item) {
    if (_selectedPeriod == 'All') return true;
    final date = _itemDate(item);
    if (date == null) return true;

    final now = DateTime.now();
    if (_selectedPeriod == 'This week') {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 7));
      return !date.isBefore(start) && date.isBefore(end);
    } else if (_selectedPeriod == 'This month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      return !date.isBefore(start) && date.isBefore(end);
    }
    return true;
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isDense: true,
          dropdownColor: AppColors.card,
          style: TextStyle(color: AppColors.onCard, fontSize: 12),
          icon: Icon(Icons.keyboard_arrow_down, color: goldColor, size: 18),
          items: const [
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'All', child: Text('All')),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _selectedPeriod = value);
            }
          },
        ),
      ),
    );
  }

  List<ActivityModel> get _filteredGivenList =>
      _givenList.where(_matchesPeriod).toList();
  List<ActivityModel> get _filteredReceivedList =>
      _receivedList.where(_matchesPeriod).toList();

  @override
  void didUpdateWidget(covariant CNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGivenByMe != widget.initialGivenByMe) {
      setState(() {
        _givenByMe = widget.initialGivenByMe;
      });
    }
  }

  /// IDs in deployed C-Notes responses are not consistent: some are numbers
  /// while others are strings. Compare their value rather than their JSON
  /// representation so dashboard cards always open only this member's rows.
  bool _sameUser(dynamic value, String userId) {
    final left = value?.toString().trim() ?? '';
    final right = userId.trim();
    if (left.isEmpty || right.isEmpty || left == 'null') return false;
    return left == right ||
        (int.tryParse(left) != null && int.tryParse(right) != null &&
            int.parse(left) == int.parse(right));
  }

  dynamic _receivedBy(ActivityModel item) => item.rawJson['received_by'] ??
      item.rawJson['member_id'] ??
      item.rawJson['to_user_id'] ??
      item.rawJson['to_member_id'] ??
      item.rawJson['recipient_id'] ??
      item.rawJson['receiver_id'];

  List<ActivityModel> get _currentList {
    final list = _givenByMe ? _filteredGivenList : _filteredReceivedList;
    if (_searchQuery.isEmpty) return list;
    return list
        .where((item) => item.rawJson
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _money(dynamic v) =>
      (double.tryParse(v?.toString() ?? '0') ?? 0).toStringAsFixed(2);

  double _totalAmount(Iterable<ActivityModel> records) =>
      records.fold(0, (total, item) => total + item.amount);

  /// C-Note cards show the business date only. The API may return a SQL
  /// datetime (for example `2026-09-30 14:25:00`) in `created_at`.
  String _dateOnly(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '—';
    return raw.split(RegExp(r'[ T]')).first;
  }

  @override
  void initState() {
    super.initState();
    _givenByMe = widget.initialGivenByMe;
    _fetchData();
  }

  Future<void> _fetchData() async {
    // These are also called straight after `await widget.onOpenSubmit()`, so
    // the screen can already be gone by the time this runs - calling setState
    // then throws "setState() called after dispose()". The shell also rebuilds
    // this screen with a new ValueKey on every refresh, which disposes it.
    if (!mounted) return;
    if (_givenList.isEmpty && _receivedList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final allData =
          await ActivityService.getActivities('cnotes.php', 'cnote');
      final givenResponses = <ActivityModel>[
        ...List<ActivityModel>.from(allData['activities'] ?? []),
      ];
      try {
        // Keep this explicit for APIs that return an organisation-wide default
        // list rather than the signed-in member's given C-Notes.
        final givenData = await ActivityService.getActivities(
          'cnotes.php',
          'cnote',
          extraParams: const {'action': 'list_given'},
        );
        givenResponses.addAll(
            List<ActivityModel>.from(givenData['activities'] ?? []));
      } catch (_) {}
      final receivedResponses = <ActivityModel>[];
      try {
        // The default response can contain only given C-Notes. Request the
        // received scope separately so its rows are available to the tab.
        final receivedData = await ActivityService.getActivities(
          'cnotes.php',
          'cnote',
          extraParams: const {'type': 'received'},
        );
        receivedResponses.addAll(
            List<ActivityModel>.from(receivedData['activities'] ?? []));
      } catch (_) {}
      try {
        // Some deployed C-Notes APIs use the same named-list convention as
        // referrals.php instead of the type query parameter.
        final receivedData = await ActivityService.getActivities(
          'cnotes.php',
          'cnote',
          extraParams: const {'action': 'list_received'},
        );
        receivedResponses.addAll(
            List<ActivityModel>.from(receivedData['activities'] ?? []));
      } catch (_) {}
      try {
        final members = await MemberService.getAllMembers();
        _memberById = {for (final m in members) m.id.toString(): m};
      } catch (_) {
        // Falls back to whatever the row carries.
      }
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      _myUserId = userId;

      final all = <int, ActivityModel>{
        for (final item in [...givenResponses, ...receivedResponses])
          item.id: item,
      }.values.toList();

      final missingIds = [
        ...all.map((a) => a.rawJson['given_by']?.toString()),
        ...all.map((a) => a.rawJson['created_by']?.toString()),
        ...all.map((a) => a.rawJson['user_id']?.toString()),
        ...all.map((a) => a.rawJson['from_member_id']?.toString()),
        ...all.map((a) => _receivedBy(a)?.toString()),
      ]
          .whereType<String>()
          .where((id) =>
              id.isNotEmpty && id != 'null' && !_memberById.containsKey(id))
          .toSet();
      if (missingIds.isNotEmpty) {
        final fetched = await Future.wait(missingIds.map((id) async {
          try {
            final detail = await MemberService.getMemberDetail(int.parse(id));
            return MapEntry(id, UserModel.fromJson(detail));
          } catch (_) {
            return null;
          }
        }));
        for (final entry in fetched) {
          if (entry != null) _memberById[entry.key] = entry.value;
        }
      }
        final given = all
            .where((a) => _sameUser(a.rawJson['given_by'], userId))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
        final received = all
            .where((a) => _sameUser(_receivedBy(a), userId))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
        setState(() {
          _givenList = given;
          _receivedList = received;
          _stats = allData['stats'] ?? {};
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonLoader();
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.listOnly) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C-Notes',
                          style: TextStyle(
                            color: AppColors.cardHeading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Record and track closed business (thank-you notes)",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodDropdown(),
                ],
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                  label: 'New C-Note',
                  onTap: () => widget.onOpenSubmit()),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: 1.25,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                      title: 'Business Given\n${_filteredGivenList.length} C-Notes',
                      value: '₹${_money(_totalAmount(_filteredGivenList))}',
                      iconColor: Colors.greenAccent,
                      icon: Icons.arrow_upward),
                  _StatCard(
                      title: 'Business Received\n${_filteredReceivedList.length} C-Notes',
                      value: '₹${_money(_totalAmount(_filteredReceivedList))}',
                      iconColor: goldColor,
                      icon: Icons.arrow_downward),
                  _StatCard(
                      title: 'Pending',
                      value: '${_stats['pending'] ?? '0'}',
                      iconColor: Colors.amber,
                      icon: Icons.hourglass_empty),
                  _StatCard(
                      title: 'Total Value',
                      value: '₹${_money(_totalAmount(_filteredGivenList) + _totalAmount(_filteredReceivedList))}',
                      iconColor: Colors.lightBlueAccent,
                      icon: Icons.currency_rupee),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (widget.listOnly) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'C-Notes',
                    style: TextStyle(
                      color: AppColors.cardHeading,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPeriodDropdown(),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _ToggleTab(
                    label: "Given by Me",
                    isActive: _givenByMe,
                    whiteTheme: true,
                    radius:
                        const BorderRadius.horizontal(left: Radius.circular(8)),
                    onTap: () => setState(() => _givenByMe = true),
                  ),
                ),
                Expanded(
                  child: _ToggleTab(
                    label: "Received by Me",
                    isActive: !_givenByMe,
                    whiteTheme: true,
                    radius: const BorderRadius.horizontal(
                        right: Radius.circular(8)),
                    onTap: () => setState(() => _givenByMe = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.searchBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Show ",
                              style: TextStyle(
                                  color: AppColors.onCardMuted, fontSize: 11)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: AppColors.searchBorder)),
                            child: Text("${_currentList.length}",
                                style: TextStyle(
                                    color: AppColors.onCard, fontSize: 11)),
                          ),
                        ],
                      ),
                      Container(
                        width: 120,
                        height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.searchBorder)),
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style:
                              TextStyle(color: AppColors.onCard, fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Search records...',
                            hintStyle: TextStyle(
                                color: AppColors.onCardLabel, fontSize: 10),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _ListErrorRetry(
                        message: _errorMessage!, onRetry: _fetchData)
                  else if (_currentList.isEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.request_quote,
                                size: 48, color: goldColor),
                            const SizedBox(height: 16),
                            Text(
                                _givenByMe
                                    ? 'No C-Notes given yet.'
                                    : 'No C-Notes received yet.',
                                style: TextStyle(
                                    color: AppColors.onCardMuted,
                                    fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: goldColor,
                                foregroundColor: AppColors.card,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              onPressed: () => widget.onOpenSubmit(),
                              child: const Text('Submit a C-Note',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._currentList.map((item) {
                      final date = _dateOnly(item.rawJson['created_at'] ??
                          item.rawJson['entry_date'] ??
                          item.date);
                      final giverId = (item.rawJson['given_by'] ??
                              item.rawJson['created_by'] ??
                              item.rawJson['user_id'] ??
                              item.rawJson['from_member_id'])
                          ?.toString();
                      final receiverId = (_receivedBy(item) ??
                              item.rawJson['to_member_id'] ??
                              item.rawJson['to_user_id'])
                          ?.toString();

                      String? valid(dynamic val) {
                        final s = val?.toString().trim();
                        return (s != null && s.isNotEmpty && s != 'null') ? s : null;
                      }

                      final isMeGiver = _sameUser(giverId, _myUserId);
                      final isMeReceiver = _sameUser(receiverId, _myUserId);

                      final giverName = valid(item.rawJson['given_by_name']) ??
                          valid(item.rawJson['from_member_name']) ??
                          valid(item.rawJson['created_by_name']) ??
                          (giverId != null ? _memberById[giverId]?.name : null) ??
                          (isMeGiver ? 'You' : (valid(giverId) != null ? 'Member #$giverId' : '—'));

                      final receiverName = valid(item.rawJson['received_by_name']) ??
                          valid(item.rawJson['to_member_name']) ??
                          (receiverId != null ? _memberById[receiverId]?.name : null) ??
                          (isMeReceiver ? 'You' : (valid(receiverId) != null ? 'Member #$receiverId' : '—'));

                      String? companyValue(dynamic value) {
                        final text = value?.toString().trim();
                        return (text != null &&
                                text.isNotEmpty &&
                                text.toLowerCase() != 'null')
                            ? text
                            : null;
                      }

                      final company = [
                        item.rawJson['company_name'],
                        item.rawJson['company'],
                        item.rawJson['business_name'],
                        item.rawJson['companyName'],
                        item.rawJson['client_company'],
                        if (receiverId != null) _memberById[receiverId]?.companyName,
                        if (giverId != null) _memberById[giverId]?.companyName,
                      ].map(companyValue).firstWhere(
                          (value) => value != null,
                          orElse: () => '') ??
                          '';
                      final amount = item.amount.toStringAsFixed(0);
                      final description = (item.rawJson['description'] ??
                              item.rawJson['comments'] ??
                              item.rawJson['notes'] ??
                              item.rawJson['details'] ??
                              item.rawJson['remark'] ??
                              item.rawJson['remarks'] ??
                              item.rawJson['topic'] ??
                              item.description ??
                              '')
                          .toString()
                          .trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Record rows: white on the white theme, blue on the blue theme.
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accentBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 5)),
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(date,
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text("Approved",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                  color: AppColors.onRecordCardDivider,
                                  height: 1),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.person,
                                      color: AppColors.onRecordCardLabel,
                                      size: 14),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 100,
                                    child: Text('Given By',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(giverName,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.person_outline,
                                      color: AppColors.onRecordCardLabel,
                                      size: 14),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 100,
                                    child: Text('Received By',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(receiverName,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.business,
                                      color: AppColors.onRecordCardLabel,
                                      size: 14),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 100,
                                    child: Text('Company',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        company.isNotEmpty ? company : '—',
                                        style: TextStyle(
                                            color: AppColors.onRecordCardMuted,
                                            fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.currency_rupee,
                                      color: AppColors.onRecordCardLabel,
                                      size: 14),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 100,
                                    child: Text('Amount',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text('₹$amount',
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                            if (description.isNotEmpty &&
                                description != 'null' &&
                                description != '—') ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.description_outlined,
                                        color: AppColors.onRecordCardLabel,
                                        size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 100,
                                      child: Text('Description',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                              color:
                                                  AppColors.onRecordCardLabel,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600))),
                                  Text(":",
                                      style: TextStyle(
                                          color: AppColors.onRecordCardLabel,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(description,
                                          style: TextStyle(
                                              color:
                                                  AppColors.onRecordCardMuted,
                                              fontSize: 13),
                                          softWrap: true)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(4))),
                        child: Icon(Icons.chevron_left,
                            color: AppColors.onCard, size: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: const Color(0xFF0D6EFD),
                        child: const Text("1",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4))),
                        child: Icon(Icons.chevron_right,
                            color: AppColors.onCard, size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class R2RScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;
  final bool initialGivenByMe;
  const R2RScreen(
      {super.key,
      required this.onOpenSubmit,
      this.onEditItem,
      this.initialGivenByMe = true});

  @override
  State<R2RScreen> createState() => _R2RScreenState();
}

class _R2RScreenState extends State<R2RScreen> {
  String _searchQuery = '';
  String _selectedPeriod = 'This week';
  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityModel> _givenList = [];

  DateTime? _parseActivityDate(String raw) {
    if (raw.trim().isEmpty || raw.trim() == 'null' || raw.trim() == '—') {
      return null;
    }
    final value = raw.trim().split(RegExp(r'[ T]')).first;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(value);
    if (dmy == null) return null;
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  DateTime? _itemDate(ActivityModel record) {
    final created = record.rawJson['date'] ??
        record.rawJson['meeting_date'] ??
        record.rawJson['r2r_date'] ??
        record.rawJson['created_at'] ??
        record.rawJson['createdAt'] ??
        record.rawJson['entry_date'] ??
        record.date;
    return _parseActivityDate(created?.toString() ?? '');
  }

  bool _matchesPeriod(ActivityModel item) {
    if (_selectedPeriod == 'All') return true;
    final date = _itemDate(item);
    if (date == null) return true;

    final now = DateTime.now();
    if (_selectedPeriod == 'This week') {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 7));
      return !date.isBefore(start) && date.isBefore(end);
    } else if (_selectedPeriod == 'This month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      return !date.isBefore(start) && date.isBefore(end);
    }
    return true;
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isDense: true,
          dropdownColor: AppColors.card,
          style: TextStyle(color: AppColors.onCard, fontSize: 12),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.secondary, size: 18),
          items: const [
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'All', child: Text('All')),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _selectedPeriod = value);
            }
          },
        ),
      ),
    );
  }

  List<ActivityModel> get _currentList {
    final list = _givenList.where(_matchesPeriod).toList();
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) {
      final partnerId = (item.rawJson['partner_id'] ??
              item.rawJson['met_with'] ??
              item.rawJson['member_id'] ??
              item.rawJson['received_by'] ??
              item.rawJson['to_user_id'] ??
              item.rawJson['to_member_id'])
          ?.toString();
      final partnerName =
          (partnerId != null && partnerId.isNotEmpty && partnerId != 'null')
              ? (_memberById[partnerId]?.name ?? '')
              : '';
      return item.rawJson.toString().toLowerCase().contains(q) ||
          partnerName.toLowerCase().contains(q);
    }).toList();
  }

  int _statCount(String status) {
    if (_selectedPeriod == 'All' && _stats[status] != null) {
      return int.tryParse(_stats[status].toString()) ??
          _currentList.where((item) =>
              (item.rawJson['status'] ?? item.status).toString().trim().toLowerCase() == status.toLowerCase()).length;
    }
    return _currentList.where((item) =>
        (item.rawJson['status'] ?? item.status).toString().trim().toLowerCase() == status.toLowerCase()).length;
  }

  Map<String, dynamic> _stats = {};

  // r2r.php only ever sends a partner_id, never a usable partner_name (it
  // comes back null on every real row), so the card always showed a dash
  // instead of who the meeting was actually with.
  Map<String, UserModel> _memberById = {};
  String _myUserId = '';
  String _myUserName = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // These are also called straight after `await widget.onOpenSubmit()`, so
    // the screen can already be gone by the time this runs - calling setState
    // then throws "setState() called after dispose()". The shell also rebuilds
    // this screen with a new ValueKey on every refresh, which disposes it.
    if (!mounted) return;
    if (_givenList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await ActivityService.getActivities('r2r.php', 'r2r');
      Map<String, dynamic> receivedData = const {};
      try {
        receivedData = await ActivityService.getActivities(
          'r2r.php',
          'r2r',
          extraParams: const {'type': 'received'},
        );
      } catch (_) {
        // A server that does not support this filter can still return both
        // sides in its default response.
      }
      final activities = [
        ...List<ActivityModel>.from(data['activities'] ?? []),
        ...List<ActivityModel>.from(receivedData['activities'] ?? []),
      ].fold<Map<int, ActivityModel>>({}, (records, item) {
        records[item.id] = item;
        return records;
      }).values.toList();
      final prefs = await SharedPreferences.getInstance();
      final userId = await ApiClient.getUserId();
      _myUserId = userId;
      String storedName = prefs.getString('user_name') ??
          prefs.getString('name') ??
          prefs.getString('display_name') ??
          prefs.getString('login_username') ??
          '';
      if (storedName.trim().toLowerCase() == 'member' ||
          storedName.trim().toLowerCase() == 'you') {
        storedName = '';
      }
      _myUserName = storedName;
      try {
        final members = await MemberService.getAllMembers();
        _memberById = {for (final m in members) m.id.toString(): m};

        if (_myUserName.isEmpty && _memberById.containsKey(_myUserId)) {
          final n = _memberById[_myUserId]?.name ?? '';
          if (n.isNotEmpty && n.toLowerCase() != 'member' && n.toLowerCase() != 'you') {
            _myUserName = n;
          }
        }

        // members.php caps out at 50 rows with no working pagination
        // override (confirmed - page=2 returns the identical 50), so any
        // R2R partner or creator outside that first 50 was unresolvable.
        // Fetch those specific ids one at a time instead.
        final missingIds = activities
            .expand((a) => [
                  a.rawJson['user_id']?.toString(),
                  a.rawJson['created_by']?.toString(),
                  a.rawJson['creator_id']?.toString(),
                  a.rawJson['given_by']?.toString(),
                  a.rawJson['partner_id']?.toString(),
                  a.rawJson['met_with']?.toString(),
                  a.rawJson['member_id']?.toString(),
                  a.rawJson['received_by']?.toString(),
                  a.rawJson['to_user_id']?.toString(),
                  a.rawJson['to_member_id']?.toString(),
                ])
            .followedBy([_myUserId])
            .whereType<String>()
            .where((id) =>
                id.isNotEmpty && id != 'null' && !_memberById.containsKey(id))
            .toSet();
        if (missingIds.isNotEmpty) {
          final fetched = await Future.wait(missingIds.map((id) async {
            try {
              final detail = await MemberService.getMemberDetail(int.parse(id));
              return MapEntry(id, UserModel.fromJson(detail));
            } catch (_) {
              return null;
            }
          }));
          for (final entry in fetched) {
            if (entry != null) _memberById[entry.key] = entry.value;
          }
        }

        if ((_myUserName.isEmpty ||
                _myUserName.toLowerCase() == 'member' ||
                _myUserName.toLowerCase() == 'you') &&
            _memberById.containsKey(_myUserId)) {
          final n = _memberById[_myUserId]?.name ?? '';
          if (n.isNotEmpty && n.toLowerCase() != 'member' && n.toLowerCase() != 'you') {
            _myUserName = n;
            prefs.setString('user_name', n).ignore();
          }
        }
      } catch (_) {
        // Leave the map empty; the row falls back to the raw values.
      }

      if (_myUserName.isEmpty ||
          _myUserName.toLowerCase() == 'member' ||
          _myUserName.toLowerCase() == 'you') {
        try {
          final prof = await AuthService.getProfile();
          final userMap = prof['data']?['user'] ?? prof['user'] ?? prof;
          final n = (userMap['display_name'] ??
                  userMap['name'] ??
                  userMap['first_name'])
              ?.toString()
              .trim();
          if (n != null &&
              n.isNotEmpty &&
              n.toLowerCase() != 'member' &&
              n.toLowerCase() != 'you') {
            _myUserName = n;
            prefs.setString('user_name', _myUserName).ignore();
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          // The Given/Received buttons are no longer on this page. The R2R
          // API already scopes its response to the signed-in member, while
          // some responses do not include `given_by` or `user_id`. Filtering
          // on those missing fields made every valid R2R row disappear.
          _givenList = activities;
          _stats = data['stats'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonLoader();
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'R2R Meetings',
                      style: TextStyle(
                        color: AppColors.cardHeading,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Track one-to-one business meetings",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildPeriodDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          _ActionBtn(
              label: 'Log R2R Meeting',
              onTap: () async {
                await widget.onOpenSubmit();
                if (mounted) {
                  _fetchData();
                }
              }),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: 1.45,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(
                  title: 'Total',
                  value: '${_currentList.length}',
                  iconColor: Colors.orange,
                  icon: Icons.handshake),
              _StatCard(
                  title: 'Pending',
                  value: '${_statCount('pending')}',
                  iconColor: Colors.amber,
                  icon: Icons.hourglass_empty),
              _StatCard(
                  title: 'Approved',
                  value: '${_statCount('approved')}',
                  iconColor: Colors.green,
                  icon: Icons.check_circle),
              _StatCard(
                  title: 'Rejected',
                  value: '${_statCount('rejected')}',
                  iconColor: Colors.redAccent,
                  icon: Icons.cancel),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Showing ${_currentList.length} records",
                  style: TextStyle(
                      color: AppColors.onCardMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              Container(
                width: 150,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.searchBorder)),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: AppColors.onCard, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search records...',
                    hintStyle:
                        TextStyle(color: AppColors.onCardLabel, fontSize: 11),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.onCardLabel, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            _ListErrorRetry(message: _errorMessage!, onRetry: _fetchData)
          else if (_currentList.isEmpty && !_isLoading)
            const _NoRecordsCard()
          else if (!_isLoading)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentList.length,
              itemBuilder: (context, index) {
                return _buildCardRow(_currentList[index]);
              },
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8))),
                child:
                    Icon(Icons.chevron_left, color: AppColors.onCard, size: 16),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFF0D6EFD),
                child: const Text("1",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8))),
                child: Icon(Icons.chevron_right,
                    color: AppColors.onCard, size: 16),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCardRow(ActivityModel item) {
    final date = (item.rawJson['meeting_date'] ??
            item.rawJson['entry_date'] ??
            item.rawJson['created_at'] ??
            item.date)
        .toString();

    String? valid(dynamic val) {
      final s = val?.toString().trim();
      return (s != null &&
              s.isNotEmpty &&
              s.toLowerCase() != 'null' &&
              s.toLowerCase() != 'undefined' &&
              s.toLowerCase() != 'none')
          ? s
          : null;
    }

    // Detect creator ID and partner ID
    final rawCreatorId = (item.rawJson['user_id'] ??
            item.rawJson['created_by'] ??
            item.rawJson['creator_id'] ??
            item.rawJson['given_by'] ??
            item.rawJson['from_user_id'] ??
            item.rawJson['from_member_id'])
        ?.toString();

    final rawPartnerId = (item.rawJson['partner_id'] ??
            item.rawJson['met_with'] ??
            item.rawJson['with_member_id'] ??
            item.rawJson['to_user_id'] ??
            item.rawJson['to_member_id'] ??
            item.rawJson['received_by'])
        ?.toString();

    final rawMemberId = item.rawJson['member_id']?.toString();

    String? creatorId = rawCreatorId;
    String? partnerId = rawPartnerId;

    if (rawMemberId != null && rawMemberId.isNotEmpty && rawMemberId != 'null') {
      if (creatorId == null || creatorId.isEmpty || creatorId == 'null') {
        if (partnerId != null &&
            partnerId.isNotEmpty &&
            partnerId != 'null' &&
            partnerId != rawMemberId) {
          creatorId = rawMemberId;
        } else if (rawMemberId == _myUserId) {
          creatorId = rawMemberId;
        } else if (partnerId == null || partnerId.isEmpty || partnerId == 'null') {
          creatorId = rawMemberId;
        }
      } else if (partnerId == null || partnerId.isEmpty || partnerId == 'null') {
        if (rawMemberId != creatorId) {
          partnerId = rawMemberId;
        }
      }
    }

    final isMeCreator = (creatorId != null &&
            creatorId.isNotEmpty &&
            creatorId == _myUserId) ||
        (creatorId == null && partnerId != null && partnerId != _myUserId) ||
        (creatorId == null && partnerId == null);

    final resolvedCreator = (creatorId != null &&
            creatorId.isNotEmpty &&
            creatorId != 'null')
        ? (_memberById[creatorId]?.name ??
            _memberById[int.tryParse(creatorId)?.toString()]?.name)
        : null;

    final resolvedPartner = (partnerId != null &&
            partnerId.isNotEmpty &&
            partnerId != 'null')
        ? (_memberById[partnerId]?.name ??
            _memberById[int.tryParse(partnerId)?.toString()]?.name)
        : null;

    final myName = (_myUserName.isNotEmpty &&
            _myUserName.toLowerCase() != 'member' &&
            _myUserName.toLowerCase() != 'you')
        ? _myUserName
        : (_memberById[_myUserId]?.name ?? _myUserName);

    // Resolve creator name:
    String creator;
    if (isMeCreator) {
      creator = (myName.isNotEmpty &&
              myName.toLowerCase() != 'member' &&
              myName.toLowerCase() != 'you')
          ? myName
          : (valid(item.rawJson['created_by_name']) ??
              valid(item.rawJson['user_name']) ??
              valid(item.rawJson['creator_name']) ??
              valid(item.rawJson['given_by_name']) ??
              resolvedCreator ??
              (myName.isNotEmpty ? myName : 'Member'));
    } else {
      creator = (valid(item.rawJson['created_by_name']) ??
              valid(item.rawJson['creator_name']) ??
              valid(item.rawJson['user_name']) ??
              valid(item.rawJson['given_by_name']) ??
              valid(item.rawJson['from_member_name']) ??
              resolvedCreator ??
              (valid(creatorId) != null
                  ? (_memberById[creatorId]?.name ?? 'Member #$creatorId')
                  : 'Member'))
          .toString();
    }

    // Resolve partner name:
    String partner;
    if (isMeCreator) {
      partner = (valid(item.rawJson['partner_name']) ??
              valid(item.rawJson['met_with_name']) ??
              valid(item.rawJson['to_member_name']) ??
              valid(item.rawJson['received_by_name']) ??
              valid(item.rawJson['to_user_name']) ??
              (partnerId != null ? resolvedPartner : null) ??
              valid(item.rawJson['member_name']) ??
              (valid(partnerId) != null
                  ? (_memberById[partnerId]?.name ?? 'Member #$partnerId')
                  : '—'))
          .toString();
    } else {
      partner = (myName.isNotEmpty &&
              myName.toLowerCase() != 'member' &&
              myName.toLowerCase() != 'you')
          ? myName
          : (valid(item.rawJson['partner_name']) ??
              valid(item.rawJson['met_with_name']) ??
              resolvedPartner ??
              myName);
    }

    final rawLoc = [
      item.rawJson['location'],
      item.rawJson['meeting_location'],
      item.rawJson['venue'],
      item.rawJson['meeting_place'],
      item.rawJson['place'],
      item.rawJson['location_name'],
      item.rawJson['meeting_address'],
      item.rawJson['address'],
    ].map(valid).firstWhere((value) => value != null, orElse: () => null);

    final location = (rawLoc != null &&
            rawLoc.trim().isNotEmpty &&
            rawLoc.trim() != '—' &&
            rawLoc.trim() != '-' &&
            rawLoc.trim().toLowerCase() != 'one-to-one meeting' &&
            rawLoc.trim().toLowerCase() != 'one-to-one' &&
            rawLoc.trim().toLowerCase() != 'one to one')
        ? rawLoc.trim()
        : '-';
    final status = (item.rawJson['status'] ?? 'Approved').toString();
    // Robustly extract all image URLs or binary/base64 strings
    final List<String> imageUrls = [];
    const imageCandidateKeys = [
      'image',
      'images',
      'proof_image',
      'proof_images',
      'image_url',
      'image_urls',
      'proof_url',
      'proof_urls',
      'image_path',
      'meeting_image',
      'photo',
      'photos',
      'proof',
      'proofs',
      'attachment',
      'attachments',
      'file',
      'files',
      'proof_photo',
      'meeting_photo',
      'r2r_image',
      'image_base64',
      'base64_image',
      'image_binary',
      'image_data',
      'proof_base64',
      'binary_image',
      'data',
      'file_data'
    ];
    for (final key in imageCandidateKeys) {
      if (item.rawJson.containsKey(key)) {
        for (final u in ImageViewer.extractImageUrls(item.rawJson[key])) {
          if (!imageUrls.contains(u)) {
            imageUrls.add(u);
          }
        }
      }
    }
    final bool hasProof = imageUrls.isNotEmpty;

    final description = (item.rawJson['topics_discussed'] ??
            item.rawJson['topic'] ??
            item.rawJson['description'] ??
            item.rawJson['notes'] ??
            item.rawJson['comments'] ??
            item.rawJson['details'] ??
            item.description ??
            '')
        .toString()
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Record rows: white on the white theme, blue on the blue theme.
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: goldColor, size: 14),
                  const SizedBox(width: 8),
                  Text(date,
                      style: TextStyle(
                          color: AppColors.onRecordCard,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(status,
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.onRecordCardDivider, height: 1),
          ),
          _buildInfoRow('Created By', creator, Icons.person),
          const SizedBox(height: 8),
          _buildInfoRow('Met With', partner, Icons.handshake),
          const SizedBox(height: 8),
          _buildInfoRow('Location', location, Icons.location_on),
          if (description.isNotEmpty &&
              description != 'null' &&
              description != '—') ...[
            const SizedBox(height: 8),
            _buildInfoRow('Description', description, Icons.description_outlined),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.image_outlined,
                  color: AppColors.onRecordCardLabel, size: 16),
              const SizedBox(width: 8),
              Text('Meeting Image',
                  style: TextStyle(
                      color: AppColors.onRecordCardLabel,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (hasProof)
                InkWell(
                  onTap: () {
                    ImageViewer.show(
                      context,
                      imageUrls,
                      caption: 'R2R Meeting: $creator & $partner',
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 5),
                        Text(
                          'View Image',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text('Not attached',
                    style: TextStyle(
                        color: AppColors.onRecordCardMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildItemActions(context, item, onEdit: (act) {
                if (widget.onEditItem != null) widget.onEditItem!(act);
              }, onActionComplete: () {
                _fetchData();
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Rows inside the R2R record card, which is white in both themes.
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.onRecordCardLabel, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  color: AppColors.onRecordCardLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Text(":",
            style: TextStyle(color: AppColors.onRecordCardLabel, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: TextStyle(color: AppColors.onRecordCard, fontSize: 14)),
        ),
      ],
    );
  }
}

/// Bottom sheet modal displaying complete R2R meeting details and attached image(s).
/// Ensures attached images submitted from Web or Mobile load properly, are not displayed
/// inline on the card, and support multiple attachments with zoom/pan viewer.
class _R2RDetailsBottomSheet extends StatefulWidget {
  final List<String> imageUrls;
  final String creator;
  final String partner;
  final ActivityModel item;
  final String date;
  final String status;
  final String location;
  final String description;

  const _R2RDetailsBottomSheet({
    required this.imageUrls,
    required this.creator,
    required this.partner,
    required this.item,
    required this.date,
    required this.status,
    required this.location,
    required this.description,
  });

  @override
  State<_R2RDetailsBottomSheet> createState() => _R2RDetailsBottomSheetState();
}

class _R2RDetailsBottomSheetState extends State<_R2RDetailsBottomSheet> {
  int _activeImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.status.toLowerCase() == 'pending'
        ? Colors.amber
        : Colors.green;

    String caption = widget.creator.isNotEmpty && widget.creator != '—'
        ? 'Created by: ${widget.creator}'
        : 'R2R Meeting Image';
    if (widget.partner.isNotEmpty && widget.partner != '—') {
      caption += '  •  Met with: ${widget.partner}';
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.modalSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onModalMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.handshake, color: goldColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'R2R Meeting Details',
                        style: TextStyle(
                          color: AppColors.onModal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.date,
                        style: TextStyle(
                          color: AppColors.onModalMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    widget.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.onModal, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Participants Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.modalInput,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Created By',
                          widget.creator,
                          Icons.person,
                          goldColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: AppColors.border.withValues(alpha: 0.3),
                            height: 1,
                          ),
                        ),
                        _buildDetailRow(
                          'Met With',
                          widget.partner,
                          Icons.handshake,
                          Colors.blueAccent,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: AppColors.border.withValues(alpha: 0.3),
                            height: 1,
                          ),
                        ),
                        _buildDetailRow(
                          'Location',
                          widget.location,
                          Icons.location_on,
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ),

                  // Description / Topics Discussed
                  if (widget.description.isNotEmpty &&
                      widget.description != '—' &&
                      widget.description != 'null') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Topics Discussed',
                      style: TextStyle(
                        color: AppColors.onModal,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.modalInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        widget.description,
                        style: TextStyle(
                          color: AppColors.onModal,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Attached Images Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: AppColors.onModal, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            widget.imageUrls.length > 1
                                ? 'Attached Images (${widget.imageUrls.length})'
                                : 'Attached Image',
                            style: TextStyle(
                              color: AppColors.onModal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (widget.imageUrls.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in,
                                  color: Colors.blueAccent, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Tap to enlarge',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (widget.imageUrls.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.modalInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              color: AppColors.onModalMuted, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'No image attached',
                            style: TextStyle(
                              color: AppColors.onModalMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.imageUrls.length == 1)
                    _buildSingleImagePreview(
                        widget.imageUrls.first, caption)
                  else
                    _buildMultiImageGallery(caption),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.onModalMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(':', style: TextStyle(color: AppColors.onModalMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.onModal,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleImagePreview(String url, String caption) {
    return GestureDetector(
      onTap: () {
        ImageViewer.show(context, [url], caption: caption);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ImageViewer.buildImageWidget(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'View Full',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiImageGallery(String caption) {
    final urls = widget.imageUrls;
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _imagePageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _activeImageIndex = i),
            itemBuilder: (context, index) {
              final raw = urls[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () {
                    ImageViewer.show(
                      context,
                      urls,
                      initialIndex: index,
                      caption: caption,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageViewer.buildImageWidget(
                          raw,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${index + 1} / ${urls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Thumbnails strip
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            itemBuilder: (context, idx) {
              final isSel = idx == _activeImageIndex;
              final raw = urls[idx];
              return GestureDetector(
                onTap: () {
                  _imagePageController.animateToPage(
                    idx,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? goldColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ImageViewer.buildImageWidget(
                    raw,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TestimonialsScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;
  final bool initialGivenByMe;
  const TestimonialsScreen(
      {super.key,
      required this.onOpenSubmit,
      this.onEditItem,
      this.initialGivenByMe = true});

  @override
  State<TestimonialsScreen> createState() => _TestimonialsScreenState();
}

class _TestimonialsScreenState extends State<TestimonialsScreen> {
  String _searchQuery = '';
  String _selectedPeriod = 'This week';
  late bool _givenByMe;
  bool _isLoading = true;
  String? _errorMessage;

  List<ActivityModel> _givenList = [];
  List<ActivityModel> _receivedList = [];

  /// Decides whether a testimonial reads as given by or received by me.
  String _myUserId = '';

  DateTime? _parseActivityDate(String raw) {
    if (raw.trim().isEmpty || raw.trim() == 'null' || raw.trim() == '—') {
      return null;
    }
    final value = raw.trim().split(RegExp(r'[ T]')).first;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(value);
    if (dmy == null) return null;
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  DateTime? _itemDate(ActivityModel record) {
    final created = record.rawJson['testimonial_date'] ??
        record.rawJson['date'] ??
        record.rawJson['created_at'] ??
        record.rawJson['createdAt'] ??
        record.rawJson['entry_date'] ??
        record.date;
    return _parseActivityDate(created?.toString() ?? '');
  }

  bool _matchesPeriod(ActivityModel item) {
    if (_selectedPeriod == 'All') return true;
    final date = _itemDate(item);
    if (date == null) return true;

    final now = DateTime.now();
    if (_selectedPeriod == 'This week') {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 7));
      return !date.isBefore(start) && date.isBefore(end);
    } else if (_selectedPeriod == 'This month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      return !date.isBefore(start) && date.isBefore(end);
    }
    return true;
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isDense: true,
          dropdownColor: AppColors.card,
          style: TextStyle(color: AppColors.onCard, fontSize: 12),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.secondary, size: 18),
          items: const [
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'All', child: Text('All')),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _selectedPeriod = value);
            }
          },
        ),
      ),
    );
  }

  List<ActivityModel> get _currentList {
    final list = _givenByMe ? _givenList : _receivedList;
    final periodFiltered = list.where(_matchesPeriod).toList();
    if (_searchQuery.isEmpty) return periodFiltered;
    return periodFiltered
        .where((item) => item.rawJson
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _givenByMe = widget.initialGivenByMe;
    _fetchData();
  }

  Future<void> _fetchData() async {
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _myUserId = p.getString('user_id') ?? '');
    });
    if (_givenList.isEmpty && _receivedList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await ActivityService.getActivities(
          'testimonials.php', 'testimonial');
      final userId = await ApiClient.getUserId();

      if (mounted) {
        setState(() {
          final allData = List<ActivityModel>.from(data['activities'] ?? []);
          _givenList = allData
              .where((item) => item.rawJson['given_by'].toString() == userId)
              .toList();
          _receivedList = allData
              .where((item) => item.rawJson['received_by'].toString() == userId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonLoader();
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Testimonials",
                    style: TextStyle(
                        color: AppColors.cardHeading,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                _buildPeriodDropdown(),
              ],
            ),
            const SizedBox(height: 16),
            _ActionBtn(
                label: 'Give Testimonial',
                onTap: () => widget.onOpenSubmit()),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.searchBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Show ",
                              style: TextStyle(
                                  color: AppColors.onCardMuted, fontSize: 11)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: AppColors.searchBorder)),
                            child: Text("${_currentList.length}",
                                style: TextStyle(
                                    color: AppColors.onCard, fontSize: 11)),
                          ),
                        ],
                      ),
                      Container(
                        width: 120,
                        height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.searchBorder)),
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style:
                              TextStyle(color: AppColors.onCard, fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Search records...',
                            hintStyle: TextStyle(
                                color: AppColors.onCardLabel, fontSize: 10),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _ListErrorRetry(
                        message: _errorMessage!, onRetry: _fetchData)
                  else if (_currentList.isEmpty && !_isLoading)
                    const _NoRecordsCard()
                  else if (!_isLoading)
                    ..._currentList.map((item) {
                      final r = item.rawJson;
                      final date = (r['testimonial_date'] ??
                              r['entry_date'] ??
                              r['created_at'] ??
                              item.date)
                          .toString();
                      // The row names the counterpart under display_name; given_by
                      // tells us which side of the testimonial we are on.
                      final counterpart = (r['display_name'] ??
                              '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}')
                          .toString()
                          .trim();
                      final givenByMe = r['given_by']?.toString() == _myUserId;
                      final other = counterpart.isEmpty ? '—' : counterpart;
                      final from = givenByMe ? 'Me' : other;
                      final to = givenByMe ? other : 'Me';
                      final title = (r['title'] ?? '').toString().trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accentBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 5)),
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(date,
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Approved',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                  color: AppColors.onRecordCardDivider,
                                  height: 1),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.person_outline,
                                    color: AppColors.onRecordCardLabel,
                                    size: 14),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 50,
                                    child: Text('From',
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(from,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.person,
                                    color: AppColors.onRecordCardLabel,
                                    size: 14),
                                const SizedBox(width: 8),
                                SizedBox(
                                    width: 50,
                                    child: Text('To',
                                        style: TextStyle(
                                            color: AppColors.onRecordCardLabel,
                                            fontSize: 13))),
                                Text(":",
                                    style: TextStyle(
                                        color: AppColors.onRecordCardLabel,
                                        fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(to,
                                        style: TextStyle(
                                            color: AppColors.onRecordCard,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (title.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.title,
                                      color: AppColors.onRecordCardLabel,
                                      size: 14),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 50,
                                      child: Text('Title',
                                          style: TextStyle(
                                              color:
                                                  AppColors.onRecordCardLabel,
                                              fontSize: 13))),
                                  Text(":",
                                      style: TextStyle(
                                          color: AppColors.onRecordCardLabel,
                                          fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(title,
                                        style: TextStyle(
                                            color: AppColors.onRecordCardMuted,
                                            fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              TestimonialCertificateScreen(
                                                  testimonial: item.rawJson)));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: goldColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium,
                                          color: goldColor, size: 14),
                                      const SizedBox(width: 4),
                                      Text('Certificate',
                                          style: TextStyle(
                                              color: goldColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Center(
                      child: Text("Showing ${_currentList.length} records",
                          style: TextStyle(
                              color: AppColors.onCardLabel, fontSize: 11))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(4))),
                        child: Icon(Icons.chevron_left,
                            color: AppColors.onCard, size: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: const Color(0xFF0D6EFD),
                        child: const Text("1",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4))),
                        child: Icon(Icons.chevron_right,
                            color: AppColors.onCard, size: 14),
                      ),
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

class InviteVisitorScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;
  const InviteVisitorScreen(
      {super.key, required this.onOpenSubmit, this.onEditItem});

  @override
  State<InviteVisitorScreen> createState() => _InviteVisitorScreenState();
}

class _InviteVisitorScreenState extends State<InviteVisitorScreen> {
  final String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityModel> _visitorsList = [];
  List<ActivityModel> get _currentList {
    if (_searchQuery.isEmpty) return _visitorsList;
    return _visitorsList
        .where((item) => item.rawJson
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int? _apiVisitorCount(List<String> keys) {
    for (final key in keys) {
      if (!_stats.containsKey(key) || _stats[key] == null) continue;
      final value = _stats[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Prefer visitor-specific totals from the API. Older endpoints omit them,
  /// so fall back to the actual rows and recognise their legacy attendance
  /// values as well.
  Map<String, int> get _visitorStats {
    var pending = 0;
    var attended = 0;
    var converted = 0;
    for (final item in _visitorsList) {
      final status = (item.rawJson['visitor_status'] ??
              item.rawJson['attendance_status'] ??
              item.rawJson['status'] ??
              item.status)
          .toString()
          .trim()
          .toLowerCase();
      final attendance = item.rawJson['attended'] ??
          item.rawJson['is_attended'] ??
          item.rawJson['attendance'] ??
          item.rawJson['checked_in'] ??
          item.rawJson['check_in_status'];
      final attendanceText = attendance?.toString().trim().toLowerCase() ?? '';
      final isAttended = attendance == true ||
          attendance == 1 ||
          const {'1', 'true', 'yes', 'attended', 'present', 'checked-in', 'checked in'}
              .contains(attendanceText);
      if (status.contains('convert')) {
        converted++;
        // Conversion can happen only after the visitor attended; it belongs
        // in both funnel counts, while Pending stays mutually exclusive.
        attended++;
      } else if (isAttended ||
          status.contains('attend') ||
          status.contains('present') ||
          status.contains('check_in') ||
          status.contains('check-in') ||
          status.contains('checked in') ||
          status == 'visited') {
        attended++;
      } else {
        pending++;
      }
    }
    return {
      'total': _apiVisitorCount(
              const ['total_visitors', 'visitors_invited', 'visitor_count', 'total']) ??
          _visitorsList.length,
      'pending': _apiVisitorCount(
              const ['pending_visitors', 'visitors_pending', 'pending']) ??
          pending,
      'attended': _apiVisitorCount(const [
            'attended_visitors',
            'visitors_attended',
            'attended_count',
            'attended',
          ]) ??
          attended,
      'converted': _apiVisitorCount(const [
            'converted_visitors',
            'visitors_converted',
            'converted_count',
            'converted',
          ]) ??
          converted,
    };
  }

  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // These are also called straight after `await widget.onOpenSubmit()`, so
    // the screen can already be gone by the time this runs - calling setState
    // then throws "setState() called after dispose()". The shell also rebuilds
    // this screen with a new ValueKey on every refresh, which disposes it.
    if (!mounted) return;
    if (_visitorsList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await ActivityService.getActivities(
          'visitors.php', 'visitor');
      if (mounted) {
        setState(() {
          _visitorsList = List<ActivityModel>.from(data['activities'] ?? []);
          _stats = data['stats'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonLoader();
    final visitorStats = _visitorStats;
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Invite visitors and track their journey to membership",
                style: TextStyle(color: AppColors.onCardMuted, fontSize: 13)),
            const SizedBox(height: 16),
            _ActionBtn(
                label: 'Invite Visitor',
                onTap: () => widget.onOpenSubmit()),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: 1.45,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                    title: 'Total Invited',
                    value: '${visitorStats['total']}',
                    iconColor: Colors.orange,
                    icon: Icons.directions_walk),
                _StatCard(
                    title: 'Pending',
                    value: '${visitorStats['pending']}',
                    iconColor: Colors.amber,
                    icon: Icons.hourglass_empty),
                _StatCard(
                    title: 'Attended',
                    value: '${visitorStats['attended']}',
                    iconColor: Colors.green,
                    icon: Icons.check_circle),
                _StatCard(
                    title: 'Converted',
                    value: '${visitorStats['converted']}',
                    iconColor: Colors.blueAccent,
                    icon: Icons.person_add),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.searchBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: _errorMessage != null
                  ? _ListErrorRetry(
                      message: _errorMessage!, onRetry: _fetchData)
                  : _visitorsList.isEmpty && !_isLoading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_walk,
                                color: goldColor, size: 48),
                            const SizedBox(height: 16),
                            Text("You haven't invited any visitors yet.",
                                style: TextStyle(
                                    color: AppColors.onCardMuted,
                                    fontSize: 12)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => widget.onOpenSubmit(),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.navAccent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20))),
                              child: const Text("Invite your first visitor",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            )
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._visitorsList.map((item) {
                              final rawDate = item.rawJson['created_at'] ??
                                  item.rawJson['entry_date'] ??
                                  item.date;
                              // API timestamps include a time, but visitor
                              // cards should show the invitation date only.
                              final date = rawDate
                                  .toString()
                                  .split(RegExp(r'[ T]'))
                                  .first;
                              // Visitors carry name and mobile only.
                              final name = (item.rawJson['name'] ??
                                      item.rawJson['visitor_name'] ??
                                      '—')
                                  .toString();
                              final mobile = (item.rawJson['mobile'] ??
                                      item.rawJson['visitor_mobile'] ??
                                      '')
                                  .toString();
                              final status = item.status;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  // Record rows: white on the white theme, blue on the blue theme.
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.accentBorder,
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.12),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5)),
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(date,
                                            style: TextStyle(
                                                color:
                                                    AppColors.onRecordCardLabel,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'Converted'
                                                ? Colors.green
                                                    .withValues(alpha: 0.2)
                                                : Colors.orange
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(status,
                                              style: TextStyle(
                                                  color: status == 'Converted'
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Divider(
                                          color: AppColors.onRecordCardDivider,
                                          height: 1),
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.person,
                                            color: AppColors.onRecordCardLabel,
                                            size: 14),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                            width: 80,
                                            child: Text('Visitor',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .onRecordCardLabel,
                                                    fontSize: 13))),
                                        Text(":",
                                            style: TextStyle(
                                                color:
                                                    AppColors.onRecordCardLabel,
                                                fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(name,
                                                style: TextStyle(
                                                    color:
                                                        AppColors.onRecordCard,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (mobile.isNotEmpty)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.phone,
                                              color:
                                                  AppColors.onRecordCardLabel,
                                              size: 14),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                              width: 80,
                                              child: Text('Mobile',
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .onRecordCardLabel,
                                                      fontSize: 13))),
                                          Text(":",
                                              style: TextStyle(
                                                  color: AppColors
                                                      .onRecordCardLabel,
                                                  fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(mobile,
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .onRecordCard,
                                                      fontSize: 14))),
                                        ],
                                      ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _buildItemActions(context, item,
                                            onEdit: (act) {
                                          if (widget.onEditItem != null) {
                                            widget.onEditItem!(act);
                                          }
                                        }, onActionComplete: () {
                                          _fetchData();
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            Center(
                                child: Text(
                                    "Showing ${_currentList.length} records",
                                    style: TextStyle(
                                        color: AppColors.onCardLabel,
                                        fontSize: 11))),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class GiveAskScreen extends StatefulWidget {
  final Future<void> Function() onOpenSubmit;
  final Function(ActivityModel)? onEditItem;

  const GiveAskScreen({super.key, required this.onOpenSubmit, this.onEditItem});

  @override
  State<GiveAskScreen> createState() => _GiveAskScreenState();
}

class _GiveAskScreenState extends State<GiveAskScreen> {
  String _searchQuery = '';
  bool _isChapterView = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityModel> _chapterGiveAskList = [];
  List<ActivityModel> _myGiveAskList = [];
  Map<String, UserModel> _memberById = {};

  List<ActivityModel> get _currentList {
    final list = _isChapterView ? _chapterGiveAskList : _myGiveAskList;
    if (_searchQuery.isEmpty) return list;
    return list
        .where((item) => item.rawJson
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchGiveAskList();
  }

  Future<void> _deleteItem(dynamic item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text('Delete Entry',
            style: TextStyle(
                color: AppColors.onCard, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this Give & Ask?',
            style: TextStyle(color: AppColors.onCardMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.onCardMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ActivityService.deleteGiveAsk(item.id.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Give & Ask deleted successfully'),
            backgroundColor: Colors.green));
        _fetchGiveAskList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Delete failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchGiveAskList() async {
    // Same dispose hazard as _fetchData: reached after `await
    // widget.onOpenSubmit()` from the delete handler's success path too.
    if (!mounted) return;
    if (_chapterGiveAskList.isEmpty && _myGiveAskList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

        final chapterData = await ActivityService.getActivities(
          'give_ask.php', 'giveask');

      final chapterList =
          List<ActivityModel>.from(chapterData['activities'] ?? []);
        final myList = chapterList.where((item) {
        final raw = item.rawJson;
        final owner = (raw['user_id'] ??
            raw['given_by'] ??
            raw['member_id'] ??
            raw['created_by'])
          ?.toString();
        return owner == userId;
        }).toList();

      try {
        final members = await MemberService.getAllMembers();
        _memberById = {for (final m in members) m.id.toString(): m};

        final missingIds = [...chapterList, ...myList]
            .map((a) =>
                (a.rawJson['user_id'] ?? a.rawJson['member_id'])?.toString())
            .whereType<String>()
            .where((id) =>
                id.isNotEmpty && id != 'null' && !_memberById.containsKey(id))
            .toSet();
        if (missingIds.isNotEmpty) {
          final fetched = await Future.wait(missingIds.map((id) async {
            try {
              final detail = await MemberService.getMemberDetail(int.parse(id));
              return MapEntry(id, UserModel.fromJson(detail));
            } catch (_) {
              return null;
            }
          }));
          for (final entry in fetched) {
            if (entry != null) _memberById[entry.key] = entry.value;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _chapterGiveAskList = chapterList;
          _myGiveAskList = myList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Weekly Give & Ask",
                style: TextStyle(
                    color: AppColors.cardHeading,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                "View chapter members Give & Ask and submit your weekly requests",
                style: TextStyle(color: AppColors.onCardMuted, fontSize: 13)),
            const SizedBox(height: 16),
            _ActionBtn(
                label: 'Submit Weekly Give & Ask',
                onTap: () => widget.onOpenSubmit()),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isChapterView = true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isChapterView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group,
                            size: 16,
                            color: _isChapterView
                                ? AppColors.primary
                                : const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text(
                            "Chapter Give & Ask (${_chapterGiveAskList.length})",
                            style: TextStyle(
                                color: _isChapterView
                                    ? AppColors.primary
                                    : const Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _isChapterView = false),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          !_isChapterView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 16,
                            color: !_isChapterView
                                ? AppColors.primary
                                : const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text("My Submissions (${_myGiveAskList.length})",
                            style: TextStyle(
                                color: !_isChapterView
                                    ? AppColors.primary
                                    : const Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.searchBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: _isLoading
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: goldColor)))
                  : _errorMessage != null
                      ? _ListErrorRetry(
                          message: _errorMessage!,
                          onRetry: _fetchGiveAskList)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text("Show ",
                                        style: TextStyle(
                                            color: AppColors.onCardMuted,
                                            fontSize: 11)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: AppColors.searchBorder)),
                                      child: Text("${_currentList.length}",
                                          style: TextStyle(
                                              color: AppColors.onCard,
                                              fontSize: 11)),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 120,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.searchBorder)),
                                  child: TextField(
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    style: TextStyle(
                                        color: AppColors.onCard, fontSize: 11),
                                    decoration: InputDecoration(
                                      hintText: 'Search records...',
                                      hintStyle: TextStyle(
                                          color: AppColors.onCardLabel,
                                          fontSize: 10),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_currentList.isEmpty) const _NoRecordsCard(),
                            ..._currentList.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildRow(item),
                              );
                            }),
                            const SizedBox(height: 16),
                            Text("Showing ${_currentList.length} records",
                                style: TextStyle(
                                    color: AppColors.onCardLabel,
                                    fontSize: 11)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(4))),
                                  child: Icon(Icons.chevron_left,
                                      color: AppColors.onCard, size: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  color: const Color(0xFF0D6EFD),
                                  child: const Text("1",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(4))),
                                  child: Icon(Icons.chevron_right,
                                      color: AppColors.onCard, size: 14),
                                ),
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

  Widget _buildRow(ActivityModel item) {
    final String date =
        item.rawJson['entry_date'] ?? item.rawJson['created_at'] ?? item.date;
    // The API sends these as `gives` / `asks`; the singular spellings are kept
    // as fallbacks for older payloads.
    final String give = item.rawJson['gives'] ??
        item.rawJson['give'] ??
        item.rawJson['what_i_give'] ??
        'N/A';
    final String ask = item.rawJson['asks'] ??
        item.rawJson['ask'] ??
        item.rawJson['what_i_ask'] ??
        'N/A';
    final String submittedOn = item.rawJson['created_at'] ?? item.date;

    final userId =
        (item.rawJson['user_id'] ?? item.rawJson['member_id'])?.toString();
    final resolvedMember = userId != null ? _memberById[userId] : null;
    final String name = (item.rawJson['display_name'] ??
            item.rawJson['first_name'] ??
            item.rawJson['user_name'] ??
            item.rawJson['name'] ??
            item.rawJson['member_name'] ??
            resolvedMember?.name ??
            (userId != null && userId.isNotEmpty && userId != 'null'
                ? 'Member #$userId'
                : '—'))
        .toString();
    final String company = (item.rawJson['company_name'] ??
            item.rawJson['company'] ??
            resolvedMember?.companyName ??
            '')
        .toString();

    if (_isChapterView) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: AppColors.onRecordCardLabel,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      if (company.isNotEmpty)
                        Text(company,
                            style: TextStyle(
                                color: AppColors.onRecordCardMuted,
                                fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(date,
                          style: TextStyle(
                              color: AppColors.onRecordCard,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.volunteer_activism,
                          color: Color(0xFF20C997), size: 14),
                      SizedBox(width: 6),
                      Text('Gives:',
                          style: TextStyle(
                              color: Color(0xFF20C997),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(give,
                      style: TextStyle(
                          color: AppColors.onRecordCard, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.handshake,
                          color: AppColors.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text('Asks:',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ask,
                      style: TextStyle(
                          color: AppColors.onRecordCard, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          // White in white theme, blue in dark theme (no dark-navy gradient).
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: AppColors.onRecordCardMuted),
                    const SizedBox(width: 6),
                    Text(date,
                        style: TextStyle(
                            color: AppColors.onRecordCard,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Submitted on: $submittedOn',
                    style: TextStyle(
                        color: AppColors.onRecordCardLabel, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.volunteer_activism,
                          color: Color(0xFF20C997), size: 14),
                      SizedBox(width: 6),
                      Text('Gives:',
                          style: TextStyle(
                              color: Color(0xFF20C997),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(give,
                      style: TextStyle(
                          color: AppColors.onRecordCardMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.handshake,
                          color: AppColors.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text('Asks:',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ask,
                      style: TextStyle(
                          color: AppColors.onRecordCardMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () {
                    if (widget.onEditItem != null) widget.onEditItem!(item);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.secondary),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text('Edit',
                            style: TextStyle(
                                color: AppColors.secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _deleteItem(item),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 14, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text('Delete',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
