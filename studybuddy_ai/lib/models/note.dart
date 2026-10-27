class NoteSection {
  final String title;
  final String description;
  final List<NoteBullet> bullets;

  const NoteSection({
    required this.title,
    required this.description,
    required this.bullets,
  });
}

class NoteBullet {
  final String term;
  final String definition;
  final String iconName;

  const NoteBullet({
    required this.term,
    required this.definition,
    required this.iconName,
  });
}

class NoteItem {
  final String id;
  final String title;
  final String courseCode;
  final String courseName;
  final String category; // 'psych', 'chem', 'econ', 'bio'
  final String summary;
  final String estimatedTime;
  final String timeAgo;
  final int accuracyPercent;
  final int keyTermsCount;
  final String readTime;
  final List<NoteSection> sections;
  final List<String> definitions;
  final String examPitfall;
  final String rawTranscript;
  bool isBookmarked;

  NoteItem({
    required this.id,
    required this.title,
    required this.courseCode,
    required this.courseName,
    required this.category,
    required this.summary,
    required this.estimatedTime,
    required this.timeAgo,
    required this.accuracyPercent,
    required this.keyTermsCount,
    required this.readTime,
    required this.sections,
    required this.definitions,
    required this.examPitfall,
    required this.rawTranscript,
    this.isBookmarked = false,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final rawDefs = json['key_definitions'] as List<dynamic>? ?? [];
    final defs = rawDefs.map((d) => "${d['title']}: ${d['body']}").toList();

    final rawPitfalls = json['exam_pitfalls'] as List<dynamic>? ?? [];
    final pitfallText = rawPitfalls.isNotEmpty
        ? "${rawPitfalls.first['title']}: ${rawPitfalls.first['description']}"
        : "Distinguish core concepts carefully during exam recall.";

    final bullets = rawDefs.map((d) {
      return NoteBullet(
        term: d['title']?.toString() ?? 'Key Term',
        definition: d['body']?.toString() ?? '',
        iconName: 'psychology',
      );
    }).toList();

    return NoteItem(
      id: json['id']?.toString() ?? '1',
      title: json['title'] ?? 'Synthesized Notes',
      courseCode: json['course_code'] ?? 'PSYC 201',
      courseName: json['course_name'] ?? 'Cognitive Psychology',
      category: 'psych',
      summary: json['summary'] ?? '',
      estimatedTime: json['read_time'] ?? '5 min read',
      timeAgo: 'Just now',
      accuracyPercent: json['accuracy_percent'] ?? 85,
      keyTermsCount: json['key_terms_count'] ?? (defs.isNotEmpty ? defs.length : 4),
      readTime: json['read_time'] ?? '5 min read',
      sections: [
        NoteSection(
          title: 'Core Concept Breakdown',
          description: json['summary'] ?? '',
          bullets: bullets,
        ),
      ],
      definitions: defs.isNotEmpty ? defs : ['Key concept definitions synthesized from document.'],
      examPitfall: pitfallText,
      rawTranscript: json['raw_transcript'] ?? '',
      isBookmarked: false,
    );
  }
}
