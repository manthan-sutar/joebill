import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customers_provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  Future<void> _payBill(
    BuildContext context,
    WidgetRef ref,
    CreditBill bill,
    String customerName,
  ) async {
    var method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: kSurface,
          title: Text('Collect ${formatCurrency(bill.subtotal)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customerName, style: const TextStyle(color: kTextMuted)),
              Text('Bill #${bill.id.toString().padLeft(4, '0')}'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'upi', label: Text('UPI')),
                ],
                selected: {method},
                onSelectionChanged: (v) => setState(() => method = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark paid')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await payCreditBill(bill.id, method);
      ref.invalidate(creditOverviewProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill #${bill.id} paid via ${method.toUpperCase()}')),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(creditOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(creditOverviewProvider),
          ),
        ],
      ),
      body: creditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), style: const TextStyle(color: kTextMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(creditOverviewProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (overview) {
          if (overview.billCount == 0) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: kGreen),
                  SizedBox(height: 12),
                  Text('No pending credit bills', style: TextStyle(color: kTextMuted)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: kAmber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total pending credit',
                                style: TextStyle(color: kTextMuted, fontSize: 12)),
                            Text(
                              formatCurrency(overview.totalPending),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text('${overview.billCount} bills',
                          style: const TextStyle(color: kTextMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...overview.customers.map((customer) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: kAccent.withValues(alpha: 0.15),
                      child: Text(
                        customer.customerName.isNotEmpty
                            ? customer.customerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(customer.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: customer.customerPhone != null
                        ? Text(customer.customerPhone!)
                        : null,
                    trailing: Text(
                      formatCurrency(customer.creditTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kAmber,
                      ),
                    ),
                    children: customer.bills.map((bill) {
                      return ListTile(
                        title: Text('Bill #${bill.id.toString().padLeft(4, '0')}'),
                        subtitle: bill.closedAt != null
                            ? Text(formatDateTime(bill.closedAt!))
                            : null,
                        trailing: FilledButton(
                          onPressed: () =>
                              _payBill(context, ref, bill, customer.customerName),
                          child: Text(formatCurrency(bill.subtotal)),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
