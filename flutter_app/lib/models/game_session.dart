class GameSession {
  final int id;
  final int tabId;
  final int menuItemId;
  final String gameName;
  final double ratePerMinute;
  final DateTime startTime;
  final DateTime? endTime;
  final double? durationMinutes;
  final double? totalCost;
  final String status;

  const GameSession({
    required this.id,
    required this.tabId,
    required this.menuItemId,
    required this.gameName,
    required this.ratePerMinute,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.totalCost,
    required this.status,
  });

  bool get isRunning => status == 'running';

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
        id: json['id'],
        tabId: json['tab_id'],
        menuItemId: json['menu_item_id'],
        gameName: json['game_name'],
        ratePerMinute: double.parse(json['rate_per_minute'].toString()),
        startTime: DateTime.parse(json['start_time']),
        endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
        durationMinutes: json['duration_minutes'] != null
            ? double.parse(json['duration_minutes'].toString())
            : null,
        totalCost: json['total_cost'] != null
            ? double.parse(json['total_cost'].toString())
            : null,
        status: json['status'],
      );

  GameSession copyWith({
    int? id,
    int? tabId,
    int? menuItemId,
    String? gameName,
    double? ratePerMinute,
    DateTime? startTime,
    DateTime? endTime,
    double? durationMinutes,
    double? totalCost,
    String? status,
  }) =>
      GameSession(
        id: id ?? this.id,
        tabId: tabId ?? this.tabId,
        menuItemId: menuItemId ?? this.menuItemId,
        gameName: gameName ?? this.gameName,
        ratePerMinute: ratePerMinute ?? this.ratePerMinute,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        totalCost: totalCost ?? this.totalCost,
        status: status ?? this.status,
      );
}
