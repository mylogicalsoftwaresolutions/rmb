import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/export_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';
import 'report_table_screen.dart' show ReportFilterField;

/// One metric shown on a report detail page - a key into reports.php's
/// `performance` map, a label, and whether to format it as currency.
class ReportMetric {
  final String key;
  final String label;
  final bool isCurrency;
  const ReportMetric(this.key, this.label, {this.isCurrency = false});
}

/// A single report from the "My Reports" hub - title, icon and which
/// metrics from reports.php's `performance` block it shows. reports.php
/// only exposes one flat `performance` map per period (confirmed against
/// the live API - it has no per-category endpoint), so every report here
/// reads from the same source and just picks a different subset of it.
class ReportConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ReportMetric> metrics;
  const ReportConfig(this.title, this.subtitle, this.icon, this.metrics);
}

class ReportDetailScreen extends StatefulWidget {
  final ReportConfig config;
  const ReportDetailScreen({super.key, required this.config});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final goldColor = AppColors.secondary;

  String _selectedPeriod = 'Monthly';
  Map<String, dynamic> _perf = {};
  String _memberName = '';
  String _chapterName = '';
  bool _loading = true;
  bool _busy = false;

  // reports.php ignores start/end date parameters entirely (confirmed
  // directly against the live API - it only ever accepts a canned period),
  // so a date range here can't narrow the aggregate the way it does on the
  // per-row report tables. Rather than show pickers that silently do
  // nothing, applying a range maps it to whichever supported period it most
  // closely matches and re-fetches that.
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _uiPeriod => switch (_selectedPeriod) {
        'Weekly' => 'This Week',
        'Quarterly' => 'This Quarter',
        'Yearly' => 'This Year',
        'Term' => 'This Term',
        'Lifetime' => 'Lifetime',
        _ => 'This Month',
      };

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

  /// Maps the picked range onto the nearest period this endpoint actually
  /// supports, then reloads with it.
  void _applyDateRange() {
    if (_fromDate == null && _toDate == null) {
      _load();
      return;
    }
    final from = _fromDate ?? _toDate!;
    final to = _toDate ?? _fromDate!;
    final days = to.difference(from).inDays.abs();
    setState(() {
      _selectedPeriod = days <= 7
          ? 'Weekly'
          : days <= 31
              ? 'Monthly'
              : days <= 92
                  ? 'Quarterly'
                  : days <= 366
                      ? 'Yearly'
                      : 'Lifetime';
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reports = await ReportService.getReports(
          period: ReportService.periodParams[_uiPeriod] ?? 'monthly');
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _perf = Map<String, dynamic>.from(reports['performance'] ?? {});
        _memberName = prefs.getString('user_name') ?? '';
        _chapterName = prefs.getString('chapter_name') ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _i(String k) => int.tryParse(_perf[k]?.toString() ?? '0') ?? 0;
  double _d(String k) => double.tryParse(_perf[k]?.toString() ?? '0') ?? 0;

  String _valueFor(ReportMetric m) =>
      m.isCurrency ? '₹${_d(m.key).toStringAsFixed(2)}' : '${_i(m.key)}';

  String get _periodRange {
    final a = _perf['start']?.toString() ?? '';
    final b = _perf['end']?.toString() ?? '';
    return (a.isEmpty || b.isEmpty) ? _selectedPeriod : '$a to $b';
  }

  List<List<String>> get _rows =>
      widget.config.metrics.map((m) => [m.label, _valueFor(m)]).toList();

  Future<void> _exportToExcel() async {
    setState(() => _busy = true);
    try {
      final rows = <List<String>>[
        ['${widget.config.title} - $_selectedPeriod'],
        [],
        ['Member', _memberName],
        ['Chapter', _chapterName],
        ['Period', _periodRange],
        [],
        ['Metric', 'Value'],
        ..._rows,
      ];
      final csv = rows
          .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
          .join(String.fromCharCode(10));
      await ExportService.saveCsv(csv,
          '${widget.config.title.toLowerCase().replaceAll(' ', '_').replaceAll('/', '')}_${_selectedPeriod.toLowerCase()}.csv');
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  pw.Document _buildReportPdf() {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(widget.config.title,
                style: const pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: ExportService.blue)),
            pw.SizedBox(height: 4),
            pw.Text(_selectedPeriod,
                style: const pw.TextStyle(fontSize: 12, color: ExportService.muted)),
            pw.Divider(color: ExportService.gold, thickness: 1.5),
            pw.SizedBox(height: 10),
            if (_memberName.isNotEmpty) pw.Text('Member: $_memberName'),
            if (_chapterName.isNotEmpty) pw.Text('Chapter: $_chapterName'),
            pw.Text('Period: $_periodRange'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const ['Metric', 'Value'],
              data: _rows,
              headerStyle: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: ExportService.blue),
              cellAlignments: {1: pw.Alignment.centerRight},
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  Future<void> _printReport() async {
    setState(() => _busy = true);
    try {
      await ExportService.printDocument(_buildReportPdf(),
          name: widget.config.title.toLowerCase().replaceAll(' ', '_'));
    } catch (e) {
      _toast('Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUI.pageBg,
      appBar: AppUI.appBar(widget.config.title,
          onBack: () => Navigator.pop(context)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PopupMenuButton<String>(
                        color: AppColors.card,
                        onSelected: (val) {
                          setState(() => _selectedPeriod = val);
                          _load();
                        },
                        itemBuilder: (context) => [
                          'Weekly',
                          'Monthly',
                          'Quarterly',
                          'Yearly',
                          'Term',
                          'Lifetime'
                        ]
                            .map((e) => PopupMenuItem(
                                value: e,
                                child: Text(e, style: AppUI.bodyText(size: 14))))
                            .toList(),
                        child: _OutlinedBtn(
                            label: _selectedPeriod,
                            color: AppColors.border,
                            textColor: AppUI.body),
                      ),
                      Wrap(spacing: 8, children: [
                        GestureDetector(
                          onTap: _busy ? null : _exportToExcel,
                          child: _OutlinedBtn(
                              label: 'Excel',
                              color: goldColor,
                              textColor: goldColor,
                              icon: Icons.description),
                        ),
                        GestureDetector(
                          onTap: _busy ? null : _printReport,
                          child: _OutlinedBtn(
                              label: 'Print',
                              color: goldColor,
                              textColor: goldColor,
                              icon: Icons.print),
                        ),
                      ]),
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
                          label: _chapterName.isEmpty ? '-' : _chapterName,
                          enabled: false,
                        ),
                        ReportFilterField(
                          label: _memberName.isEmpty ? '-' : _memberName,
                          enabled: false,
                        ),
                        ElevatedButton(
                          onPressed: _applyDateRange,
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
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: AppUI.cardDecoration,
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _BannerItem(
                            title: 'Member',
                            value: _memberName.isEmpty ? '-' : _memberName),
                        _BannerItem(
                            title: 'Chapter',
                            value:
                                _chapterName.isEmpty ? '-' : _chapterName),
                        _BannerItem(title: 'Period', value: _periodRange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    childAspectRatio: 1.6,
                    physics: const NeverScrollableScrollPhysics(),
                    children: widget.config.metrics
                        .map((m) =>
                            _StatCard(title: m.label, value: _valueFor(m)))
                        .toList(),
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
  final Color textColor;
  final IconData? icon;

  const _OutlinedBtn(
      {required this.label,
      required this.color,
      required this.textColor,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 14),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final String title;
  final String value;
  const _BannerItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppUI.mutedText(size: 12)),
        const SizedBox(height: 8),
        Text(value,
            style: AppUI.bodyText(size: 14, weight: FontWeight.bold),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.cardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: AppUI.mutedText(size: 11), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(value, style: AppUI.headingText(size: 20)),
        ],
      ),
    );
  }
}
