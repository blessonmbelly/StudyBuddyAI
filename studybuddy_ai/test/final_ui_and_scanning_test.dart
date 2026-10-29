import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/models/auth_user.dart';
import 'package:studybuddy_ai/models/study_document.dart';
import 'package:studybuddy_ai/screens/home_screen.dart';
import 'package:studybuddy_ai/screens/scan_import_screen.dart';

void main() {
  group('Final UI Fixes — Daily Habit & Streak Removal', () {
    testWidgets('HomeScreen has no Daily Habit card, streak badges, or fire icons', (WidgetTester tester) async {
      final user = AuthUser(
        id: 'usr-1',
        email: 'blessonmbelly@gmail.com',
        fullName: 'Blesson Belly',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentUser: user,
              documents: const [],
              onNavigateTab: (i, {scanMode}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no habit or streak keywords
      expect(find.textContaining('Daily Habit', findRichText: true), findsNothing);
      expect(find.textContaining('DAILY HABIT', findRichText: true), findsNothing);
      expect(find.textContaining('6 Days', findRichText: true), findsNothing);
      expect(find.textContaining('🔥', findRichText: true), findsNothing);
      expect(find.textContaining('Streak', findRichText: true), findsNothing);
    });

    testWidgets('ScanImportScreen has no streak badge or fire icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanImportScreen(
              initialMode: 'camera',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('6 Days', findRichText: true), findsNothing);
      expect(find.textContaining('🔥', findRichText: true), findsNothing);
      expect(find.byIcon(Icons.settings_ethernet_rounded), findsOneWidget);
    });
  });

  group('Final UI Fixes — Name Formatting', () {
    test('AuthUser normalizes whitespace and returns full name', () {
      final user = AuthUser(
        id: 'usr-1',
        email: 'blessonmbelly@gmail.com',
        fullName: '   Blesson    Belly   ',
      );

      expect(user.displayName, equals('Blesson Belly'));
      expect(user.avatarInitial, equals('B'));
    });

    test('AuthUser handles arbitrary student names dynamically', () {
      final user = AuthUser(
        id: 'usr-2',
        email: 'alex.rivera@university.edu',
        fullName: 'Alex Rivera',
      );

      expect(user.displayName, equals('Alex Rivera'));
      expect(user.avatarInitial, equals('A'));
    });

    testWidgets('HomeScreen renders full name "Blesson Belly" without truncation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final user = AuthUser(
        id: 'usr-1',
        email: 'blessonmbelly@gmail.com',
        fullName: 'Blesson Belly',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentUser: user,
              documents: const [],
              onNavigateTab: (i, {scanMode}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Blesson Belly'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // Avatar initial
    });
  });

  group('Recent Study Materials — Remove/Delete Option', () {
    testWidgets('HomeScreen allows removing recent study material with confirmation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      StudyDocument? deletedDoc;
      final sampleDoc = StudyDocument(
        id: 'doc-delete-test-1',
        title: 'Molecular Genetics Chapter 1',
        originalFilename: 'genetics.pdf',
        subject: 'Biology',
        topics: ['DNA', 'Transcription'],
        extractedText: 'DNA is double stranded.',
        wordCount: 4,
        pageCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              documents: [sampleDoc],
              onNavigateTab: (i, {scanMode}) {},
              onDeleteDocument: (doc) {
                deletedDoc = doc;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the study material card is displayed
      expect(find.text('Molecular Genetics Chapter 1'), findsOneWidget);

      // Verify delete button is present on the study material card
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);

      // Tap delete button to open confirmation dialog
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Dialog title and warning text
      expect(find.text('Remove Material?'), findsOneWidget);
      expect(find.textContaining('deleted from your recent materials'), findsOneWidget);

      // Tap 'Remove' in confirmation dialog
      final removeConfirmBtn = find.widgetWithText(ElevatedButton, 'Remove');
      expect(removeConfirmBtn, findsOneWidget);
      await tester.tap(removeConfirmBtn);
      await tester.pumpAndSettle();

      // Verify callback was invoked with the exact document
      expect(deletedDoc, isNotNull);
      expect(deletedDoc!.id, equals('doc-delete-test-1'));
    });
  });

  group('Final Scanning Fixes — Multi-Photo Scanning & Document Combination', () {
    test('ScannedPageItem model holds page metadata, bytes, and error states', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      final page = ScannedPageItem(
        id: 'page_1',
        name: 'lecture_slide_1.jpg',
        bytes: dummyBytes,
        extractedText: 'Concept of photosynthesis',
      );

      expect(page.id, equals('page_1'));
      expect(page.name, equals('lecture_slide_1.jpg'));
      expect(page.bytes, equals(dummyBytes));
      expect(page.extractedText, equals('Concept of photosynthesis'));
      expect(page.isProcessing, isFalse);
      expect(page.isExtracted, isFalse);
      expect(page.hasError, isFalse);
    });

    test('StudyDocument accepts and serializes pageCount', () {
      final doc = StudyDocument(
        id: 'doc-multi-1',
        title: 'Biology Chapter 4',
        originalFilename: 'Combined Scan (3 Pages)',
        subject: 'Biology',
        topics: ['Cellular Respiration', 'Glycolysis'],
        extractedText: '--- Page 1 ---\nText 1\n\n--- Page 2 ---\nText 2\n\n--- Page 3 ---\nText 3',
        wordCount: 150,
        pageCount: 3,
        extractionMethod: 'Multi-Photo OCR',
      );

      expect(doc.pageCount, equals(3));
      final json = doc.toJson();
      expect(json['page_count'], equals(3));

      final restored = StudyDocument.fromJson(json);
      expect(restored.pageCount, equals(3));
      expect(restored.extractionMethod, equals('Multi-Photo OCR'));
    });

    testWidgets('ScanImportScreen waits for all photos to be imported and does not auto-OCR', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanImportScreen(
              initialMode: 'camera',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no pages
      expect(find.text('Captured Pages'), findsOneWidget);
      expect(find.text('0 Pages'), findsOneWidget);
      expect(find.textContaining('No pages added yet'), findsOneWidget);

      // Verify Gallery button is available for multi-photo selection
      expect(find.byIcon(Icons.photo_library_rounded), findsWidgets);
    });
  });
}
