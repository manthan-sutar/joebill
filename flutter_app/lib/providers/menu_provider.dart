import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';

int _menuTempId = -10000;
int _nextMenuTempId() => _menuTempId--;

final menuItemsProvider =
    StateNotifierProvider<MenuItemsNotifier, AsyncValue<List<MenuItem>>>(
  (_) => MenuItemsNotifier(),
);

class MenuItemsNotifier extends StateNotifier<AsyncValue<List<MenuItem>>> {
  MenuItemsNotifier() : super(const AsyncValue.loading());

  Future<void> load({bool allItems = false}) async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncValue.loading();
    try {
      final path = allItems ? '/menu-items/all' : '/menu-items';
      final data = await ApiService.instance.get(path) as List;
      state = AsyncValue.data(data.map((e) => MenuItem.fromJson(e)).toList());
    } catch (e, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addItem(Map<String, dynamic> body) async {
    final items = state.valueOrNull ?? [];
    final tempId = _nextMenuTempId();
    final optimistic = MenuItem(
      id: tempId,
      name: body['name'] as String,
      category: body['category'] as String,
      price: (body['price'] as num).toDouble(),
      unit: body['unit'] as String,
      isActive: body['is_active'] as bool? ?? true,
    );
    state = AsyncValue.data([...items, optimistic]);

    try {
      final data = await ApiService.instance.post('/menu-items', body);
      final saved = MenuItem.fromJson(data);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((i) => i.id == tempId ? saved : i).toList(),
      );
    } catch (e) {
      state = AsyncValue.data(items);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> importItems(
    List<Map<String, dynamic>> items, {
    bool upsert = true,
  }) async {
    final data = await ApiService.instance.post('/menu-items/import', {
      'items': items,
      'upsert': upsert,
    }) as Map<String, dynamic>;
    await load(allItems: true);
    return data;
  }

  Future<void> updateItem(int id, Map<String, dynamic> body) async {
    final items = state.valueOrNull;
    if (items == null) return;

    final index = items.indexWhere((i) => i.id == id);
    if (index < 0) return;

    final previous = items[index];
    final optimistic = previous.copyWith(
      name: body['name'] as String? ?? previous.name,
      category: body['category'] as String? ?? previous.category,
      price: body['price'] != null ? (body['price'] as num).toDouble() : previous.price,
      unit: body['unit'] as String? ?? previous.unit,
      isActive: body['is_active'] as bool? ?? previous.isActive,
    );
    final updated = [...items];
    updated[index] = optimistic;
    state = AsyncValue.data(updated);

    try {
      await ApiService.instance.patch('/menu-items/$id', body);
    } catch (e) {
      final current = List<MenuItem>.from(state.valueOrNull ?? []);
      if (index < current.length) {
        current[index] = previous;
        state = AsyncValue.data(current);
      }
      rethrow;
    }
  }
}
