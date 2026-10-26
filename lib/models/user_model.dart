import 'member.dart';

class UserModel {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final int chapterId;
  final String memberCode;
  final String companyName;
  final String chapterName;
  final String businessCategory;
  final String city;
  final String email;
  final String avatar;
  final String give;
  final String ask;
  final Map<String, dynamic>? rawJson;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.chapterId,
    this.memberCode = '',
    this.companyName = '',
    this.chapterName = '',
    this.businessCategory = '',
    this.city = '',
    this.email = '',
    this.avatar = '',
    this.give = '',
    this.ask = '',
    this.rawJson,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
        name: json['display_name']?.toString() ??
          json['name']?.toString() ??
          json['first_name']?.toString() ??
          '',
      mobile: (json['mobile'] ??
              json['phone'] ??
              json['phone_number'] ??
              json['mobile_number'] ??
              json['contact_number'] ??
              json['contact_no'] ??
              '')
          .toString(),
      role: json['role_name']?.toString() ?? json['role']?.toString() ?? '',
      chapterId: json['chapter_id'] != null ? int.tryParse(json['chapter_id'].toString()) ?? 0 : 0,
      memberCode: json['member_code']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? json['company']?.toString() ?? '',
      chapterName: json['chapter_name']?.toString() ?? json['chapter']?.toString() ?? '',
      businessCategory: json['business_category']?.toString() ?? json['category']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
        avatar: json['profile_photo']?.toString() ??
          json['avatar']?.toString() ??
          '',
      give: json['give']?.toString() ??
          json['gives']?.toString() ??
          json['what_i_give']?.toString() ??
          '',
      ask: json['ask']?.toString() ??
          json['asks']?.toString() ??
          json['what_i_ask']?.toString() ??
          '',
      rawJson: json,
    );
  }

  Member toMember() {
    return Member(
      id: id,
      name: name,
      code: memberCode.isNotEmpty ? memberCode : 'N/A',
      mobile: mobile.isNotEmpty ? mobile : 'N/A',
      chapter: chapterName.isNotEmpty ? chapterName : 'Unknown',
      chapterId: chapterId,
      category: businessCategory.isNotEmpty ? businessCategory : 'Unknown',
      company: companyName.isNotEmpty ? companyName : 'Unknown',
      email: email.isNotEmpty ? email : 'N/A',
      role: role.isNotEmpty ? role : 'Member',
      city: city.isNotEmpty ? city : 'Delhi',
      avatar: avatar,
    );
  }
}
