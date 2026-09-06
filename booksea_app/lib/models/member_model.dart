// A company member as seen by the owner-facing Members screen (see
// backend/src/routes/companies.ts GET/PATCH /companies/:id/members). A
// "pending" member is just one with hasAccess == false - there's no
// separate invite/request model, joining with the company code
// (AuthProvider/ApiDatabase.writeCompanyIdToUserDocument) already produces
// exactly that state.
class MemberModel {
  final String id;
  final String email;
  final String nickname;
  final bool hasAccess;
  final bool isAdmin;
  final bool isOwner;
  final int provision;
  final List<String> boatNames;

  MemberModel({
    required this.id,
    required this.email,
    required this.nickname,
    required this.hasAccess,
    required this.isAdmin,
    required this.isOwner,
    required this.provision,
    required this.boatNames,
  });

  factory MemberModel.fromMap(Map<String, dynamic> data) {
    return MemberModel(
      id: data['id'] as String,
      email: data['email'] as String,
      nickname: data['nickname'] as String,
      hasAccess: data['hasAccess'] as bool,
      isAdmin: data['isAdmin'] as bool,
      isOwner: data['isOwner'] as bool,
      provision: ((data['provision'] ?? 0) as num).round(),
      boatNames: (data['boatNames'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
