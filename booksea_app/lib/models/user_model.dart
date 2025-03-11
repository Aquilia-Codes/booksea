// not sure about this import: import 'package:meta/meta.dart';

class UserModel {
  final String uid;
  final bool hasAccess;
  final bool isAdmin; 
  final bool isOwner; 
  final String companyId;
  final String email;
  final String nickname;
  final int provision;

  UserModel({
    required this.uid,
    required this.hasAccess,
    required this.isAdmin,
    required this.isOwner, 
    this.companyId = '',
    required this.email,
    required this.nickname,
    required this.provision,
  });

  UserModel copyWith({
    String? uid,
    bool? hasAccess,
    bool? isAdmin,
    bool? isOwner,
    String? companyId,
    String? email,
    String? nickname,
    int? provision,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      hasAccess: hasAccess ?? this.hasAccess,
      isAdmin: isAdmin ?? this.isAdmin,
      isOwner: isOwner ?? this.isOwner,
      companyId: companyId ?? this.companyId,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      provision: provision ?? this.provision,
    );
  }
  

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final provision = data['provision'] ?? 0;
    return UserModel(
      uid: data['uid'],
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
      'uid': uid,
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

// This class can be useful during the signup process. When a new user signs up, you can create an instance of `UserModel` with their details.
// If the user is already signed up, you can use the `fromMap` factory constructor to read their data from a database or other data source and create an `AccessModel` instance.
// This allows you to easily manage and access user information in a structured way.