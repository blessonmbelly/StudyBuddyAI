import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/auth_user.dart';
import 'models/note.dart';
import 'models/quiz_question.dart';
import 'models/study_document.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_import_screen.dart';
import 'screens/short_notes_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/flashcards_screen.dart';
import 'screens/flashcard_study_screen.dart';
import 'screens/chat_with_notes_screen.dart';
import 'widgets/app_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const StudyBuddyApp());
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyBuddy AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;

        // On physical phones or narrow screens, render full screen naturally
        if (screenWidth <= 500) {
          return child;
        }

        // On laptops / desktops, frame into modern mobile phone aspect ratio
        final double phoneWidth = screenWidth > 430 ? 412.0 : screenWidth * 0.95;
        final double phoneHeight = (screenHeight * 0.94).clamp(650.0, 892.0);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          body: Center(
            child: Container(
              width: phoneWidth,
              height: phoneHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 40,
                    spreadRadius: 6,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: MediaQuery(
                  data: mq.copyWith(
                    size: Size(phoneWidth, phoneHeight),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isRestoring = true;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final user = await AuthService.instance.tryRestoreSession();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isRestoring = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isRestoring = false;
        });
      }
    }
  }

  void _onLoginSuccess(AuthUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.logout();
    if (mounted) {
      setState(() {
        _currentUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'StudyBuddy AI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restoring session...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return LoginScreen(
        onLoginSuccess: _onLoginSuccess,
      );
    }

    return MainNavigationShell(
      currentUser: _currentUser,
      onLogout: _handleLogout,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final AuthUser? currentUser;
  final VoidCallback? onLogout;

  const MainNavigationShell({
    super.key,
    this.currentUser,
    this.onLogout,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentTabIndex = 0;
  String _scanInitialMode = 'camera';
  NoteItem? _selectedNoteForDetails;
  final List<NoteItem> _notes = [];
  final List<StudyDocument> _documents = [];
  StudyDocument? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _loadUserLibrary();
  }

  /// Automatically restores user's documents and notes from PostgreSQL
  Future<void> _loadUserLibrary() async {
    if (AuthService.instance.isAuthenticated) {
      try {
        final docs = await ApiService.fetchDocuments();
        final notes = await ApiService.fetchNotes();
        if (mounted) {
          setState(() {
            _documents.clear();
            final seenDocKeys = <String>{};
            for (final d in docs) {
              final key = '${d.title.trim().toLowerCase()}_${d.subject.trim().toLowerCase()}';
              if (!seenDocKeys.contains(key)) {
                seenDocKeys.add(key);
                _documents.add(d);
              }
            }

            _notes.clear();
            final seenNoteKeys = <String>{};
            for (final n in notes) {
              final key = '${n.title.trim().toLowerCase()}_${n.courseName.trim().toLowerCase()}';
              if (!seenNoteKeys.contains(key)) {
                seenNoteKeys.add(key);
                _notes.add(n);
              }
            }

            // Pair notes with their corresponding documents
            for (final doc in _documents) {
              if (doc.generatedNote == null) {
                final matchingNote = _notes
                    .where((n) =>
                        n.id == doc.id ||
                        n.title.toLowerCase().trim() ==
                            doc.title.toLowerCase().trim())
                    .firstOrNull;
                if (matchingNote != null) {
                  doc.generatedNote = matchingNote;
                }
              }
            }

            if (_notes.isNotEmpty && _selectedNoteForDetails == null) {
              _selectedNoteForDetails = _notes.first;
            }
          });
        }
      } catch (e) {
        debugPrint('Library load notice: $e');
      }
    }
  }

  void _onTabSelected(int index, {String? scanMode}) {
    setState(() {
      _currentTabIndex = index;
      if (scanMode != null) {
        _scanInitialMode = scanMode;
      }
    });
  }

  void _openNote(NoteItem note) {
    setState(() {
      _selectedNoteForDetails = note;
      _currentTabIndex = 2; // Switch to Short Notes tab
    });
  }

  void _onNoteExported(NoteItem note) {
    setState(() {
      _notes.removeWhere((n) =>
          n.id == note.id ||
          (n.title.trim().toLowerCase() == note.title.trim().toLowerCase() &&
              n.courseName.trim().toLowerCase() == note.courseName.trim().toLowerCase()));
      _notes.insert(0, note);
      _selectedNoteForDetails = note;
      if (_selectedDocument != null) {
        _selectedDocument!.generatedNote = note;
      }
      _currentTabIndex = 2; // Switch to Short Notes tab
    });
  }

  Future<void> _onDocumentExported(StudyDocument doc) async {
    setState(() {
      _documents.removeWhere((d) =>
          d.id == doc.id ||
          (d.title.trim().toLowerCase() == doc.title.trim().toLowerCase() &&
              d.subject.trim().toLowerCase() == doc.subject.trim().toLowerCase()));
      _documents.insert(0, doc);
      _selectedDocument = doc;
      if (doc.generatedNote != null) {
        _notes.removeWhere((n) =>
            n.id == doc.generatedNote!.id ||
            (n.title.trim().toLowerCase() == doc.generatedNote!.title.trim().toLowerCase() &&
                n.courseName.trim().toLowerCase() == doc.generatedNote!.courseName.trim().toLowerCase()));
        _notes.insert(0, doc.generatedNote!);
        _selectedNoteForDetails = doc.generatedNote;
        _currentTabIndex = 2; // Switch to Short Notes tab
      } else {
        _currentTabIndex = 0; // Return to Home
      }
    });

    // If document has a temporary ID and not yet persisted, save it to PostgreSQL
    if (AuthService.instance.isAuthenticated && !doc.id.contains('-')) {
      try {
        final persistedDoc = await ApiService.saveDocument(doc);
        if (mounted) {
          setState(() {
            final idx = _documents.indexWhere((d) =>
                d.id == doc.id ||
                (d.title.trim().toLowerCase() == doc.title.trim().toLowerCase() &&
                    d.subject.trim().toLowerCase() == doc.subject.trim().toLowerCase()));
            if (idx != -1) {
              _documents[idx] = persistedDoc;
            }
            if (_selectedDocument?.id == doc.id) {
              _selectedDocument = persistedDoc;
            }
          });
        }
      } catch (e) {
        debugPrint('Document persistence notice: $e');
      }
    }
  }

  Future<void> _onEditDocument(StudyDocument doc) async {
    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = doc;
        if (_selectedDocument?.id == doc.id) {
          _selectedDocument = doc;
        }
        if (doc.generatedNote != null) {
          final n = doc.generatedNote!;
          final updatedNote = n.copyWith(
            title: doc.title,
            courseName: doc.subject,
            category: doc.subject.toLowerCase(),
          );
          doc.generatedNote = updatedNote;
          final nIdx = _notes.indexWhere((item) => item.id == n.id);
          if (nIdx != -1) {
            _notes[nIdx] = updatedNote;
          }
          if (_selectedNoteForDetails?.id == n.id) {
            _selectedNoteForDetails = updatedNote;
          }
        }
      }
    });

    if (AuthService.instance.isAuthenticated && doc.id.contains('-')) {
      try {
        await ApiService.updateDocument(doc);
      } catch (e) {
        debugPrint('Document update notice: $e');
      }
    }
  }

  Future<void> _onDeleteDocument(StudyDocument doc) async {
    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
      if (doc.generatedNote != null) {
        _notes.removeWhere((n) => n.id == doc.generatedNote!.id);
      }
      if (_selectedDocument?.id == doc.id) {
        _selectedDocument = null;
      }
    });

    if (AuthService.instance.isAuthenticated && doc.id.contains('-')) {
      try {
        await ApiService.deleteDocument(doc.id);
      } catch (e) {
        debugPrint('Delete document notice: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${doc.title}" from recent study materials.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openDocumentNotes(StudyDocument doc) async {
    _selectedDocument = doc;
    if (doc.generatedNote != null) {
      _openNote(doc.generatedNote!);
      return;
    }

    // Auto-generate notes if not already created
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Generating study notes for "${doc.title}"...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Subject: ${doc.subject}',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final note = await ApiService.generateNotes(
        text: doc.extractedText,
        title: doc.title,
        courseName: doc.subject,
        documentId: doc.id.contains('-') ? doc.id : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      doc.generatedNote = note;
      _onNoteExported(note);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note generation notice: ${e.toString().replaceAll("Exception: ", "")}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startDocumentQuiz(StudyDocument doc) async {
    _selectedDocument = doc;
    if (doc.generatedQuiz != null && doc.generatedQuiz!.isNotEmpty) {
      _startQuiz(questions: doc.generatedQuiz, quizTitle: doc.title);
      return;
    }

    // Auto-generate quiz if not already created
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Generating 5 quiz questions for "${doc.title}"...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Subject: ${doc.subject}',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final questions = await ApiService.generateQuiz(
        text: doc.extractedText,
        numQuestions: 5,
        noteTitle: doc.title,
        documentId: doc.id.contains('-') ? doc.id : null,
        noteId: doc.generatedNote != null && doc.generatedNote!.id.contains('-')
            ? doc.generatedNote!.id
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      doc.generatedQuiz = questions;
      _startQuiz(questions: questions, quizTitle: doc.title);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz generation notice: ${e.toString().replaceAll("Exception: ", "")}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChatWithDocument(StudyDocument doc) {
    setState(() {
      _selectedDocument = doc;
      if (doc.generatedNote != null) {
        _selectedNoteForDetails = doc.generatedNote;
      }
      _currentTabIndex = 4; // Switch to Chat tab
    });
  }

  void _startQuiz({List<QuizQuestion>? questions, String? quizTitle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          quizTitle: quizTitle,
          onQuit: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          onReturnHome: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            _onTabSelected(0);
          },
          onReturnNotes: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            _onTabSelected(2);
          },
        ),
      ),
    );
  }

  Future<void> _openDocumentFlashcards(StudyDocument doc) async {
    _selectedDocument = doc;
    if (doc.extractedText.trim().length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document text is too short to generate flashcards (< 15 characters).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Generating flashcards for "${doc.title}"...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Subject: ${doc.subject}',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final deck = await ApiService.generateFlashcards(
        text: doc.extractedText,
        deckTitle: '${doc.title} Flashcards',
        subject: doc.subject,
        numCards: 6,
        documentId: doc.id.contains('-') ? doc.id : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardStudyScreen(deck: deck),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.cleanErrorMessage(e, 'Flashcard generation')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startFlashcardsForNote(NoteItem note) async {
    final noteText = note.rawTranscript.isNotEmpty
        ? note.rawTranscript
        : '${note.title}\n${note.summary}\n${note.sections.map((s) => '${s.title}\n${s.bullets.map((b) => '${b.term}: ${b.definition}').join('\n')}').join('\n')}';

    if (noteText.trim().length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note content is too short to generate flashcards (< 15 characters).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Generating flashcards for "${note.title}"...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final deck = await ApiService.generateFlashcards(
        text: noteText,
        deckTitle: '${note.title} Flashcards',
        subject: note.courseName.isNotEmpty ? note.courseName : 'General',
        numCards: 6,
        noteId: note.id.contains('-') ? note.id : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardStudyScreen(deck: deck),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.cleanErrorMessage(e, 'Flashcard generation')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChatWithNote([NoteItem? note]) {
    setState(() {
      if (note != null) {
        _selectedNoteForDetails = note;
        final matchingDoc = _documents.where((d) => d.id == note.id).firstOrNull;
        if (matchingDoc != null) {
          _selectedDocument = matchingDoc;
        }
      }
      _currentTabIndex = 4; // Switch to Chat tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        currentUser: widget.currentUser,
        onLogout: widget.onLogout,
        documents: _documents,
        notes: _notes,
        onNavigateTab: (targetTab, {scanMode}) =>
            _onTabSelected(targetTab, scanMode: scanMode),
        onOpenDocumentNotes: _openDocumentNotes,
        onStartDocumentQuiz: _startDocumentQuiz,
        onOpenDocumentChat: _openChatWithDocument,
        onOpenDocumentFlashcards: _openDocumentFlashcards,
        onEditDocument: _onEditDocument,
        onDeleteDocument: _onDeleteDocument,
        onOpenNote: _openNote,
        onStartQuiz: () => _startQuiz(),
        onOpenChat: () => _openChatWithNote(_selectedNoteForDetails),
      ),
      ScanImportScreen(
        initialMode: _scanInitialMode,
        onExportToNotes: _onNoteExported,
        onExportDocument: _onDocumentExported,
        onNavigateToNotes: () => _onTabSelected(2),
      ),
      ShortNotesScreen(
        note: _selectedNoteForDetails,
        onStartQuiz: ([questions, quizTitle]) =>
            _startQuiz(questions: questions, quizTitle: quizTitle),
        onChatWithNote: (note) => _openChatWithNote(note),
        onStudyFlashcards: (note) => _startFlashcardsForNote(note),
        onNavigateToScan: () => _onTabSelected(1),
      ),
      FlashcardsScreen(
        availableDocuments: _documents,
        availableNotes: _notes,
      ),
      ChatWithNotesScreen(
        selectedDocument: _selectedDocument,
        availableDocuments: _documents,
        selectedNote: _selectedNoteForDetails,
        availableNotes: _notes,
        onSelectDocument: (doc) => setState(() => _selectedDocument = doc),
        onSelectNote: (note) => setState(() => _selectedNoteForDetails = note),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: screens,
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentTabIndex,
        onTabSelected: (index) => _onTabSelected(index),
      ),
    );
  }
}
