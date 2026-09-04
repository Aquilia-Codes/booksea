// not sure about this import: import 'package:meta/meta.dart';

class UserModel {
  final String uid;
  final bool hasAccess;
  final bool isAdmin;
  final bool isOwner;
  final String companyId;
  final String email;
  final String? phoneNumber;
  final String nickname;
  final int provision;
  final String? photoUrl;
  final List<dynamic>
      boatIds; //The ids of the boats that the user has access to

  UserModel({
    required this.uid,
    required this.hasAccess,
    required this.isAdmin,
    required this.isOwner,
    this.companyId = '',
    required this.email,
    required this.nickname,
    required this.provision,
    this.phoneNumber,
    this.photoUrl,
    this.boatIds = const [],
  });

  UserModel copyWith({
    String? uid, //TODO: Check if this is needed
    bool? hasAccess,
    bool? isAdmin,
    bool? isOwner,
    String? companyId,
    String? email,
    String? phoneNumber,
    String? nickname,
    int? provision,
    String? photoUrl,
    List<dynamic>? boatIds,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      hasAccess: hasAccess ?? this.hasAccess,
      isAdmin: isAdmin ?? this.isAdmin,
      isOwner: isOwner ?? this.isOwner,
      companyId: companyId ?? this.companyId,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nickname: nickname ?? this.nickname,
      provision: provision ?? this.provision,
      photoUrl: photoUrl ?? this.photoUrl,
      boatIds: boatIds ?? this.boatIds,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    // The API's provision column allows decimals (Decimal(5,2)); this model
    // has always been an int, so round rather than let a fractional value
    // (e.g. 2.5) throw a "double isn't a subtype of int" at parse time.
    final provision = ((data['provision'] ?? 0) as num).round();
    return UserModel(
      uid: data['uid'],
      hasAccess: data['hasAccess'],
      isAdmin: data['isAdmin'],
      isOwner: data['isOwner'],
      // A brand-new user has no company yet - the API sends this as JSON
      // null (companyId is nullable in Postgres), which would otherwise
      // crash here since this field is a non-nullable String.
      companyId: data['companyId'] ?? '',
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      nickname: data['nickname'],
      provision: provision,
      photoUrl: data['photoUrl'],
      boatIds: data['boatIds'] ?? [],
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
      'phoneNumber': phoneNumber,
      'nickname': nickname,
      'provision': provision,
      'photoUrl': photoUrl,
      'boatIds': boatIds,
    };
  }
}

// This class can be useful during the signup process. When a new user signs up, you can create an instance of `UserModel` with their details.
// If the user is already signed up, you can use the `fromMap` factory constructor to read their data from a database or other data source and create an `AccessModel` instance.
// This allows you to easily manage and access user information in a structured way.
