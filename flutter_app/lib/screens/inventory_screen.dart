import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

final _inventoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final data = await ApiService.instance.get('/inventory');
  return List<dynamic>.from(data as List);
});

final _lowStockProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final data = await ApiService.instance.get('/inventory?low_only=true');
  return List<dynamic>.from(data as List);
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _lowOnly = false;

  void _refresh() {
    ref.invalidate(_inventoryProvider);
    ref.invalidate(_lowStockProvider);
  }

  Future<void> _adjustItem(Map<String, dynamic> item) async {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final stock = item['stock_quantity']?.toString() ?? '0';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(item['name'] ?? 'Adjust stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: $stock', style: const TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Add / subtract (+5, -2)',
                hintText: '+10',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final delta = int.tryParse(qtyCtrl.text.trim());
    if (delta == null || delta == 0) return;

    try {
      await ApiService.instance.patch('/inventory/${item['id']}', {
        'adjust_qty': delta,
        if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
      });
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_lowOnly ? _lowStockProvider : _inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          FilterChip(
            label: const Text('Low stock'),
            selected: _lowOnly,
            onSelected: (v) => setState(() => _lowOnly = v),
            checkmarkColor: kAccent,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          const SizedBox(width: 8),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                _lowOnly ? 'No low-stock items' : 'No inventory items',
                style: const TextStyle(color: kTextMuted),
              ),
            );
          }

          final grouped = <String, List<dynamic>>{};
          for (final item in items) {
            final cat = item['category'] as String? ?? 'other';
            grouped.putIfAbsent(cat, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.expand((e) {
              return [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    categoryLabel(e.key).toUpperCase(),
                    style: const TextStyle(
                      color: kTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...e.value.map((item) {
                  final track = item['track_stock'] == true;
                  final qty = item['stock_quantity'];
                  final low = item['is_low_stock'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: track
                          ? Text(
                              qty != null ? 'Stock: $qty' : 'Not set',
                              style: TextStyle(
                                color: low ? kAccent : kTextMuted,
                                fontWeight: low ? FontWeight.w600 : null,
                              ),
                            )
                          : const Text('Tracking off', style: TextStyle(color: kTextMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (low)
                            const Icon(Icons.warning_amber_rounded,
                                color: kAccent, size: 20),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _adjustItem(item),
                          ),
                        ],
                      ),
                      onTap: () => _adjustItem(item),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ];
            }).toList(),
          );
        },
      ),
    );
  }
}
