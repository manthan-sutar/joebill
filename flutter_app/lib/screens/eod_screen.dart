import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

class EodScreen extends ConsumerStatefulWidget {
  const EodScreen({super.key});

  @override
  ConsumerState<EodScreen> createState() => _EodScreenState();
}

class _EodScreenState extends ConsumerState<EodScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.get('/reports/eod') as Map<String, dynamic>;
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('End of Day'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(_data!),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final openTabs = data['open_tabs'] ?? 0;
    final runningGames = data['running_games'] ?? 0;
    final overdue = data['overdue_tabs'] ?? 0;
    final settled = data['settled_today'] ?? 0;
    final revenue = (data['revenue_today'] as num?)?.toDouble() ?? 0;
    final openTotal = (data['open_total'] as num?)?.toDouble() ?? 0;
    final allClear = openTabs == 0 && runningGames == 0;

    return ListView(
      padding: const EdgeInsets.all(kSpaceMD),
      children: [
        Container(
          padding: const EdgeInsets.all(kSpaceMD),
          decoration: BoxDecoration(
            color: allClear ? kGreen.withValues(alpha: 0.12) : kAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kRadiusLG),
            border: Border.all(color: allClear ? kGreen.withValues(alpha: 0.4) : kAmber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(allClear ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: allClear ? kGreen : kAmber),
              const SizedBox(width: kSpaceSM),
              Expanded(
                child: Text(
                  allClear ? 'All clear — ready to close shop' : 'Action needed before closing',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: allClear ? kGreen : kAmber,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpaceLG),
        _StatRow('Open tabs', '$openTabs', openTabs > 0 ? kAmber : kTextLight),
        _StatRow('Open tabs total', formatCurrency(openTotal), kTextLight),
        _StatRow('Running games', '$runningGames', runningGames > 0 ? kAccent : kTextLight),
        _StatRow('Overdue tabs (3h+)', '$overdue', overdue > 0 ? kAmber : kTextLight),
        const Divider(height: kSpaceXL),
        _StatRow('Settled today', '$settled', kTextLight),
        _StatRow('Revenue today', formatCurrency(revenue), kGreen),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceSM),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: kTextMuted))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
        ],
      ),
    );
  }
}
