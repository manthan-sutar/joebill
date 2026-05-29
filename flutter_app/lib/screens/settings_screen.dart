import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../utils/menu_import.dart';
import 'inventory_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuItemsProvider.notifier).load(allItems: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Inventory',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Menu Items'),
            Tab(text: 'Users'),
          ],
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: kTextMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MenuItemsTab(isAdmin: isAdmin),
          _UsersTab(isAdmin: isAdmin),
        ],
      ),
    );
  }
}

class _MenuItemsTab extends ConsumerWidget {
  final bool isAdmin;
  const _MenuItemsTab({required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsProvider);

    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (items) {
        final categories = ['beverage', 'drink', 'food', 'game'];
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: categories.map((cat) {
                final catItems = items.where((i) => i.category == cat).toList();
                if (catItems.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          kSpaceMD, kSpaceMD, kSpaceMD, kSpaceSM),
                      child: Text(
                        categoryLabel(cat).toUpperCase(),
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...catItems.map((item) => _MenuItemTile(
                          item: item,
                          isAdmin: isAdmin,
                          onEdit: isAdmin
                              ? () => _showEditDialog(context, ref, item)
                              : null,
                          onToggle: isAdmin
                              ? () => ref
                                  .read(menuItemsProvider.notifier)
                                  .updateItem(
                                      item.id, {'is_active': !item.isActive})
                              : null,
                        )),
                  ],
                );
              }).toList(),
            ),
            if (isAdmin)
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'import_menu',
                      onPressed: () => _importFromExcel(context, ref),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import Excel'),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: 'add_menu',
                      onPressed: () => _showAddDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _importFromExcel(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file')),
        );
      }
      return;
    }

    List<MenuImportRow> rows;
    try {
      rows = parseMenuImportBytes(file.bytes!, file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
        );
      }
      return;
    }

    if (rows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data rows found')),
        );
      }
      return;
    }

    var upsert = true;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: kSurface,
          title: const Text('Import menu items'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${rows.length} rows from ${file.name}'),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Update existing (same name + category)'),
                value: upsert,
                onChanged: (v) => setState(() => upsert = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref.read(menuItemsProvider.notifier).importItems(
            rows.map((r) => r.data).toList(),
            upsert: upsert,
          );
      final created = result['created'] ?? 0;
      final updated = result['updated'] ?? 0;
      final errors = (result['errors'] as List?)?.length ?? 0;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported: $created new, $updated updated${errors > 0 ? ', $errors errors' : ''}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
        );
      }
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _MenuItemDialog(
        onSave: (body) async {
          await ref.read(menuItemsProvider.notifier).addItem(body);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _MenuItemDialog(
        item: item,
        onSave: (body) async {
          await ref.read(menuItemsProvider.notifier).updateItem(item.id, body);
        },
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  const _MenuItemTile({
    required this.item,
    required this.isAdmin,
    this.onEdit,
    this.onToggle,
  });

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'beverage':
        return kBlue;
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

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(item.category);
    return Opacity(
      opacity: item.isActive ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.fromLTRB(kSpaceMD, 0, kSpaceMD, kSpaceSM),
        padding: const EdgeInsets.symmetric(
            horizontal: kSpaceMD, vertical: kSpaceSM + 4),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusMD),
          border: Border.all(color: kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusSM + 2),
              ),
              child: Center(
                child: Text(
                  item.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    item.isPerMinute
                        ? '₹${item.price.toStringAsFixed(2)} / min'
                        : '₹${item.price.toStringAsFixed(2)} per item',
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kCardAlt,
                    borderRadius: BorderRadius.circular(kRadiusSM),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: kTextMuted),
                ),
              ),
              const SizedBox(width: kSpaceSM),
              Switch(
                value: item.isActive,
                onChanged: onToggle != null ? (_) => onToggle!() : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItemDialog extends StatefulWidget {
  final MenuItem? item;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _MenuItemDialog({this.item, required this.onSave});

  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _category = 'food';
  String _unit = 'per_item';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!.name;
      _priceCtrl.text = widget.item!.price.toString();
      _category = widget.item!.category;
      _unit = widget.item!.unit;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'price': double.parse(_priceCtrl.text.trim()),
        'unit': _unit,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      title: Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              dropdownColor: kCard,
              items: const [
                DropdownMenuItem(value: 'beverage', child: Text('Beverage')),
                DropdownMenuItem(value: 'drink', child: Text('Drink')),
                DropdownMenuItem(value: 'food', child: Text('Food')),
                DropdownMenuItem(value: 'game', child: Text('Game')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _category = v;
                  _unit = v == 'game' ? 'per_minute' : 'per_item';
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              dropdownColor: kCard,
              items: const [
                DropdownMenuItem(value: 'per_item', child: Text('Per Item')),
                DropdownMenuItem(
                    value: 'per_minute', child: Text('Per Minute')),
              ],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.item == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

// Users tab
class _UsersTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const _UsersTab({required this.isAdmin});

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiService.instance.get('/auth/users') as List;
      setState(() {
        _users = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _UserDialog(
        onSave: (body) async {
          await ApiService.instance.post('/auth/users', body);
          await _loadUsers();
        },
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => _UserDialog(
        user: user,
        onSave: (body) async {
          await ApiService.instance.patch('/auth/users/${user['id']}', body);
          await _loadUsers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(kSpaceMD, kSpaceSM, kSpaceMD, 80),
          itemCount: _users.length,
          itemBuilder: (_, i) {
            final user = _users[i];
            final isActive = user['is_active'] == true;
            final isAdmin = user['role'] == 'admin';
            return Opacity(
              opacity: isActive ? 1.0 : 0.45,
              child: Container(
                margin: const EdgeInsets.only(bottom: kSpaceSM),
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceMD, vertical: kSpaceSM + 4),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(kRadiusMD),
                  border: Border.all(color: kDivider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isAdmin ? kAccent.withValues(alpha: 0.15) : kCardAlt,
                      child: Text(
                        (user['name'] as String).substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isAdmin ? kAccent : kTextLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: kSpaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('@${user['username']}',
                                  style: const TextStyle(
                                      color: kTextMuted, fontSize: 12)),
                              const SizedBox(width: kSpaceXS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? kAccent.withValues(alpha: 0.12)
                                      : kCardAlt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user['role'],
                                  style: TextStyle(
                                    color: isAdmin ? kAccent : kTextMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.isAdmin)
                      GestureDetector(
                        onTap: () => _showEditUserDialog(user),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: kCardAlt,
                            borderRadius: BorderRadius.circular(kRadiusSM),
                          ),
                          child: const Icon(Icons.edit_outlined,
                              size: 16, color: kTextMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.isAdmin)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_user',
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            ),
          ),
      ],
    );
  }
}

class _UserDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _UserDialog({this.user, required this.onSave});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'staff';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameCtrl.text = widget.user!['name'] ?? '';
      _usernameCtrl.text = widget.user!['username'] ?? '';
      _role = widget.user!['role'] ?? 'staff';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'role': _role,
      };
      if (widget.user == null) {
        body['username'] = _usernameCtrl.text.trim();
        body['password'] = _passCtrl.text;
      } else if (_passCtrl.text.isNotEmpty) {
        body['password'] = _passCtrl.text;
      }
      await widget.onSave(body);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      title: Text(widget.user == null ? 'Add User' : 'Edit User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            if (widget.user == null)
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                autocorrect: false,
              ),
            if (widget.user == null) const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: widget.user == null
                    ? 'Password'
                    : 'New Password (leave blank to keep)',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              dropdownColor: kCard,
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.user == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
