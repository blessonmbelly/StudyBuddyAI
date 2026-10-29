import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studybuddy_ai/models/note.dart';
import 'package:studybuddy_ai/models/study_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('StudyDocument Model & Persistence Serialization Tests', () {
    test('Correctly deserializes DocumentResponse from PostgreSQL backend', () {
      final json = {
        'id': 'a8105b41-26c7-43cf-8d96-e24c29753e1a',
        'title': 'Molecular Biology: Transcription and Translation',
        'original_filename': 'molbio_ch3.pdf',
        'file_type': 'PDF',
        'subject': 'Biology',
        'topics': ['RNA Polymerase', 'Ribosomes', 'tRNA', 'Codons'],
        'extracted_text': 'Transcription begins when RNA polymerase binds to promoter sequence.',
        'word_count': 10,
        'page_count': 3,
        'extraction_method': 'pdf_embedded_text',
        'processing_status': 'completed',
        'created_at': '2026-10-28T23:45:00Z',
        'generated_note': {
          'id': 'b9216c52-37d8-54df-9e07-f35d3a864f2b',
          'title': 'Molecular Biology Core Notes',
          'course_name': 'Biology 101',
          'course_code': 'BIO 101',
          'summary': 'Summary of transcription and translation.',
          'sections': [],
          'key_definitions': [],
          'exam_pitfalls': [],
          'raw_transcript': '',
          'accuracy_percent': 95,
          'key_terms_count': 8,
          'read_time': '4 min read',
        },
      };

      final doc = StudyDocument.fromJson(json);

      expect(doc.id, 'a8105b41-26c7-43cf-8d96-e24c29753e1a');
      expect(doc.title, 'Molecular Biology: Transcription and Translation');
      expect(doc.subject, 'Biology');
      expect(doc.topics, contains('RNA Polymerase'));
      expect(doc.wordCount, 10);
      expect(doc.extractionMethod, 'pdf_embedded_text');
      expect(doc.generatedNote, isNotNull);
      expect(doc.generatedNote!.id, 'b9216c52-37d8-54df-9e07-f35d3a864f2b');
      expect(doc.generatedNote!.courseName, 'Biology 101');
    });

    test('toJson serializes all fields required for PostgreSQL persistence', () {
      final doc = StudyDocument(
        id: 'c1234567-89ab-cdef-0123-456789abcdef',
        title: 'Algorithms: Dynamic Programming',
        originalFilename: 'lecture5.docx',
        subject: 'Computer Science',
        topics: ['Memoization', 'Tabulation', 'Knapsack Problem'],
        extractedText: 'Dynamic programming solves complex problems by breaking them into simpler subproblems.',
        wordCount: 12,
        extractionMethod: 'docx_parser',
        processingStatus: 'completed',
      );

      final json = doc.toJson();

      expect(json['id'], 'c1234567-89ab-cdef-0123-456789abcdef');
      expect(json['title'], 'Algorithms: Dynamic Programming');
      expect(json['subject'], 'Computer Science');
      expect(json['topics'], contains('Memoization'));
      expect(json['word_count'], 12);
      expect(json['extraction_method'], 'docx_parser');
    });

    test('copyWith preserves properties and updates title and subject', () {
      final doc = StudyDocument(
        id: '1',
        title: 'Original Title',
        originalFilename: 'notes.txt',
        subject: 'General',
        topics: ['Tag1'],
        extractedText: 'Sample text',
      );

      final updated = doc.copyWith(
        title: 'New Edited Title',
        subject: 'Physics',
      );

      expect(updated.id, '1');
      expect(updated.title, 'New Edited Title');
      expect(updated.subject, 'Physics');
      expect(updated.originalFilename, 'notes.txt');
    });
  });

  group('NoteItem Serialization Tests', () {
    test('Correctly deserializes persisted note from PostgreSQL', () {
      final json = {
        'id': 'note-uuid-1234',
        'title': 'Quantum Mechanics Summary',
        'course_name': 'Modern Physics',
        'course_code': 'PHYS 301',
        'summary': 'Core equations and wave particle duality.',
        'sections': [
          {
            'title': 'Wave Functions',
            'description': 'Description of Schrodinger equation',
            'bullets': [
              {
                'term': 'Psi',
                'definition': 'Wave function probability amplitude',
                'icon_name': 'science'
              }
            ]
          }
        ],
        'key_definitions': [
          {
            'title': 'Superposition',
            'tag': 'Principle',
            'body': 'Linear combination of states',
          }
        ],
        'exam_pitfalls': [
          {
            'title': 'Uncertainty Principle',
            'description': 'Cannot measure position and momentum simultaneously',
            'concept_a': 'Delta x',
            'concept_b': 'Delta p',
          }
        ],
        'raw_transcript': '',
        'accuracy_percent': 92,
        'key_terms_count': 6,
        'read_time': '6 min read',
      };

      final note = NoteItem.fromJson(json);

      expect(note.id, 'note-uuid-1234');
      expect(note.title, 'Quantum Mechanics Summary');
      expect(note.courseName, 'Modern Physics');
      expect(note.courseCode, 'PHYS 301');
      expect(note.accuracyPercent, 92);
      expect(note.sections.length, 1);
      expect(note.sections.first.bullets.first.term, 'Psi');
      expect(note.keyDefinitions.first.title, 'Superposition');
    });
  });
}

