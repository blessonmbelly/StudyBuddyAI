import 'note.dart';
import 'quiz_question.dart';

class StudyDocument {
  final String id;
  String title;
  final String originalFilename;
  String subject;
  List<String> topics;
  String extractedText;
  int wordCount;
  String extractionMethod;
  String processingStatus; // 'completed', 'fallback', 'edited'
  final int pageCount;
  final DateTime createdAt;
  NoteItem? generatedNote;
  List<QuizQuestion>? generatedQuiz;

  StudyDocument({
    required this.id,
    required this.title,
    required this.originalFilename,
    required this.subject,
    required this.topics,
    required this.extractedText,
    this.wordCount = 0,
    this.extractionMethod = 'OCR',
    this.processingStatus = 'completed',
    this.pageCount = 1,
    DateTime? createdAt,
    this.generatedNote,
    this.generatedQuiz,
  }) : createdAt = createdAt ?? DateTime.now();

  StudyDocument copyWith({
    String? id,
    String? title,
    String? originalFilename,
    String? subject,
    List<String>? topics,
    String? extractedText,
    int? wordCount,
    String? extractionMethod,
    String? processingStatus,
    int? pageCount,
    DateTime? createdAt,
    NoteItem? generatedNote,
    List<QuizQuestion>? generatedQuiz,
  }) {
    return StudyDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      originalFilename: originalFilename ?? this.originalFilename,
      subject: subject ?? this.subject,
      topics: topics ?? List.from(this.topics),
      extractedText: extractedText ?? this.extractedText,
      wordCount: wordCount ?? this.wordCount,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      processingStatus: processingStatus ?? this.processingStatus,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      generatedNote: generatedNote ?? this.generatedNote,
      generatedQuiz: generatedQuiz ?? this.generatedQuiz,
    );
  }

  factory StudyDocument.fromJson(Map<String, dynamic> json) {
    return StudyDocument(
      id: json['id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Untitled Document',
      originalFilename: json['original_filename']?.toString() ?? 'document',
      subject: json['subject']?.toString() ??
          json['detected_subject']?.toString() ??
          'Unknown',
      topics: (json['topics'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      extractedText: json['extracted_text']?.toString() ?? '',
      wordCount: json['word_count'] is int
          ? json['word_count'] as int
          : int.tryParse(json['word_count']?.toString() ?? '0') ?? 0,
      extractionMethod: json['extraction_method']?.toString() ?? 'OCR',
      processingStatus: json['processing_status']?.toString() ?? 'completed',
      pageCount: json['page_count'] is int
          ? json['page_count'] as int
          : int.tryParse(json['page_count']?.toString() ?? '1') ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      generatedNote: json['generated_note'] != null
          ? NoteItem.fromJson(json['generated_note'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_filename': originalFilename,
      'subject': subject,
      'topics': topics,
      'extracted_text': extractedText,
      'word_count': wordCount,
      'page_count': pageCount,
      'extraction_method': extractionMethod,
      'processing_status': processingStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
