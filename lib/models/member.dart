class Member {
  final int id;
  final String name;
  final String code;
  final String mobile;
  final String chapter;
  final int chapterId;
  final String category;
  final String company;
  final String email;
  final String role;
  final String city;
  final String avatar;

  Member({
    required this.id,
    required this.name,
    required this.code,
    required this.mobile,
    required this.chapter,
    this.chapterId = 0,
    required this.category,
    required this.company,
    required this.email,
    required this.role,
    this.city = 'Delhi',
    this.avatar = '',
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      code: json['code']?.toString() ?? 'N/A',
      mobile: json['mobile']?.toString() ?? 'N/A',
      chapter: json['chapter']?.toString() ?? 'Unknown',
      chapterId: int.tryParse(json['chapter_id']?.toString() ?? '0') ?? 0,
      category: json['category']?.toString() ?? 'Unknown',
      company: json['company']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? 'N/A',
      role: json['role']?.toString() ?? 'Member',
      city: json['city']?.toString() ?? 'Delhi',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}
