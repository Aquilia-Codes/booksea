// not sure about this import: import 'package:meta/meta.dart';

class AccessModel {
  final String userId;
  final bool hasAccess;
  final bool isAdmin; 
  final bool isOwner; 
  final String companyId;
  final String email;
  final String nickname;
  final int provision;

  AccessModel({
    required this.userId,
    required this.hasAccess,
    required this.isAdmin,
    required this.isOwner, 
    required this.companyId,
    required this.email,
    required this.nickname,
    required this.provision,
  });

  factory AccessModel.fromMap(Map<String, dynamic> data, String documentId) {
    final provision = data['provision'] ?? 0;
    return AccessModel(
      userId: data['userId'],
      hasAccess: data['hasAccess'],
      isAdmin: data['isAdmin'],
      isOwner: data['isOwner'], 
      companyId: data['companyId'],
      email: data['email'],
      nickname: data['nickname'],
      provision: provision,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'hasAccess': hasAccess,
      'isAdmin': isAdmin,
      'isOwner': isOwner, 
      'companyId': companyId,
      'email': email,
      'nickname': nickname,
      'provision': provision,
    };
  }
}

// This class can be useful during the signup process. When a new user signs up, you can create an instance of `AccessModel` with their details.
// If the user is already signed up, you can use the `fromMap` factory constructor to read their data from a database or other data source and create an `AccessModel` instance.
// This allows you to easily manage and access user information in a structured way.