class BoatModel {
  final String name; //sets the tour name the same as the boat name + type name
  final int capacity;

  BoatModel({
    required this.name,
    required this.capacity,
  });

  factory BoatModel.fromMap(Map<String, dynamic> data) {
    return BoatModel(
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
