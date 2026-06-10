import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class CreditBill {
  final int id;
  final double subtotal;
  final DateTime? closedAt;
  final String? notes;

  const CreditBill({
    required this.id,
    required this.subtotal,
    this.closedAt,
    this.notes,
  });

  factory CreditBill.fromJson(Map<String, dynamic> json) => CreditBill(
        id: json['id'],
        subtotal: double.parse(json['subtotal'].toString()),
        closedAt:
            json['closed_at'] != null ? DateTime.parse(json['closed_at']) : null,
        notes: json['notes'],
      );
}

class CustomerCredit {
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final double creditTotal;
  final List<CreditBill> bills;

  const CustomerCredit({
    this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.creditTotal,
    required this.bills,
  });

  factory CustomerCredit.fromJson(Map<String, dynamic> json) => CustomerCredit(
        customerId: json['customer_id'],
        customerName: json['customer_name'],
        customerPhone: json['customer_phone'],
        creditTotal: double.parse(json['credit_total'].toString()),
        bills: (json['bills'] as List)
            .map((e) => CreditBill.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CreditOverview {
  final double totalPending;
  final int billCount;
  final List<CustomerCredit> customers;

  const CreditOverview({
    required this.totalPending,
    required this.billCount,
    required this.customers,
  });

  factory CreditOverview.fromJson(Map<String, dynamic> json) => CreditOverview(
        totalPending: double.parse(json['total_pending'].toString()),
        billCount: json['bill_count'] ?? 0,
        customers: (json['customers'] as List? ?? [])
            .map((e) => CustomerCredit.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

final creditOverviewProvider =
    FutureProvider.autoDispose<CreditOverview>((ref) async {
  final data =
      await ApiService.instance.get('/customers/credit') as Map<String, dynamic>;
  return CreditOverview.fromJson(data);
});

Future<void> payCreditBill(int tabId, String paymentMethod) async {
  await ApiService.instance.post('/tabs/$tabId/pay-credit', {
    'payment_method': paymentMethod,
  });
}

bool isGenericTabName(String name) {
  return RegExp(r'^(table\s*\d+|bar|pool table|counter)$', caseSensitive: false)
      .hasMatch(name.trim());
}
