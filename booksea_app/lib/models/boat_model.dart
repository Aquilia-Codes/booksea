class BoatModel {
  final String id;
  final String name; //sets the tour name the same as the boat name + type name
  final int capacity;

  BoatModel({
    required this.id,
    required this.name,
    required this.capacity,
  });

  factory BoatModel.fromMap(Map<String, dynamic> data, String documentId) {
    return BoatModel(
      id: documentId,
      name: data['name'],
      capacity: data['capacity'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'capacity': capacity,
    };
  }
}
