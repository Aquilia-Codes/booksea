class TourModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String
      tourName; //sets the tour name the same as the boat name + type name
  final String tourType;
  final int typeImage;
  final int capacity;
  final int filled;
  final int arrived;
  final double price;
  final bool isBooked;
  final String note;

  TourModel({
    this.id = '',
    required this.startTime,
    required this.endTime,
    required this.tourName,
    required this.tourType,
    required this.typeImage,
    required this.capacity,
    this.filled = 0, //this is the number of adult people in the tour
    this.arrived = 0, //this is the number of adult people that have arrived
    this.price =
        0.0, //this is the all together price from all the groups together
    this.isBooked = false,
    required this.note,
  });

  factory TourModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TourModel(
      id: documentId,
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      tourName: data['tourName'],
      tourType: data['tourType'],
      typeImage: data['typeImage'],
      capacity: data['capacity'],
      filled: data['filled'] ?? 0,
      arrived: data['arrived'] ?? 0,
      // A whole-number price (e.g. 0) decodes from JSON as a Dart int, which
      // throws if assigned directly to this double field - num.toDouble()
      // handles both.
      price: ((data['price'] ?? 0.0) as num).toDouble(),
      isBooked: data['isBooked'] ?? false,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // The backend requires a UTC-formatted datetime (zod's
      // z.string().datetime() rejects a bare local-time string with no
      // timezone marker at all - which plain toIso8601String() on a local
      // DateTime produces, since these are usually built via the local
      // DateTime(...) constructor in the tour-creation/edit UI).
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'tourName': tourName,
      'tourType': tourType,
      'typeImage': typeImage,
      'capacity': capacity,
      'filled': filled,
      'arrived': arrived,
      'price': price,
      'isBooked': isBooked,
      'note': note,
    };
  }
}
