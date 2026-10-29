import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/flashcard.dart';
import '../models/note.dart';
import '../models/quiz_question.dart';
import '../models/study_document.dart';
import 'auth_service.dart';

class ApiService {
  // Configurable base URL:
  // - Physical phone over USB: http://127.0.0.1:8000 (with `adb reverse tcp:8000 tcp:8000`)
  // - Android emulator:        http://10.0.2.2:8000
  // Can also be set at compile-time via --dart-define=API_BASE_URL=http://...
  static const String _defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static String baseUrl = _defaultUrl;

  static void setBaseUrl(String newUrl) {
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
  }

  static const Duration requestTimeout = Duration(seconds: 45);

  /// Helper providing authenticated JSON headers
  static Map<String, String> get authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Check health and configuration of the backend
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw HttpException('Server returned status ${response.statusCode}');
    } catch (e) {
      throw Exception('Unable to reach backend at $baseUrl ($e).');
    }
  }

  /// Upload a file by path and extract text
  static Future<Map<String, dynamic>> extractFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    final bytes = await file.readAsBytes();
    final filename = filePath.split(Platform.pathSeparator).last;
    return extractFromBytes(bytes, filename);
  }

  static String cleanErrorMessage(dynamic e, String defaultPrefix) {
    final str = e.toString().replaceAll('Exception: ', '').trim();
    final lower = str.toLowerCase();
    if (lower.contains('closed before full header') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection reset') ||
        lower.contains('handshakeexception')) {
      return 'Cannot reach backend at $baseUrl.\n\nPlease start the backend on your PC:\ncd backend\n.\\venv\\Scripts\\uvicorn.exe main:app --reload --host 127.0.0.1 --port 8000\nand verify: adb reverse tcp:8000 tcp:8000';
    }
    if (lower.contains('timeout')) {
      return '$defaultPrefix timed out. Please check your network or try a smaller section.';
    }
    return str.isNotEmpty ? str : '$defaultPrefix failed.';
  }

  /// Upload in-memory bytes and extract text
  static Future<Map<String, dynamic>> extractFromBytes(
      List<int> bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/api/files/extract');
      final request = http.MultipartRequest('POST', uri);
      final token = AuthService.instance.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Extraction failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Extraction'));
    }
  }

  /// Upload multiple files / photos and extract combined text with smart organization
  static Future<Map<String, dynamic>> extractFromMultipleFiles(
      List<List<int>> bytesList, List<String> filenames) async {
    try {
      final uri = Uri.parse('$baseUrl/api/files/extract-multiple');
      final request = http.MultipartRequest('POST', uri);
      final token = AuthService.instance.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      for (int i = 0; i < bytesList.length; i++) {
        final name = (i < filenames.length) ? filenames[i] : 'page_${i + 1}.jpg';
        request.files.add(
          http.MultipartFile.fromBytes('files', bytesList[i], filename: name),
        );
      }

      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Multi-file extraction failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Multi-photo extraction'));
    }
  }

  /// Organize study material text to generate meaningful title, subject, and topics
  static Future<Map<String, dynamic>> organizeText({
    required String text,
    String? filename,
    int? pageCount,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/files/organize');
      final payload = <String, dynamic>{'text': text};
      if (filename != null) payload['filename'] = filename;
      if (pageCount != null) payload['page_count'] = pageCount;

      final response = await http
          .post(
            uri,
            headers: authHeaders,
            body: json.encode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Organization failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Document organization'));
    }
  }

  /// Fetch all persisted documents for authenticated user
  static Future<List<StudyDocument>> fetchDocuments() async {
    try {
      final uri = Uri.parse('$baseUrl/api/documents');
      final response = await http.get(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(utf8.decode(response.bodyBytes));
        return raw.map((d) => StudyDocument.fromJson(d as Map<String, dynamic>)).toList();
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to load documents (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Fetch documents'));
    }
  }

  /// Persist a newly created or imported document to PostgreSQL
  static Future<StudyDocument> saveDocument(StudyDocument doc) async {
    try {
      final uri = Uri.parse('$baseUrl/api/documents');
      final payload = {
        'title': doc.title,
        'original_filename': doc.originalFilename,
        'file_type': 'TXT',
        'subject': doc.subject,
        'topics': doc.topics,
        'extracted_text': doc.extractedText,
        'word_count': doc.wordCount,
        'page_count': doc.pageCount,
        'extraction_method': doc.extractionMethod,
        'processing_status': doc.processingStatus,
      };

      final response = await http
          .post(uri, headers: authHeaders, body: json.encode(payload))
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return StudyDocument.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to save document (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Save document'));
    }
  }

  /// Update an existing document's title or subject in PostgreSQL
  static Future<StudyDocument> updateDocument(StudyDocument doc) async {
    try {
      final uri = Uri.parse('$baseUrl/api/documents/${doc.id}');
      final payload = {
        'title': doc.title,
        'subject': doc.subject,
        'topics': doc.topics,
      };

      final response = await http
          .put(uri, headers: authHeaders, body: json.encode(payload))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return StudyDocument.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to update document (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Update document'));
    }
  }

  /// Delete a document from PostgreSQL
  static Future<void> deleteDocument(String docId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/documents/$docId');
      final response = await http.delete(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode != 200) {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to delete document (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Delete document'));
    }
  }

  /// Fetch all persisted study notes from PostgreSQL
  static Future<List<NoteItem>> fetchNotes() async {
    try {
      final uri = Uri.parse('$baseUrl/api/notes');
      final response = await http.get(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(utf8.decode(response.bodyBytes));
        return raw.map((n) => NoteItem.fromJson(n as Map<String, dynamic>)).toList();
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to load notes (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Fetch notes'));
    }
  }

  /// Generate structured study notes from raw text
  static Future<NoteItem> generateNotes({
    required String text,
    String? courseCode,
    String? courseName,
    String? title,
    String? documentId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/notes/generate');
      final payload = <String, dynamic>{'text': text};
      if (courseCode != null) payload['course_code'] = courseCode;
      if (courseName != null) payload['course_name'] = courseName;
      if (title != null) payload['title'] = title;
      if (documentId != null) payload['document_id'] = documentId;

      final response = await http
          .post(
            uri,
            headers: authHeaders,
            body: json.encode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return NoteItem.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Note generation failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Note generation'));
    }
  }

  /// Generate MCQs from study text
  static Future<List<QuizQuestion>> generateQuiz({
    required String text,
    int numQuestions = 5,
    String? noteTitle,
    String? documentId,
    String? noteId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/quiz/generate');
      final payload = <String, dynamic>{
        'text': text,
        'num_questions': numQuestions,
      };
      if (noteTitle != null) payload['note_title'] = noteTitle;
      if (documentId != null) payload['document_id'] = documentId;
      if (noteId != null) payload['note_id'] = noteId;

      final response = await http
          .post(
            uri,
            headers: authHeaders,
            body: json.encode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final rawList = data['questions'] as List<dynamic>? ?? [];
        return rawList.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>)).toList();
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Quiz generation failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Quiz generation'));
    }
  }

  /// Record a completed quiz attempt to PostgreSQL
  static Future<Map<String, dynamic>> recordQuizAttempt({
    required String quizId,
    required int score,
    int totalQuestions = 5,
    int timeSpentSeconds = 0,
    Map<String, dynamic> userAnswers = const {},
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/quiz/$quizId/attempt');
      final response = await http
          .post(
            uri,
            headers: authHeaders,
            body: json.encode({
              'score': score,
              'total_questions': totalQuestions,
              'time_spent_seconds': timeSpentSeconds,
              'user_answers': userAnswers,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to record attempt (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Record quiz attempt'));
    }
  }

  /// Chat grounded on study note
  static Future<Map<String, dynamic>> chatWithNotes({
    required String message,
    String noteContext = '',
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat');
      final response = await http
          .post(
            uri,
            headers: authHeaders,
            body: json.encode({
              'message': message,
              'note_context': noteContext,
              'history': history,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Chat request failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Chat'));
    }
  }

  // =========================================================================
  // FLASHCARDS API
  // =========================================================================

  /// Fetch all flashcard decks owned by current student
  static Future<List<FlashcardDeck>> fetchFlashcardDecks() async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/decks');
      final response = await http.get(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(utf8.decode(response.bodyBytes));
        return raw.map((d) => FlashcardDeck.fromJson(d as Map<String, dynamic>)).toList();
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to load flashcard decks (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Fetch flashcards'));
    }
  }

  /// Fetch a single flashcard deck by ID
  static Future<FlashcardDeck> fetchFlashcardDeck(String deckId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/decks/$deckId');
      final response = await http.get(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return FlashcardDeck.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to load deck (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Fetch deck'));
    }
  }

  /// Generate Q&A flashcards using Gemini AI and persist directly to PostgreSQL
  static Future<FlashcardDeck> generateFlashcards({
    required String text,
    String? deckTitle,
    String? subject,
    int numCards = 6,
    String? documentId,
    String? noteId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/generate');
      final payload = <String, dynamic>{
        'text': text,
        'num_cards': numCards,
      };
      if (deckTitle != null && deckTitle.isNotEmpty) payload['deck_title'] = deckTitle;
      if (subject != null && subject.isNotEmpty) payload['subject'] = subject;
      if (documentId != null && documentId.isNotEmpty) payload['document_id'] = documentId;
      if (noteId != null && noteId.isNotEmpty) payload['note_id'] = noteId;

      final response = await http
          .post(uri, headers: authHeaders, body: json.encode(payload))
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return FlashcardDeck.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Flashcard generation failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Generate flashcards'));
    }
  }

  /// Update the status of an individual card ('known' / 'learning')
  static Future<FlashcardModel> updateCardStatus({
    required String cardId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/cards/$cardId/status');
      final response = await http
          .put(uri, headers: authHeaders, body: json.encode({'status': status}))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return FlashcardModel.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Card update failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Update card status'));
    }
  }

  /// Record a completed review session to PostgreSQL
  static Future<Map<String, dynamic>> recordFlashcardReview({
    required String deckId,
    required int cardsReviewed,
    required int knownCount,
    required int reviewAgainCount,
    required int durationSeconds,
    required List<Map<String, String>> cardUpdates,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/decks/$deckId/review');
      final payload = {
        'cards_reviewed': cardsReviewed,
        'known_count': knownCount,
        'review_again_count': reviewAgainCount,
        'duration_seconds': durationSeconds,
        'card_updates': cardUpdates,
      };

      final response = await http
          .post(uri, headers: authHeaders, body: json.encode(payload))
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to log review (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Record review'));
    }
  }

  /// Add a custom flashcard to an existing deck
  static Future<FlashcardModel> addCustomCard({
    required String deckId,
    required String front,
    required String back,
    String? hint,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/decks/$deckId/cards');
      final payload = <String, dynamic>{
        'front': front,
        'back': back,
      };
      if (hint != null && hint.isNotEmpty) payload['hint'] = hint;

      final response = await http
          .post(uri, headers: authHeaders, body: json.encode(payload))
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return FlashcardModel.fromJson(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to add card (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Add custom card'));
    }
  }

  /// Delete a flashcard deck from PostgreSQL
  static Future<void> deleteFlashcardDeck(String deckId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/flashcards/decks/$deckId');
      final response = await http.delete(uri, headers: authHeaders).timeout(requestTimeout);

      if (response.statusCode != 200) {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Failed to delete deck (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(cleanErrorMessage(e, 'Delete flashcard deck'));
    }
  }
}
