import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/note.dart';
import '../models/quiz_question.dart';

class ApiService {
  // Default to 127.0.0.1:8000 which works on physical phone over USB with `adb reverse tcp:8000 tcp:8000`
  static String baseUrl = 'http://127.0.0.1:8000';
  static const Duration requestTimeout = Duration(seconds: 45);

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

  /// Upload in-memory bytes and extract text
  static Future<Map<String, dynamic>> extractFromBytes(
      List<int> bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/api/files/extract');
      final request = http.MultipartRequest('POST', uri);
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
    } on TimeoutException {
      throw Exception('Extraction timed out. Try a smaller file or shorter section.');
    } on SocketException {
      throw Exception('Network error: Unable to connect to backend at $baseUrl. Ensure server is running.');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Extraction error: $e');
    }
  }

  /// Generate structured study notes from raw text
  static Future<NoteItem> generateNotes({
    required String text,
    String? courseCode,
    String? courseName,
    String? title,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/notes/generate');
      final payload = <String, dynamic>{'text': text};
      if (courseCode != null) payload['course_code'] = courseCode;
      if (courseName != null) payload['course_name'] = courseName;
      if (title != null) payload['title'] = title;

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
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
    } on SocketException {
      throw Exception('Cannot connect to backend at $baseUrl.');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Note generation error: $e');
    }
  }

  /// Generate MCQs from study text
  static Future<List<QuizQuestion>> generateQuiz({
    required String text,
    int numQuestions = 5,
    String? noteTitle,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/quiz/generate');
      final payload = <String, dynamic>{
        'text': text,
        'num_questions': numQuestions,
      };
      if (noteTitle != null) payload['note_title'] = noteTitle;

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
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
    } on SocketException {
      throw Exception('Cannot connect to backend at $baseUrl.');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Quiz generation error: $e');
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
            headers: {'Content-Type': 'application/json'},
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
    } on SocketException {
      throw Exception('Cannot connect to backend at $baseUrl.');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Chat error: $e');
    }
  }
}
