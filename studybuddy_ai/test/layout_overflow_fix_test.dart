import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studybuddy_ai/models/study_document.dart';
import 'package:studybuddy_ai/screens/chat_with_notes_screen.dart';
import 'package:studybuddy_ai/screens/flashcards_screen.dart';
import 'package:studybuddy_ai/screens/scan_import_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Layout Overflow Fix Tests — Narrow Screen Viewports', () {
    testWidgets('FlashcardsScreen header and "+ New Deck" button fit without 33px overflow on 360x640 viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashcardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflow exceptions were thrown
      expect(tester.takeException(), isNull);

      // Verify Header components are present
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Active recall powered by spaced repetition'), findsOneWidget);
      expect(find.text('New Deck'), findsOneWidget);

      // Verify "+ New Deck" button is entirely inside the 360px viewport
      final newDeckRect = tester.getRect(find.widgetWithText(ElevatedButton, 'New Deck'));
      expect(newDeckRect.left, greaterThan(0.0));
      expect(newDeckRect.right, lessThanOrEqualTo(360.0));
    });

    testWidgets('FlashcardsScreen header fits on ultra-narrow 320x640 screen without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashcardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('New Deck'), findsOneWidget);

      final newDeckRect = tester.getRect(find.widgetWithText(ElevatedButton, 'New Deck'));
      expect(newDeckRect.right, lessThanOrEqualTo(320.0));
    });

    testWidgets('ScanImportScreen shutter controls and ribbon header fit without overflow on 360x640 viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Ensure no RenderFlex overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify 'Captured Pages' is fully visible and not squeezed
      expect(find.text('Captured Pages'), findsOneWidget);
      expect(find.text('0 Pages'), findsOneWidget);

      // Verify 'Extracted Text' label is present and not cut off
      expect(find.text('Extracted Text'), findsOneWidget);

      // Verify gallery picker icon is present and within viewport
      final galleryIcon = find.widgetWithIcon(IconButton, Icons.photo_library_rounded);
      expect(galleryIcon, findsOneWidget);
      final galleryRect = tester.getRect(galleryIcon);
      expect(galleryRect.left, greaterThanOrEqualTo(0.0));
      expect(galleryRect.right, lessThan(360.0));
    });

    testWidgets('ScanImportScreen with imported photos renders shutter row and "Scan & Process" without overflow on 360x640', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final samplePages = [
        ScannedPageItem(
          id: 'page_test_1',
          name: 'photo_1.jpg',
          bytes: Uint8List.fromList([0, 1, 2, 3]),
          extractedText: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanImportScreen(
              initialMode: 'camera',
              initialPages: samplePages,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure NO RenderFlex overflow exception
      expect(tester.takeException(), isNull);

      // Verify status badge shows "1 Ready" and "Captured Pages" is completely visible
      expect(find.text('Captured Pages'), findsOneWidget);
      expect(find.text('1 Ready'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Verify "Scan & Process (1)" button exists and fits within 360px without overflowing
      final scanBtn = find.widgetWithText(ElevatedButton, 'Scan & Process (1)');
      expect(scanBtn, findsOneWidget);
      final scanBtnRect = tester.getRect(scanBtn);
      expect(scanBtnRect.left, greaterThan(0.0));
      expect(scanBtnRect.right, lessThanOrEqualTo(360.0));
    });

    testWidgets('ScanImportScreen with multiple photos on 320x640 ultra-narrow screen does not overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final samplePages = [
        ScannedPageItem(
          id: 'page_1',
          name: 'photo_1.jpg',
          bytes: Uint8List.fromList([0, 1]),
          extractedText: '',
        ),
        ScannedPageItem(
          id: 'page_2',
          name: 'photo_2.jpg',
          bytes: Uint8List.fromList([2, 3]),
          extractedText: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanImportScreen(
              initialMode: 'camera',
              initialPages: samplePages,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no overflow on 320px
      expect(tester.takeException(), isNull);
      expect(find.text('Captured Pages'), findsOneWidget);
      expect(find.text('2 Ready'), findsOneWidget);

      final scanBtn = find.byType(ElevatedButton);
      expect(scanBtn, findsWidgets);
    });

    testWidgets('ChatWithNotesScreen message bubbles and note chips fit without overflow on 360x640 screen with long titles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longDoc = StudyDocument(
        id: 'doc-long',
        title: 'Mechanical Properties of Solids and Elasticity',
        originalFilename: 'physics_solids.pdf',
        subject: 'Physics',
        topics: ['Elasticity', 'Hookes Law', 'Stress and Strain'],
        extractedText: 'Mechanical properties of solids and elasticity concepts...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatWithNotesScreen(
              selectedDocument: longDoc,
              availableDocuments: [longDoc],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ZERO RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify title badge rendered and constrained inside viewport
      expect(find.text('AI Tutor'), findsOneWidget);
      expect(find.text('Context: Mechanical Properties of Solids and Elasticity'), findsOneWidget);

      final chipFinder = find.textContaining('Mechanical Properties of Solids');
      expect(chipFinder, findsWidgets);
    });
  });
}
