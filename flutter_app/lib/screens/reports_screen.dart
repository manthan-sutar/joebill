import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

enum _ReportPreset { today, yesterday, week, month, custom }

class _ReportQuery {
  final DateTime from;
  final DateTime to;
  final String paymentMethod;
  final String category;

  const _ReportQuery({
    required this.from,
    required this.to,
    this.paymentMethod = 'all',
    this.category = 'all',
  });

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String toApiPath() {
    final sameDay = from.year == to.year &&
        from.month == to.month &&
        from.day == to.day;
    var path = sameDay
        ? '/reports/daily?date=${_d(from)}'
        : '/reports/daily?from=${_d(from)}&to=${_d(to)}';
    if (paymentMethod != 'all') path += '&payment_method=$paymentMethod';
    if (category != 'all') path += '&category=$category';
    return path;
  }
}

final _reportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, path) async {
  return await ApiService.instance.get(path);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportPreset _preset = _ReportPreset.today;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _payment = 'all';
  String _category = 'all';

  _ReportQuery get _query => _ReportQuery(
        from: _from,
        to: _to,
        paymentMethod: _payment,
        category: _category,
      );

  void _applyPreset(_ReportPreset p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = p;
      switch (p) {
        case _ReportPreset.today:
          _from = _to = today;
        case _ReportPreset.yesterday:
          _from = _to = today.subtract(const Duration(days: 1));
        case _ReportPreset.week:
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to = today;
        case _ReportPreset.month:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
        case _ReportPreset.custom:
          break;
      }
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kAccent),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _preset = _ReportPreset.custom;
        _from = range.start;
        _to = range.end;
      });
    }
  }

  String get _periodLabel {
    if (_from.year == _to.year &&
        _from.month == _to.month &&
        _from.day == _to.day) {
      return formatDate(_from);
    }
    return '${formatDate(_from)} – ${formatDate(_to)}';
  }

  @override
  Widget build(BuildContext context) {
    final apiPath = _query.toApiPath();
    final reportAsync = ref.watch(_reportProvider(apiPath));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _presetChip('Today', _ReportPreset.today),
                  _presetChip('Yesterday', _ReportPreset.yesterday),
                  _presetChip('Week', _ReportPreset.week),
                  _presetChip('Month', _ReportPreset.month),
                  ActionChip(
                    label: Text(_preset == _ReportPreset.custom
                        ? _periodLabel
                        : 'Custom'),
                    avatar: const Icon(Icons.date_range, size: 16),
                    onPressed: _pickRange,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _payment,
                    decoration: const InputDecoration(
                      labelText: 'Payment',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    ],
                    onChanged: (v) => setState(() => _payment = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'beverage', child: Text('Beverage')),
                      DropdownMenuItem(value: 'drink', child: Text('Drink')),
                      DropdownMenuItem(value: 'food', child: Text('Food')),
                      DropdownMenuItem(value: 'game', child: Text('Game')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_periodLabel,
                style: const TextStyle(color: kTextMuted, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.toString(), style: const TextStyle(color: kTextMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_reportProvider(apiPath)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (report) => _ReportBody(report: report),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, _ReportPreset preset) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _preset == preset,
        onSelected: (_) => _applyPreset(preset),
        checkmarkColor: kAccent,
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final summary = report['summary'] as Map<String, dynamic>;
    final byCategory = report['by_category'] as List<dynamic>;
    final gameBreakdown = report['game_breakdown'] as List<dynamic>;
    final topItems = report['top_items'] as List<dynamic>;

    final totalRevenue =
        double.parse(summary['total_revenue']?.toString() ?? '0');
    final totalBills = int.parse(summary['total_bills']?.toString() ?? '0');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Revenue',
                value: formatCurrency(totalRevenue),
                icon: Icons.currency_rupee,
                color: kAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Bills Settled',
                value: '$totalBills',
                icon: Icons.receipt_long,
                color: kGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Cash',
                value: formatCurrency(
                    double.parse(summary['cash_revenue']?.toString() ?? '0')),
                icon: Icons.money,
                color: kAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'UPI',
                value: formatCurrency(
                    double.parse(summary['upi_revenue']?.toString() ?? '0')),
                icon: Icons.qr_code,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (byCategory.isNotEmpty) ...[
          const Text('Revenue by Category',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(byCategory, totalRevenue),
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...byCategory.map((cat) {
            final rev = double.parse(cat['revenue']?.toString() ?? '0');
            final pct = totalRevenue > 0
                ? (rev / totalRevenue * 100).toStringAsFixed(1)
                : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _categoryColor(cat['category']),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(categoryLabel(cat['category'])),
                  const Spacer(),
                  Text('$pct%', style: const TextStyle(color: kTextMuted)),
                  const SizedBox(width: 12),
                  Text(formatCurrency(rev),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
        if (gameBreakdown.isNotEmpty) ...[
          const Text('Game Breakdown',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          ...gameBreakdown.map((g) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_esports, color: kGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g['game_name'],
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${g['sessions']} sessions • ${double.parse(g['total_minutes']?.toString() ?? '0').toStringAsFixed(0)} min',
                              style: const TextStyle(color: kTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(
                            double.parse(g['revenue']?.toString() ?? '0')),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),
        ],
        if (topItems.isNotEmpty) ...[
          const Text('Top Items',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          ...topItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: kAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['menu_item_name'],
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(categoryLabel(item['category']),
                              style: const TextStyle(color: kTextMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('x${item['total_qty']}',
                            style: const TextStyle(color: kTextMuted, fontSize: 12)),
                        Text(
                          formatCurrency(
                              double.parse(item['revenue']?.toString() ?? '0')),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        if (totalBills == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No bills in this period',
                  style: TextStyle(color: kTextMuted)),
            ),
          ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(List<dynamic> cats, double total) {
    return cats.map((cat) {
      final rev = double.parse(cat['revenue']?.toString() ?? '0');
      final pct = total > 0 ? rev / total * 100 : 0.0;
      return PieChartSectionData(
        value: rev,
        title: '${pct.toStringAsFixed(0)}%',
        color: _categoryColor(cat['category']),
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'beverage':
        return Colors.blue;
      case 'drink':
        return kAmber;
      case 'food':
        return kGreen;
      case 'game':
        return kAccent;
      default:
        return kTextMuted;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
