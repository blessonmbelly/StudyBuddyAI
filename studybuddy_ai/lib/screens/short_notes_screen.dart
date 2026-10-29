import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../models/quiz_question.dart';
import '../services/api_service.dart';
import '../widgets/gradient_button.dart';

class ShortNotesScreen extends StatefulWidget {
  final NoteItem? note;
  final void Function([List<QuizQuestion>? questions, String? quizTitle]) onStartQuiz;
  final void Function(NoteItem note) onChatWithNote;
  final void Function(NoteItem note)? onStudyFlashcards;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToScan;

  const ShortNotesScreen({
    super.key,
    this.note,
    required this.onStartQuiz,
    required this.onChatWithNote,
    this.onStudyFlashcards,
    this.onBack,
    this.onNavigateToScan,
  });

  @override
  State<ShortNotesScreen> createState() => _ShortNotesScreenState();
}

class _ShortNotesScreenState extends State<ShortNotesScreen> {
  NoteItem? _note;
  bool _isTranscriptExpanded = false;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  @override
  void didUpdateWidget(covariant ShortNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != _note) {
      setState(() {
        _note = widget.note;
      });
    }
  }

  Future<void> _generateAndStartQuiz() async {
    if (_note == null) return;
    setState(() => _isGeneratingQuiz = true);
    try {
      final text = _note!.rawTranscript.isNotEmpty
          ? _note!.rawTranscript
          : '${_note!.title}\n${_note!.summary}\n${_note!.definitions.join("\n")}';

      final questions = await ApiService.generateQuiz(
        text: text,
        numQuestions: 5,
        noteTitle: _note!.title,
      );

      setState(() => _isGeneratingQuiz = false);
      widget.onStartQuiz(questions, _note!.title);
    } catch (e) {
      setState(() => _isGeneratingQuiz = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quiz notice: ${e.toString().replaceAll("Exception: ", "")}. Starting quiz mode.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onStartQuiz(null, _note!.title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_note != null) _buildAuxiliaryContextBar(),
            Expanded(
              child: _note == null
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDigestBanner(),
                          const SizedBox(height: 12),
                          _buildMetaPillsRow(),
                          const SizedBox(height: 16),
                          _buildSummarySection(),
                          const SizedBox(height: 16),
                          ..._buildDynamicSections(),
                          _buildKeyDefinitionsSection(),
                          const SizedBox(height: 16),
                          _buildExamPitfallsSection(),
                          const SizedBox(height: 16),
                          _buildRawTranscriptCollapsible(),
                          const SizedBox(height: 16),
                          _buildRetentionFeedbackCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
            if (_note != null) _buildStickyBottomDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Study Deck Selected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Synthesize structured study notes with headings, key definitions, and exam pitfalls dynamically from your lecture slides, textbook photos, or pasted text.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              height: 48,
              onPressed: widget.onNavigateToScan,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Scan or Import Study Material',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
        children: [
          if (widget.onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: Colors.white, size: 18),
            ),
          const SizedBox(width: 10),
          const Text(
            'Deck Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          if (_note != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _note!.courseCode,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimaryFixed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuxiliaryContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'AI SYNTHESIS VERIFIED',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _note!.isBookmarked = !_note!.isBookmarked;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _note!.isBookmarked
                            ? 'Bookmarked for quick review'
                            : 'Bookmark removed',
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _note!.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: _note!.isBookmarked
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigestBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _note!.courseCode,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimaryFixed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _note!.courseName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _note!.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPillsRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildPill(Icons.bolt_rounded, 'AI Condensed • ${_note!.readTime}',
            AppColors.primaryFixed, AppColors.onPrimaryFixed),
        _buildPill(Icons.school_rounded, _note!.courseCode,
            AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
        _buildPill(Icons.check_circle_outline_rounded, '${_note!.accuracyPercent}% Density',
            AppColors.emeraldBg, AppColors.emerald),
        _buildPill(Icons.format_list_bulleted_rounded, '${_note!.keyTermsCount} Key Terms',
            AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
      ],
    );
  }

  Widget _buildPill(
      IconData icon, String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Executive Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _note!.summary,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicSections() {
    final widgets = <Widget>[];
    for (int i = 0; i < _note!.sections.length; i++) {
      final section = _note!.sections[i];
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceContainerHigh),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              if (section.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  section.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              if (section.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...section.bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildBulletItem(
                    icon: _getIconForName(b.iconName),
                    term: b.term,
                    desc: b.definition,
                  ),
                )),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildBulletItem({
    required IconData icon,
    required String term,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyDefinitionsSection() {
    if (_note!.keyDefinitions.isEmpty && _note!.definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = _note!.keyDefinitions.isNotEmpty
        ? _note!.keyDefinitions
        : _note!.definitions.map((d) {
            final parts = d.split(':');
            final term = parts.first.trim();
            final body = parts.length > 1 ? parts.sublist(1).join(':').trim() : d;
            return KeyDefinitionItem(title: term, tag: 'Core Concept', body: body);
          }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 14),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Key Definitions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} Terms',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((kd) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDefinitionCard(
              title: kd.title,
              tag: kd.tag,
              body: kd.body,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDefinitionCard({
    required String title,
    required String tag,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamPitfallsSection() {
    final pitfalls = _note!.examPitfalls;
    final hasPitfalls = pitfalls.isNotEmpty || _note!.examPitfall.isNotEmpty;
    if (!hasPitfalls) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.crimson),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Common Exam Pitfalls & Misconceptions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pitfalls.isNotEmpty)
            ...pitfalls.map((ep) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.crimson),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ep.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.crimson,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ep.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurface,
                      height: 1.35,
                    ),
                  ),
                  if (ep.conceptA.isNotEmpty && ep.conceptB.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ep.conceptA,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('vs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.crimson)),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ep.conceptB,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _note!.examPitfall,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurface,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRawTranscriptCollapsible() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isTranscriptExpanded = !_isTranscriptExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Original Extracted Material',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Raw extracted source text processed by AI',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isTranscriptExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isTranscriptExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _note!.rawTranscript.isNotEmpty
                      ? _note!.rawTranscript
                      : 'No source transcript recorded.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.45,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRetentionFeedbackCard() {
    final pct = _note!.accuracyPercent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Synthesis Quality',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$pct% Core Concept Density',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _buildMasteryBar(pct >= 60),
              const SizedBox(width: 4),
              _buildMasteryBar(pct >= 75),
              const SizedBox(width: 4),
              _buildMasteryBar(pct >= 85),
              const SizedBox(width: 4),
              _buildMasteryBar(pct >= 90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryBar(bool isFilled) {
    return Container(
      width: 8,
      height: 24,
      decoration: BoxDecoration(
        color: isFilled ? AppColors.emerald : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStickyBottomDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
        border: const Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientButton(
              height: 50,
              onPressed: _isGeneratingQuiz ? null : _generateAndStartQuiz,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: _isGeneratingQuiz
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.quiz_rounded,
                                  color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isGeneratingQuiz ? 'Generating AI Quiz...' : '✨ Generate AI Quiz',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '5 Qs',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _isGeneratingQuiz ? 'Building questions from note deck' : 'Test your recall in under 2 mins',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_note != null) {
                        widget.onStudyFlashcards?.call(_note!);
                      }
                    },
                    icon: const Icon(Icons.style_rounded, size: 15),
                    label: const Text(
                      'Flashcards',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onChatWithNote(_note!),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                    label: const Text(
                      'Chat AI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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

  IconData _getIconForName(String name) {
    switch (name.toLowerCase()) {
      case 'visibility':
        return Icons.visibility_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'all_inclusive':
        return Icons.all_inclusive_rounded;
      case 'biotech':
      case 'dna':
        return Icons.biotech_rounded;
      case 'code':
      case 'terminal':
        return Icons.code_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'memory':
        return Icons.memory_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }
}
