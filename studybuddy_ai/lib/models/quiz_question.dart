class QuizOption {
  final String label; // "A", "B", "C", "D"
  final String text;
  final String subtitle;

  const QuizOption({
    required this.label,
    required this.text,
    required this.subtitle,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      label: json['label'] ?? 'A',
      text: json['text'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
}

class QuizQuestion {
  final int id;
  final String concept;
  final String questionText;
  final String aiHint;
  final List<QuizOption> options;
  final int correctOptionIndex;
  final String explanation;
  final String topicBadge;
  final String averageTime;

  const QuizQuestion({
    required this.id,
    required this.concept,
    required this.questionText,
    required this.aiHint,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.topicBadge,
    this.averageTime = '30s',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List<dynamic>? ?? [])
        .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
        .toList();

    return QuizQuestion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 1,
      concept: json['concept'] ?? 'Concept Recall',
      questionText: json['question_text'] ?? '',
      aiHint: json['ai_hint'] ?? 'Review the core note concepts.',
      options: rawOptions,
      correctOptionIndex: json['correct_option_index'] is int ? json['correct_option_index'] : 0,
      explanation: json['explanation'] ?? '',
      topicBadge: json['topic_badge'] ?? 'Concept Recall',
      averageTime: json['average_time'] ?? '30s',
    );
  }
}

class QuizResultSummary {
  final List<QuizQuestion> questions;
  final Map<int, int> userAnswers; // questionIndex -> selectedOptionIndex
  final Duration timeTaken;

  const QuizResultSummary({
    required this.questions,
    required this.userAnswers,
    required this.timeTaken,
  });

  int get correctCount {
    int count = 0;
    for (int i = 0; i < questions.length; i++) {
      if (userAnswers[i] == questions[i].correctOptionIndex) {
        count++;
      }
    }
    return count;
  }

  int get percentage {
    if (questions.isEmpty) return 0;
    return ((correctCount / questions.length) * 100).round();
  }
}
