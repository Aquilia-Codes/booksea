// The signed-in user's own booked tickets/price/provision for a boat and
// date range - see backend/src/routes/boats.ts GET /boats/:id/performance.
class PerformanceModel {
  final int tickets;
  final double totalPrice;
  final double provision;

  PerformanceModel({
    required this.tickets,
    required this.totalPrice,
    required this.provision,
  });

  factory PerformanceModel.fromMap(Map<String, dynamic> data) {
    return PerformanceModel(
      tickets: (data['tickets'] as num).toInt(),
      totalPrice: (data['totalPrice'] as num).toDouble(),
      provision: (data['provision'] as num).toDouble(),
    );
  }
}

// One row of the owner-only team view - GET /boats/:id/performance/team.
class TeamPerformanceEntry {
  final String userId;
  final String nickname;
  final int tickets;
  final double totalPrice;
  final double provision;

  TeamPerformanceEntry({
    required this.userId,
    required this.nickname,
    required this.tickets,
    required this.totalPrice,
    required this.provision,
  });

  factory TeamPerformanceEntry.fromMap(Map<String, dynamic> data) {
    return TeamPerformanceEntry(
      userId: data['userId'] as String,
      nickname: data['nickname'] as String,
      tickets: (data['tickets'] as num).toInt(),
      totalPrice: (data['totalPrice'] as num).toDouble(),
      provision: (data['provision'] as num).toDouble(),
    );
  }
}
