import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/quiz_question.dart';
import '../data/sample_quiz.dart';
import 'quiz_results_screen.dart';

class QuizScreen extends StatefulWidget {
  final List<QuizQuestion>? questions;
  final String? quizTitle;
  final VoidCallback? onQuit;

  const QuizScreen({
    super.key,
    this.questions,
    this.quizTitle,
    this.onQuit,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions;
  int _currentIndex = 0;
  final Map<int, int> _userAnswers = {}; // questionIndex -> selectedOptionIndex

  late Timer _timer;
  late int _initialSeconds;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _questions = (widget.questions != null && widget.questions!.isNotEmpty)
        ? widget.questions!
        : sampleMemoryQuiz;
    _initialSeconds = _questions.length * 50; // 50s per question
    _secondsLeft = _initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer.cancel();
        _submitQuiz();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectOption(int optionIndex) {
    setState(() {
      _userAnswers[_currentIndex] = optionIndex;
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  void _submitQuiz() {
    _timer.cancel();
    final summary = QuizResultSummary(
      questions: _questions,
      userAnswers: _userAnswers,
      timeTaken: Duration(seconds: _initialSeconds - _secondsLeft),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultsScreen(
          summary: summary,
          onRetake: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  questions: widget.questions,
                  quizTitle: widget.quizTitle,
                ),
              ),
            );
          },
          onBackToNotes: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentIndex];
    final selectedOption = _userAnswers[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final unansweredCount = _questions.length - _userAnswers.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildProgressBar(progress),
            _buildQuickNavigator(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionCard(currentQ),
                    const SizedBox(height: 16),
                    _buildOptionsList(currentQ, selectedOption),
                    const SizedBox(height: 16),
                    _buildVisualAnchorCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomControls(unansweredCount),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    if (widget.onQuit != null) {
                      widget.onQuit!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STUDYBUDDY QUIZ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        widget.quizTitle ?? 'PSYC 201 Practice Quiz',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).round()}% Complete',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_questions.length, (index) {
              final isFilled = index <= _currentIndex;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                      right: index < _questions.length - 1 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? AppColors.primary
                        : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(_questions.length, (index) {
          final isCurrent = index == _currentIndex;
          final isAnswered = _userAnswers.containsKey(index);

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                margin: EdgeInsets.only(
                    right: index < _questions.length - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary
                      : (isAnswered
                          ? AppColors.surfaceContainerHigh
                          : AppColors.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCurrent
                            ? Colors.white
                            : (isAnswered
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (isAnswered && !isCurrent) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: AppColors.emerald),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Concept: ${q.concept}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.bookmark_border_rounded,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q.questionText,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // AI Cue Pill
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                      children: [
                        const TextSpan(
                          text: 'AI Cue: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: q.aiHint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(QuizQuestion q, int? selectedOption) {
    return Column(
      children: List.generate(q.options.length, (index) {
        final opt = q.options[index];
        final isSelected = selectedOption == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _selectOption(index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.surfaceContainerHigh
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainerHigh,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white)
                          : Text(
                              opt.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.8)
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVisualAnchorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medial Temporal Anatomy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'High-yield visual diagram for neural pathways and synaptic plasticity.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Diagram zoom preview'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(int unansweredCount) {
    final isLastQuestion = _currentIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unansweredCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.crimson),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$unansweredCount unanswered question${unansweredCount > 1 ? 's' : ''} remaining',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _currentIndex > 0 ? _goToPrevious : null,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _goToNext,
                    icon: Icon(
                      isLastQuestion
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      isLastQuestion ? 'Finish Quiz' : 'Next Question',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
