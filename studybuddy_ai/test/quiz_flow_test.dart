import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/models/quiz_question.dart';
import 'package:studybuddy_ai/screens/quiz_screen.dart';
import 'package:studybuddy_ai/screens/quiz_results_screen.dart';

List<QuizQuestion> _mockQuestions() {
  return [
    const QuizQuestion(
      id: 1,
      concept: 'Neural Plasticity',
      questionText: 'What is neuroplasticity?',
      aiHint: 'Think brain adaptation.',
      options: [
        QuizOption(label: 'A', text: 'Brain adaptability over time', subtitle: 'Structural changes'),
        QuizOption(label: 'B', text: 'Fixed neuron count', subtitle: 'Static wiring'),
      ],
      correctOptionIndex: 0,
      explanation: 'Neuroplasticity allows neural pathways to change with experience.',
      topicBadge: 'Neuroscience',
    ),
    const QuizQuestion(
      id: 2,
      concept: 'Working Memory',
      questionText: 'What is the average capacity of working memory?',
      aiHint: 'Miller\'s law',
      options: [
        QuizOption(label: 'A', text: '7 ± 2 items', subtitle: 'Classic Miller limit'),
        QuizOption(label: 'B', text: 'Unlimited items', subtitle: 'No constraints'),
      ],
      correctOptionIndex: 0,
      explanation: 'Miller found human working memory holds roughly 7 items.',
      topicBadge: 'Cognition',
    ),
  ];
}

void main() {
  group('Quiz Screen and Navigation Tests', () {
    testWidgets('Quiz screen displays questions and options properly', (tester) async {
      final questions = _mockQuestions();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizScreen(
            questions: questions,
            quizTitle: 'Biology 101 Quiz',
            onReturnHome: () {},
            onReturnNotes: () {},
          ),
        ),
      );

      // Verify question content is displayed
      expect(find.text('What is neuroplasticity?'), findsOneWidget);
      expect(find.text('Brain adaptability over time'), findsOneWidget);
      expect(find.text('Biology 101 Quiz'), findsOneWidget);

      // Verify quit dialog opens when close icon is tapped
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Exit Quiz?'), findsOneWidget);
      expect(find.text('Resume Quiz'), findsOneWidget);
      expect(find.text('Go to Home'), findsOneWidget);
      expect(find.text('Exit to Notes'), findsOneWidget);

      // Resume quiz dismisses the dialog
      await tester.tap(find.text('Resume Quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Exit Quiz?'), findsNothing);
      expect(find.text('What is neuroplasticity?'), findsOneWidget);
    });

    testWidgets('Quit dialog navigation routes to Home properly', (tester) async {
      final questions = _mockQuestions();
      bool homeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: QuizScreen(
            questions: questions,
            quizTitle: 'Biology 101 Quiz',
            onReturnHome: () => homeCalled = true,
          ),
        ),
      );

      // Open quit prompt
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Go to Home
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(homeCalled, isTrue);
    });

    testWidgets('Quiz results screen review & retake flow', (tester) async {
      final questions = _mockQuestions();
      bool retakeTriggered = false;
      bool notesTriggered = false;
      bool homeTriggered = false;

      final summary = QuizResultSummary(
        questions: questions,
        userAnswers: const {0: 0, 1: 0},
        timeTaken: const Duration(seconds: 45),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuizResultsScreen(
            summary: summary,
            quizTitle: 'Cognitive Science Quiz',
            onRetake: () => retakeTriggered = true,
            onBackToNotes: () => notesTriggered = true,
            onReturnHome: () => homeTriggered = true,
          ),
        ),
      );

      // Verify dynamic title & score
      expect(find.text('Cognitive Science Quiz'), findsOneWidget);
      expect(find.text('2 of 2 correct'), findsOneWidget);
      expect(find.text('100%'), findsAtLeast(1));

      // Verify review items exist
      expect(find.text('Cognition'), findsAtLeast(1));
      expect(find.text('What is neuroplasticity?'), findsOneWidget);

      // Verify action buttons in bottom sticky bar
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Short Notes'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      // Tap retake
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();
      expect(retakeTriggered, isTrue);

      // Tap Short Notes
      await tester.tap(find.text('Short Notes'));
      await tester.pumpAndSettle();
      expect(notesTriggered, isTrue);

      // Tap Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(homeTriggered, isTrue);
    });

    testWidgets('Responsive rendering on narrow 360dp screen width', (tester) async {
      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final questions = _mockQuestions();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizScreen(
            questions: questions,
            quizTitle: 'Responsive Narrow Screen Quiz',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(caughtDetails, isNull);
    });
  });
}
