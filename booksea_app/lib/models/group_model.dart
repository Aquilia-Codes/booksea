class GroupModel {
  final String id;
  final String groupName;
  final int adultCount;
  final int childCount;
  final double price;
  final String paymentStatus;
  String bookerId;
  final String mobileNumber;
  final String countryCode;
  final String countryDialogCode;

  GroupModel({
    this.id = '',
    required this.groupName,
    required this.adultCount,
    required this.childCount,
    required this.price,
    required this.paymentStatus,
    this.bookerId = '',
    required this.mobileNumber,
    required this.countryCode,
    required this.countryDialogCode,
  });

  factory GroupModel.fromMap(Map<String, dynamic> data, String documentId) {
    return GroupModel(
      id: documentId,
      groupName: data['groupName'],
      adultCount: data['adultCount'],
      childCount: data['childCount'],
      price: data['price'],
      paymentStatus: data['paymentStatus'],
      bookerId: data['bookerId'],
      mobileNumber: data['mobileNumber'],
      countryCode: data['countryCode'],
      countryDialogCode: data['countryDialogCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupName': groupName,
      'adultCount': adultCount,
      'childCount': childCount,
      'price': price,
      'paymentStatus': paymentStatus,
      'bookerId': bookerId,
      'mobileNumber': mobileNumber,
      'countryCode': countryCode,
      'countryDialogCode': countryDialogCode,
    };
  }
}
