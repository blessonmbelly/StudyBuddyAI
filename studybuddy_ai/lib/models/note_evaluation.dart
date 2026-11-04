import 'package:flutter/foundation.dart';

/// Models an individual claim flagged during fact-checking
@immutable
class FlaggedClaim {
  final String statement;
  final String issueType; // INCORRECT, MISLEADING, UNSUPPORTED, OUTDATED
  final String severity; // HIGH, MEDIUM, LOW
  final String explanation;
  final String evidence;
  final String? correction;

  const FlaggedClaim({
    required this.statement,
    required this.issueType,
    required this.severity,
    required this.explanation,
    required this.evidence,
    this.correction,
  });

  factory FlaggedClaim.fromJson(Map<String, dynamic> json) {
    return FlaggedClaim(
      statement: json['statement']?.toString() ?? '',
      issueType: (json['issue_type']?.toString() ?? 'INCORRECT').toUpperCase(),
      severity: (json['severity']?.toString() ?? 'MEDIUM').toUpperCase(),
      explanation: json['explanation']?.toString() ?? '',
      evidence: json['evidence']?.toString() ?? '',
      correction: json['correction']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'statement': statement,
        'issue_type': issueType,
        'severity': severity,
        'explanation': explanation,
        'evidence': evidence,
        if (correction != null) 'correction': correction,
      };
}

/// Models a foundational topic or concept missing from the notes
@immutable
class MissingTopic {
  final String topic;
  final String importance; // CRITICAL, HIGH, MODERATE
  final String explanation;
  final String? recommendedOverview;

  const MissingTopic({
    required this.topic,
    required this.importance,
    required this.explanation,
    this.recommendedOverview,
  });

  factory MissingTopic.fromJson(Map<String, dynamic> json) {
    return MissingTopic(
      topic: json['topic']?.toString() ?? '',
      importance: (json['importance']?.toString() ?? 'HIGH').toUpperCase(),
      explanation: json['explanation']?.toString() ?? '',
      recommendedOverview: json['recommended_overview']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'importance': importance,
        'explanation': explanation,
        if (recommendedOverview != null) 'recommended_overview': recommendedOverview,
      };
}

/// Models a verified factual statement with corroboration
@immutable
class VerifiedFact {
  final String fact;
  final String corroboration;

  const VerifiedFact({
    required this.fact,
    required this.corroboration,
  });

  factory VerifiedFact.fromJson(Map<String, dynamic> json) {
    return VerifiedFact(
      fact: json['fact']?.toString() ?? '',
      corroboration: json['corroboration']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fact': fact,
        'corroboration': corroboration,
      };
}

/// Models an ambiguous or debated claim
@immutable
class UncertainClaim {
  final String claim;
  final String reason;

  const UncertainClaim({
    required this.claim,
    required this.reason,
  });

  factory UncertainClaim.fromJson(Map<String, dynamic> json) {
    return UncertainClaim(
      claim: json['claim']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'claim': claim,
        'reason': reason,
      };
}

/// Complete Note Quality Evaluation response
@immutable
class NoteEvaluation {
  final String id;
  final String? documentId;
  final String? userId;
  final int topicRelevanceScore; // 0-100
  final int factualAccuracyScore; // 0-100
  final int contentCompletenessScore; // 0-100
  final int overallScore; // 0-100
  final String qualityGrade; // A+, A, B+, B, C, etc.
  final String summary;
  final List<FlaggedClaim> flaggedClaims;
  final List<MissingTopic> missingTopics;
  final List<VerifiedFact> verifiedFacts;
  final List<UncertainClaim> uncertainClaims;
  final List<String> additionalContext;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NoteEvaluation({
    required this.id,
    this.documentId,
    this.userId,
    required this.topicRelevanceScore,
    required this.factualAccuracyScore,
    required this.contentCompletenessScore,
    required this.overallScore,
    required this.qualityGrade,
    required this.summary,
    this.flaggedClaims = const [],
    this.missingTopics = const [],
    this.verifiedFacts = const [],
    this.uncertainClaims = const [],
    this.additionalContext = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.recommendations = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory NoteEvaluation.fromJson(Map<String, dynamic> json) {
    List<FlaggedClaim> parseClaims(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => FlaggedClaim.fromJson(e))
            .toList();
      }
      return const [];
    }

    List<MissingTopic> parseTopics(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => MissingTopic.fromJson(e))
            .toList();
      }
      return const [];
    }

    List<VerifiedFact> parseFacts(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => VerifiedFact.fromJson(e))
            .toList();
      }
      return const [];
    }

    List<UncertainClaim> parseUncertain(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => UncertainClaim.fromJson(e))
            .toList();
      }
      return const [];
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      try {
        return DateTime.parse(raw.toString());
      } catch (_) {
        return null;
      }
    }

    return NoteEvaluation(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString(),
      userId: json['user_id']?.toString(),
      topicRelevanceScore: (json['topic_relevance_score'] as num?)?.toInt() ?? 0,
      factualAccuracyScore: (json['factual_accuracy_score'] as num?)?.toInt() ?? 0,
      contentCompletenessScore: (json['content_completeness_score'] as num?)?.toInt() ?? 0,
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      qualityGrade: json['quality_grade']?.toString() ?? 'N/A',
      summary: json['summary']?.toString() ?? '',
      flaggedClaims: parseClaims(json['flagged_claims']),
      missingTopics: parseTopics(json['missing_topics']),
      verifiedFacts: parseFacts(json['verified_facts']),
      uncertainClaims: parseUncertain(json['uncertain_claims']),
      additionalContext: parseStringList(json['additional_context']),
      strengths: parseStringList(json['strengths']),
      weaknesses: parseStringList(json['weaknesses']),
      recommendations: parseStringList(json['recommendations']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (documentId != null) 'document_id': documentId,
        if (userId != null) 'user_id': userId,
        'topic_relevance_score': topicRelevanceScore,
        'factual_accuracy_score': factualAccuracyScore,
        'content_completeness_score': contentCompletenessScore,
        'overall_score': overallScore,
        'quality_grade': qualityGrade,
        'summary': summary,
        'flagged_claims': flaggedClaims.map((c) => c.toJson()).toList(),
        'missing_topics': missingTopics.map((t) => t.toJson()).toList(),
        'verified_facts': verifiedFacts.map((f) => f.toJson()).toList(),
        'uncertain_claims': uncertainClaims.map((u) => u.toJson()).toList(),
        'additional_context': additionalContext,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'recommendations': recommendations,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

