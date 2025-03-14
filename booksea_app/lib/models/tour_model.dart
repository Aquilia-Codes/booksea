import 'package:cloud_firestore/cloud_firestore.dart';

class TourModel {
  final String id;
  final Timestamp startTime;
  final Timestamp endTime;
  final String
      tourName; //sets the tour name the same as the boat name + type name
  final String tourType;
  final int capacity;
  final int filled;
  final double price;
  final bool isBooked;
  final String note;

  TourModel({
    this.id = '',
    required this.startTime,
    required this.endTime,
    required this.tourName,
    required this.tourType,
    required this.capacity,
    this.filled = 0, //this is the number of adult people in the tour
    this.price =
        0.0, //this is the all together price from all the groups together
    this.isBooked = false,
    required this.note,
  });

  factory TourModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TourModel(
      id: documentId,
      startTime: (data['startTime'] is Timestamp)
          ? data['startTime'] as Timestamp
          : Timestamp.fromDate(DateTime.parse(data['startTime'])),
      endTime: (data['endTime'] is Timestamp)
          ? data['endTime'] as Timestamp
          : Timestamp.fromDate(DateTime.parse(data['endTime'])),
      tourName: data['tourName'],
      tourType: data['tourType'],
      capacity: data['capacity'],
      filled: data['filled'] ?? 0,
      price: data['price'] ?? 0.0,
      isBooked: data['isBooked'] ?? false,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'tourName': tourName,
      'tourType': tourType,
      'capacity': capacity,
      'filled': filled,
      'isBooked': isBooked,
      'note': note,
    };
  }
}
