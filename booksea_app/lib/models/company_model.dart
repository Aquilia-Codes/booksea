class CompanyModel {
  final String companyName;
  final String companyCode;
  final String status;
  final String tier;

  CompanyModel({
    required this.companyName,
    required this.companyCode,
    required this.status,
    required this.tier,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> data) {
    return CompanyModel(
      companyName: data['companyName'],
      companyCode: data['companyCode'],
      status: data['status'],
      tier: data['tier'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyCode': companyCode,
      'status': status,
      'tier': tier,
    };
  }
}

