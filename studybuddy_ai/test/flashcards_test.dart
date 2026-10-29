import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studybuddy_ai/models/flashcard.dart';
import 'package:studybuddy_ai/screens/flashcard_study_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('FlashcardModel & FlashcardDeck Unit Tests', () {
    test('FlashcardModel JSON serialization and deserialization', () {
      final json = {
        'id': 'card-1234',
        'front': 'What is the function of Mitochondria?',
        'back': 'Mitochondria generate ATP through oxidative phosphorylation.',
        'hint': 'Powerhouse of the cell',
        'order_index': 0,
        'status': 'known',
        'review_count': 3,
        'last_reviewed_at': '2026-10-28T22:30:00.000Z',
      };

      final card = FlashcardModel.fromJson(json);

      expect(card.id, 'card-1234');
      expect(card.front, 'What is the function of Mitochondria?');
      expect(card.back, 'Mitochondria generate ATP through oxidative phosphorylation.');
      expect(card.hint, 'Powerhouse of the cell');
      expect(card.status, 'known');
      expect(card.isKnown, isTrue);
      expect(card.isLearning, isFalse);
      expect(card.isUnreviewed, isFalse);
      expect(card.reviewCount, 3);
      expect(card.lastReviewedAt, isNotNull);

      final encoded = card.toJson();
      expect(encoded['id'], 'card-1234');
      expect(encoded['front'], 'What is the function of Mitochondria?');
      expect(encoded['status'], 'known');
    });

    test('FlashcardDeck JSON serialization and mastery calculation', () {
      final json = {
        'id': 'deck-5678',
        'title': 'Cellular Respiration & Bioenergetics',
        'subject': 'Biology',
        'description': 'Active recall cards for Chapter 4.',
        'card_count': 4,
        'mastered_count': 3,
        'document_id': 'doc-1111',
        'note_id': 'note-2222',
        'created_at': '2026-10-28T21:00:00.000Z',
        'cards': [
          {
            'id': 'c-1',
            'front': 'What is ATP?',
            'back': 'Adenosine Triphosphate, energy currency of the cell.',
            'status': 'known',
          },
          {
            'id': 'c-2',
            'front': 'What is Glycolysis?',
            'back': 'Anaerobic breakdown of glucose into pyruvate.',
            'status': 'known',
          },
          {
            'id': 'c-3',
            'front': 'What is the Krebs Cycle?',
            'back': 'Series of chemical reactions generating NADH and FADH2.',
            'status': 'known',
          },
          {
            'id': 'c-4',
            'front': 'What is Chemiosmosis?',
            'back': 'Movement of ions across a semipermeable membrane down electrochemical gradient.',
            'status': 'learning',
          },
        ],
      };

      final deck = FlashcardDeck.fromJson(json);

      expect(deck.id, 'deck-5678');
      expect(deck.title, 'Cellular Respiration & Bioenergetics');
      expect(deck.subject, 'Biology');
      expect(deck.cardCount, 4);
      expect(deck.masteredCount, 3);
      expect(deck.cards.length, 4);
      expect(deck.documentId, 'doc-1111');
      expect(deck.noteId, 'note-2222');

      // Mastery calculations
      expect(deck.masteryPercent, 0.75);
      expect(deck.masteryPercentageInt, 75);

      // Edge case: 0 cards
      final emptyDeck = FlashcardDeck(id: '0', title: 'Empty', subject: 'None');
      expect(emptyDeck.masteryPercent, 0.0);
      expect(emptyDeck.masteryPercentageInt, 0);
    });
  });

  group('FlashcardStudyScreen Widget Tests', () {
    testWidgets('Renders deck title, prompt, flips card and navigates to completion', (tester) async {
      final sampleDeck = FlashcardDeck(
        id: 'test-deck-1',
        title: 'Photosynthesis Fundamentals',
        subject: 'Biology',
        cardCount: 2,
        masteredCount: 0,
        cards: [
          FlashcardModel(
            id: 'card-1',
            front: 'Where do light-dependent reactions take place?',
            back: 'In the thylakoid membranes of chloroplasts.',
            hint: 'Contains thylakoids',
            orderIndex: 0,
          ),
          FlashcardModel(
            id: 'card-2',
            front: 'What is the primary photosynthetic pigment?',
            back: 'Chlorophyll a.',
            hint: 'Absorbs blue and red light',
            orderIndex: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FlashcardStudyScreen(deck: sampleDeck),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Header and Card 1 Front
      expect(find.text('Photosynthesis Fundamentals'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(find.text('Where do light-dependent reactions take place?'), findsOneWidget);
      expect(find.text('Need a hint?'), findsOneWidget);

      // 2. Test Hint reveal
      await tester.tap(find.text('Need a hint?'));
      await tester.pumpAndSettle();
      expect(find.text('Contains thylakoids'), findsOneWidget);

      // 3. Test Tap to Flip
      await tester.tap(find.text('Tap to flip card'));
      await tester.pumpAndSettle();

      // 4. Verify Answer on Back
      expect(find.text('In the thylakoid membranes of chloroplasts.'), findsOneWidget);
      expect(find.text('ANSWER'), findsOneWidget);

      // 5. Test "Know it!" action on Card 1
      await tester.tap(find.text('Know it!'));
      await tester.pumpAndSettle();

      // 6. Should advance to Card 2
      expect(find.text('Card 2 of 2'), findsOneWidget);
      expect(find.text('What is the primary photosynthetic pigment?'), findsOneWidget);

      // 7. Test "Review again" action on Card 2
      await tester.tap(find.text('Review again'));
      await tester.pumpAndSettle();

      // 8. Reaches Completion Screen
      expect(find.text('Session Complete! 🎉'), findsOneWidget);
      expect(find.text('1 of 2 Cards Mastered'), findsOneWidget);
      expect(find.text('Review Deck Again'), findsOneWidget);
      expect(find.text('Back to Decks'), findsOneWidget);
    });
  });
}

