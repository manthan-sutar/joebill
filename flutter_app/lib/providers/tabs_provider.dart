import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_tab.dart';
import '../models/tab_item.dart';
import '../models/game_session.dart';
import '../services/api_service.dart';
import 'sync_provider.dart';

class RunningGamesException implements Exception {
  final String message;
  RunningGamesException([this.message = 'Stop running games before settling']);
  @override
  String toString() => message;
}

int _tempIdCounter = -1;
int _nextTempId() => _tempIdCounter--;

final tabsProvider = StateNotifierProvider<TabsNotifier, AsyncValue<List<BillTab>>>(
  (ref) => TabsNotifier(ref),
);

class TabsNotifier extends StateNotifier<AsyncValue<List<BillTab>>> {
  TabsNotifier(this.ref) : super(const AsyncValue.loading());

  final Ref ref;

  SyncNotifier get _sync => ref.read(syncProvider.notifier);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.instance.get('/tabs') as List;
      state = AsyncValue.data(data.map((e) => BillTab.fromJson(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      final data = await ApiService.instance.get('/tabs') as List;
      state = AsyncValue.data(data.map((e) => BillTab.fromJson(e)).toList());
    } catch (e, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  BillTab? findOpenTabByName(String name) {
    final tabs = state.valueOrNull;
    if (tabs == null) return null;
    final q = name.trim().toLowerCase();
    for (final t in tabs) {
      if (t.customerName.toLowerCase() == q) return t;
    }
    return null;
  }

  void patchFromDetail(BillTab detail) {
    final tabs = state.valueOrNull;
    if (tabs == null) return;
    state = AsyncValue.data(tabs.map((t) {
      if (t.id != detail.id) return t;
      return t.copyWith(
        customerName: detail.customerName,
        subtotal: detail.subtotal,
        itemCount: detail.items.length,
        activeGames: detail.gameSessions.where((g) => g.isRunning).length,
      );
    }).toList());
  }

  void prependTab(BillTab tab) {
    final tabs = state.valueOrNull ?? [];
    state = AsyncValue.data([tab, ...tabs]);
  }

  void replaceTab(int tempId, BillTab tab) {
    final tabs = state.valueOrNull;
    if (tabs == null) return;
    state = AsyncValue.data(tabs.map((t) => t.id == tempId ? tab : t).toList());
  }

  void removeTab(int tabId) {
    final tabs = state.valueOrNull;
    if (tabs == null) return;
    state = AsyncValue.data(tabs.where((t) => t.id != tabId).toList());
  }

  Future<BillTab> createTab(
    String customerName, {
    String? notes,
    int? customerId,
    String? customerPhone,
  }) async {
    final tempId = _nextTempId();
    final optimistic = BillTab(
      id: tempId,
      customerName: customerName,
      openedAt: DateTime.now(),
      status: 'open',
      subtotal: 0,
      notes: notes,
      customerPhone: customerPhone,
      itemCount: 0,
      activeGames: 0,
    );
    prependTab(optimistic);

    _sync.start();
    try {
      final data = await ApiService.instance.post('/tabs', {
        'customer_name': customerName,
        if (notes != null) 'notes': notes,
        if (customerId != null) 'customer_id': customerId,
        if (customerPhone != null) 'customer_phone': customerPhone,
      });
      final tab = BillTab.fromJson(data);
      replaceTab(tempId, tab);
      _sync.finish();
      return tab;
    } catch (e) {
      removeTab(tempId);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }
}

final tabDetailProvider =
    StateNotifierProvider.family<TabDetailNotifier, AsyncValue<BillTab?>, int>(
  (ref, id) => TabDetailNotifier(ref, id),
);

class TabDetailNotifier extends StateNotifier<AsyncValue<BillTab?>> {
  TabDetailNotifier(this.ref, this.tabId) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref ref;
  final int tabId;

  BillTab? get _tab => state.valueOrNull;
  SyncNotifier get _sync => ref.read(syncProvider.notifier);

  void _apply(BillTab tab) {
    state = AsyncValue.data(tab);
    ref.read(tabsProvider.notifier).patchFromDetail(tab);
  }

  void _revert(BillTab previous) {
    state = AsyncValue.data(previous);
    ref.read(tabsProvider.notifier).patchFromDetail(previous);
  }

  void revertTo(BillTab previous) => _revert(previous);

  Future<void> undoToSnapshot(BillTab previous) async {
    final current = _tab;
    if (current == null) return;

    for (final item in current.items) {
      if (item.id <= 0) continue;
      TabItem? prevMatch;
      for (final i in previous.items) {
        if (i.id == item.id) {
          prevMatch = i;
          break;
        }
      }
      if (prevMatch == null) {
        await removeItem(item.id);
      } else if (prevMatch.quantity != item.quantity) {
        await updateItemQty(item.id, prevMatch.quantity);
      }
    }

    for (final prevItem in previous.items) {
      if (prevItem.id <= 0) continue;
      if (!current.items.any((i) => i.id == prevItem.id)) {
        await addItem(
          prevItem.menuItemId,
          prevItem.quantity,
          menuItemName: prevItem.menuItemName,
          unitPrice: prevItem.unitPrice,
        );
      }
    }

    for (final session in current.gameSessions) {
      if (session.id <= 0 || !session.isRunning) continue;
      final wasRunning = previous.gameSessions.any((g) => g.id == session.id && g.isRunning);
      if (wasRunning) continue;
      // can't easily restart game — revert full snapshot locally
      _revert(previous);
      return;
    }

    _revert(previous);
    await load();
  }

  bool get hasRunningGames => _tab?.gameSessions.any((g) => g.isRunning) ?? false;

  Future<void> load() async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncValue.loading();
    try {
      final data = await ApiService.instance.get('/tabs/$tabId');
      final tab = BillTab.fromJson(data);
      state = AsyncValue.data(tab);
      ref.read(tabsProvider.notifier).patchFromDetail(tab);
    } catch (e, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addItem(
    int menuItemId,
    int quantity, {
    required String menuItemName,
    required double unitPrice,
  }) async {
    final tab = _tab;
    if (tab == null) return;

    final existingIdx = tab.items.indexWhere((i) => i.menuItemId == menuItemId);
    if (existingIdx >= 0 && tab.items[existingIdx].id > 0) {
      return updateItemQty(tab.items[existingIdx].id, tab.items[existingIdx].quantity + quantity);
    }

    final lineSubtotal = unitPrice * quantity;
    final previous = tab;
    List<TabItem> newItems;

    if (existingIdx >= 0) {
      final existing = tab.items[existingIdx];
      final merged = existing.copyWith(
        quantity: existing.quantity + quantity,
        subtotal: existing.unitPrice * (existing.quantity + quantity),
      );
      newItems = [...tab.items];
      newItems[existingIdx] = merged;
    } else {
      final tempId = _nextTempId();
      newItems = [
        ...tab.items,
        TabItem(
          id: tempId,
          tabId: tabId,
          menuItemId: menuItemId,
          menuItemName: menuItemName,
          quantity: quantity,
          unitPrice: unitPrice,
          subtotal: lineSubtotal,
        ),
      ];
    }

    _apply(tab.copyWith(items: newItems, subtotal: tab.subtotal + lineSubtotal));

    _sync.start();
    try {
      final data = await ApiService.instance.post('/tabs/$tabId/items', {
        'menu_item_id': menuItemId,
        'quantity': quantity,
      });
      final saved = TabItem.fromJson(data);
      final current = _tab;
      if (current == null) return;

      final deduped = <TabItem>[];
      var merged = false;
      for (final item in current.items) {
        if (item.menuItemId == menuItemId && item.id != saved.id) continue;
        if (item.menuItemId == menuItemId || item.id == saved.id) {
          if (!merged) {
            deduped.add(saved);
            merged = true;
          }
        } else {
          deduped.add(item);
        }
      }
      if (!merged) deduped.add(saved);

      final itemsTotal = deduped.fold(0.0, (s, i) => s + i.subtotal);
      final gamesTotal = current.gameSessions
          .where((g) => !g.isRunning && g.totalCost != null)
          .fold(0.0, (s, g) => s + (g.totalCost ?? 0));
      _apply(current.copyWith(items: deduped, subtotal: itemsTotal + gamesTotal));
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateItemQty(int itemId, int quantity) async {
    final tab = _tab;
    if (tab == null) return;

    final index = tab.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final oldItem = tab.items[index];
    final newSubtotal = oldItem.unitPrice * quantity;
    final delta = newSubtotal - oldItem.subtotal;
    final updatedItem = oldItem.copyWith(quantity: quantity, subtotal: newSubtotal);
    final previous = tab;
    final newItems = [...tab.items];
    newItems[index] = updatedItem;
    _apply(tab.copyWith(items: newItems, subtotal: tab.subtotal + delta));

    _sync.start();
    try {
      await ApiService.instance.patch('/tabs/$tabId/items/$itemId', {'quantity': quantity});
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeItem(int itemId) async {
    final tab = _tab;
    if (tab == null) return;

    final item = tab.items.firstWhere((i) => i.id == itemId);
    final previous = tab;
    _apply(tab.copyWith(
      items: tab.items.where((i) => i.id != itemId).toList(),
      subtotal: tab.subtotal - item.subtotal,
    ));

    _sync.start();
    try {
      await ApiService.instance.delete('/tabs/$tabId/items/$itemId');
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> startGame({
    required int menuItemId,
    required String gameName,
    required double ratePerMinute,
  }) async {
    final tab = _tab;
    if (tab == null) return;

    final tempId = _nextTempId();
    final session = GameSession(
      id: tempId,
      tabId: tabId,
      menuItemId: menuItemId,
      gameName: gameName,
      ratePerMinute: ratePerMinute,
      startTime: DateTime.now(),
      status: 'running',
    );
    final previous = tab;
    _apply(tab.copyWith(gameSessions: [...tab.gameSessions, session]));

    _sync.start();
    try {
      final data = await ApiService.instance.post('/tabs/$tabId/game-sessions', {
        'menu_item_id': menuItemId,
      });
      final saved = GameSession.fromJson(data);
      final current = _tab;
      if (current == null) return;
      _apply(current.copyWith(
        gameSessions: current.gameSessions.map((g) => g.id == tempId ? saved : g).toList(),
      ));
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> addManualGame({
    required int menuItemId,
    required String gameName,
    required double ratePerMinute,
    required double durationMinutes,
  }) async {
    final tab = _tab;
    if (tab == null) return;

    final totalCost = ratePerMinute * durationMinutes;
    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(seconds: (durationMinutes * 60).round()));
    final tempId = _nextTempId();
    final session = GameSession(
      id: tempId,
      tabId: tabId,
      menuItemId: menuItemId,
      gameName: gameName,
      ratePerMinute: ratePerMinute,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      totalCost: totalCost,
      status: 'stopped',
    );
    final previous = tab;
    _apply(tab.copyWith(
      gameSessions: [...tab.gameSessions, session],
      subtotal: tab.subtotal + totalCost,
    ));

    _sync.start();
    try {
      final data = await ApiService.instance.post('/tabs/$tabId/game-sessions', {
        'menu_item_id': menuItemId,
        'duration_minutes': durationMinutes,
      });
      final saved = GameSession.fromJson(data);
      final current = _tab;
      if (current == null) return;
      _apply(current.copyWith(
        gameSessions: current.gameSessions.map((g) => g.id == tempId ? saved : g).toList(),
        subtotal: current.subtotal - totalCost + (saved.totalCost ?? totalCost),
      ));
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> stopGame(int sessionId) async {
    final tab = _tab;
    if (tab == null) return;

    final index = tab.gameSessions.indexWhere((g) => g.id == sessionId);
    if (index < 0) return;

    final session = tab.gameSessions[index];
    final endTime = DateTime.now();
    final durationMinutes = endTime.difference(session.startTime).inSeconds / 60.0;
    final totalCost = durationMinutes * session.ratePerMinute;
    final stopped = session.copyWith(
      endTime: endTime,
      durationMinutes: durationMinutes,
      totalCost: totalCost,
      status: 'stopped',
    );
    final previous = tab;
    final newSessions = [...tab.gameSessions];
    newSessions[index] = stopped;
    _apply(tab.copyWith(
      gameSessions: newSessions,
      subtotal: tab.subtotal + totalCost,
    ));

    _sync.start();
    try {
      final data = await ApiService.instance.patch('/tabs/$tabId/game-sessions/$sessionId', {});
      final saved = GameSession.fromJson(data);
      final current = _tab;
      if (current == null) return;
      final savedIndex = current.gameSessions.indexWhere((g) => g.id == sessionId);
      if (savedIndex < 0) return;
      final adjustedSubtotal = current.subtotal - totalCost + (saved.totalCost ?? totalCost);
      final sessions = [...current.gameSessions];
      sessions[savedIndex] = saved;
      _apply(current.copyWith(gameSessions: sessions, subtotal: adjustedSubtotal));
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<BillTab> settle(String paymentMethod, {bool confirmRunningGames = false}) async {
    final tab = _tab;
    if (tab == null) throw Exception('Tab not found');

    final previous = tab;
    _apply(tab.copyWith(
      status: 'closed',
      paymentMethod: paymentMethod,
      closedAt: DateTime.now(),
    ));
    ref.read(tabsProvider.notifier).removeTab(tabId);

    _sync.start();
    try {
      final data = await ApiService.instance.post('/tabs/$tabId/settle', {
        'payment_method': paymentMethod,
        if (confirmRunningGames) 'confirm_running_games': true,
      });
      final settled = BillTab.fromJson(data);
      state = AsyncValue.data(settled);
      _sync.finish();
      return settled;
    } on ApiException catch (e) {
      _revert(previous);
      ref.read(tabsProvider.notifier).patchFromDetail(previous);
      _sync.finish(error: e.message);
      if (e.statusCode == 409 && e.message == 'running_games') {
        throw RunningGamesException();
      }
      rethrow;
    } catch (e) {
      _revert(previous);
      ref.read(tabsProvider.notifier).patchFromDetail(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateTab(String customerName, {String? notes}) async {
    final tab = _tab;
    if (tab == null) return;

    final previous = tab;
    _apply(tab.copyWith(customerName: customerName, notes: notes ?? tab.notes));

    _sync.start();
    try {
      await ApiService.instance.patch('/tabs/$tabId', {
        'customer_name': customerName,
        if (notes != null) 'notes': notes,
      });
      _sync.finish();
    } catch (e) {
      _revert(previous);
      _sync.finish(error: e.toString());
      rethrow;
    }
  }
}
