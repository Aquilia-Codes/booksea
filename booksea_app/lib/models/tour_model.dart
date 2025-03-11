class TourModel {
  final String id;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String tourName; //sets the tour name the same as the boat name + type name
  final String tourType;
  final int capacity;
  final double price;
  final bool isBooked;
  final String note;

  TourModel({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.tourName,
    required this.tourType,
    required this.capacity,
    this.price = 0, //this is the all together price from all the groups together
    required this.isBooked,
    required this.note,
  });

  factory TourModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TourModel(
      id: documentId,
      date: DateTime.parse(data['date']),
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      tourName: data['tourName'],
      tourType: data['tourType'],
      capacity: data['capacity'],
      price: data['price'],
      isBooked: data['isBooked'],
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'tourName': tourName,
      'tourType': tourType,
      'capacity': capacity,
      'isBooked': isBooked,
      'note': note,
    };
  }
}
