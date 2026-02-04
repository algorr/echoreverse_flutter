import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  String _recognizedText = '';
  bool _isListening = false;

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  bool get isAvailable => _isInitialized;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _isListening = false;
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String) onResult,
    String localeId = 'en-US',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    _recognizedText = '';
    _isListening = true;

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        _recognizedText = result.recognizedWords;
        onResult(_recognizedText);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.confirmation,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    await _speechToText.stop();
  }

  /// Cancel listening
  Future<void> cancel() async {
    _isListening = false;
    await _speechToText.cancel();
  }

  /// Calculate similarity score between spoken text and target text
  /// Returns a percentage (0-100)
  static int calculateSimilarity(String spoken, String target) {
    if (spoken.isEmpty) return 0;

    final spokenLower = spoken.toLowerCase().trim();
    final targetLower = target.toLowerCase().trim();

    // Exact match
    if (spokenLower == targetLower) {
      return 100;
    }

    // Check if target is contained in spoken text
    if (spokenLower.contains(targetLower)) {
      return 95;
    }

    // Check if spoken is contained in target (partial word)
    if (targetLower.contains(spokenLower)) {
      return 80;
    }

    // Calculate Levenshtein distance based similarity
    final distance = _levenshteinDistance(spokenLower, targetLower);
    final maxLength = spokenLower.length > targetLower.length
        ? spokenLower.length
        : targetLower.length;

    if (maxLength == 0) return 0;

    final similarity = ((1 - (distance / maxLength)) * 100).round();
    return similarity.clamp(0, 100);
  }

  /// Levenshtein distance algorithm for string similarity
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  void dispose() {
    _speechToText.stop();
  }
}
