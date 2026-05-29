import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/tabs_provider.dart';
import '../models/bill_tab.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../utils/confirm_dialog.dart';
import '../utils/validators.dart';
import 'tab_detail_screen.dart';
import 'eod_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _refreshTimer;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tabsProvider.notifier).load();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.read(tabsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BillTab> _filterTabs(List<BillTab> tabs) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _sortTabs(tabs);
    return _sortTabs(tabs.where((t) {
      if (t.customerName.toLowerCase().contains(q)) return true;
      final phone = t.customerPhone;
      return phone != null && phone.contains(q);
    }).toList());
  }

  List<BillTab> _sortTabs(List<BillTab> tabs) {
    final sorted = [...tabs];
    sorted.sort((a, b) {
      final aOld = DateTime.now().difference(a.openedAt).inHours >= 3;
      final bOld = DateTime.now().difference(b.openedAt).inHours >= 3;
      if (aOld != bOld) return aOld ? -1 : 1;
      final aLive = (a.activeGames ?? 0) > 0;
      final bLive = (b.activeGames ?? 0) > 0;
      if (aLive != bLive) return aLive ? -1 : 1;
      return b.openedAt.compareTo(a.openedAt);
    });
    return sorted;
  }

  Future<void> _newTab() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXXL)),
      ),
      builder: (_) => const _NewTabSheet(),
    );
    if (result == null) return;

    final name = result['name'] as String;
    final existing = ref.read(tabsProvider.notifier).findOpenTabByName(name);
    if (existing != null && mounted) {
      final openExisting = await confirmAction(
        context,
        title: 'Tab already open',
        message: '"$name" already has an open tab. Open it instead of creating a duplicate?',
        confirmLabel: 'Open Existing',
      );
      if (openExisting) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TabDetailScreen(tabId: existing.id)),
        ).then((_) => ref.read(tabsProvider.notifier).refresh());
        return;
      }
    }

    try {
      final tab = await ref.read(tabsProvider.notifier).createTab(
            result['name'],
            customerId: result['customer_id'],
            customerPhone: result['phone'],
          );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TabDetailScreen(tabId: tab.id)),
      ).then((_) => ref.read(tabsProvider.notifier).refresh());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final tabsAsync = ref.watch(tabsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(kRadiusSM),
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 18, color: kAccent),
            ),
            const SizedBox(width: kSpaceSM),
            const Text("Joe's Corner"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'End of Day',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EodScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(tabsProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: kSpaceXS),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Staff info + stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM + 2),
            decoration: const BoxDecoration(
              color: kSurface,
              border: Border(bottom: BorderSide(color: kDivider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kCardAlt,
                    borderRadius: BorderRadius.circular(kRadiusSM),
                  ),
                  child: Center(
                    child: Text(
                      (auth.user?.name ?? 'S').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: kTextLight, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: kSpaceSM),
                Text(
                  auth.user?.name ?? '',
                  style: const TextStyle(color: kTextMuted, fontSize: 13),
                ),
                const Spacer(),
                tabsAsync.when(
                  data: (tabs) {
                    final oldTabs = tabs.where((t) => DateTime.now().difference(t.openedAt).inHours >= 3).length;
                    return Row(
                      children: [
                        if (oldTabs > 0) ...[
                          _StatPill(label: '$oldTabs overdue', color: kAmber, icon: Icons.warning_amber_rounded),
                          const SizedBox(width: kSpaceSM),
                        ],
                        _StatPill(label: '${tabs.length} open', color: kGreen, icon: Icons.table_bar_rounded),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM + 4, kSpaceMD, kSpaceSM),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search open tabs...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: kSpaceSM + 2),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          Expanded(
            child: tabsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.read(tabsProvider.notifier).load(),
              ),
              data: (tabs) {
                if (tabs.isEmpty) return _EmptyState(onNewTab: _newTab);
                final filtered = _filterTabs(tabs);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 40, color: kTextMuted),
                        const SizedBox(height: kSpaceSM),
                        Text(
                          'No tabs match "$_searchQuery"',
                          style: const TextStyle(color: kTextMuted),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: kAccent,
                  onRefresh: () => ref.read(tabsProvider.notifier).refresh(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(kSpaceMD),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent: 186,
                      crossAxisSpacing: kSpaceSM + 4,
                      mainAxisSpacing: kSpaceSM + 4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _TabCard(
                      tab: filtered[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TabDetailScreen(tabId: filtered[i].id),
                        ),
                      ).then((_) => ref.read(tabsProvider.notifier).refresh()),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTab,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Tab'),
        elevation: 4,
      ),
    );
  }
}

// ─── New Tab Bottom Sheet ───────────────────────────────────────────────────

class _NewTabSheet extends StatefulWidget {
  const _NewTabSheet();

  @override
  State<_NewTabSheet> createState() => _NewTabSheetState();
}

class _NewTabSheetState extends State<_NewTabSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<Customer> _suggestions = [];
  Customer? _selectedCustomer;
  bool _loadingSuggestions = false;
  Timer? _debounce;

  static const _tablePresets = [
    ('Table 1', Icons.table_bar_rounded),
    ('Table 2', Icons.table_bar_rounded),
    ('Table 3', Icons.table_bar_rounded),
    ('Table 4', Icons.table_bar_rounded),
    ('Pool Table', Icons.sports_esports_rounded),
    ('Bar', Icons.local_bar_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadTopCustomers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTopCustomers() async {
    setState(() => _loadingSuggestions = true);
    try {
      final data = await ApiService.instance.get('/customers') as List;
      if (mounted) {
        setState(() {
          _suggestions = data.map((e) => Customer.fromJson(e)).toList();
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _searchCustomers(String q) async {
    if (q.trim().isEmpty) { _loadTopCustomers(); return; }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final data = await ApiService.instance.get('/customers?q=${Uri.encodeComponent(q)}') as List;
        if (mounted) setState(() => _suggestions = data.map((e) => Customer.fromJson(e)).toList());
      } catch (_) {}
    });
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone ?? '';
      _suggestions = [];
    });
  }

  void _selectPreset(String name) {
    setState(() {
      _selectedCustomer = null;
      _nameCtrl.text = name;
      _phoneCtrl.clear();
      _suggestions = [];
    });
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final phoneErr = phoneValidationMessage(_phoneCtrl.text.trim());
    if (phoneErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneErr), backgroundColor: kAccent),
      );
      return;
    }
    Navigator.pop(context, {
      'name': name,
      'customer_id': _selectedCustomer?.id,
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: kSpaceMD),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kTextMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: kSpaceMD),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
            child: Row(
              children: [
                const Text('Open New Tab',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_nameCtrl.text.trim().isNotEmpty)
                  ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
                    ),
                    child: const Text('Open Tab'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: kSpaceMD),

          // Table presets
          const Padding(
            padding: EdgeInsets.only(left: kSpaceMD, bottom: kSpaceSM),
            child: Text('QUICK SELECT',
                style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
            child: Row(
              children: _tablePresets.map((p) {
                final selected = _nameCtrl.text == p.$1 && _selectedCustomer == null;
                return Padding(
                  padding: const EdgeInsets.only(right: kSpaceSM),
                  child: GestureDetector(
                    onTap: () => _selectPreset(p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM + 2),
                      decoration: BoxDecoration(
                        color: selected ? kAccent.withValues(alpha: 0.15) : kCardAlt,
                        borderRadius: BorderRadius.circular(kRadiusMD),
                        border: Border.all(
                          color: selected ? kAccent : kDivider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.$2, size: 14,
                              color: selected ? kAccent : kTextMuted),
                          const SizedBox(width: kSpaceXS + 2),
                          Text(
                            p.$1,
                            style: TextStyle(
                              color: selected ? kAccent : kTextLight,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: kSpaceMD),

          // Name field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                suffixIcon: _nameCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _nameCtrl.clear();
                          _phoneCtrl.clear();
                          setState(() => _selectedCustomer = null);
                          _loadTopCustomers();
                        },
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) {
                setState(() => _selectedCustomer = null);
                _searchCustomers(v);
              },
              onSubmitted: (_) => _confirm(),
            ),
          ),

          // Autocomplete suggestions
          if (_loadingSuggestions)
            const Padding(
              padding: EdgeInsets.all(kSpaceMD),
              child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM, kSpaceMD, 0),
              decoration: BoxDecoration(
                color: kCardAlt,
                borderRadius: BorderRadius.circular(kRadiusMD),
                border: Border.all(color: kDivider),
              ),
              child: Column(
                children: _suggestions.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  final isLast = i == _suggestions.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: kAccent.withValues(alpha: 0.12),
                          child: Text(
                            c.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          [
                            if (c.phone != null) c.phone!,
                            '${c.visitCount} visit${c.visitCount != 1 ? 's' : ''}',
                            if (c.lastVisit != null) 'last: ${formatDate(c.lastVisit!)}',
                          ].join(' · '),
                          style: const TextStyle(color: kTextMuted, fontSize: 11),
                        ),
                        onTap: () => _selectCustomer(c),
                      ),
                      if (!isLast) const Divider(height: 1, indent: kSpaceMD),
                    ],
                  );
                }).toList(),
              ),
            ),

          // Phone field
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM + 4, kSpaceMD, 0),
            child: TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional — for WhatsApp bill)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              onSubmitted: (_) => _confirm(),
            ),
          ),
          const SizedBox(height: kSpaceMD),

          Padding(
            padding: const EdgeInsets.fromLTRB(kSpaceMD, 0, kSpaceMD, kSpaceLG),
            child: ElevatedButton(
              onPressed: _nameCtrl.text.trim().isEmpty ? null : _confirm,
              child: const Text('Open Tab'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Card ───────────────────────────────────────────────────────────────

class _TabCard extends StatefulWidget {
  final BillTab tab;
  final VoidCallback onTap;
  const _TabCard({required this.tab, required this.onTap});

  @override
  State<_TabCard> createState() => _TabCardState();
}

class _TabCardState extends State<_TabCard> with SingleTickerProviderStateMixin {
  Timer? _timer;
  double _liveCost = 0;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _liveCost = widget.tab.runningGamesCost;
    if (widget.tab.activeGames != null && widget.tab.activeGames! > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _liveCost = widget.tab.runningGamesCost);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final total = tab.subtotal + _liveCost;
    final hasRunningGame = tab.activeGames != null && tab.activeGames! > 0;
    final duration = DateTime.now().difference(tab.openedAt);
    final isOld = duration.inHours >= 3;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLG),
          border: Border.all(
            color: isOld ? kAmber.withValues(alpha: 0.5) : kDivider,
            width: isOld ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent stripe
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: isOld ? kAmber : (hasRunningGame ? kGreen : kAccent),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadiusLG)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM + 4, kSpaceMD, kSpaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + live badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tab.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kTextLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasRunningGame)
                          FadeTransition(
                            opacity: Tween(begin: 0.55, end: 1.0).animate(_pulseCtrl),
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5, height: 5,
                                  decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                const Text('LIVE',
                                    style: TextStyle(color: kGreen, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          ),
                      ],
                    ),
                    const SizedBox(height: kSpaceXS),

                    // Duration
                    Row(
                      children: [
                        Icon(
                          isOld ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                          size: 12,
                          color: isOld ? kAmber : kTextMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDuration(duration),
                          style: TextStyle(
                            color: isOld ? kAmber : kTextMuted,
                            fontSize: 11,
                            fontWeight: isOld ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Item count + phone indicator
                    Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 12, color: kTextMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${tab.itemCount ?? 0} items',
                          style: const TextStyle(color: kTextMuted, fontSize: 11),
                        ),
                        if (tab.customerPhone != null && tab.customerPhone!.isNotEmpty) ...[
                          const SizedBox(width: kSpaceSM),
                          const Icon(Icons.phone_rounded, size: 11, color: kGreen),
                        ],
                      ],
                    ),
                    const SizedBox(height: kSpaceXS),

                    // Total
                    Text(
                      formatCurrency(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                        letterSpacing: -0.5,
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
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatPill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceSM + 2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: kPadPage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: kTextMuted),
            const SizedBox(height: kSpaceMD),
            Text(message, style: const TextStyle(color: kTextMuted), textAlign: TextAlign.center),
            const SizedBox(height: kSpaceLG),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(160, 46)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewTab;
  const _EmptyState({required this.onNewTab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kCardAlt,
              borderRadius: BorderRadius.circular(kRadiusXL),
            ),
            child: const Icon(Icons.table_bar_rounded, size: 40, color: kTextMuted),
          ),
          const SizedBox(height: kSpaceMD),
          const Text('No open tabs',
              style: TextStyle(fontSize: 17, color: kTextLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: kSpaceXS),
          const Text('Tap the button below to open a new tab',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
          const SizedBox(height: kSpaceLG),
          ElevatedButton.icon(
            onPressed: onNewTab,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Open First Tab'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
          ),
        ],
      ),
    );
  }
}
