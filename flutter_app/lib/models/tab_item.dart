class TabItem {
  final int id;
  final int tabId;
  final int menuItemId;
  final String menuItemName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const TabItem({
    required this.id,
    required this.tabId,
    required this.menuItemId,
    required this.menuItemName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory TabItem.fromJson(Map<String, dynamic> json) => TabItem(
        id: json['id'],
        tabId: json['tab_id'],
        menuItemId: json['menu_item_id'],
        menuItemName: json['menu_item_name'],
        quantity: json['quantity'],
        unitPrice: double.parse(json['unit_price'].toString()),
        subtotal: double.parse(json['subtotal'].toString()),
      );
}
