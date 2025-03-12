import 'package:cloud_firestore/cloud_firestore.dart';

class TypeModel {   
  final String typeName; //sets the tour name the same as the boat name + type name
  final double pricePerAdult;
  final double pricePerChild; 
  final DateTime startTime;
  final DateTime endTime;

  TypeModel({
    required this.typeName,
    required this.pricePerAdult,
    required this.pricePerChild, 
    required this.startTime,
    required this.endTime,
  });

  factory TypeModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TypeModel(
      typeName: data['typeName'],
      pricePerAdult: (data['pricePerAdult'] is double) ? data['pricePerAdult'] : double.parse(data['pricePerAdult'].toString()),
      pricePerChild: (data['pricePerChild'] is double) ? data['pricePerChild'] : double.parse(data['pricePerChild'].toString()),
      startTime: (data['startTime'] is Timestamp) ? (data['startTime'] as Timestamp).toDate() : DateTime.parse(data['startTime']),
      endTime: (data['endTime'] is Timestamp) ? (data['endTime'] as Timestamp).toDate() : DateTime.parse(data['endTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeName': typeName,
      'pricePerAdult': pricePerAdult,
      'pricePerChild': pricePerChild, 
      // The following lines convert the DateTime objects `startTime` and `endTime` to ISO 8601 string format,
      // then split the resulting string at the 'T' character to isolate the time portion (the part after 'T').
      // This effectively extracts only the time part of the DateTime, discarding the date.
      'startTime': startTime.toIso8601String().split('T')[1], // Return only the time part
      'endTime': endTime.toIso8601String().split('T')[1], // Return only the time part
    };
  }
}
