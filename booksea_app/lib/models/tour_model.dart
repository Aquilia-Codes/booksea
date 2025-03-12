import 'package:cloud_firestore/cloud_firestore.dart';

class TourModel { 
  final DateTime date; //TODO probably not needed, remove later
  final Timestamp startTime;
  final Timestamp endTime;
  final String tourName; //sets the tour name the same as the boat name + type name
  final String tourType;
  final int capacity;
  final double price;
  final bool isBooked;
  final String note;

  TourModel({ 
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.tourName,
    required this.tourType,
    required this.capacity,
    this.price = 0.0, //this is the all together price from all the groups together
    this.isBooked = false,
    required this.note,
  });

  factory TourModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TourModel( 
      date: DateTime.parse(data['date']), 
      startTime: (data['startTime'] is Timestamp) ? data['startTime'] as Timestamp : Timestamp.fromDate(DateTime.parse(data['startTime'])),
      endTime: (data['endTime'] is Timestamp) ? data['endTime'] as Timestamp : Timestamp.fromDate(DateTime.parse(data['endTime'])),
      tourName: data['tourName'],
      tourType: data['tourType'],
      capacity: data['capacity'],
      price: data['price'] ?? 0.0,
      isBooked: data['isBooked'] ?? false,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'tourName': tourName,
      'tourType': tourType,
      'capacity': capacity,
      'isBooked': isBooked,
      'note': note,
    };
  }
}
