class MenuItem {
  final int id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final bool isActive;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.isActive,
  });

  bool get isPerMinute => unit == 'per_minute';

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        price: double.parse(json['price'].toString()),
        unit: json['unit'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'unit': unit,
        'is_active': isActive,
      };
}
