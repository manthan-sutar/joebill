import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tabs_provider.dart';
import '../providers/menu_provider.dart';
import '../models/bill_tab.dart';
import '../models/tab_item.dart';
import '../models/game_session.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import 'settle_screen.dart';

// Quick-add favourites provider — top 6 items from reports
final quickItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final data = await ApiService.instance.get('/reports/quick-items') as List;
    return data.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class TabDetailScreen extends ConsumerStatefulWidget {
  final int tabId;
  const TabDetailScreen({super.key, required this.tabId});

  @override
  ConsumerState<TabDetailScreen> createState() => _TabDetailScreenState();
}

class _TabDetailScreenState extends ConsumerState<TabDetailScreen> {
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuItemsProvider.notifier).load();
    });
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _addItem(BillTab tab) async {
    final menuAsync = ref.read(menuItemsProvider);
    final items = menuAsync.value ?? [];
    if (items.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddItemSheet(
        tabId: widget.tabId,
        items: items.where((i) => i.category != 'game').toList(),
        onAdd: (menuItemId, qty) async {
          await ref.read(tabDetailProvider(widget.tabId).notifier).addItem(menuItemId, qty);
        },
      ),
    );
  }

  Future<void> _startGame() async {
    final menuAsync = ref.read(menuItemsProvider);
    final games = (menuAsync.value ?? []).where((i) => i.category == 'game').toList();
    if (games.isEmpty) return;

    // Step 1: pick game
    final game = await showDialog<MenuItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Select Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: games
              .map((g) => ListTile(
                    leading: const Icon(Icons.sports_esports, color: kAccent),
                    title: Text(g.name),
                    subtitle: Text('₹${g.price.toStringAsFixed(2)}/min'),
                    onTap: () => Navigator.pop(ctx, g),
                  ))
              .toList(),
        ),
      ),
    );
    if (game == null) return;

    // Step 2: pick mode — live timer or manual entry
    if (!mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(game.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer, color: kGreen),
              title: const Text('Start Timer'),
              subtitle: const Text('Track time live, stop when done'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: kCard,
              onTap: () => Navigator.pop(ctx, 'timer'),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.edit_note, color: kAmber),
              title: const Text('Manual Entry'),
              subtitle: const Text('Enter minutes played directly'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: kCard,
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;

    if (mode == 'timer') {
      try {
        await ref.read(tabDetailProvider(widget.tabId).notifier).startGame(game.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
        );
      }
    } else {
      // Manual entry dialog
      if (!mounted) return;
      await _showManualGameEntry(game);
    }
  }

  Future<void> _showManualGameEntry(MenuItem game) async {
    final minsCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('${game.name} — Manual Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate: ₹${game.price.toStringAsFixed(2)}/min',
              style: const TextStyle(color: kTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minsCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minutes played',
                suffixText: 'min',
                hintText: 'e.g. 45',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: minsCtrl,
              builder: (_, val, __) {
                final mins = double.tryParse(val.text) ?? 0;
                final cost = mins * game.price;
                return Text(
                  'Estimated cost: ₹${cost.toStringAsFixed(2)}',
                  style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add to Bill')),
        ],
      ),
    );

    if (confirmed != true) return;
    final mins = double.tryParse(minsCtrl.text.trim());
    if (mins == null || mins <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of minutes'), backgroundColor: kAccent),
      );
      return;
    }

    try {
      await ref.read(tabDetailProvider(widget.tabId).notifier).addManualGame(game.id, mins);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
      );
    }
  }

  Future<void> _stopGame(GameSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Stop Game?'),
        content: Text('Stop ${session.gameName} session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(tabDetailProvider(widget.tabId).notifier).stopGame(session.id);
  }

  Future<void> _settle(BillTab tab) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SettleScreen(tabId: widget.tabId)),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _editName(BillTab tab) async {
    final ctrl = TextEditingController(text: tab.customerName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Edit Customer Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Customer Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(tabDetailProvider(widget.tabId).notifier).updateTab(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabAsync = ref.watch(tabDetailProvider(widget.tabId));

    return tabAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (tab) {
        if (tab == null) return const Scaffold(body: Center(child: Text('Tab not found')));
        final runningGames = tab.gameSessions.where((g) => g.isRunning).toList();
        final stoppedGames = tab.gameSessions.where((g) => !g.isRunning).toList();
        final now = DateTime.now();
        final liveGameCost = runningGames.fold(0.0, (sum, g) {
          final mins = now.difference(g.startTime).inSeconds / 60.0;
          return sum + (mins * g.ratePerMinute);
        });
        final grandTotal = tab.subtotal + liveGameCost;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: tab.isOpen ? () => _editName(tab) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.customerName),
                  if (tab.isOpen) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 16, color: kTextMuted),
                  ],
                ],
              ),
            ),
            actions: [
              if (tab.isOpen)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(tabDetailProvider(widget.tabId).notifier).load(),
                ),
            ],
          ),
          body: Column(
            children: [
              // Total bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceMD),
                decoration: const BoxDecoration(
                  color: kSurface,
                  border: Border(bottom: BorderSide(color: kDivider)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Running Total', style: TextStyle(color: kTextMuted, fontSize: 12)),
                        Text(
                          formatCurrency(grandTotal),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kAccent,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Opened ${formatTime(tab.openedAt)}',
                          style: const TextStyle(color: kTextMuted, fontSize: 12),
                        ),
                        Text(
                          formatDuration(now.difference(tab.openedAt)),
                          style: const TextStyle(color: kTextLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick-add favourites bar
              if (tab.isOpen) _QuickAddBar(tabId: widget.tabId),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceMD, kSpaceMD, kSpaceLG),
                  children: [
                    // Running game sessions
                    if (runningGames.isNotEmpty) ...[
                      _SectionHeader(title: 'Active Games', color: kGreen),
                      ...runningGames.map((g) => _RunningGameTile(
                            session: g,
                            onStop: tab.isOpen ? () => _stopGame(g) : null,
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Food/drink items
                    if (tab.items.isNotEmpty) ...[
                      _SectionHeader(title: 'Items', color: kAmber),
                      ...tab.items.map((item) => _ItemTile(
                            item: item,
                            editable: tab.isOpen,
                            onQtyChange: (qty) => ref
                                .read(tabDetailProvider(widget.tabId).notifier)
                                .updateItemQty(item.id, qty),
                            onDelete: () => ref
                                .read(tabDetailProvider(widget.tabId).notifier)
                                .removeItem(item.id),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Completed game sessions
                    if (stoppedGames.isNotEmpty) ...[
                      _SectionHeader(title: 'Completed Games', color: kTextMuted),
                      ...stoppedGames.map((g) => _CompletedGameTile(session: g)),
                      const SizedBox(height: 16),
                    ],

                    if (tab.items.isEmpty && tab.gameSessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No items yet.\nAdd food, drinks or start a game.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextMuted),
                          ),
                        ),
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: tab.isOpen
              ? Container(
                  decoration: const BoxDecoration(
                    color: kSurface,
                    border: Border(top: BorderSide(color: kDivider)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM + 4, kSpaceMD, kSpaceSM + 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addItem(tab),
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                              label: const Text('Items'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(horizontal: kSpaceSM),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpaceSM),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _startGame,
                              icon: const Icon(Icons.sports_esports_rounded, size: 18),
                              label: const Text('Game'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kGreen,
                                side: const BorderSide(color: kGreen),
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(horizontal: kSpaceSM),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpaceSM),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _settle(tab),
                              icon: const Icon(Icons.payment_rounded, size: 18),
                              label: const Text('Settle Bill'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(horizontal: kSpaceSM),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpaceSM + 2, top: kSpaceXS),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: kSpaceSM),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunningGameTile extends StatefulWidget {
  final GameSession session;
  final VoidCallback? onStop;
  const _RunningGameTile({required this.session, this.onStop});

  @override
  State<_RunningGameTile> createState() => _RunningGameTileState();
}

class _RunningGameTileState extends State<_RunningGameTile> {
  Timer? _t;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.session.startTime);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(widget.session.startTime));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = (_elapsed.inSeconds / 60.0) * widget.session.ratePerMinute;
    return Container(
      margin: const EdgeInsets.only(bottom: kSpaceSM),
      padding: const EdgeInsets.all(kSpaceMD),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLG),
        border: Border.all(color: kGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusMD),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: kGreen, size: 22),
          ),
          const SizedBox(width: kSpaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.session.gameName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(_elapsed)}  ·  ₹${widget.session.ratePerMinute.toStringAsFixed(2)}/min',
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpaceSM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(cost),
                style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (widget.onStop != null)
                GestureDetector(
                  onTap: widget.onStop,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: kSpaceSM + 2, vertical: 3),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(kRadiusSM),
                      border: Border.all(color: kAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('STOP',
                        style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedGameTile extends StatelessWidget {
  final GameSession session;
  const _CompletedGameTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kSpaceSM),
      padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM + 4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLG),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kTextMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(kRadiusSM + 2),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: kTextMuted, size: 18),
          ),
          const SizedBox(width: kSpaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.gameName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${session.durationMinutes?.toStringAsFixed(1) ?? 0} min',
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(session.totalCost ?? 0),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Quick-Add Favourites Bar ────────────────────────────────────────────────

class _QuickAddBar extends ConsumerWidget {
  final int tabId;
  const _QuickAddBar({required this.tabId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickAsync = ref.watch(quickItemsProvider);

    return quickAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(bottom: BorderSide(color: kDivider)),
          ),
          padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM + 2, kSpaceMD, kSpaceSM + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QUICK ADD',
                style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: kSpaceSM),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: kSpaceSM),
                      child: _QuickAddChip(
                        name: item['menu_item_name'],
                        price: double.parse(item['price'].toString()),
                        onTap: () async {
                          try {
                            await ref.read(tabDetailProvider(tabId).notifier).addItem(
                              item['menu_item_id'],
                              1,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item['menu_item_name']} added'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAddChip extends StatefulWidget {
  final String name;
  final double price;
  final VoidCallback onTap;
  const _QuickAddChip({required this.name, required this.price, required this.onTap});

  @override
  State<_QuickAddChip> createState() => _QuickAddChipState();
}

class _QuickAddChipState extends State<_QuickAddChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM + 2),
        decoration: BoxDecoration(
          color: _pressed ? kAccent : kCardAlt,
          borderRadius: BorderRadius.circular(kRadiusMD),
          border: Border.all(
            color: _pressed ? kAccent : kAccent.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _pressed ? Colors.white : kTextLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${widget.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                color: _pressed ? Colors.white70 : kAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final TabItem item;
  final bool editable;
  final ValueChanged<int> onQtyChange;
  final VoidCallback onDelete;
  const _ItemTile({
    required this.item,
    required this.editable,
    required this.onQtyChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kSpaceSM),
      padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM + 4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLG),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.menuItemName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '₹${item.unitPrice.toStringAsFixed(2)} each',
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (editable) ...[
            _QtyButton(
              icon: Icons.remove_rounded,
              enabled: item.quantity > 1,
              onTap: () => onQtyChange(item.quantity - 1),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${item.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _QtyButton(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: () => onQtyChange(item.quantity + 1),
              color: kAccent,
            ),
            const SizedBox(width: kSpaceSM),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(kRadiusSM),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: kAccent),
              ),
            ),
          ] else
            Text('×${item.quantity}', style: const TextStyle(color: kTextMuted, fontSize: 13)),
          const SizedBox(width: kSpaceSM),
          Text(
            formatCurrency(item.subtotal),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;
  const _QtyButton({required this.icon, required this.enabled, required this.onTap, this.color = kTextMuted});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusSM),
        ),
        child: Icon(icon, size: 16, color: enabled ? color : kTextMuted.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final int tabId;
  final List<MenuItem> items;
  final Future<void> Function(int menuItemId, int qty) onAdd;
  const _AddItemSheet({required this.tabId, required this.items, required this.onAdd});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  String _selectedCategory = 'all';
  final Map<int, int> _quantities = {};

  List<MenuItem> get _filtered => _selectedCategory == 'all'
      ? widget.items
      : widget.items.where((i) => i.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: kSpaceSM + 4),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: kTextMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: kSpaceMD),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
            child: Row(
              children: [
                const Text('Add Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_quantities.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      for (final entry in _quantities.entries) {
                        if (entry.value > 0) await widget.onAdd(entry.key, entry.value);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
                    ),
                    child: Text('Add ${_quantities.values.fold(0, (a, b) => a + b)}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: kSpaceMD),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
            child: Row(
              children: ['all', 'beverage', 'drink', 'food'].map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: kSpaceSM),
                  child: FilterChip(
                    label: Text(cat == 'all' ? 'All' : categoryLabel(cat)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    checkmarkColor: kAccent,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: kSpaceSM),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: kSpaceMD),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final qty = _quantities[item.id] ?? 0;
                final isLast = i == _filtered.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: kSpaceXS + 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(formatCurrency(item.price),
                                    style: const TextStyle(color: kTextMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.remove_rounded,
                            enabled: qty > 0,
                            onTap: () => setState(() => _quantities[item.id] = qty - 1),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: qty > 0 ? kAccent : kTextMuted,
                              ),
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.add_rounded,
                            enabled: true,
                            onTap: () => setState(() => _quantities[item.id] = qty + 1),
                            color: kAccent,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: kSpaceSM),
        ],
      ),
    );
  }
}
