import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_tab.dart';
import '../services/api_service.dart';

final tabsProvider = StateNotifierProvider<TabsNotifier, AsyncValue<List<BillTab>>>(
  (_) => TabsNotifier(),
);

class TabsNotifier extends StateNotifier<AsyncValue<List<BillTab>>> {
  TabsNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.instance.get('/tabs') as List;
      state = AsyncValue.data(data.map((e) => BillTab.fromJson(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<BillTab> createTab(String customerName, {String? notes, int? customerId, String? customerPhone}) async {
    final data = await ApiService.instance.post('/tabs', {
      'customer_name': customerName,
      if (notes != null) 'notes': notes,
      if (customerId != null) 'customer_id': customerId,
      if (customerPhone != null) 'customer_phone': customerPhone,
    });
    final tab = BillTab.fromJson(data);
    await load();
    return tab;
  }

  Future<void> refresh() => load();
}

final tabDetailProvider =
    StateNotifierProvider.family<TabDetailNotifier, AsyncValue<BillTab?>, int>(
  (_, id) => TabDetailNotifier(id),
);

class TabDetailNotifier extends StateNotifier<AsyncValue<BillTab?>> {
  final int tabId;
  TabDetailNotifier(this.tabId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final data = await ApiService.instance.get('/tabs/$tabId');
      state = AsyncValue.data(BillTab.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(int menuItemId, int quantity) async {
    await ApiService.instance.post('/tabs/$tabId/items', {
      'menu_item_id': menuItemId,
      'quantity': quantity,
    });
    await load();
  }

  Future<void> updateItemQty(int itemId, int quantity) async {
    await ApiService.instance.patch('/tabs/$tabId/items/$itemId', {'quantity': quantity});
    await load();
  }

  Future<void> removeItem(int itemId) async {
    await ApiService.instance.delete('/tabs/$tabId/items/$itemId');
    await load();
  }

  Future<void> startGame(int menuItemId) async {
    await ApiService.instance.post('/tabs/$tabId/game-sessions', {'menu_item_id': menuItemId});
    await load();
  }

  Future<void> addManualGame(int menuItemId, double durationMinutes) async {
    await ApiService.instance.post('/tabs/$tabId/game-sessions', {
      'menu_item_id': menuItemId,
      'duration_minutes': durationMinutes,
    });
    await load();
  }

  Future<void> stopGame(int sessionId) async {
    await ApiService.instance.patch('/tabs/$tabId/game-sessions/$sessionId', {});
    await load();
  }

  Future<BillTab> settle(String paymentMethod) async {
    final data = await ApiService.instance.post('/tabs/$tabId/settle', {
      'payment_method': paymentMethod,
    });
    final tab = BillTab.fromJson(data);
    state = AsyncValue.data(tab);
    return tab;
  }

  Future<void> updateTab(String customerName, {String? notes}) async {
    await ApiService.instance.patch('/tabs/$tabId', {
      'customer_name': customerName,
      if (notes != null) 'notes': notes,
    });
    await load();
  }
}
