import 'tab_item.dart';
import 'game_session.dart';

class BillTab {
  final int id;
  final String customerName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status;
  final String? paymentMethod;
  final double subtotal;
  final String? notes;
  final String? customerPhone;
  final List<TabItem> items;
  final List<GameSession> gameSessions;
  final int? itemCount;
  final int? activeGames;

  const BillTab({
    required this.id,
    required this.customerName,
    required this.openedAt,
    this.closedAt,
    required this.status,
    this.paymentMethod,
    required this.subtotal,
    this.notes,
    this.customerPhone,
    this.items = const [],
    this.gameSessions = const [],
    this.itemCount,
    this.activeGames,
  });

  bool get isOpen => status == 'open';

  double get runningGamesCost {
    final now = DateTime.now();
    return gameSessions
        .where((g) => g.isRunning)
        .fold(0.0, (sum, g) {
          final minutes = now.difference(g.startTime).inSeconds / 60.0;
          return sum + (minutes * g.ratePerMinute);
        });
  }

  double get totalWithRunningGames => subtotal + runningGamesCost;

  factory BillTab.fromJson(Map<String, dynamic> json) => BillTab(
        id: json['id'],
        customerName: json['customer_name'],
        openedAt: DateTime.parse(json['opened_at']),
        closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at']) : null,
        status: json['status'],
        paymentMethod: json['payment_method'],
        subtotal: double.parse(json['subtotal']?.toString() ?? '0'),
        notes: json['notes'],
        customerPhone: json['customer_phone'],
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => TabItem.fromJson(e))
                .toList() ??
            [],
        gameSessions: (json['game_sessions'] as List<dynamic>?)
                ?.map((e) => GameSession.fromJson(e))
                .toList() ??
            [],
        itemCount: json['item_count'] != null ? int.parse(json['item_count'].toString()) : null,
        activeGames: json['active_games'] != null ? int.parse(json['active_games'].toString()) : null,
      );

  BillTab copyWith({
    int? id,
    String? customerName,
    DateTime? openedAt,
    DateTime? closedAt,
    String? status,
    String? paymentMethod,
    double? subtotal,
    String? notes,
    String? customerPhone,
    List<TabItem>? items,
    List<GameSession>? gameSessions,
    int? itemCount,
    int? activeGames,
  }) =>
      BillTab(
        id: id ?? this.id,
        customerName: customerName ?? this.customerName,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt ?? this.closedAt,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        subtotal: subtotal ?? this.subtotal,
        notes: notes ?? this.notes,
        customerPhone: customerPhone ?? this.customerPhone,
        items: items ?? this.items,
        gameSessions: gameSessions ?? this.gameSessions,
        itemCount: itemCount ?? this.itemCount,
        activeGames: activeGames ?? this.activeGames,
      );
}
