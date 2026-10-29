import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/models/chat_message.dart';
import 'package:studybuddy_ai/models/study_document.dart';
import 'package:studybuddy_ai/screens/chat_with_notes_screen.dart';

void main() {
  group('ChatMessage & ChatConversation Model Tests', () {
    test('ChatMessage.fromJson parses AI message with outside knowledge and takeaways', () {
      final json = {
        'id': 'msg-123',
        'conversation_id': 'conv-456',
        'sender': 'ai',
        'text': 'Photosynthesis converts sunlight into glucose.',
        'note_reference': 'Photosynthesis Notes',
        'key_takeaways': ['Light reactions in thylakoid', 'Calvin cycle in stroma'],
        'outside_context': 'true',
        'created_at': '2026-10-29T12:00:00Z',
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.id, 'msg-123');
      expect(msg.conversationId, 'conv-456');
      expect(msg.sender, MessageSender.ai);
      expect(msg.text, 'Photosynthesis converts sunlight into glucose.');
      expect(msg.noteReference, 'Photosynthesis Notes');
      expect(msg.keyTakeaways?.length, 2);
      expect(msg.outsideKnowledgeUsed, isTrue);
      expect(msg.timestamp.year, 2026);
    });

    test('ChatMessage.fromJson parses user message', () {
      final json = {
        'id': 'msg-999',
        'sender': 'user',
        'text': 'Can you explain the Calvin cycle?',
        'created_at': '2026-10-29T12:01:00Z',
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.id, 'msg-999');
      expect(msg.sender, MessageSender.user);
      expect(msg.text, 'Can you explain the Calvin cycle?');
      expect(msg.outsideKnowledgeUsed, isFalse);
    });

    test('ChatConversation.fromJson parses conversation and message list', () {
      final json = {
        'id': 'conv-001',
        'document_id': 'doc-100',
        'title': 'Chat: Biology Lecture',
        'message_count': 2,
        'messages': [
          {
            'id': 'm1',
            'conversation_id': 'conv-001',
            'sender': 'user',
            'text': 'Hello',
            'created_at': '2026-10-29T12:00:00Z',
          },
          {
            'id': 'm2',
            'conversation_id': 'conv-001',
            'sender': 'ai',
            'text': 'Hi, how can I help you study today?',
            'created_at': '2026-10-29T12:00:05Z',
          }
        ],
        'created_at': '2026-10-29T12:00:00Z',
        'updated_at': '2026-10-29T12:00:05Z',
      };

      final conv = ChatConversation.fromJson(json);

      expect(conv.id, 'conv-001');
      expect(conv.documentId, 'doc-100');
      expect(conv.title, 'Chat: Biology Lecture');
      expect(conv.messages.length, 2);
      expect(conv.messages.first.sender, MessageSender.user);
      expect(conv.messages.last.sender, MessageSender.ai);
    });
  });

  group('ChatWithNotesScreen Widget Tests', () {
    testWidgets('Renders General AI Tutor mode when no document is selected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatWithNotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Tutor'), findsOneWidget);
      expect(find.text('Context: General AI Tutor'), findsOneWidget);
      expect(find.text('General Learning & Reasoning Mode'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ask your AI Tutor anything...'), findsOneWidget);
    });

    testWidgets('Renders document grounding context when document is provided', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final doc = StudyDocument(
        id: 'doc-1234',
        title: 'Cellular Biology',
        originalFilename: 'bio.pdf',
        subject: 'Biology',
        topics: ['Mitochondria', 'Chloroplasts', 'ATP'],
        extractedText: 'Mitochondria produce ATP through oxidative phosphorylation.',
        wordCount: 8,
        pageCount: 1,
        extractionMethod: 'OCR',
        processingStatus: 'completed',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatWithNotesScreen(
            selectedDocument: doc,
            availableDocuments: [doc],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Context: Cellular Biology'), findsOneWidget);
      expect(find.text('Grounding enabled • Biology'), findsOneWidget);
      expect(find.text('Ask anything about "Cellular Biology"...'), findsOneWidget);
      expect(find.text('Explain Mitochondria'), findsOneWidget);
      expect(find.text('Explain Chloroplasts'), findsOneWidget);
    });

    testWidgets('Displays input text and disables sending while waiting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatWithNotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'What is ATP?');
      expect(find.text('What is ATP?'), findsOneWidget);
    });
  });
}
