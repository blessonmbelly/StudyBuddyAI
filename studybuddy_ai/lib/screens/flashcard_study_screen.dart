import 'dart:math';
import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/metric_ring.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardDeck deck;
  final VoidCallback? onDeckUpdated;

  const FlashcardStudyScreen({
    super.key,
    required this.deck,
    this.onDeckUpdated,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  late List<FlashcardModel> _cards;
  int _currentIndex = 0;
  bool _showHint = false;

  // 3D Flip animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Session tracking
  final Map<String, String> _sessionAnswers = {}; // cardId -> 'known' | 'learning'
  final Stopwatch _sessionTimer = Stopwatch();
  bool _isSessionFinished = false;
  bool _isSavingReview = false;

  @override
  void initState() {
    super.initState();
    _cards = List<FlashcardModel>.from(widget.deck.cards);
    _sessionTimer.start();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer.stop();
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _goToCard(int newIndex) {
    if (newIndex < 0 || newIndex >= _cards.length) return;
    if (_flipController.value != 0) {
      _flipController.reset();
    }
    setState(() {
      _currentIndex = newIndex;
      _showHint = false;
    });
  }

  Future<void> _markCurrentCard(String status) async {
    if (_cards.isEmpty) return;
    final currentCard = _cards[_currentIndex];

    // Optimistic local update
    setState(() {
      _sessionAnswers[currentCard.id] = status;
      _cards[_currentIndex] = currentCard.copyWith(status: status);
    });

    // Persist to backend asynchronously
    try {
      await ApiService.updateCardStatus(
        cardId: currentCard.id,
        status: status,
      );
      widget.onDeckUpdated?.call();
    } catch (e) {
      debugPrint('Card status update notice: $e');
    }

    // Auto advance
    if (_currentIndex < _cards.length - 1) {
      _goToCard(_currentIndex + 1);
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    _sessionTimer.stop();
    setState(() {
      _isSessionFinished = true;
    });
    _persistReviewSession();
  }

  Future<void> _persistReviewSession() async {
    if (_sessionAnswers.isEmpty) return;
    setState(() {
      _isSavingReview = true;
    });

    final knownCount = _sessionAnswers.values.where((s) => s == 'known').length;
    final learningCount = _sessionAnswers.values.where((s) => s == 'learning').length;
    final duration = _sessionTimer.elapsed.inSeconds.clamp(1, 86400);

    final updates = _sessionAnswers.entries
        .map((e) => {'card_id': e.key, 'status': e.value})
        .toList();

    try {
      await ApiService.recordFlashcardReview(
        deckId: widget.deck.id,
        cardsReviewed: _sessionAnswers.length,
        knownCount: knownCount,
        reviewAgainCount: learningCount,
        durationSeconds: duration,
        cardUpdates: updates,
      );
      widget.onDeckUpdated?.call();
    } catch (e) {
      debugPrint('Failed to save review session: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingReview = false;
        });
      }
    }
  }

  void _restartSession() {
    _sessionTimer.reset();
    _sessionTimer.start();
    _flipController.reset();
    setState(() {
      _currentIndex = 0;
      _showHint = false;
      _sessionAnswers.clear();
      _isSessionFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.deck.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.style_outlined, size: 64, color: AppColors.outline),
                const SizedBox(height: 16),
                const Text(
                  'No Cards in this Deck',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This deck currently has no cards to review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Decks'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isSessionFinished) {
      return _buildCompletionScreen();
    }

    final currentCard = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            _buildHeader(progress),

            // Card Body (Flippable)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * pi;
                      final isFront = angle <= (pi / 2);

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle),
                        child: isFront
                            ? _buildCardFront(currentCard)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _buildCardBack(currentCard),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Flip Indicator Pill
            _buildFlipPrompt(),

            // Bottom Action Controls (Know it / Review again / Prev / Next)
            _buildBottomControls(currentCard),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Exit Session',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.deck.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Card ${_currentIndex + 1} of ${_cards.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: AppColors.onSurfaceVariant),
                onPressed: _finishSession,
                tooltip: 'End & Save Session',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerLow,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(FlashcardModel card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceContainerHigh, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Top Tags
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.deck.subject.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimaryFixed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildCardStatusBadge(card.status),
            ],
          ),
          const Spacer(),

          // Prompt / Question
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    card.front,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Hint Section (if present)
          if (card.hint != null && card.hint!.isNotEmpty) ...[
            if (_showHint)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: AppColors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.hint!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showHint = true;
                    });
                  },
                  icon: const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: AppColors.amber),
                  label: const Text(
                    'Need a hint?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCardBack(FlashcardModel card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.emerald.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 12, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'ANSWER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCardStatusBadge(card.status),
            ],
          ),
          const Spacer(),

          // Answer Text
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.back,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Note indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync_rounded,
                    size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                const Text(
                  'Tap card to flip back to question',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStatusBadge(String status) {
    if (status == 'known') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.emeraldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: AppColors.emerald),
            SizedBox(width: 3),
            Text(
              'Known',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'learning') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.crimsonBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.refresh_rounded, size: 12, color: AppColors.crimson),
            SizedBox(width: 3),
            Text(
              'Learning',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.crimson,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Unreviewed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFlipPrompt() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _flipCard,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceContainerHigh),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flip_rounded, size: 15, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Tap to flip card',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(FlashcardModel currentCard) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Know it vs Review again Action Buttons
          Row(
            children: [
              // Review Again Button
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _markCurrentCard('learning'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Review again',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.crimson,
                      side: const BorderSide(color: AppColors.crimson, width: 1.5),
                      backgroundColor: AppColors.crimsonBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Know it Button
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _markCurrentCard('known'),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Know it!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Previous / Next Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentIndex > 0 ? () => _goToCard(_currentIndex - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${_currentIndex + 1} / ${_cards.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                onPressed: _currentIndex < _cards.length - 1
                    ? () => _goToCard(_currentIndex + 1)
                    : _finishSession,
                label: Text(
                  _currentIndex < _cards.length - 1 ? 'Next' : 'Finish',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final knownCount = _sessionAnswers.values.where((s) => s == 'known').length;
    final learningCount = _sessionAnswers.values.where((s) => s == 'learning').length;
    final total = _cards.length;
    final percent = total > 0 ? (knownCount / total) : 0.0;
    final percentInt = (percent * 100).round();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Celebration Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Session Complete! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Great job practicing active recall for "${widget.deck.title}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // Metric Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
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
                    children: [
                      MetricRing(
                        progress: percent,
                        size: 88,
                        strokeWidth: 8,
                        progressColor: AppColors.emerald,
                        trackColor: AppColors.surfaceContainerLow,
                        centerChild: Text(
                          '$percentInt%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$knownCount of $total Cards Mastered',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.surfaceContainerHigh),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Know it', '$knownCount', AppColors.emerald),
                          _buildStatItem('Review again', '$learningCount', AppColors.crimson),
                          _buildStatItem('Time', '${_sessionTimer.elapsed.inSeconds}s', AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_isSavingReview)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Saving mastery to cloud...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Action Buttons
                GradientButton(
                  height: 50,
                  onPressed: _restartSession,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Review Deck Again',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back to Decks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

