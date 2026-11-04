import 'package:flutter/material.dart';
import '../models/note_evaluation.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

class NoteQualityScreen extends StatefulWidget {
  final String? documentId;
  final String? documentTitle;
  final String? rawText;
  final String? subject;
  final NoteEvaluation? initialEvaluation;

  const NoteQualityScreen({
    super.key,
    this.documentId,
    this.documentTitle,
    this.rawText,
    this.subject,
    this.initialEvaluation,
  });

  @override
  State<NoteQualityScreen> createState() => _NoteQualityScreenState();
}

class _NoteQualityScreenState extends State<NoteQualityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NoteEvaluation? _evaluation;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedIssueFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialEvaluation != null) {
      _evaluation = widget.initialEvaluation;
    } else {
      _loadOrRunEvaluation();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrRunEvaluation({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      NoteEvaluation? eval;

      // 1. If we have a documentId and not forcing refresh, try loading saved evaluation first
      if (widget.documentId != null && !forceRefresh) {
        try {
          eval = await ApiService.getDocumentEvaluation(widget.documentId!);
        } catch (_) {
          eval = null;
        }
      }

      // 2. If no saved evaluation or force refresh requested:
      if (eval == null) {
        if (widget.documentId != null) {
          eval = await ApiService.evaluateDocument(
            widget.documentId!,
            forceRefresh: forceRefresh,
          );
        } else if (widget.rawText != null && widget.rawText!.trim().length >= 15) {
          eval = await ApiService.evaluateText(
            text: widget.rawText!,
            title: widget.documentTitle,
            subject: widget.subject,
          );
        } else {
          throw Exception(
              'No note text or document available to evaluate. Please provide study content.');
        }
      }

      if (mounted) {
        setState(() {
          _evaluation = eval;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return const Color(0xFF10B981); // Emerald
    if (score >= 70) return const Color(0xFF3B82F6); // Blue
    if (score >= 55) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  Color _getIssueColor(String issueType) {
    switch (issueType.toUpperCase()) {
      case 'INCORRECT':
        return AppColors.crimson;
      case 'MISLEADING':
        return const Color(0xFFEA580C); // Deep Orange
      case 'UNSUPPORTED':
        return const Color(0xFFD97706); // Amber
      case 'OUTDATED':
        return const Color(0xFF7C3AED); // Purple
      default:
        return AppColors.outline;
    }
  }

  Color _getImportanceColor(String importance) {
    switch (importance.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.crimson;
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MODERATE':
        return const Color(0xFF2563EB);
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.documentTitle ?? 'Study Note';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Note Quality Evaluation',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Re-evaluate with Gemini',
              onPressed: () => _loadOrRunEvaluation(forceRefresh: true),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_evaluation == null) {
      return _buildEmptyState();
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverallCard(),
                  const SizedBox(height: 16),
                  _buildThreeScoresSection(),
                  const SizedBox(height: 16),
                  _buildEpistemicCautionBanner(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Flagged Issues (${_evaluation!.flaggedClaims.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.find_in_page_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Missing Topics (${_evaluation!.missingTopics.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Facts & Debates (${_evaluation!.verifiedFacts.length + _evaluation!.uncertainClaims.length})',
                        ),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Recommendations'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlaggedIssuesTab(),
          _buildMissingTopicsTab(),
          _buildFactsAndDebatesTab(),
          _buildRecommendationsTab(),
        ],
      ),
    );
  }

  // --- Header Cards ---

  Widget _buildOverallCard() {
    final eval = _evaluation!;
    final overallColor = _getScoreColor(eval.overallScore);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: overallColor.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    eval.qualityGrade,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: overallColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eval.overallScore}% Overall Quality',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI Fact-Checked & Epistemically Verified',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            eval.summary,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeScoresSection() {
    final eval = _evaluation!;

    return Row(
      children: [
        Expanded(
          child: _buildScoreMeterCard(
            label: 'Relevance',
            score: eval.topicRelevanceScore,
            icon: Icons.track_changes_rounded,
            color: const Color(0xFF6366F1), // Indigo
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildScoreMeterCard(
            label: 'Accuracy',
            score: eval.factualAccuracyScore,
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF0D9488), // Teal
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildScoreMeterCard(
            label: 'Completeness',
            score: eval.contentCompletenessScore,
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF8B5CF6), // Violet
          ),
        ),
      ],
    );
  }

  Widget _buildScoreMeterCard({
    required String label,
    required int score,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpistemicCautionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Grounding Standard: Evaluated against academic textbook consensus. No note is scored 100% without exhaustive formal proof to acknowledge nuanced context.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Flagged Claims ---

  Widget _buildFlaggedIssuesTab() {
    final claims = _evaluation!.flaggedClaims;

    if (claims.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 36,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Problematic Claims Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No incorrect, misleading, or outdated claims were flagged in these notes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _selectedIssueFilter == 'ALL'
        ? claims
        : claims.where((c) => c.issueType == _selectedIssueFilter).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Issue filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All (${claims.length})'),
              _buildFilterChip('INCORRECT', 'Incorrect'),
              _buildFilterChip('MISLEADING', 'Misleading'),
              _buildFilterChip('UNSUPPORTED', 'Unsupported'),
              _buildFilterChip('OUTDATED', 'Outdated'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No "$_selectedIssueFilter" claims detected.',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...filtered.map((c) => _buildClaimCard(c)),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedIssueFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.onSurface,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLow,
        onSelected: (_) {
          setState(() {
            _selectedIssueFilter = filterKey;
          });
        },
      ),
    );
  }

  Widget _buildClaimCard(FlaggedClaim claim) {
    final issueColor = _getIssueColor(claim.issueType);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: issueColor.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header badges: Issue type and Severity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: issueColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  claim.issueType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: issueColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${claim.severity} Severity',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Statement quote
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: issueColor, width: 3.5)),
            ),
            child: Text(
              '"${claim.statement}"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Explanation
          const Text(
            'Why it is flagged:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            claim.explanation,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          // Authoritative Evidence / Source comparison
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // Soft Blue
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reliable Sources & Academic Consensus:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claim.evidence,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Suggested Correction if available
          if (claim.correction != null && claim.correction!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5), // Soft Emerald
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suggested Correction:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim.correction!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF047857),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tab 2: Missing Topics ---

  Widget _buildMissingTopicsTab() {
    final topics = _evaluation!.missingTopics;

    if (topics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'All core foundational topics for this subject appear to be addressed!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final t = topics[index];
        final importanceColor = _getImportanceColor(t.importance);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.topic,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: importanceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.importance,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: importanceColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.explanation,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (t.recommendedOverview != null && t.recommendedOverview!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.recommendedOverview!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- Tab 3: Verified Facts vs. Uncertainties ---

  Widget _buildFactsAndDebatesTab() {
    final facts = _evaluation!.verifiedFacts;
    final uncertain = _evaluation!.uncertainClaims;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Verified Facts
        const Row(
          children: [
            Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text(
              'Verified Accurate Statements',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (facts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No claims explicitly classified as verified.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          )
        else
          ...facts.map(
            (vf) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vf.fact,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (vf.corroboration.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        vf.corroboration,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        // Uncertain / Nuanced Claims
        const Row(
          children: [
            Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text(
              'Uncertain or Context-Dependent Claims',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (uncertain.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No disputed or ambiguous claims identified.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          )
        else
          ...uncertain.map(
            (uc) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uc.claim,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (uc.reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        uc.reason,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Tab 4: Recommendations & Extra Context ---

  Widget _buildRecommendationsTab() {
    final eval = _evaluation!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Actionable Study Recommendations
        if (eval.recommendations.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Actionable Study Recommendations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...eval.recommendations.asMap().entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 18),
        ],

        // Strengths & Weaknesses
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.thumb_up_alt_rounded, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'Strengths',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...eval.strengths.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $s',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 14, color: Color(0xFFEA580C)),
                        SizedBox(width: 6),
                        Text(
                          'Weaknesses',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...eval.weaknesses.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $w',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Additional Context & Modern Applications
        if (eval.additionalContext.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Additional Knowledge & Real-World Context',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...eval.additionalContext.map(
            (ctx) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ctx,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- State Views ---

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Evaluating Note Quality...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gemini is checking topic relevance, verifying claims against academic consensus, and identifying missing core concepts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.crimson),
            const SizedBox(height: 14),
            const Text(
              'Evaluation Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.crimson,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              width: 180,
              height: 46,
              onPressed: () => _loadOrRunEvaluation(forceRefresh: true),
              child: const Text(
                'Retry Evaluation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 54, color: AppColors.primary),
            const SizedBox(height: 14),
            const Text(
              'Evaluate Note Quality',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Analyze this document for topic relevance, factual accuracy, and missing concepts with Gemini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            GradientButton(
              width: 200,
              height: 48,
              onPressed: () => _loadOrRunEvaluation(forceRefresh: true),
              child: const Text(
                'Start Evaluation',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

