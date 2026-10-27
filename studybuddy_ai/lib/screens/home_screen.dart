import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../data/sample_notes.dart';
import '../widgets/metric_ring.dart';

class HomeScreen extends StatefulWidget {
  final Function(int targetTab, {String? scanMode}) onNavigateTab;
  final Function(NoteItem note) onOpenNote;
  final VoidCallback onStartQuiz;
  final VoidCallback onOpenChat;
  final List<NoteItem>? notes;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    required this.onOpenNote,
    required this.onStartQuiz,
    required this.onOpenChat,
    this.notes,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final allNotes = widget.notes ?? sampleStudyNotes;
    final filteredNotes = _selectedCategory == 'all'
        ? allNotes
        : allNotes
            .where((n) => n.category == _selectedCategory)
            .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Main Content Body
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeGreeting(),
                  const SizedBox(height: 16),
                  _buildHabitTrackerCard(),
                  const SizedBox(height: 20),
                  _buildSmartImportSection(),
                  const SizedBox(height: 20),
                  _buildCourseFilterChips(),
                  const SizedBox(height: 16),
                  _buildRecentMaterialsHeader(filteredNotes.length),
                  const SizedBox(height: 12),
                  if (_selectedCategory == 'bio')
                    _buildBiologyEmptyState()
                  else
                    ...filteredNotes.map((note) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildMaterialCard(note),
                        )),
                  const SizedBox(height: 16),
                  _buildFloatingAiBuddyBanner(),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'StudyBuddy AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: const Row(
              children: [
                Text('🔥', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  '6 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // User Avatar
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryFixed,
            child: const Text(
              'A',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimaryFixed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Good morning, Alex 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 2),
                  Text(
                    'Pro AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Ready to ace Cognitive Psychology today?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHabitTrackerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.emerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'DAILY HABIT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emerald,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '3 of 4 tasks completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '1 more session to secure today\'s 7-day streak milestone!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const MetricRing(
                progress: 0.75,
                size: 56,
                strokeWidth: 5,
                progressColor: AppColors.primaryContainer,
                trackColor: AppColors.surfaceContainerLow,
                centerChild: Text(
                  '75%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 4 Micro checkpoints
          Row(
            children: [
              _buildTaskCheckpoint('Flashcards', true),
              const SizedBox(width: 6),
              _buildTaskCheckpoint('Recap Quiz', true),
              const SizedBox(width: 6),
              _buildTaskCheckpoint('Audio Note', true),
              const SizedBox(width: 6),
              _buildTaskCheckpoint('Practice Test', false, isNext: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCheckpoint(String title, bool isDone, {bool isNext = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isNext
              ? AppColors.primaryFixed.withValues(alpha: 0.45)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: isNext
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: isDone
                  ? AppColors.emerald
                  : (isNext ? AppColors.primary : AppColors.outline),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: isNext ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartImportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Smart Import',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Powered by Vision OCR',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildImportActionCard(
          icon: Icons.document_scanner_rounded,
          iconBg: AppColors.primaryFixed,
          iconColor: AppColors.onPrimaryFixed,
          title: 'Scan Notes',
          subtitle: 'Instant OCR & summarization',
          onTap: () => widget.onNavigateTab(1, scanMode: 'camera'),
        ),
        const SizedBox(height: 8),
        _buildImportActionCard(
          icon: Icons.cloud_upload_rounded,
          iconBg: AppColors.secondaryFixed,
          iconColor: AppColors.onSecondaryFixedVariant,
          title: 'Upload File',
          subtitle: 'Lecture slides & syllabus (PDF, DOCX)',
          onTap: () => widget.onNavigateTab(1, scanMode: 'upload'),
        ),
        const SizedBox(height: 8),
        _buildImportActionCard(
          icon: Icons.content_paste_rounded,
          iconBg: AppColors.surfaceContainerHigh,
          iconColor: AppColors.primary,
          title: 'Paste Text',
          subtitle: 'Articles, transcripts & raw lectures',
          onTap: () => widget.onNavigateTab(1, scanMode: 'paste'),
        ),
      ],
    );
  }

  Widget _buildImportActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceContainerHigh),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseFilterChips() {
    final chips = [
      {'key': 'all', 'label': 'All Courses'},
      {'key': 'psych', 'label': 'Psychology 201'},
      {'key': 'chem', 'label': 'Chem 302'},
      {'key': 'econ', 'label': 'Econ 101'},
      {'key': 'bio', 'label': 'Biology'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chips.map((c) {
          final isSelected = _selectedCategory == c['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = c['key']!;
                });
              },
              backgroundColor: AppColors.surfaceContainerLowest,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainerHigh,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentMaterialsHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Recent Study Materials',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count Active',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimaryFixed,
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => widget.onNavigateTab(2),
          child: const Text(
            'View all',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialCard(NoteItem note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: note.category == 'psych'
                          ? AppColors.secondaryFixed
                          : (note.category == 'chem'
                              ? AppColors.surfaceContainerHighest
                              : AppColors.surfaceContainerHigh),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      note.courseName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: note.category == 'psych'
                            ? AppColors.onSecondaryFixedVariant
                            : AppColors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    note.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  note.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: note.isBookmarked
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    note.isBookmarked = !note.isBookmarked;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.summary,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${note.accuracyPercent}% recall',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.style_rounded,
                      size: 15,
                      color: AppColors.outline,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${note.keyTermsCount} terms',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (note.category == 'chem') {
                    widget.onStartQuiz();
                  } else {
                    widget.onOpenNote(note);
                  }
                },
                icon: Icon(
                  note.category == 'chem'
                      ? Icons.play_arrow_rounded
                      : Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: Text(
                  note.category == 'chem' ? 'Quiz me' : 'Study',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.5),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBiologyEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.biotech_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No study sets in "Biology"',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to snap a photo of your bio lab notes or import chapter slides.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => widget.onNavigateTab(1, scanMode: 'camera'),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              'Create Biology Set',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAiBuddyBanner() {
    return InkWell(
      onTap: widget.onOpenChat,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask StudyBuddy AI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '"Quiz me on memory retrieval cues"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
