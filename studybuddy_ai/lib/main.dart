import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/note.dart';
import 'models/quiz_question.dart';
import 'data/sample_notes.dart';
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
  final List<NoteItem> _notes = List.from(sampleStudyNotes);

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
      if (!_notes.any((n) => n.id == note.id)) {
        _notes.insert(0, note);
      }
      _selectedNoteForDetails = note;
      _currentTabIndex = 2; // Switch to Short Notes tab
    });
  }

  void _startQuiz({List<QuizQuestion>? questions, String? quizTitle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          quizTitle: quizTitle,
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
        notes: _notes,
        onNavigateTab: (targetTab, {scanMode}) =>
            _onTabSelected(targetTab, scanMode: scanMode),
        onOpenNote: _openNote,
        onStartQuiz: () => _startQuiz(),
        onOpenChat: () => _openChatWithNote(_selectedNoteForDetails),
      ),
      ScanImportScreen(
        initialMode: _scanInitialMode,
        onExportToNotes: _onNoteExported,
        onNavigateToNotes: () => _onTabSelected(2),
      ),
      ShortNotesScreen(
        note: _selectedNoteForDetails,
        onStartQuiz: ([questions, quizTitle]) =>
            _startQuiz(questions: questions, quizTitle: quizTitle),
        onChatWithNote: (note) => _openChatWithNote(note),
      ),
      ChatWithNotesScreen(
        selectedNote: _selectedNoteForDetails,
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
