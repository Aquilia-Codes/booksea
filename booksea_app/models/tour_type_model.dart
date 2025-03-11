class TourTypeModel {
  final String id;
  final String name;
  // add other fields

  TourTypeModel({required this.id, required this.name});

  factory TourTypeModel.fromMap(Map<String, dynamic> data, String id) {
    return TourTypeModel(
      id: id,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
} 