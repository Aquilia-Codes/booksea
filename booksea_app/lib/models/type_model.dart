class TypeModel {
  final String id;
  final String typeName; //sets the tour name the same as the boat name + type name
  final double pricePerAdult;
  final double pricePerChild;
  final String boatId;
  final DateTime startTime;
  final DateTime endTime;

  TypeModel({
    required this.id,
    required this.typeName,
    required this.pricePerAdult,
    required this.pricePerChild,
    required this.boatId,
    required this.startTime,
    required this.endTime,
  });

  factory TypeModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TypeModel(
      id: documentId,
      typeName: data['typeName'],
      pricePerAdult: data['pricePerAdult'],
      pricePerChild: data['pricePerChild'],
      boatId: data['boatId'],
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeName': typeName,
      'pricePerAdult': pricePerAdult,
      'pricePerChild': pricePerChild,
      'boatId': boatId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }
}
