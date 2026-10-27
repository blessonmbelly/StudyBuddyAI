import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../models/quiz_question.dart';
import '../services/api_service.dart';
import '../data/sample_notes.dart';
import '../widgets/gradient_button.dart';

class ShortNotesScreen extends StatefulWidget {
  final NoteItem? note;
  final void Function([List<QuizQuestion>? questions, String? quizTitle]) onStartQuiz;
  final void Function(NoteItem note) onChatWithNote;
  final VoidCallback? onBack;

  const ShortNotesScreen({
    super.key,
    this.note,
    required this.onStartQuiz,
    required this.onChatWithNote,
    this.onBack,
  });

  @override
  State<ShortNotesScreen> createState() => _ShortNotesScreenState();
}

class _ShortNotesScreenState extends State<ShortNotesScreen> {
  late NoteItem _note;
  bool _isTranscriptExpanded = false;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note ?? sampleStudyNotes.first;
  }

  @override
  void didUpdateWidget(covariant ShortNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != null && widget.note != _note) {
      _note = widget.note!;
    }
  }

  Future<void> _generateAndStartQuiz() async {
    setState(() => _isGeneratingQuiz = true);
    try {
      final text = _note.rawTranscript.isNotEmpty
          ? _note.rawTranscript
          : '${_note.title}\n${_note.summary}\n${_note.definitions.join("\n")}';

      final questions = await ApiService.generateQuiz(
        text: text,
        numQuestions: 5,
        noteTitle: _note.title,
      );

      setState(() => _isGeneratingQuiz = false);

      widget.onStartQuiz(questions, _note.title);
    } catch (e) {
      setState(() => _isGeneratingQuiz = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quiz note: ${e.toString().replaceAll("Exception: ", "")}. Starting quiz mode.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onStartQuiz(null, _note.title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildAuxiliaryContextBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDigestBanner(),
                    const SizedBox(height: 12),
                    _buildMetaPillsRow(),
                    const SizedBox(height: 16),
                    _buildDualStoreSection(),
                    const SizedBox(height: 16),
                    _buildKeyDefinitionsSection(),
                    const SizedBox(height: 16),
                    _buildExamPitfallsSection(),
                    const SizedBox(height: 16),
                    _buildRawTranscriptCollapsible(),
                    const SizedBox(height: 16),
                    _buildRetentionFeedbackCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildStickyBottomDock(),
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
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryFixed,
            child: const Text(
              'A',
              style: TextStyle(
                fontSize: 13,
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
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'AI SYNTHESIS VERIFIED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _note.isBookmarked = !_note.isBookmarked;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _note.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: _note.isBookmarked
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note summary link copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCANNED DOCUMENT • OCT 14',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _note.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                const Text(
                  'Synthesized from 14 handwritten slides & audio',
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
    );
  }

  Widget _buildMetaPillsRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildPill(Icons.bolt_rounded, 'AI Condensed • 6 min read',
            AppColors.primaryFixed, AppColors.onPrimaryFixed),
        _buildPill(Icons.school_rounded, _note.courseCode,
            AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
        _buildPill(Icons.document_scanner_rounded, 'Lecture 4 OCR',
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

  Widget _buildDualStoreSection() {
    return Container(
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
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dual-Store Memory Model',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Core Theory',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSecondaryFixedVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Atkinson & Shiffrin's multistore architecture detailing structural memory stages:",
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.visibility_rounded,
            term: 'Sensory Memory',
            desc:
                'Holds raw sensory stimuli for milliseconds (iconic visual & echoic auditory storage).',
          ),
          const SizedBox(height: 8),
          _buildBulletItem(
            icon: Icons.timer_rounded,
            term: 'Short-Term Memory (STM)',
            desc:
                'Limited capacity (7 ± 2 chunks), duration ~20–30s without active rehearsal.',
          ),
          const SizedBox(height: 8),
          _buildBulletItem(
            icon: Icons.all_inclusive_rounded,
            term: 'Long-Term Memory (LTM)',
            desc:
                'Potentially limitless capacity with dense semantic organization and associative indexing.',
          ),
        ],
      ),
    );
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
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
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
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Key Definitions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              const Icon(Icons.psychology_rounded,
                  size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          _buildDefinitionCard(
            title: 'Encoding Specificity',
            tag: 'Tulving (1973)',
            body:
                'Retrieval is most effective when retrieval cues match the exact environmental and cognitive context present during initial encoding.',
          ),
          const SizedBox(height: 8),
          _buildDefinitionCard(
            title: 'Consolidation',
            tag: 'Synaptic & Systems',
            body:
                'The biological process by which fragile, labile memories stabilize and transform into enduring, permanent neural traces within the neocortex.',
          ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.crimson,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Common Exam Pitfalls',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onErrorContainer,
                ),
              ),
              const Spacer(),
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: AppColors.crimson),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.crimson),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Don't confuse Retrograde with Anterograde!",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.crimson,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prof. Vance emphasized this for Midterm 2. Remember:',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
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
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retrograde',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cannot recall memories formed before injury.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anterograde',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cannot form new enduring memories after trauma.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                          'View Original Raw Transcript',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Scanned Lecture Notes & Voice Sync',
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
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _note.rawTranscript,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'View Scanned Notebook (.PDF)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '1.2 MB',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRetentionFeedbackCard() {
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Mastery',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '78% Solid Recall',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildMasteryBar(true),
              const SizedBox(width: 4),
              _buildMasteryBar(true),
              const SizedBox(width: 4),
              _buildMasteryBar(true),
              const SizedBox(width: 4),
              _buildMasteryBar(false),
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
              height: 52,
              onPressed: _isGeneratingQuiz ? null : _generateAndStartQuiz,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
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
                                  color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isGeneratingQuiz ? 'Generating AI Quiz...' : '✨ Generate AI Quiz',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
                                _isGeneratingQuiz ? 'Building dynamic questions from text' : 'Test your recall in under 2 mins',
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
                    onPressed: () => widget.onChatWithNote(_note),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                    label: const Text('Chat with Notes', style: TextStyle(fontSize: 12)),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exporting note to Anki .apkg format...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.style_rounded, size: 15),
                    label: const Text('Export to Anki', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
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
}
