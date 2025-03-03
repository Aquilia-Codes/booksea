class GroupModel {
  final String groupName;
  final int adultCount;
  final int childCount;
  final double price;
  final String paymentStatus;
  final String bookerId;

  GroupModel({
    required this.groupName,
    required this.adultCount,
    required this.childCount,
    required this.price,
    required this.paymentStatus,
    required this.bookerId,
  });

  factory GroupModel.fromMap(Map<String, dynamic> data) {
    return GroupModel(
      groupName: data['groupName'],
      adultCount: data['adultCount'],
      childCount: data['childCount'],
      price: data['price'],
      paymentStatus: data['paymentStatus'],
      bookerId: data['bookerId'],
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
    };
  }
}
