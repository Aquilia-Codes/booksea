class TierModel {
  final String id;
  final String tierName;
  final int maxBoats;
  final int seats;
  final int additionalSeats;

  TierModel({
    required this.id,
    required this.tierName,
    required this.maxBoats,
    required this.seats,
    required this.additionalSeats,
  });

  factory TierModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TierModel(
      id: documentId,
      tierName: data['tierName'],
      maxBoats: data['maxBoats'],
      seats: data['seats'],
      additionalSeats: data['additionalSeats'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tierName': tierName,
      'maxBoats': maxBoats,
      'seats': seats,
      'additionalSeats': additionalSeats,
    };
  }
}
