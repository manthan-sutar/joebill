import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';

final menuItemsProvider =
    StateNotifierProvider<MenuItemsNotifier, AsyncValue<List<MenuItem>>>(
  (_) => MenuItemsNotifier(),
);

class MenuItemsNotifier extends StateNotifier<AsyncValue<List<MenuItem>>> {
  MenuItemsNotifier() : super(const AsyncValue.loading());

  Future<void> load({bool allItems = false}) async {
    state = const AsyncValue.loading();
    try {
      final path = allItems ? '/menu-items/all' : '/menu-items';
      final data = await ApiService.instance.get(path) as List;
      state = AsyncValue.data(data.map((e) => MenuItem.fromJson(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(Map<String, dynamic> body) async {
    await ApiService.instance.post('/menu-items', body);
    await load(allItems: true);
  }

  Future<void> updateItem(int id, Map<String, dynamic> body) async {
    await ApiService.instance.patch('/menu-items/$id', body);
    await load(allItems: true);
  }
}
