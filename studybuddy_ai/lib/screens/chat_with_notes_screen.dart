import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import '../data/sample_notes.dart';
import '../data/mock_chat_data.dart';

class ChatWithNotesScreen extends StatefulWidget {
  final NoteItem? selectedNote;
  final VoidCallback? onBack;

  const ChatWithNotesScreen({
    super.key,
    this.selectedNote,
    this.onBack,
  });

  @override
  State<ChatWithNotesScreen> createState() => _ChatWithNotesScreenState();
}

class _ChatWithNotesScreenState extends State<ChatWithNotesScreen> {
  late NoteItem _currentNote;
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<String> _suggestedPrompts = [
    'Summarize Atkinson-Shiffrin Model',
    'Retrograde vs Anterograde Amnesia',
    'Explain Ebbinghaus forgetting curve',
    'Give me a mnemonic for memory stores',
  ];

  @override
  void initState() {
    super.initState();
    _currentNote = widget.selectedNote ?? sampleStudyNotes.first;
    _messages.addAll(initialChatMessages);
  }

  @override
  void didUpdateWidget(covariant ChatWithNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNote != null && widget.selectedNote != _currentNote) {
      setState(() {
        _currentNote = widget.selectedNote!;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? promptText]) async {
    final text = promptText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      if (promptText == null) {
        _inputController.clear();
      }
      _isTyping = true;
    });

    _scrollToBottom();

    final noteContext = _currentNote.rawTranscript.isNotEmpty
        ? _currentNote.rawTranscript
        : '${_currentNote.title}\n${_currentNote.summary}\n${_currentNote.definitions.join("\n")}';

    final history = _messages
        .take(6)
        .map((m) => {
              'role': m.sender == MessageSender.user ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    try {
      final res = await ApiService.chatWithNotes(
        message: text,
        noteContext: noteContext,
        history: history,
      );
      final replyText = res['reply'] as String? ?? 'No response received.';

      if (!mounted) return;
      final aiMsg = ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.ai,
        text: replyText,
        timestamp: DateTime.now(),
        noteReference: '${_currentNote.courseCode} • ${_currentNote.title}',
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      // Graceful fallback to offline/mock reply so student experience is uninterrupted
      final replyText = MockChatService.generateReply(text);
      final aiMsg = ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.ai,
        text: replyText,
        timestamp: DateTime.now(),
        noteReference: '${_currentNote.courseCode} • ${_currentNote.title}',
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });

      _scrollToBottom();
    }
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
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildNoteContextBar(),
            _buildSuggestionsRibbon(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 20),
            ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat with Notes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'Grounding enabled • PSYC 201',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.onSurfaceVariant),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.addAll(initialChatMessages);
              });
            },
            tooltip: 'Clear conversation',
          ),
        ],
      ),
    );
  }

  Widget _buildNoteContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceContainerLow,
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Active Note: ${_currentNote.title}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<NoteItem>(
            onSelected: (note) {
              setState(() {
                _currentNote = note;
              });
            },
            itemBuilder: (context) {
              return sampleStudyNotes.map((n) {
                return PopupMenuItem(
                  value: n,
                  child: Text(n.title, style: const TextStyle(fontSize: 13)),
                );
              }).toList();
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
                onTap: () => _sendMessage(prompt),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      const Icon(Icons.auto_awesome_rounded,
                          size: 13, color: AppColors.primary),
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
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.surfaceContainerHigh),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'StudyBuddy AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (msg.noteReference != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Verified Note',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isUser ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                  if (msg.keyTakeaways != null &&
                      msg.keyTakeaways!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...msg.keyTakeaways!.map((k) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                k,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
              child: const Text(
                'A',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimaryFixed,
                ),
              ),
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Reviewing study notes...',
                  style: TextStyle(
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
            IconButton(
              icon: const Icon(Icons.mic_none_rounded,
                  color: AppColors.onSurfaceVariant),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Listening... (Voice note mode)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
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
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Ask anything about your notes...',
                    hintStyle: TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _sendMessage(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
