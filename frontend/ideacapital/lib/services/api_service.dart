import 'package:dio/dio.dart';

/// Central API service for communicating with backend services.
/// Routes requests through Firebase Cloud Functions (which proxy to Vault/Brain).
class ApiService {
  final Dio _dio;

  ApiService({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? 'https://us-central1-ideacapital-dev.cloudfunctions.net',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        ));

  /// Set the Firebase Auth token for authenticated requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ---- Invention API ----

  /// Submit raw idea to the AI Agent for processing.
  Future<Map<String, dynamic>> submitIdea({
    String? rawText,
    String? voiceNoteUrl,
    String? sketchUrl,
  }) async {
    final response = await _dio.post('/api/inventions/analyze', data: {
      if (rawText != null) 'raw_text': rawText,
      if (voiceNoteUrl != null) 'voice_url': voiceNoteUrl,
      if (sketchUrl != null) 'sketch_url': sketchUrl,
    });
    return response.data;
  }

  /// Continue AI conversation to drill down on invention details.
  Future<Map<String, dynamic>> continueAgentChat({
    required String inventionId,
    required String message,
  }) async {
    final response = await _dio.post('/api/inventions/$inventionId/chat', data: {
      'message': message,
    });
    return response.data;
  }

  /// Publish a draft invention to the live feed.
  Future<void> publishInvention(String inventionId) async {
    await _dio.post('/api/inventions/$inventionId/publish');
  }

  // ---- Investment API ----

  /// Get investment details for a project (reads from Firestore cache).
  Future<Map<String, dynamic>> getInvestmentStatus(String inventionId) async {
    final response = await _dio.get('/api/investments/$inventionId/status');
    return response.data;
  }

  // ---- Profile API ----

  /// Update user profile.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _dio.put('/api/profile', data: data);
  }
}
