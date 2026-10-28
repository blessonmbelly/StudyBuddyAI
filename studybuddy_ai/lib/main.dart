import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/note.dart';
import 'models/quiz_question.dart';
import 'models/study_document.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/scan_import_screen.dart';
import 'screens/short_notes_screen.dart';
import 'screens/quiz_screen.dart';
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
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

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
      _notes.removeWhere((n) => n.id == note.id);
      _notes.insert(0, note);
      _selectedNoteForDetails = note;
      if (_selectedDocument != null) {
        _selectedDocument!.generatedNote = note;
      }
      _currentTabIndex = 2; // Switch to Short Notes tab
    });
  }

  void _onDocumentExported(StudyDocument doc) {
    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
      _documents.insert(0, doc);
      _selectedDocument = doc;
      if (doc.generatedNote != null) {
        _notes.removeWhere((n) => n.id == doc.generatedNote!.id);
        _notes.insert(0, doc.generatedNote!);
        _selectedNoteForDetails = doc.generatedNote;
        _currentTabIndex = 2; // Switch to Short Notes tab
      } else {
        _currentTabIndex = 0; // Return to Home
      }
    });
  }

  void _onEditDocument(StudyDocument doc) {
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
    _selectedDocument = doc;
    if (doc.generatedNote != null) {
      _openChatWithNote(doc.generatedNote);
    } else {
      final synthesizedNote = NoteItem.synthesizedFromDocument(
        id: doc.id,
        title: doc.title,
        subject: doc.subject,
        text: doc.extractedText,
        topics: doc.topics,
      );
      _openChatWithNote(synthesizedNote);
    }
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

  void _openChatWithNote([NoteItem? note]) {
    setState(() {
      if (note != null) {
        _selectedNoteForDetails = note;
      }
      _currentTabIndex = 3; // Switch to Chat tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        documents: _documents,
        notes: _notes,
        onNavigateTab: (targetTab, {scanMode}) =>
            _onTabSelected(targetTab, scanMode: scanMode),
        onOpenDocumentNotes: _openDocumentNotes,
        onStartDocumentQuiz: _startDocumentQuiz,
        onOpenDocumentChat: _openChatWithDocument,
        onEditDocument: _onEditDocument,
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
        onNavigateToScan: () => _onTabSelected(1),
      ),
      ChatWithNotesScreen(
        selectedNote: _selectedNoteForDetails,
        availableNotes: _notes,
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
