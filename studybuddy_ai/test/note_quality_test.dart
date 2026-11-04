import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/models/note_evaluation.dart';
import 'package:studybuddy_ai/screens/note_quality_screen.dart';

void main() {
  group('NoteEvaluation Model Tests', () {
    test('Correctly deserializes complete evaluation JSON', () {
      final json = {
        'id': 'eval-12345',
        'document_id': 'doc-67890',
        'user_id': 'user-11111',
        'topic_relevance_score': 90,
        'factual_accuracy_score': 85,
        'content_completeness_score': 78,
        'overall_score': 84,
        'quality_grade': 'B+',
        'summary': 'Well-researched notes on Quantum Computing basics.',
        'flagged_claims': [
          {
            'statement': 'Qubits can store infinite classical bits.',
            'issue_type': 'INCORRECT',
            'severity': 'HIGH',
            'explanation': "Holevo's theorem proves a qubit cannot transmit more than one classical bit.",
            'evidence': "Holevo's bound (1973), Nielsen & Chuang Quantum Computation.",
            'correction': 'A qubit exists in superposition but measurement yields only 1 classical bit.',
          }
        ],
        'missing_topics': [
          {
            'topic': 'Quantum Decoherence',
            'importance': 'CRITICAL',
            'explanation': 'Primary obstacle in building physical quantum processors.',
            'recommended_overview': 'Loss of quantum coherence due to environmental noise.',
          }
        ],
        'verified_facts': [
          {
            'fact': 'Quantum superposition allows qubits to represent combinations of |0> and |1>.',
            'corroboration': 'Standard state vector representation in Hilbert space.',
          }
        ],
        'uncertain_claims': [
          {
            'claim': 'Shor algorithm will break RSA within 5 years.',
            'reason': 'Timeline depends on fault-tolerant logical qubit scaling.',
          }
        ],
        'additional_context': ['Quantum supremacy demonstrated by sycamore processor in 2019.'],
        'strengths': ['Solid mathematical foundation.'],
        'weaknesses': ['Omitted error correction.'],
        'recommendations': ['Study surface codes and threshold theorems.'],
        'created_at': '2026-11-04T12:00:00Z',
      };

      final eval = NoteEvaluation.fromJson(json);

      expect(eval.id, 'eval-12345');
      expect(eval.documentId, 'doc-67890');
      expect(eval.topicRelevanceScore, 90);
      expect(eval.factualAccuracyScore, 85);
      expect(eval.contentCompletenessScore, 78);
      expect(eval.overallScore, 84);
      expect(eval.qualityGrade, 'B+');
      expect(eval.flaggedClaims.length, 1);
      expect(eval.flaggedClaims[0].issueType, 'INCORRECT');
      expect(eval.flaggedClaims[0].severity, 'HIGH');
      expect(eval.missingTopics.length, 1);
      expect(eval.missingTopics[0].importance, 'CRITICAL');
      expect(eval.verifiedFacts.length, 1);
      expect(eval.uncertainClaims.length, 1);
      expect(eval.additionalContext.length, 1);
      expect(eval.strengths.length, 1);
      expect(eval.weaknesses.length, 1);
      expect(eval.recommendations.length, 1);
    });

    test('toJson produces valid structure', () {
      const claim = FlaggedClaim(
        statement: 'Wrong fact',
        issueType: 'INCORRECT',
        severity: 'HIGH',
        explanation: 'Contradicted by science',
        evidence: 'Textbook reference',
      );

      final claimJson = claim.toJson();
      expect(claimJson['statement'], 'Wrong fact');
      expect(claimJson['issue_type'], 'INCORRECT');
      expect(claimJson['severity'], 'HIGH');
    });
  });

  group('NoteQualityScreen Widget Tests', () {
    testWidgets('Renders 3 scores, overall grade, and tabs with initial evaluation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testEval = NoteEvaluation(
        id: 'test-eval-1',
        topicRelevanceScore: 92,
        factualAccuracyScore: 88,
        contentCompletenessScore: 75,
        overallScore: 86,
        qualityGrade: 'B+',
        summary: 'Solid foundational study note with rigorous relevance.',
        flaggedClaims: [
          FlaggedClaim(
            statement: 'Electrons orbit the nucleus in rigid planetary circles.',
            issueType: 'MISLEADING',
            severity: 'MEDIUM',
            explanation: 'Bohr model simplification; quantum mechanics uses probability density orbitals.',
            evidence: 'Schrodinger wave equation & Griffiths Quantum Mechanics.',
            correction: 'Electrons occupy three-dimensional probability orbitals.',
          )
        ],
        missingTopics: [
          MissingTopic(
            topic: 'Pauli Exclusion Principle',
            importance: 'HIGH',
            explanation: 'Essential for understanding atomic shell occupancy.',
          )
        ],
        verifiedFacts: [
          VerifiedFact(
            fact: 'Protons and neutrons reside in the nucleus.',
            corroboration: 'Rutherford alpha-scattering experiment (1911).',
          )
        ],
        uncertainClaims: [
          UncertainClaim(
            claim: 'Protons may eventually decay after 10^34 years.',
            reason: 'Grand Unified Theories predict decay, but Super-Kamiokande has not observed it.',
          )
        ],
        recommendations: ['Review orbital hybridization before the exam.'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: NoteQualityScreen(
            documentTitle: 'Atomic Structure Notes',
            initialEvaluation: testEval,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & grade
      expect(find.text('Note Quality Evaluation'), findsOneWidget);
      expect(find.text('Atomic Structure Notes'), findsOneWidget);
      expect(find.text('86% Overall Quality'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);

      // Verify 3 scores
      expect(find.text('Relevance'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('Completeness'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);

      // Verify Epistemic Caution notice
      expect(find.textContaining('Grounding Standard'), findsOneWidget);

      // Verify Flagged Issue card appears in the default tab
      expect(find.text('MISLEADING'), findsOneWidget);
      expect(find.textContaining('Electrons orbit the nucleus'), findsOneWidget);
      expect(find.textContaining('Schrodinger wave equation'), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on narrow 360x640 mobile screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const saltEval = NoteEvaluation(
        id: 'test-salt-eval',
        topicRelevanceScore: 95,
        factualAccuracyScore: 78,
        contentCompletenessScore: 72,
        overallScore: 82,
        qualityGrade: 'B',
        summary: 'The study notes provide a comprehensive and structured overview of salt classification and an introduction to salt hydrolysis, complete with helpful chemical examples. However, there are minor chemical inaccuracies regarding neutralization equations.',
        flaggedClaims: [
          FlaggedClaim(
            statement: 'All salts produce neutral solutions when dissolved in water.',
            issueType: 'INCORRECT',
            severity: 'HIGH',
            explanation: 'Salts formed from weak acids or weak bases undergo hydrolysis.',
            evidence: 'Standard General Chemistry (Zumdahl ch. 14).',
            correction: 'Only salts of strong acid-strong base pairs produce neutral pH 7 solutions.',
          )
        ],
        missingTopics: [],
        verifiedFacts: [],
        uncertainClaims: [],
        recommendations: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: NoteQualityScreen(
            documentTitle: 'Classification and Hydrolysis of Salts',
            initialEvaluation: saltEval,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must not trigger render overflow errors');
      expect(find.text('Classification and Hydrolysis of Salts'), findsOneWidget);
      expect(find.text('82% Overall Quality'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Relevance'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Completeness'), findsOneWidget);
    });
  });
}


