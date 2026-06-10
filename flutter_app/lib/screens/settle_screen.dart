import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/tabs_provider.dart';
import '../models/bill_tab.dart';
import '../services/pdf_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../utils/confirm_dialog.dart';
import '../providers/customers_provider.dart';

class SettleScreen extends ConsumerStatefulWidget {
  final int tabId;
  final bool hasRunningGames;
  const SettleScreen({super.key, required this.tabId, this.hasRunningGames = false});

  @override
  ConsumerState<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends ConsumerState<SettleScreen> {
  String _paymentMethod = 'cash';
  bool _settling = false;
  BillTab? _settledTab;

  Future<void> _settle(BillTab tab) async {
    final total = tab.subtotal + tab.runningGamesCost;

    if (_paymentMethod == 'credit' && isGenericTabName(tab.customerName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use a real customer name for credit (not Table/Bar)'),
          backgroundColor: kAccent,
        ),
      );
      return;
    }

    if (total >= 500 || _paymentMethod == 'credit') {
      final msg = _paymentMethod == 'credit'
          ? 'Put ${formatCurrency(total)} for ${tab.customerName} on credit? Bill will appear in Customers.'
          : 'Settle ${formatCurrency(total)} for ${tab.customerName} via ${_paymentMethod.toUpperCase()}?';
      final ok = await confirmAction(
        context,
        title: _paymentMethod == 'credit' ? 'Confirm credit' : 'Confirm settlement',
        message: msg,
        confirmLabel: _paymentMethod == 'credit' ? 'On Credit' : 'Settle',
      );
      if (!ok) return;
    }

    setState(() => _settling = true);
    try {
      var confirmRunning = widget.hasRunningGames;
      try {
        final settled = await ref.read(tabDetailProvider(widget.tabId).notifier).settle(
              _paymentMethod,
              confirmRunningGames: confirmRunning,
            );
        setState(() => _settledTab = settled);
      } on RunningGamesException {
        final ok = await confirmAction(
          context,
          title: 'Stop running games?',
          message: 'Games are still running. Auto-stop them and settle this bill?',
          confirmLabel: 'Stop & Settle',
        );
        if (!ok) return;
        final settled = await ref.read(tabDetailProvider(widget.tabId).notifier).settle(
              _paymentMethod,
              confirmRunningGames: true,
            );
        setState(() => _settledTab = settled);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kAccent),
      );
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }

  Future<void> _printReceipt(BillTab tab) async {
    final bytes = await PdfService.generateReceipt(tab);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareReceipt(BillTab tab) async {
    final bytes = await PdfService.generateReceipt(tab);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${tab.id}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: "Bill Receipt - Joe's Corner",
      text: "Bill for ${tab.customerName}: ${formatCurrency(tab.subtotal)}",
    );
  }

  Future<void> _sendWhatsApp(BillTab tab, {String? phone}) async {
    final number = phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';

    // Build text bill
    final buffer = StringBuffer();
    buffer.writeln("*JOE'S CORNER — BILL RECEIPT*");
    buffer.writeln('Bill #${tab.id.toString().padLeft(4, '0')} | ${tab.customerName}');
    buffer.writeln('Date: ${formatDateTime(tab.closedAt ?? DateTime.now())}');
    buffer.writeln();
    if (tab.items.isNotEmpty) {
      buffer.writeln('*ITEMS*');
      for (final item in tab.items) {
        buffer.writeln('• ${item.menuItemName} x${item.quantity} — ${formatCurrency(item.subtotal)}');
      }
    }
    if (tab.gameSessions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*GAMES*');
      for (final g in tab.gameSessions) {
        buffer.writeln('• ${g.gameName} (${g.durationMinutes?.toStringAsFixed(0) ?? 0} min) — ${formatCurrency(g.totalCost ?? 0)}');
      }
    }
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*TOTAL: ${formatCurrency(tab.subtotal)}*');
    buffer.writeln('Payment: ${(tab.paymentMethod ?? '').toUpperCase()}');
    buffer.writeln();
    buffer.writeln("Thank you! Visit again 🎱");
    buffer.writeln("— Joe's Corner");

    final encoded = Uri.encodeComponent(buffer.toString());
    final url = number.isNotEmpty
        ? 'https://wa.me/91$number?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not installed'), backgroundColor: kAccent),
      );
    }
  }

  Future<void> _promptWhatsApp(BillTab tab) async {
    // If phone already saved, send directly
    if (tab.customerPhone != null && tab.customerPhone!.isNotEmpty) {
      await _sendWhatsApp(tab, phone: tab.customerPhone);
      return;
    }
    // Otherwise ask for number
    final ctrl = TextEditingController();
    if (!mounted) return;
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Send on WhatsApp'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Customer phone number',
            prefixText: '+91 ',
            hintText: '9876543210',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (phone == null) return;
    await _sendWhatsApp(tab, phone: phone.isEmpty ? null : phone);
  }

  @override
  Widget build(BuildContext context) {
    final tabAsync = ref.watch(tabDetailProvider(widget.tabId));

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Bill')),
      body: tabAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (tab) {
          if (tab == null) return const Center(child: Text('Tab not found'));
          final displayTab = _settledTab ?? tab;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kSpaceMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bill summary card
                Container(
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(kRadiusXL),
                    border: Border.all(color: kDivider),
                  ),
                  padding: const EdgeInsets.all(kSpaceLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(kRadiusMD),
                            ),
                            child: const Icon(Icons.person_rounded, color: kAccent, size: 22),
                          ),
                          const SizedBox(width: kSpaceMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayTab.customerName,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                if (displayTab.customerPhone != null && displayTab.customerPhone!.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 12, color: kGreen),
                                      const SizedBox(width: 4),
                                      Text(displayTab.customerPhone!,
                                          style: const TextStyle(color: kGreen, fontSize: 12)),
                                    ],
                                  ),
                                Text(
                                  'Opened ${formatDateTime(displayTab.openedAt)}',
                                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '#${displayTab.id.toString().padLeft(4, '0')}',
                            style: const TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpaceMD),
                      const Divider(),
                      const SizedBox(height: kSpaceSM),

                      if (displayTab.items.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(width: 3, height: 14,
                                decoration: BoxDecoration(color: kAmber, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: kSpaceSM),
                            const Text('ITEMS',
                                style: TextStyle(fontWeight: FontWeight.w700, color: kAmber, fontSize: 11, letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: kSpaceSM),
                        ...displayTab.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: kSpaceXS),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${item.menuItemName}  ×${item.quantity}',
                                      style: const TextStyle(fontSize: 13))),
                                  Text(formatCurrency(item.subtotal),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            )),
                        const SizedBox(height: kSpaceSM),
                      ],

                      if (displayTab.gameSessions.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(width: 3, height: 14,
                                decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: kSpaceSM),
                            const Text('GAMES',
                                style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 11, letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: kSpaceSM),
                        ...displayTab.gameSessions.map((g) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: kSpaceXS),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        '${g.gameName}  (${g.durationMinutes?.toStringAsFixed(1) ?? 0} min)',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                  Text(formatCurrency(g.totalCost ?? 0),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            )),
                        const SizedBox(height: kSpaceSM),
                      ],

                      const Divider(),
                      const SizedBox(height: kSpaceSM),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                          Text(
                            formatCurrency(displayTab.subtotal + displayTab.runningGamesCost),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24, color: kAccent, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: kSpaceLG),

                if (_settledTab == null) ...[
                  const Text('Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: kSpaceSM + 4),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentOption(
                          icon: Icons.money_rounded,
                          label: 'Cash',
                          selected: _paymentMethod == 'cash',
                          onTap: () => setState(() => _paymentMethod = 'cash'),
                        ),
                      ),
                      const SizedBox(width: kSpaceSM + 4),
                      Expanded(
                        child: _PaymentOption(
                          icon: Icons.qr_code_rounded,
                          label: 'UPI',
                          selected: _paymentMethod == 'upi',
                          onTap: () => setState(() => _paymentMethod = 'upi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpaceSM + 4),
                  SizedBox(
                    width: double.infinity,
                    child: _PaymentOption(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Credit (pay later)',
                      selected: _paymentMethod == 'credit',
                      onTap: () => setState(() => _paymentMethod = 'credit'),
                    ),
                  ),
                  const SizedBox(height: kSpaceLG),
                  ElevatedButton(
                    onPressed: _settling ? null : () => _settle(displayTab),
                    child: _settling
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm & Settle'),
                  ),
                ] else ...[
                  // Settled — success banner
                  Container(
                    padding: const EdgeInsets.all(kSpaceMD),
                    decoration: BoxDecoration(
                      color: (_settledTab!.isOnCredit ? kAmber : kGreen)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(kRadiusMD),
                      border: Border.all(
                        color: (_settledTab!.isOnCredit ? kAmber : kGreen)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _settledTab!.isOnCredit
                              ? Icons.schedule_rounded
                              : Icons.check_circle_rounded,
                          color: _settledTab!.isOnCredit ? kAmber : kGreen,
                          size: 22,
                        ),
                        const SizedBox(width: kSpaceSM + 2),
                        Expanded(
                          child: Text(
                            _settledTab!.isOnCredit
                                ? 'On credit — collect from Customers tab'
                                : 'Settled via ${_settledTab!.paymentMethod?.toUpperCase()}',
                            style: TextStyle(
                              color: _settledTab!.isOnCredit ? kAmber : kGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpaceLG),
                  const Text('Share Receipt',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: kSpaceSM + 4),

                  // WhatsApp — primary action
                  ElevatedButton.icon(
                    onPressed: () => _promptWhatsApp(_settledTab!),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(
                      _settledTab!.customerPhone != null && _settledTab!.customerPhone!.isNotEmpty
                          ? 'WhatsApp  ·  ${_settledTab!.customerPhone}'
                          : 'Send on WhatsApp',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                  ),
                  const SizedBox(height: kSpaceSM),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _printReceipt(_settledTab!),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Print'),
                        ),
                      ),
                      const SizedBox(width: kSpaceSM),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareReceipt(_settledTab!),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpaceMD),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: kSpaceLG),
        decoration: BoxDecoration(
          color: selected ? kAccent.withValues(alpha: 0.12) : kCard,
          borderRadius: BorderRadius.circular(kRadiusLG),
          border: Border.all(
            color: selected ? kAccent : kDivider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: selected ? kAccent : kTextMuted),
            const SizedBox(height: kSpaceSM),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? kAccent : kTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
