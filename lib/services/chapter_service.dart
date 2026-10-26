import 'api_client.dart';

class ChapterService {
  /// GET /chapters
  /// Expected: { success: true, data: [...] } or { success: true, chapters: [...] }
  static Future<List<ChapterItem>> getChapters() async {
    final response = await ApiClient.get('chapters');

    List<dynamic> rawList = [];
    if (response['data'] is List) {
      rawList = response['data'] as List<dynamic>;
    } else if (response['chapters'] is List) {
      rawList = response['chapters'] as List<dynamic>;
    } else if (response is List) {
      rawList = response;
    }

    return rawList
        .map((json) => ChapterItem.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}

class ChapterItem {
  final String id;
  final String name;
  final String? location;
  final String? team;

  ChapterItem({
    required this.id,
    required this.name,
    this.location,
    this.team,
  });

  factory ChapterItem.fromJson(Map<String, dynamic> json) {
    return ChapterItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Chapter',
      location: json['location']?.toString(),
      team: json['team']?.toString(),
    );
  }
}
