class LogModel {
  final String message;
  final DateTime timestamp;

  LogModel({required this.message, required this.timestamp});

  factory LogModel.fromMap(Map<String, dynamic> data) {
    return LogModel(
      message: data['message'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': timestamp,
    };
  }
}
