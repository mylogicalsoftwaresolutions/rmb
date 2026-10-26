import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/member_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';
import 'report_detail_screen.dart';
import 'report_table_screen.dart';

/// The 8 reports on the web app's "My Reports" hub.
///
/// Performance and Attendance read reports.php's aggregate `performance`
/// block (no per-row data available for either - attendance.php doesn't
/// exist on this API, confirmed 404). The other five are real per-row
/// tables from their own list endpoints, matching the website's report
/// pages field-for-field. Business has no endpoint of its own either
/// (business.php also 404s) but is fully derivable by aggregating C-Notes
/// by giver/receiver pair, which is exactly what the website's Business
/// Report shows.
Future<List<Map<String, dynamic>>> _resolveMembers() async {
  final members = await MemberService.getAllMembers();
  return [for (final m in members) {'id': m.id.toString(), 'name': m.name}];
}

Future<String> _myUserId() async =>
    (await SharedPreferences.getInstance()).getString('user_id') ?? '';
Future<String> _myName() async =>
    (await SharedPreferences.getInstance()).getString('user_name') ?? '';
Future<String> _myChapter() async =>
    (await SharedPreferences.getInstance()).getString('chapter_name') ?? '';

Future<List<dynamic>> _rowsFrom(String endpoint) async {
  final userId = await _myUserId();
  final response = await ApiClient.get(
    endpoint,
    queryParams: {'user_id': userId},
      baseOverride: {
        'cnotes.php',
        'referrals.php',
        'testimonials.php',
        'visitors.php',
        'give_ask.php',
      }.contains(endpoint)
          ? ApiClient.flutterBaseUrl
          : null,
  );
  final data = response is Map ? response['data'] : null;
  return data is List ? data : [];
}

Future<List<Map<String, dynamic>>> _loadReferrals() async {
  final rows = await _rowsFrom('referrals.php');
  final myName = await _myName();
  final myChapter = await _myChapter();
  final members = await _resolveMembers();
  final nameById = {for (final m in members) m['id']?.toString(): m['name']};
  return rows.map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final receivedId = m['received_by']?.toString();
    final receiver = nameById[receivedId] ??
        (m['external_name']?.toString().isNotEmpty == true
            ? m['external_name'].toString()
            : '—');
    final desc = (m['description'] ?? m['details'] ?? m['notes'] ?? m['comments'] ?? '').toString().trim();
    return {
      'date': m['referral_date'] ?? '',
      'giver': myName,
      'receiver': receiver,
      'type': m['referral_type'] ?? '',
      'chapter': myChapter,
      'description': desc.isNotEmpty && desc != 'null' ? desc : '—',
      'status': m['status'] ?? '',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> _loadCNotes() async {
  final rows = await _rowsFrom('cnotes.php');
  final myChapter = await _myChapter();
  final myName = await _myName();
  final members = await _resolveMembers();
  final nameById = {for (final m in members) m['id']?.toString(): m['name']};

  final missingReceivedIds = rows
      .map((r) => (r as Map)['received_by']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty && id != 'null' && !nameById.containsKey(id))
      .toSet();
  if (missingReceivedIds.isNotEmpty) {
    final fetched = await Future.wait(missingReceivedIds.map((id) async {
      try {
        final detail = await MemberService.getMemberDetail(int.parse(id));
        return MapEntry(id, (detail['name'] ?? '').toString());
      } catch (_) {
        return null;
      }
    }));
    for (final entry in fetched) {
      if (entry != null && entry.value.isNotEmpty) nameById[entry.key] = entry.value;
    }
  }

  return rows.map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final desc = (m['description'] ?? m['notes'] ?? m['comments'] ?? m['details'] ?? m['topic'] ?? '').toString().trim();
    return {
      'date': m['cnote_date'] ?? '',
      'given_by': myName,
      'received_by': nameById[m['received_by']?.toString()] ?? '—',
      'chapter': myChapter,
      'description': desc.isNotEmpty && desc != 'null' ? desc : '—',
      'status': m['status'] ?? '',
      'amount': m['amount']?.toString() ?? '0',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> _loadR2R() async {
  final rows = await _rowsFrom('r2r.php');
  final myName = await _myName();
  final myChapter = await _myChapter();
  final members = await _resolveMembers();
  final nameById = {for (final m in members) m['id']?.toString(): m['name']};

  final missingPartnerIds = rows
      .map((r) {
        final m = r as Map;
        return (m['partner_id'] ?? m['met_with'] ?? m['member_id'] ?? m['received_by'] ?? m['to_user_id'] ?? m['to_member_id'])?.toString();
      })
      .whereType<String>()
      .where((id) => id.isNotEmpty && id != 'null' && !nameById.containsKey(id))
      .toSet();

  if (missingPartnerIds.isNotEmpty) {
    final fetched = await Future.wait(missingPartnerIds.map((id) async {
      try {
        final detail = await MemberService.getMemberDetail(int.parse(id));
        return MapEntry(id, (detail['name'] ?? '').toString());
      } catch (_) {
        return null;
      }
    }));
    for (final entry in fetched) {
      if (entry != null && entry.value.isNotEmpty) nameById[entry.key] = entry.value;
    }
  }

  return rows.map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final partnerNameRaw = (m['partner_name'] ?? m['met_with_name'] ?? m['member_name'] ?? m['to_member_name'])?.toString() ?? '';
    final partnerId = (m['partner_id'] ?? m['met_with'] ?? m['member_id'] ?? m['received_by'] ?? m['to_user_id'] ?? m['to_member_id'])?.toString();
    final partner = partnerNameRaw.isNotEmpty
        ? partnerNameRaw
        : (nameById[partnerId] ?? (partnerId != null && partnerId != 'null' && partnerId.isNotEmpty ? 'Member #$partnerId' : '—'));
    final desc = (m['topic'] ?? m['description'] ?? m['notes'] ?? m['comments'] ?? m['details'] ?? '').toString().trim();
    return {
      'date': m['meeting_date'] ?? m['entry_date'] ?? m['created_at'] ?? '',
      'given_by': myName,
      'received_by': partner,
      'chapter': myChapter,
      'description': desc.isNotEmpty && desc != 'null' ? desc : '—',
      'status': m['status'] ?? '',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> _loadTestimonials() async {
  final rows = await _rowsFrom('testimonials.php');
  final myName = await _myName();
  final myChapter = await _myChapter();
  return rows.map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final receiver = (m['display_name']?.toString().isNotEmpty == true)
        ? m['display_name'].toString()
        : '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    return {
      'date': m['testimonial_date'] ?? '',
      'given_by': myName,
      'received_by': receiver.isEmpty ? '—' : receiver,
      'chapter': myChapter,
      'status': m['status'] ?? '',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> _loadVisitors() async {
  final rows = await _rowsFrom('visitors.php');
  final myName = await _myName();
  final myChapter = await _myChapter();
  return rows.map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    return {
      'date': m['visit_date'] ?? m['entry_date'] ?? m['created_at'] ?? '',
      'visitor': m['name'] ?? m['visitor_name'] ?? '',
      'company': m['company'] ?? m['company_name'] ?? '',
      'mobile': m['mobile'] ?? m['visitor_mobile'] ?? '',
      'invited_by': myName,
      'chapter': myChapter,
      'status': m['status'] ?? '',
    };
  }).toList();
}

/// business.php 404s on this API - there is no dedicated endpoint - but the
/// website's Business Report is exactly a C-Notes rollup grouped by
/// giver/receiver pair, which is fully derivable from cnotes.php alone.
Future<List<Map<String, dynamic>>> _loadBusiness() async {
  final cnotes = await _loadCNotes();
  final grouped = <String, Map<String, dynamic>>{};
  for (final r in cnotes) {
    final key = '${r['given_by']}|${r['received_by']}';
    final entry = grouped.putIfAbsent(
        key,
        () => {
              'given_by': r['given_by'],
              'received_by': r['received_by'],
              'chapter': r['chapter'],
              'cnotes_count': 0,
              'amount': 0.0,
            });
    entry['cnotes_count'] = (entry['cnotes_count'] as int) + 1;
    entry['amount'] = (entry['amount'] as double) +
        (double.tryParse(r['amount'].toString()) ?? 0);
  }
  return grouped.values.toList();
}

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <_HubCard>[
      _HubCard(
        'My Performance',
        'Your personal PR across all metrics',
        Icons.pie_chart_outline,
        () => const ReportDetailScreen(
            config: ReportConfig('My Performance',
                'Your personal PR across all metrics', Icons.pie_chart_outline, [
              ReportMetric('referrals_given', 'Referrals Given'),
              ReportMetric('referrals_received', 'Referrals Received'),
              ReportMetric('business_given_count', 'Business Given (Count)'),
              ReportMetric('business_given_amount', 'Business Given (Amount)',
                  isCurrency: true),
              ReportMetric(
                  'business_received_count', 'Business Received (Count)'),
              ReportMetric(
                  'business_received_amount', 'Business Received (Amount)',
                  isCurrency: true),
              ReportMetric('testimonials_given', 'Testimonials Given'),
              ReportMetric('testimonials_received', 'Testimonials Received'),
              ReportMetric('r2r_count', 'R2R Meetings'),
              ReportMetric('present_count', 'Present'),
              ReportMetric('absent_count', 'Absent'),
              ReportMetric('visitor_count', 'Visitors Invited'),
            ])),
      ),
      _HubCard(
        'My Referrals',
        'Referrals given & received by you',
        Icons.share_outlined,
        () => ReportTableScreen(
          title: 'Referral Report',
          dateColumnKey: 'date',
          loader: _loadReferrals,
          columns: [
            ReportColumn('DATE', (r) => r['date'].toString()),
            ReportColumn('GIVER', (r) => r['giver'].toString()),
            ReportColumn('RECEIVER', (r) => r['receiver'].toString()),
            ReportColumn('TYPE', (r) => r['type'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('DESCRIPTION', (r) => (r['description'] ?? '—').toString()),
            ReportColumn('STATUS', (r) => r['status'].toString(),
                isStatus: true),
          ],
        ),
      ),
      _HubCard(
        'My C-Notes / Business',
        'Closed business value for you',
        Icons.description_outlined,
        () => ReportTableScreen(
          title: 'C-Notes',
          dateColumnKey: 'date',
          loader: _loadCNotes,
          columns: [
            ReportColumn('DATE', (r) => r['date'].toString()),
            ReportColumn('GIVEN BY', (r) => r['given_by'].toString()),
            ReportColumn('RECEIVED BY', (r) => r['received_by'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('DESCRIPTION', (r) => (r['description'] ?? '—').toString()),
            ReportColumn('STATUS', (r) => r['status'].toString(),
                isStatus: true),
            ReportColumn(
                'AMOUNT',
                (r) =>
                    (double.tryParse(r['amount'].toString()) ?? 0)
                        .toStringAsFixed(2)),
          ],
          summaryBuilder: (rows) {
            final total = rows.fold<double>(
                0, (s, r) => s + (double.tryParse(r['amount'].toString()) ?? 0));
            return [
              MapEntry('Total Amount', '₹${total.toStringAsFixed(2)}'),
              MapEntry('Records', '${rows.length}'),
            ];
          },
        ),
      ),
      _HubCard(
        'My R2R',
        'Rotary-to-Rotary meetings',
        Icons.handshake_outlined,
        () => ReportTableScreen(
          title: 'R2R',
          dateColumnKey: 'date',
          loader: _loadR2R,
          columns: [
            ReportColumn('DATE', (r) => r['date'].toString()),
            ReportColumn('GIVEN BY', (r) => r['given_by'].toString()),
            ReportColumn('RECEIVED BY', (r) => r['received_by'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('DESCRIPTION', (r) => (r['description'] ?? '—').toString()),
            ReportColumn('STATUS', (r) => r['status'].toString(),
                isStatus: true),
          ],
        ),
      ),
      _HubCard(
        'My Testimonials',
        'Testimonials given & received',
        Icons.format_quote,
        () => ReportTableScreen(
          title: 'Testimonials',
          dateColumnKey: 'date',
          loader: _loadTestimonials,
          columns: [
            ReportColumn('DATE', (r) => r['date'].toString()),
            ReportColumn('GIVEN BY', (r) => r['given_by'].toString()),
            ReportColumn('RECEIVED BY', (r) => r['received_by'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('STATUS', (r) => r['status'].toString(),
                isStatus: true),
          ],
        ),
      ),
      _HubCard(
        'My Attendance',
        'Your meeting attendance history',
        Icons.check_circle_outline,
        () => const ReportDetailScreen(
            config: ReportConfig('My Attendance',
                'Your meeting attendance history', Icons.check_circle_outline, [
              ReportMetric('present_count', 'Present'),
              ReportMetric('absent_count', 'Absent'),
            ])),
      ),
      _HubCard(
        'My Visitors',
        'Your visitor invitations',
        Icons.person_add_alt,
        () => ReportTableScreen(
          title: 'Visitor Report',
          dateColumnKey: 'date',
          loader: _loadVisitors,
          columns: [
            ReportColumn('DATE', (r) => r['date'].toString()),
            ReportColumn('VISITOR', (r) => r['visitor'].toString()),
            ReportColumn('COMPANY', (r) => r['company'].toString()),
            ReportColumn('MOBILE', (r) => r['mobile'].toString()),
            ReportColumn('INVITED BY', (r) => r['invited_by'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('STATUS', (r) => r['status'].toString(),
                isStatus: true),
          ],
          summaryBuilder: (rows) => [MapEntry('Visitors', '${rows.length}')],
        ),
      ),
      _HubCard(
        'My Business',
        'Aggregated business analytics for you',
        Icons.currency_rupee,
        () => ReportTableScreen(
          title: 'Business Report',
          dateColumnKey: 'date',
          loader: _loadBusiness,
          columns: [
            ReportColumn(
                'BUSINESS GIVEN BY', (r) => r['given_by'].toString()),
            ReportColumn(
                'BUSINESS RECEIVED BY', (r) => r['received_by'].toString()),
            ReportColumn('CHAPTER', (r) => r['chapter'].toString()),
            ReportColumn('C-NOTES', (r) => r['cnotes_count'].toString()),
            ReportColumn('AMOUNT',
                (r) => (r['amount'] as double).toStringAsFixed(2)),
          ],
          summaryBuilder: (rows) {
            final total =
                rows.fold<double>(0, (s, r) => s + (r['amount'] as double));
            return [MapEntry('Total Business', '₹${total.toStringAsFixed(2)}')];
          },
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppUI.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Reports', style: AppUI.headingText(size: 22)),
            const SizedBox(height: 4),
            Text('View and export your personal activity reports',
                style: AppUI.mutedText(size: 12)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: 1.1,
              physics: const NeverScrollableScrollPhysics(),
              children: cards,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;

  const _HubCard(this.title, this.subtitle, this.icon, this.builder);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => builder())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppUI.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.secondary, size: 26),
            const Spacer(),
            Text(title,
                style: AppUI.headingText(size: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(subtitle,
                style: AppUI.mutedText(size: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
