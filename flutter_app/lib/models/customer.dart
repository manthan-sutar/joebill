class Customer {
  final int id;
  final String name;
  final String? phone;
  final int visitCount;
  final DateTime? lastVisit;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.visitCount,
    this.lastVisit,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        visitCount: json['visit_count'] ?? 0,
        lastVisit: json['last_visit'] != null ? DateTime.parse(json['last_visit']) : null,
      );
}
