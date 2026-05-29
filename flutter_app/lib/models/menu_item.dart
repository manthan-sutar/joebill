class MenuItem {
  final int id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final bool isActive;
  final int? stockQuantity;
  final bool trackStock;
  final int lowStockThreshold;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.isActive,
    this.stockQuantity,
    this.trackStock = false,
    this.lowStockThreshold = 5,
  });

  bool get isPerMinute => unit == 'per_minute';
  bool get isLowStock =>
      trackStock && stockQuantity != null && stockQuantity! <= lowStockThreshold;
  bool get isOutOfStock => trackStock && (stockQuantity ?? 0) <= 0;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        price: double.parse(json['price'].toString()),
        unit: json['unit'],
        isActive: json['is_active'] ?? true,
        stockQuantity: json['stock_quantity'] != null
            ? int.parse(json['stock_quantity'].toString())
            : null,
        trackStock: json['track_stock'] == true,
        lowStockThreshold:
            int.tryParse(json['low_stock_threshold']?.toString() ?? '') ?? 5,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'unit': unit,
        'is_active': isActive,
      };

  MenuItem copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    String? unit,
    bool? isActive,
    int? stockQuantity,
    bool? trackStock,
    int? lowStockThreshold,
  }) =>
      MenuItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        isActive: isActive ?? this.isActive,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        trackStock: trackStock ?? this.trackStock,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      );
}
