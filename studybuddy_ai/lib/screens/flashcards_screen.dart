import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../models/note.dart';
import '../models/study_document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/metric_ring.dart';
import 'flashcard_study_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  final List<StudyDocument> availableDocuments;
  final List<NoteItem> availableNotes;
  final Function(FlashcardDeck deck)? onStudyDeck;

  const FlashcardsScreen({
    super.key,
    this.availableDocuments = const [],
    this.availableNotes = const [],
    this.onStudyDeck,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<FlashcardDeck> _decks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedSubjectFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final decks = await ApiService.fetchFlashcardDecks();
      if (mounted) {
        setState(() {
          _decks = decks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.cleanErrorMessage(e, 'Flashcard decks');
          _isLoading = false;
        });
      }
    }
  }

  void _openStudyScreen(FlashcardDeck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardStudyScreen(
          deck: deck,
          onDeckUpdated: _loadDecks,
        ),
      ),
    ).then((_) => _loadDecks());
  }

  Future<void> _showCreateDeckDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final textController = TextEditingController();
    int numCards = 6;
    String sourceMode = widget.availableDocuments.isNotEmpty ? 'document' : 'custom';
    StudyDocument? selectedDoc = widget.availableDocuments.isNotEmpty
        ? widget.availableDocuments.first
        : null;

    if (selectedDoc != null) {
      titleController.text = '${selectedDoc.title} Flashcards';
      subjectController.text = selectedDoc.subject;
      textController.text = selectedDoc.extractedText;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final isSubmitting = ValueNotifier<bool>(false);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Generate AI Flashcards',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Source Mode Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (widget.availableDocuments.isNotEmpty)
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    sourceMode = 'document';
                                    if (selectedDoc != null) {
                                      titleController.text =
                                          '${selectedDoc!.title} Flashcards';
                                      subjectController.text =
                                          selectedDoc!.subject;
                                      textController.text =
                                          selectedDoc!.extractedText;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sourceMode == 'document'
                                        ? AppColors.surfaceContainerLowest
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: sourceMode == 'document'
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'From Document',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sourceMode == 'document'
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  sourceMode = 'custom';
                                  textController.clear();
                                  titleController.clear();
                                  subjectController.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: sourceMode == 'custom'
                                      ? AppColors.surfaceContainerLowest
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: sourceMode == 'custom'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Custom Text',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sourceMode == 'custom'
                                        ? AppColors.primary
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Document Selector (if mode is document)
                    if (sourceMode == 'document' && widget.availableDocuments.isNotEmpty) ...[
                      const Text(
                        'Select Document',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<StudyDocument>(
                        initialValue: selectedDoc,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
                          ),
                        ),
                        items: widget.availableDocuments.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(
                              '${d.title} (${d.subject})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (doc) {
                          if (doc != null) {
                            setModalState(() {
                              selectedDoc = doc;
                              titleController.text = '${doc.title} Flashcards';
                              subjectController.text = doc.subject;
                              textController.text = doc.extractedText;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Deck Title
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Deck Title',
                        hintText: 'e.g. Mitochondria & Cellular Respiration',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Enter a deck title' : null,
                    ),
                    const SizedBox(height: 12),

                    // Subject
                    TextFormField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Biology, CS, History',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Source Text Input (editable or visible)
                    TextFormField(
                      controller: textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Source Study Material',
                        hintText: 'Paste study material or notes to generate cards from...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Study text cannot be empty';
                        }
                        if (val.trim().length < 15) {
                          return 'Please provide at least 15 characters of study text';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Number of cards selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Number of Cards:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '$numCards Cards',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: numCards.toDouble(),
                      min: 3,
                      max: 15,
                      divisions: 12,
                      label: '$numCards',
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          numCards = val.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Submit Button with Progress
                    ValueListenableBuilder<bool>(
                      valueListenable: isSubmitting,
                      builder: (context, submitting, child) {
                        return GradientButton(
                          height: 50,
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  isSubmitting.value = true;

                                  try {
                                    final newDeck = await ApiService.generateFlashcards(
                                      text: textController.text.trim(),
                                      deckTitle: titleController.text.trim(),
                                      subject: subjectController.text.trim().isNotEmpty
                                          ? subjectController.text.trim()
                                          : 'General',
                                      numCards: numCards,
                                      documentId: selectedDoc?.id.contains('-') == true
                                          ? selectedDoc!.id
                                          : null,
                                    );

                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(ctx);
                                    _loadDecks();
                                    _openStudyScreen(newDeck);
                                  } catch (e) {
                                    isSubmitting.value = false;
                                    if (!sheetContext.mounted) return;
                                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ApiService.cleanErrorMessage(
                                              e, 'Flashcard generation'),
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (submitting) ...[
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Gemini AI is creating cards...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ] else ...[
                                const Icon(Icons.bolt_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Generate Deck',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddCardDialog(FlashcardDeck deck) async {
    final formKey = GlobalKey<FormState>();
    final frontController = TextEditingController();
    final backController = TextEditingController();
    final hintController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Add Custom Card', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: frontController,
                    decoration: InputDecoration(
                      labelText: 'Question / Active Recall Prompt',
                      hintText: 'e.g. What is ATP?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: backController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Answer / Explanation',
                      hintText: 'e.g. Adenosine Triphosphate, energy molecule of the cell.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hintController,
                    decoration: InputDecoration(
                      labelText: 'Hint (Optional)',
                      hintText: 'Brief memory trigger',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ApiService.addCustomCard(
                          deckId: deck.id,
                          front: frontController.text.trim(),
                          back: backController.text.trim(),
                          hint: hintController.text.trim().isNotEmpty
                              ? hintController.text.trim()
                              : null,
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(ctx);
                        _loadDecks();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!dialogCtx.mounted) return;
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(content: Text(ApiService.cleanErrorMessage(e, 'Add card'))),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Card', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDeck(FlashcardDeck deck) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Deck?'),
        content: Text('Are you sure you want to delete "${deck.title}" and its ${deck.cardCount} cards?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteFlashcardDeck(deck.id);
        _loadDecks();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.cleanErrorMessage(e, 'Delete deck'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subject categories
    final subjects = {'all', ..._decks.map((d) => d.subject.trim()).where((s) => s.isNotEmpty)};
    final filteredDecks = _selectedSubjectFilter == 'all'
        ? _decks
        : _decks
            .where((d) => d.subject.toLowerCase() == _selectedSubjectFilter.toLowerCase())
            .toList();

    final totalCards = _decks.fold<int>(0, (sum, d) => sum + d.cardCount);
    final totalMastered = _decks.fold<int>(0, (sum, d) => sum + d.masteredCount);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDecks,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Screen Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.style_rounded, color: AppColors.primary, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Flashcards',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Active recall powered by spaced repetition',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showCreateDeckDialog,
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'New Deck',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Overview Progress Banner
              if (_decks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildMasteryOverviewCard(totalCards, totalMastered),
                  ),
                ),

              // Subject Filter Chips
              if (subjects.length > 2)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: subjects.map((subj) {
                        final isSelected = _selectedSubjectFilter.toLowerCase() == subj.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(subj == 'all' ? 'All Decks' : subj),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedSubjectFilter = subj;
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
                                color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Content Body (Loading / Error / Empty / Decks list)
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Loading flashcard decks...',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.crimson),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _loadDecks,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (filteredDecks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDeckCard(deck),
                        );
                      },
                      childCount: filteredDecks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasteryOverviewCard(int totalCards, int totalMastered) {
    final percent = totalCards > 0 ? (totalMastered / totalCards).clamp(0.0, 1.0) : 0.0;
    final percentInt = (percent * 100).round();

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
      child: Row(
        children: [
          MetricRing(
            progress: percent,
            size: 58,
            strokeWidth: 5.5,
            progressColor: AppColors.emerald,
            trackColor: AppColors.surfaceContainerLow,
            centerChild: Text(
              '$percentInt%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'TOTAL MASTERY',
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
                Text(
                  '$totalMastered of $totalCards Cards Known',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _decks.length == 1
                      ? '1 active study deck'
                      : '${_decks.length} active study decks',
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _buildDeckCard(FlashcardDeck deck) {
    final percent = deck.masteryPercent;
    final percentInt = deck.masteryPercentageInt;

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
          // Subject badge & Popup Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  deck.subject,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryFixed,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.onSurfaceVariant),
                onSelected: (val) {
                  if (val == 'add') {
                    _showAddCardDialog(deck);
                  } else if (val == 'delete') {
                    _confirmDeleteDeck(deck);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Add Card'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.crimson),
                        SizedBox(width: 8),
                        Text('Delete Deck', style: TextStyle(color: AppColors.crimson)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Deck Title
          Text(
            deck.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.25,
            ),
          ),
          if (deck.description != null && deck.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              deck.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // Progress & Study Button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${deck.masteredCount} / ${deck.cardCount} Mastered',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '$percentInt%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerLow,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percent >= 0.8 ? AppColors.emerald : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openStudyScreen(deck),
                icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Study',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.style_outlined,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Flashcard Decks Yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate question-and-answer active recall cards directly from your uploaded study materials or notes.',
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
              onPressed: _showCreateDeckDialog,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Generate Flashcards with AI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}
