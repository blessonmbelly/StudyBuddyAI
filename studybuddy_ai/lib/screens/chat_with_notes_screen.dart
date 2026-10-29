import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/note.dart';
import '../models/study_document.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ChatWithNotesScreen extends StatefulWidget {
  final StudyDocument? selectedDocument;
  final List<StudyDocument>? availableDocuments;
  final NoteItem? selectedNote;
  final List<NoteItem>? availableNotes;
  final VoidCallback? onBack;
  final void Function(StudyDocument? doc)? onSelectDocument;
  final void Function(NoteItem note)? onSelectNote;

  const ChatWithNotesScreen({
    super.key,
    this.selectedDocument,
    this.availableDocuments,
    this.selectedNote,
    this.availableNotes,
    this.onBack,
    this.onSelectDocument,
    this.onSelectNote,
  });

  @override
  State<ChatWithNotesScreen> createState() => _ChatWithNotesScreenState();
}

class _ChatWithNotesScreenState extends State<ChatWithNotesScreen> {
  StudyDocument? _currentDocument;
  NoteItem? _currentNote;
  String? _activeConversationId;

  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _isLoadingHistory = false;
  String? _lastError;
  String? _lastFailedPrompt;
  List<String> _suggestedPrompts = [];

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.selectedDocument;
    _currentNote = widget.selectedNote;
    _loadConversationAndState();
  }

  @override
  void didUpdateWidget(covariant ChatWithNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final docChanged = widget.selectedDocument?.id != _currentDocument?.id;
    final noteChanged = widget.selectedNote?.id != _currentNote?.id;

    if (docChanged || noteChanged) {
      setState(() {
        _currentDocument = widget.selectedDocument;
        _currentNote = widget.selectedNote;
      });
      _loadConversationAndState();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentContextTitle {
    if (_currentDocument != null) {
      return _currentDocument!.title;
    }
    if (_currentNote != null) {
      return _currentNote!.title;
    }
    return 'General AI Tutor';
  }

  String get _currentContextSubtitle {
    if (_currentDocument != null) {
      final subject = _currentDocument!.subject.isNotEmpty
          ? _currentDocument!.subject
          : 'Study Document';
      return 'Grounding enabled • $subject';
    }
    if (_currentNote != null) {
      final code = _currentNote!.courseCode.isNotEmpty
          ? _currentNote!.courseCode
          : _currentNote!.courseName;
      return 'Grounding enabled • $code';
    }
    return 'General Learning & Reasoning Mode';
  }

  String? get _currentDocumentId {
    if (_currentDocument != null && _currentDocument!.id.contains('-')) {
      return _currentDocument!.id;
    }
    if (_currentNote != null && _currentNote!.id.contains('-')) {
      return _currentNote!.id;
    }
    return null;
  }

  Future<void> _loadConversationAndState() async {
    _updateSuggestedPrompts();
    _lastError = null;

    final docId = _currentDocumentId;
    if (!AuthService.instance.isAuthenticated) {
      _showInitialWelcome();
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final convs = await ApiService.fetchConversations(documentId: docId);
      if (!mounted) return;

      if (convs.isNotEmpty) {
        final latest = convs.first;
        _activeConversationId = latest.id;
        final fullConv = await ApiService.fetchConversation(latest.id);
        if (!mounted) return;

        setState(() {
          _messages.clear();
          if (fullConv.messages.isNotEmpty) {
            _messages.addAll(fullConv.messages);
          } else {
            _showInitialWelcome(keepExisting: false);
          }
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _activeConversationId = null;
          _showInitialWelcome(keepExisting: false);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _showInitialWelcome(keepExisting: false);
      });
    }
  }

  void _updateSuggestedPrompts() {
    if (_currentDocument != null) {
      final topics = _currentDocument!.topics;
      if (topics.isNotEmpty) {
        _suggestedPrompts = topics.take(4).map((t) => 'Explain $t').toList();
      } else {
        _suggestedPrompts = [
          'Summarize the core takeaways',
          'Give me an analogy to understand this',
          'What are common exam pitfalls here?',
          'Generate 3 practice questions',
        ];
      }
    } else if (_currentNote != null && _currentNote!.definitions.isNotEmpty) {
      _suggestedPrompts = _currentNote!.definitions.take(4).map((d) {
        final term = d.split(':').first.trim();
        return 'Explain $term';
      }).toList();
    } else {
      _suggestedPrompts = [
        'Explain photosynthesis with an everyday analogy',
        'How do operating system deadlocks occur?',
        'Give me a 3-step study plan for my exams',
        'Explain Newton\'s laws with real-world examples',
      ];
    }
  }

  void _showInitialWelcome({bool keepExisting = true}) {
    if (keepExisting && _messages.isNotEmpty) return;

    final welcomeText = _currentDocument != null
        ? "Hi! 👋 I'm your AI Tutor. I've indexed **${_currentDocument!.title}**. Ask me questions directly from your notes, request real-world analogies, or ask broader concepts beyond the text!"
        : _currentNote != null
            ? "Hi! 👋 I'm your AI Tutor. I'm grounded in **${_currentNote!.title}**. Feel free to ask about definitions, step-by-step explanations, or related topics!"
            : "Hi! 👋 I'm StudyBuddy AI, your personal AI Tutor. Ask me any study question, brainstorm concepts, request step-by-step explanations, or select a document above to study together!";

    _messages.clear();
    _messages.add(
      ChatMessage(
        id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.ai,
        text: welcomeText,
        timestamp: DateTime.now(),
        noteReference: _currentDocument != null
            ? _currentDocument!.title
            : _currentNote?.title,
        outsideKnowledgeUsed: _currentDocument == null && _currentNote == null,
      ),
    );
  }

  Future<void> _sendMessage([String? promptText]) async {
    final text = promptText ?? _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    final userMsg = ChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
      conversationId: _activeConversationId,
    );

    setState(() {
      _messages.add(userMsg);
      if (promptText == null) {
        _inputController.clear();
      }
      _isSending = true;
      _lastError = null;
      _lastFailedPrompt = null;
    });

    _scrollToBottom();

    final docId = _currentDocumentId;

    try {
      final aiResponse = await ApiService.sendTutorMessage(
        message: text,
        conversationId: _activeConversationId,
        documentId: docId,
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _activeConversationId = aiResponse.conversationId ?? _activeConversationId;
        _messages.add(aiResponse);
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final cleanErr = ApiService.cleanErrorMessage(e, 'AI Tutor');
      setState(() {
        _isSending = false;
        _lastError = cleanErr;
        _lastFailedPrompt = text;
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Chat History?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'This will remove this conversation and its persisted messages from your account.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_activeConversationId != null && AuthService.instance.isAuthenticated) {
      try {
        await ApiService.deleteConversation(_activeConversationId!);
      } catch (e) {
        debugPrint('Conversation delete notice: $e');
      }
    }

    setState(() {
      _activeConversationId = null;
      _lastError = null;
      _lastFailedPrompt = null;
      _showInitialWelcome(keepExisting: false);
    });
  }

  void _switchToGeneralTutor() {
    setState(() {
      _currentDocument = null;
      _currentNote = null;
    });
    if (widget.onSelectDocument != null) {
      widget.onSelectDocument!(null);
    }
    _loadConversationAndState();
  }

  void _switchToDocument(StudyDocument doc) {
    setState(() {
      _currentDocument = doc;
      _currentNote = doc.generatedNote;
    });
    if (widget.onSelectDocument != null) {
      widget.onSelectDocument!(doc);
    }
    if (doc.generatedNote != null && widget.onSelectNote != null) {
      widget.onSelectNote!(doc.generatedNote!);
    }
    _loadConversationAndState();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildContextSelectorBar(),
            _buildSuggestionsRibbon(),
            if (_isLoadingHistory)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length +
                    (_isSending ? 1 : 0) +
                    (_lastError != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  } else if (_isSending && index == _messages.length) {
                    return _buildTypingIndicator();
                  } else {
                    return _buildErrorCard();
                  }
                },
              ),
            ),
            _buildInputBar(),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Tutor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  _currentContextSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.emerald,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.onSurfaceVariant),
            onPressed: _messages.isEmpty ? null : _clearConversation,
            tooltip: 'Clear conversation history',
          ),
        ],
      ),
    );
  }

  Widget _buildContextSelectorBar() {
    final docs = widget.availableDocuments ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceContainerLow,
      child: Row(
        children: [
          Icon(
            _currentDocument != null ? Icons.description_rounded : Icons.psychology_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Context: $_currentContextTitle',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<dynamic>(
            tooltip: 'Switch learning material',
            onSelected: (value) {
              if (value == 'general') {
                _switchToGeneralTutor();
              } else if (value is StudyDocument) {
                _switchToDocument(value);
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<dynamic>>[];

              items.add(
                PopupMenuItem<dynamic>(
                  value: 'general',
                  child: Row(
                    children: [
                      Icon(Icons.psychology_rounded,
                          size: 16,
                          color: _currentDocument == null ? AppColors.primary : AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'General AI Tutor (No Document)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_currentDocument == null && _currentNote == null)
                        const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );

              if (docs.isNotEmpty) {
                items.add(const PopupMenuDivider());
                for (final doc in docs) {
                  final isSelected = _currentDocument?.id == doc.id;
                  items.add(
                    PopupMenuItem<dynamic>(
                      value: doc,
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 16,
                              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '[${doc.subject}] ${doc.title}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                }
              }

              return items;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: const Row(
                children: [
                  Text('Switch', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsRibbon() {
    if (_suggestedPrompts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _suggestedPrompts.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _isSending ? null : () => _sendMessage(prompt),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: AppColors.surfaceContainerHigh),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'StudyBuddy AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (msg.noteReference != null && msg.noteReference!.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 195),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 10, color: AppColors.emerald),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Notes: ${msg.noteReference}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emerald,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (msg.outsideKnowledgeUsed)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 195),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, size: 10, color: AppColors.secondary),
                                SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'General Knowledge / Analogy',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildFormattedText(msg.text, isUser),
                  if (msg.keyTakeaways != null && msg.keyTakeaways!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Key Takeaways:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...msg.keyTakeaways!.map((k) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      k,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryFixed,
              child: const Icon(Icons.person_rounded, size: 16, color: AppColors.onPrimaryFixed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentDocument != null
                      ? 'AI Tutor analyzing document & notes...'
                      : 'AI Tutor thinking...',
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

  Widget _buildFormattedText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : AppColors.onSurface;
    final spans = <TextSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold && !isUser ? AppColors.primary : baseColor,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _lastError ?? 'Failed to send message. Please check your network.',
              style: const TextStyle(fontSize: 12, color: AppColors.onErrorContainer),
            ),
          ),
          if (_lastFailedPrompt != null)
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _sendMessage(_lastFailedPrompt),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  enabled: !_isSending,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _currentDocument != null
                        ? 'Ask anything about "${_currentDocument!.title}"...'
                        : 'Ask your AI Tutor anything...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _isSending ? null : () => _sendMessage(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: _isSending ? null : AppColors.primaryGradient,
                  color: _isSending ? AppColors.surfaceContainerHigh : null,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
