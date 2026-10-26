import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

/// One column of a report table: a header label and how to pull that
/// column's text out of a row map. [isStatus] renders the value as a
/// coloured pill instead of plain text, matching the website's badges.
class ReportColumn {
  final String header;
  final String Function(Map<String, dynamic> row) valueOf;
  final bool isStatus;
  const ReportColumn(this.header, this.valueOf, {this.isStatus = false});
}

Color statusColor(String rawStatus) {
  switch (rawStatus.trim().toLowerCase()) {
    case 'approved':
      return const Color(0xFF22C55E);
    case 'success':
      return const Color(0xFF38BDF8);
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'failure':
    case 'rejected':
      return const Color(0xFFEF4444);
    default:
      return Colors.grey;
  }
}

/// A report backed by a real list endpoint (referrals.php, cnotes.php, ...)
/// rather than reports.php's aggregate `performance` block. Mirrors the
/// website's per-report tables: a date range, a search box, a data table
/// with status badges, and Excel/Print export of exactly what's on screen.
class ReportTableScreen extends StatefulWidget {
  final String title;
  final String dateColumnKey;
  final List<ReportColumn> columns;
  final Future<List<Map<String, dynamic>>> Function() loader;
  /// Extra summary tiles above the table, e.g. "Total Amount". Computed from
  /// the currently visible (filtered) rows.
  final List<MapEntry<String, String>> Function(List<Map<String, dynamic>> rows)?
      summaryBuilder;
  /// Shown instead of an empty state when the loader itself failed - the
  /// two reports with no working endpoint (Attendance, Business) use this.
  final String? unavailableMessage;

  const ReportTableScreen({
    super.key,
    required this.title,
    required this.dateColumnKey,
    required this.columns,
    required this.loader,
    this.summaryBuilder,
    this.unavailableMessage,
  });

  @override
  State<ReportTableScreen> createState() => _ReportTableScreenState();
}

class _ReportTableScreenState extends State<ReportTableScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  bool _busy = false;

  // Matches the website's filter row (date from/to + chapter + member name)
  // on every report page. The list endpoints don't respect date query
  // params (confirmed on reports.php; assumed the same here rather than
  // risk silently-ignored filters), so this filters client-side against
  // whatever rows are already loaded.
  DateTime? _fromDate;
  DateTime? _toDate;
  String _myChapter = '';
  String _myName = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _load();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _myChapter = prefs.getString('chapter_name') ?? '';
      _myName = prefs.getString('user_name') ?? '';
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.loader();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: AppUI.datePickerTheme,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'dd-mm-yyyy'
      : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  /// The summary tiles used to just say "Records: 7" with no way to tell
  /// which date range that number covered once a filter was applied.
  String get _periodLabel {
    if (_fromDate == null && _toDate == null) return 'All records';
    if (_fromDate != null && _toDate != null) {
      return '${_fmtDate(_fromDate)} to ${_fmtDate(_toDate)}';
    }
    if (_fromDate != null) return 'From ${_fmtDate(_fromDate)}';
    return 'Until ${_fmtDate(_toDate)}';
  }

  List<Map<String, dynamic>> get _visibleRows {
    var rows = _rows;
    if (_fromDate != null || _toDate != null) {
      rows = rows.where((r) {
        final raw = r[widget.dateColumnKey]?.toString() ?? '';
        final d = DateTime.tryParse(raw);
        if (d == null) return true;
        if (_fromDate != null && d.isBefore(_fromDate!)) return false;
        if (_toDate != null &&
            d.isAfter(_toDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      rows = rows
          .where((r) => widget.columns.any((c) => c.valueOf(r).toLowerCase().contains(q)))
          .toList();
    }
    return rows;
  }

  List<List<String>> get _tableData => _visibleRows
      .map((r) => widget.columns.map((c) => c.valueOf(r)).toList())
      .toList();

  Future<void> _exportToExcel() async {
    setState(() => _busy = true);
    try {
      final rows = <List<String>>[
        [widget.title],
        [],
        [for (final c in widget.columns) c.header],
        ..._tableData,
      ];
      final csv = rows
          .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
          .join(String.fromCharCode(10));
      await ExportService.saveCsv(
          csv, '${widget.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.csv');
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  pw.Document _buildPdf() {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(widget.title,
                style: const pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: ExportService.blue)),
            pw.Divider(color: ExportService.gold, thickness: 1.5),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [for (final c in widget.columns) c.header],
              data: _tableData,
              headerStyle: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: ExportService.blue),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      await ExportService.printDocument(_buildPdf(),
          name: widget.title.toLowerCase().replaceAll(' ', '_'));
    } catch (e) {
      _toast('Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final rows = _visibleRows;
    final summary = [
      MapEntry('Period', _periodLabel),
      ...(widget.summaryBuilder?.call(rows) ??
          [MapEntry('Records', '${rows.length}')]),
    ];

    return Scaffold(
      backgroundColor: AppUI.pageBg,
      appBar: AppUI.appBar(widget.title, onBack: () => Navigator.pop(context)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.unavailableMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(widget.unavailableMessage!,
                        textAlign: TextAlign.center,
                        style: AppUI.mutedText(size: 13)),
                  ),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Could not load this report.\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _busy ? null : _exportToExcel,
                                child: _OutlinedBtn(
                                    label: 'Export CSV',
                                    color: goldColor,
                                    icon: Icons.description),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _busy ? null : _print,
                                child: _OutlinedBtn(
                                    label: 'Print / Save PDF',
                                    color: goldColor,
                                    icon: Icons.print),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppColors.cardGradient,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ReportFilterField(
                                  label: _fmtDate(_fromDate),
                                  icon: Icons.calendar_today,
                                  onTap: () => _pickDate(true),
                                ),
                                ReportFilterField(
                                  label: _fmtDate(_toDate),
                                  icon: Icons.calendar_today,
                                  onTap: () => _pickDate(false),
                                ),
                                ReportFilterField(
                                  label: _myChapter.isEmpty ? '-' : _myChapter,
                                  enabled: false,
                                ),
                                ReportFilterField(
                                  label: _myName.isEmpty ? '-' : _myName,
                                  enabled: false,
                                ),
                                ElevatedButton(
                                  onPressed: () => setState(() {}),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: goldColor,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Apply filters',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (_fromDate != null || _toDate != null)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _fromDate = null;
                                      _toDate = null;
                                    }),
                                    child: const Text('Clear'),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: summary
                                .map((e) => _SummaryTile(
                                    label: e.key, value: e.value))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              style: AppUI.bodyText(size: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search records...',
                                hintStyle: AppUI.mutedText(size: 12),
                                prefixIcon: Icon(Icons.search,
                                    color: AppColors.textMuted, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (rows.isEmpty)
                            const AppEmptyState('No records found.')
                          else
                            Column(
                              children: [
                                for (final r in rows)
                                  _RecordCard(columns: widget.columns, row: r),
                              ],
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _OutlinedBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _OutlinedBtn({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(14),
      decoration: AppUI.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppUI.mutedText(size: 12)),
          const SizedBox(height: 6),
          Text(value, style: AppUI.headingText(size: 18)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = status.isEmpty
        ? '-'
        : status[0].toUpperCase() + status.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// One record rendered as a vertical card instead of a DataTable row, so
/// the report pages don't need horizontal scrolling to read a record.
/// The first non-status column is used as the card's title; every other
/// column (status columns rendered as a badge, not a label:value row).
class _RecordCard extends StatelessWidget {
  final List<ReportColumn> columns;
  final Map<String, dynamic> row;
  const _RecordCard({required this.columns, required this.row});

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();
    final statusCols = columns.where((c) => c.isStatus).toList();
    final nonStatusCols = columns.where((c) => !c.isStatus).toList();
    final titleCol = nonStatusCols.isNotEmpty ? nonStatusCols.first : columns.first;
    final detailCols = nonStatusCols.skip(nonStatusCols.isNotEmpty ? 1 : 0).toList();

    String valueOrDash(ReportColumn c) {
      final v = c.valueOf(row);
      return v.isEmpty ? '-' : v;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppUI.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(valueOrDash(titleCol), style: AppUI.titleText(size: 14)),
              ),
              if (statusCols.isNotEmpty) ...[
                const SizedBox(width: 8),
                _StatusBadge(statusCols.first.valueOf(row)),
              ],
            ],
          ),
          if (detailCols.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: AppUI.divider, height: 1),
            const SizedBox(height: 10),
            for (final c in detailCols)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(c.header,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    Text(':',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(valueOrDash(c), style: AppUI.bodyText(size: 13))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One box in the filter row - a date/chapter/member field. Read-only
/// fields (chapter, member) match the website's greyed-out, disabled
/// versions of the same inputs.
class ReportFilterField extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;

  const ReportFilterField({super.key, 
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.card : AppColors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: enabled ? AppUI.body : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
