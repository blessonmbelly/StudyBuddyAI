import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/models/study_document.dart';
import 'package:studybuddy_ai/screens/home_screen.dart';

void main() {
  group('Smart Document Model & Organization Tests', () {
    test('StudyDocument serialization and copyWith works correctly', () {
      final doc = StudyDocument(
        id: 'doc_123',
        title: 'Mitochondrial Respiration and ATP Synthesis',
        originalFilename: 'bio_lecture_ch4.pdf',
        subject: 'Biology',
        topics: const ['Glycolysis', 'Krebs Cycle', 'Electron Transport Chain'],
        extractedText: 'Mitochondria are the powerhouses of the cell producing ATP.',
        wordCount: 8,
        extractionMethod: 'tesseract',
        processingStatus: 'completed',
        createdAt: DateTime(2026, 10, 28),
      );

      final json = doc.toJson();
      expect(json['id'], 'doc_123');
      expect(json['title'], 'Mitochondrial Respiration and ATP Synthesis');
      expect(json['subject'], 'Biology');
      expect(json['topics'], ['Glycolysis', 'Krebs Cycle', 'Electron Transport Chain']);

      final revived = StudyDocument.fromJson(json);
      expect(revived.id, doc.id);
      expect(revived.title, doc.title);
      expect(revived.subject, doc.subject);
      expect(revived.topics, doc.topics);

      // Test copyWith
      final updated = doc.copyWith(
        title: 'Cellular Respiration in Eukaryotes',
        subject: 'Cell Biology',
      );
      expect(updated.id, 'doc_123');
      expect(updated.title, 'Cellular Respiration in Eukaryotes');
      expect(updated.subject, 'Cell Biology');
      expect(updated.extractedText, doc.extractedText);
    });

    testWidgets('HomeScreen renders dynamic documents and subjects, not hardcoded mock courses', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleDocs = [
        StudyDocument(
          id: 'doc_bio_1',
          title: 'Cellular Respiration and ATP Synthase',
          originalFilename: 'mitochondria.pdf',
          subject: 'Biology',
          topics: const ['Krebs Cycle', 'Electron Transport'],
          extractedText: 'Sample biology extracted content.',
          wordCount: 4,
          extractionMethod: 'tesseract',
          createdAt: DateTime.now(),
        ),
        StudyDocument(
          id: 'doc_cs_1',
          title: 'Relational Database Normalization',
          originalFilename: 'db_lecture.docx',
          subject: 'Computer Science',
          topics: const ['1NF', '2NF', '3NF', 'BCNF'],
          extractedText: 'Sample CS database normalization text.',
          wordCount: 5,
          extractionMethod: 'docx',
          createdAt: DateTime.now(),
        ),
        StudyDocument(
          id: 'doc_econ_1',
          title: 'Keynesian Multiplier Effect',
          originalFilename: 'macro_econ_handout.txt',
          subject: 'Economics',
          topics: const ['Marginal Propensity', 'Fiscal Policy'],
          extractedText: 'Sample macroeconomics text.',
          wordCount: 3,
          extractionMethod: 'text',
          createdAt: DateTime.now(),
        ),
      ];

      StudyDocument? selectedDocForNotes;
      StudyDocument? selectedDocForQuiz;
      StudyDocument? editedDoc;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            documents: sampleDocs,
            onNavigateTab: (tab, {scanMode}) {},
            onOpenDocumentNotes: (doc) => selectedDocForNotes = doc,
            onStartDocumentQuiz: (doc) => selectedDocForQuiz = doc,
            onEditDocument: (doc) => editedDoc = doc,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dynamic document titles are rendered
      expect(find.text('Cellular Respiration and ATP Synthase'), findsWidgets);
      expect(find.text('Relational Database Normalization'), findsOneWidget);
      expect(find.text('Keynesian Multiplier Effect'), findsOneWidget);

      // Verify dynamic subject chips exist
      expect(find.text('All Subjects'), findsOneWidget);
      expect(find.text('Biology'), findsWidgets);
      expect(find.text('Computer Science'), findsWidgets);
      expect(find.text('Economics'), findsWidgets);

      // Verify 3 Active materials badge
      expect(find.text('3 Active'), findsOneWidget);

      // Verify topic badges
      expect(find.text('Krebs Cycle'), findsOneWidget);
      expect(find.text('1NF'), findsOneWidget);
      expect(find.text('Fiscal Policy'), findsOneWidget);

      // Tap on Notes for the first document
      final notesButtons = find.text('Notes');
      expect(notesButtons, findsWidgets);
      await tester.tap(notesButtons.first);
      await tester.pumpAndSettle();
      expect(selectedDocForNotes?.id, 'doc_bio_1');

      // Tap on Quiz for the second document
      final quizButtons = find.text('Quiz');
      expect(quizButtons, findsWidgets);
      await tester.tap(quizButtons.at(1));
      await tester.pumpAndSettle();
      expect(selectedDocForQuiz?.id, 'doc_cs_1');

      // Test Edit Document Dialog
      final editButtons = find.byTooltip('Edit Title & Subject');
      expect(editButtons, findsWidgets);
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Document Info'), findsOneWidget);
      expect(find.text('Cellular Respiration and ATP Synthase'), findsWidgets);

      // Change title
      await tester.enterText(
        find.widgetWithText(TextField, 'Cellular Respiration and ATP Synthase'),
        'Advanced Cellular Bioenergetics',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(editedDoc?.title, 'Advanced Cellular Bioenergetics');
    });

    testWidgets('HomeScreen displays clean empty state when no documents uploaded', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            documents: const [],
            onNavigateTab: (tab, {scanMode}) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No study materials imported yet'), findsOneWidget);
      expect(find.text('0 Active'), findsOneWidget);
      expect(find.text('Scan or Import Document'), findsOneWidget);
    });
  });
}
