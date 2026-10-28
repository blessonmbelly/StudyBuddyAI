class KeyDefinitionItem {
  final String title;
  final String tag;
  final String body;

  const KeyDefinitionItem({
    required this.title,
    required this.tag,
    required this.body,
  });

  factory KeyDefinitionItem.fromJson(Map<String, dynamic> json) {
    return KeyDefinitionItem(
      title: json['title']?.toString() ?? 'Core Concept',
      tag: json['tag']?.toString() ?? 'Definition',
      body: json['body']?.toString() ?? '',
    );
  }
}

class ExamPitfallItem {
  final String title;
  final String description;
  final String conceptA;
  final String conceptB;

  const ExamPitfallItem({
    required this.title,
    required this.description,
    this.conceptA = '',
    this.conceptB = '',
  });

  factory ExamPitfallItem.fromJson(Map<String, dynamic> json) {
    return ExamPitfallItem(
      title: json['title']?.toString() ?? 'Common Pitfall',
      description: json['description']?.toString() ?? '',
      conceptA: json['concept_a']?.toString() ?? '',
      conceptB: json['concept_b']?.toString() ?? '',
    );
  }
}

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
  final String category; // 'psych', 'chem', 'econ', 'bio', 'cs', 'general'
  final String summary;
  final String estimatedTime;
  final String timeAgo;
  final int accuracyPercent;
  final int keyTermsCount;
  final String readTime;
  final List<NoteSection> sections;
  final List<KeyDefinitionItem> keyDefinitions;
  final List<ExamPitfallItem> examPitfalls;
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
    this.keyDefinitions = const [],
    this.examPitfalls = const [],
    required this.definitions,
    required this.examPitfall,
    required this.rawTranscript,
    this.isBookmarked = false,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    // Parse key definitions
    final rawDefs = json['key_definitions'] as List<dynamic>? ?? [];
    final keyDefs = rawDefs
        .whereType<Map<String, dynamic>>()
        .map((d) => KeyDefinitionItem.fromJson(d))
        .toList();
    final defs = keyDefs.map((d) => "${d.title}: ${d.body}").toList();

    // Parse exam pitfalls
    final rawPitfalls = json['exam_pitfalls'] as List<dynamic>? ?? [];
    final pitfalls = rawPitfalls
        .whereType<Map<String, dynamic>>()
        .map((p) => ExamPitfallItem.fromJson(p))
        .toList();
    final pitfallText = pitfalls.isNotEmpty
        ? "${pitfalls.first.title}: ${pitfalls.first.description}"
        : "Distinguish core concepts carefully during exam recall.";

    // Parse sections
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    List<NoteSection> sections = [];
    if (rawSections.isNotEmpty) {
      for (final s in rawSections) {
        if (s is Map<String, dynamic>) {
          final rawBullets = s['bullets'] as List<dynamic>? ?? [];
          final bullets = rawBullets
              .whereType<Map<String, dynamic>>()
              .map((b) => NoteBullet(
                    term: b['term']?.toString() ?? 'Key Term',
                    definition: b['definition']?.toString() ?? '',
                    iconName: b['icon_name']?.toString() ?? 'psychology',
                  ))
              .toList();
          sections.add(NoteSection(
            title: s['title']?.toString() ?? 'Key Concept Breakdown',
            description: s['description']?.toString() ?? '',
            bullets: bullets,
          ));
        }
      }
    }

    if (sections.isEmpty) {
      final bullets = keyDefs.map((d) {
        return NoteBullet(
          term: d.title,
          definition: d.body,
          iconName: 'psychology',
        );
      }).toList();
      sections = [
        NoteSection(
          title: 'Core Concept Breakdown',
          description: json['summary']?.toString() ?? '',
          bullets: bullets,
        ),
      ];
    }

    final courseName = json['course_name']?.toString() ?? 'General Academic Study';
    final courseCode = json['course_code']?.toString() ?? 'GEN 101';
    final lower = courseName.toLowerCase();
    String category = 'general';
    if (lower.contains('bio') || lower.contains('life') || lower.contains('plant') || lower.contains('cell')) {
      category = 'bio';
    } else if (lower.contains('chem')) {
      category = 'chem';
    } else if (lower.contains('psych') || lower.contains('neuro') || lower.contains('cognit')) {
      category = 'psych';
    } else if (lower.contains('comp') || lower.contains('data') || lower.contains('code') || lower.contains('tech')) {
      category = 'cs';
    } else if (lower.contains('econ') || lower.contains('financ') || lower.contains('market')) {
      category = 'econ';
    }

    return NoteItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Synthesized Notes',
      courseCode: courseCode,
      courseName: courseName,
      category: category,
      summary: json['summary']?.toString() ?? '',
      estimatedTime: json['read_time']?.toString() ?? '5 min read',
      timeAgo: 'Just now',
      accuracyPercent: (json['accuracy_percent'] as num?)?.toInt() ?? 92,
      keyTermsCount: (json['key_terms_count'] as num?)?.toInt() ?? (keyDefs.isNotEmpty ? keyDefs.length : 4),
      readTime: json['read_time']?.toString() ?? '5 min read',
      sections: sections,
      keyDefinitions: keyDefs,
      examPitfalls: pitfalls,
      definitions: defs.isNotEmpty ? defs : ['Key concept definitions synthesized from document.'],
      examPitfall: pitfallText,
      rawTranscript: json['raw_transcript']?.toString() ?? '',
      isBookmarked: false,
    );
  }

  NoteItem copyWith({
    String? id,
    String? title,
    String? courseCode,
    String? courseName,
    String? category,
    String? summary,
    String? estimatedTime,
    String? timeAgo,
    int? accuracyPercent,
    int? keyTermsCount,
    String? readTime,
    List<NoteSection>? sections,
    List<KeyDefinitionItem>? keyDefinitions,
    List<ExamPitfallItem>? examPitfalls,
    List<String>? definitions,
    String? examPitfall,
    String? rawTranscript,
    bool? isBookmarked,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      timeAgo: timeAgo ?? this.timeAgo,
      accuracyPercent: accuracyPercent ?? this.accuracyPercent,
      keyTermsCount: keyTermsCount ?? this.keyTermsCount,
      readTime: readTime ?? this.readTime,
      sections: sections ?? this.sections,
      keyDefinitions: keyDefinitions ?? this.keyDefinitions,
      examPitfalls: examPitfalls ?? this.examPitfalls,
      definitions: definitions ?? this.definitions,
      examPitfall: examPitfall ?? this.examPitfall,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory NoteItem.synthesizedFromDocument({
    required String id,
    required String title,
    required String subject,
    required String text,
    List<String> topics = const [],
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return NoteItem(
      id: id,
      title: title,
      courseCode: subject.isNotEmpty ? subject.split(' ').first.toUpperCase() : 'STUDY',
      courseName: subject.isNotEmpty ? subject : 'General Academic Study',
      category: 'general',
      summary: 'Document containing $words words extracted via OCR.',
      estimatedTime: '4 min read',
      timeAgo: 'Just now',
      accuracyPercent: 95,
      keyTermsCount: topics.length,
      readTime: '4 min read',
      sections: [
        NoteSection(
          title: 'Document Topics',
          description: 'Key topics identified from material',
          bullets: topics
              .map((t) => NoteBullet(
                  term: t,
                  definition: 'Core extracted topic',
                  iconName: 'bookmark'))
              .toList(),
        ),
      ],
      keyDefinitions: topics
          .map((t) => KeyDefinitionItem(
              title: t,
              tag: 'Topic',
              body: 'Core concept identified in document.'))
          .toList(),
      examPitfalls: const [],
      definitions: topics.map((t) => '$t: Core topic from document.').toList(),
      examPitfall: 'Carefully review core concepts and definitions.',
      rawTranscript: text,
      isBookmarked: false,
    );
  }
}
