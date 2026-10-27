import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/quiz_question.dart';
import '../widgets/metric_ring.dart';
import '../widgets/gradient_button.dart';

class QuizResultsScreen extends StatefulWidget {
  final QuizResultSummary summary;
  final VoidCallback onRetake;
  final VoidCallback onBackToNotes;

  const QuizResultsScreen({
    super.key,
    required this.summary,
    required this.onRetake,
    required this.onBackToNotes,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  String _filter = 'all'; // 'all', 'incorrect', 'bookmarked'
  final Set<int> _bookmarkedQuestions = {2}; // default bookmark on question 3

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final total = summary.questions.length;
    final correct = summary.correctCount;
    final percentage = summary.percentage;

    final incorrectCount = total - correct;

    final filteredList = <MapEntry<int, QuizQuestion>>[];
    for (int i = 0; i < summary.questions.length; i++) {
      final q = summary.questions[i];
      final isCorrect = summary.userAnswers[i] == q.correctOptionIndex;
      final isBookmarked = _bookmarkedQuestions.contains(i);

      if (_filter == 'incorrect' && isCorrect) continue;
      if (_filter == 'bookmarked' && !isBookmarked) continue;

      filteredList.add(MapEntry(i, q));
    }

    final minutes = summary.timeTaken.inMinutes;
    final seconds = summary.timeTaken.inSeconds % 60;
    final timeString = '${minutes}m ${seconds}s';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSummaryCard(percentage, correct, total, timeString),
                    const SizedBox(height: 20),
                    _buildBreakdownHeader(total),
                    const SizedBox(height: 10),
                    _buildFilterPills(total, incorrectCount),
                    const SizedBox(height: 14),
                    ...filteredList.map((entry) {
                      final idx = entry.key;
                      final q = entry.value;
                      final userAnswerIdx = summary.userAnswers[idx];
                      final isCorrect = userAnswerIdx == q.correctOptionIndex;
                      final isBookmarked = _bookmarkedQuestions.contains(idx);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildQuestionReviewCard(
                          questionIndex: idx,
                          question: q,
                          userAnswerIndex: userAnswerIdx,
                          isCorrect: isCorrect,
                          isBookmarked: isBookmarked,
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _buildRecommendedDeckCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildStickyActionsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBackToNotes,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quiz Results',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: widget.onBackToNotes,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(
      int percentage, int correct, int total, String timeString) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'Cognitive Psychology • Quiz 04',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Large Score Ring
          MetricRing(
            progress: percentage / 100.0,
            size: 120,
            strokeWidth: 10,
            progressColor: AppColors.primaryContainer,
            trackColor: AppColors.surfaceContainer,
            centerChild: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '$correct of $total correct',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            percentage >= 70 ? 'Great job, Alex! 🎉' : 'Keep practicing, Alex! 💪',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            percentage >= 70
                ? "You've mastered core memory systems and sensory recall with high accuracy!"
                : 'Review hippocampal consolidation and amnesia systems before your next session.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Bento stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildBentoStat(Icons.timer_rounded, 'Time', timeString,
                    AppColors.secondary),
                Container(
                    height: 28, width: 1, color: AppColors.surfaceContainerHigh),
                _buildBentoStat(Icons.verified_rounded, 'Accuracy',
                    '$percentage%', AppColors.emerald),
                Container(
                    height: 28, width: 1, color: AppColors.surfaceContainerHigh),
                _buildBentoStat(Icons.bolt_rounded, 'Bonus',
                    '+${percentage * 1} XP', AppColors.primaryContainer),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Companion note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StudyBuddy AI Insight',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Procedural vs Episodic distinction is your main review priority before tomorrow.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStat(
      IconData icon, String label, String value, Color iconColor) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownHeader(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question Breakdown',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review answers, explanations, and flagged concepts',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$total Items',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPills(int total, int incorrectCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('all', 'All ($total)'),
          const SizedBox(width: 6),
          _buildFilterChip('incorrect', 'Incorrect ($incorrectCount)',
              badgeColor: AppColors.crimson),
          const SizedBox(width: 6),
          _buildFilterChip('bookmarked', 'Bookmarked (${_bookmarkedQuestions.length})',
              icon: Icons.bookmark_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label,
      {Color? badgeColor, IconData? icon}) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
            if (badgeColor != null) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionReviewCard({
    required int questionIndex,
    required QuizQuestion question,
    required int? userAnswerIndex,
    required bool isCorrect,
    required bool isBookmarked,
  }) {
    final correctOpt = question.options[question.correctOptionIndex];
    final userOpt = userAnswerIndex != null
        ? question.options[userAnswerIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.tertiaryFixed
                            : AppColors.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${questionIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCorrect
                                ? AppColors.onTertiaryFixed
                                : AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.topicBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.tertiaryFixed
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 14,
                      color: isCorrect
                          ? AppColors.onTertiaryFixed
                          : AppColors.onErrorContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCorrect ? 'Correct' : 'Incorrect',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCorrect
                            ? AppColors.onTertiaryFixed
                            : AppColors.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          // Answer comparison
          if (isCorrect) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('Your Choice: ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      userOpt?.text ?? 'None',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.crimsonBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('Your Answer: ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      '${userOpt?.text ?? 'Unanswered'} ✕',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('Correct Answer: ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      '${correctOpt.text} ✓',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Explanation
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_rounded,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Deep Dive Explanation',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  question.explanation,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed_rounded,
                      size: 14, color: AppColors.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${question.averageTime} answered',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isBookmarked) {
                      _bookmarkedQuestions.remove(questionIndex);
                    } else {
                      _bookmarkedQuestions.add(questionIndex);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 16,
                      color: isBookmarked
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBookmarked ? 'Saved' : 'Save',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isBookmarked
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedDeckCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Practice Deck',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Explicit vs. Implicit Drills',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  '8 flashcards • 4 min quick session',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: widget.onRetake,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerLowest,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Start', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onRetake,
                    icon: const Icon(Icons.cached_rounded, size: 16),
                    label: const Text('Retake Quiz',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientButton(
                    height: 48,
                    onPressed: widget.onBackToNotes,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Back to Notes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quiz result link copied for your study group!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 14),
              label: const Text(
                'Share Quiz Results with Study Group',
                style: TextStyle(fontSize: 11),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
