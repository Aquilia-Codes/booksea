class TypeModel {
  final String
      typeName; //sets the tour name the same as the boat name + type name
  final double pricePerAdult;
  final double pricePerChild;
  final DateTime startTime;
  final DateTime endTime;
  final int typeImage;
  final List<String>? options;

  TypeModel({
    required this.typeName,
    required this.pricePerAdult,
    required this.pricePerChild,
    required this.startTime,
    required this.endTime,
    required this.typeImage,
    this.options,
  });

  factory TypeModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TypeModel(
      typeName: data['typeName'],
      pricePerAdult: (data['pricePerAdult'] is double)
          ? data['pricePerAdult']
          : double.parse(data['pricePerAdult'].toString()),
      pricePerChild: (data['pricePerChild'] is double)
          ? data['pricePerChild']
          : double.parse(data['pricePerChild'].toString()),
      // The API sends these as a time-of-day-only string ("HH:mm:ss"), not a
      // full date - the date component here is a placeholder, only the hour
      // and minute are ever used (see TimeOfDay.fromDateTime call sites).
      startTime: DateTime.parse('1970-01-01T${data['startTime']}'),
      endTime: DateTime.parse('1970-01-01T${data['endTime']}'),
      typeImage: data['typeImage'],
      options: data['options'],
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
      'startTime': startTime
          .toIso8601String()
          .split('T')[1], // Return only the time part
      'endTime':
          endTime.toIso8601String().split('T')[1], // Return only the time part
      'typeImage': typeImage,
      'options': options,
    };
  }
}
