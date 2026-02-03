import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../models/app_models.dart';

/// Audio service handling recording, processing, and playback
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Uuid _uuid = const Uuid();

  String? _currentRecordingPath;
  String? _currentReversedPath;

  /// Check if recording is supported
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    final directory = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    _currentRecordingPath = path.join(directory.path, 'recording_$id.wav');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _currentRecordingPath!,
    );
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    final recordPath = await _recorder.stop();
    return recordPath;
  }

  /// Reverse the audio file
  Future<String> reverseAudio(String inputPath) async {
    final file = File(inputPath);

    if (!await file.exists()) {
      throw Exception('Audio file not found: $inputPath');
    }

    final bytes = await file.readAsBytes();

    // Parse WAV file - find the 'data' chunk
    if (bytes.length < 12) {
      throw Exception('Invalid WAV file - too small');
    }

    // Verify RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw Exception('Invalid WAV file format');
    }

    // Find the 'data' chunk
    int dataChunkPos = 12;
    int dataSize = 0;

    while (dataChunkPos < bytes.length - 8) {
      final chunkId = String.fromCharCodes(
        bytes.sublist(dataChunkPos, dataChunkPos + 4),
      );
      final chunkSize =
          bytes[dataChunkPos + 4] |
          (bytes[dataChunkPos + 5] << 8) |
          (bytes[dataChunkPos + 6] << 16) |
          (bytes[dataChunkPos + 7] << 24);

      if (chunkId == 'data') {
        dataSize = chunkSize;
        break;
      }

      // Move to next chunk (8 bytes for id + size, then chunk data)
      dataChunkPos += 8 + chunkSize;
    }

    if (dataSize == 0) {
      throw Exception('Could not find data chunk in WAV file');
    }

    // Header is everything before the audio data
    final headerSize = dataChunkPos + 8; // includes 'data' and size
    final header = Uint8List.fromList(bytes.sublist(0, headerSize));
    final audioData = bytes.sublist(headerSize, headerSize + dataSize);

    // Reverse audio samples (16-bit samples = 2 bytes each)
    final reversedAudio = Uint8List(audioData.length);
    const sampleSize = 2; // 16-bit audio
    final numSamples = audioData.length ~/ sampleSize;

    for (int i = 0; i < numSamples; i++) {
      final srcIndex = (numSamples - 1 - i) * sampleSize;
      final dstIndex = i * sampleSize;
      if (srcIndex + 1 < audioData.length &&
          dstIndex + 1 < reversedAudio.length) {
        reversedAudio[dstIndex] = audioData[srcIndex];
        reversedAudio[dstIndex + 1] = audioData[srcIndex + 1];
      }
    }

    // Create reversed file
    final directory = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    _currentReversedPath = path.join(directory.path, 'reversed_$id.wav');

    final reversedFile = File(_currentReversedPath!);
    final output = Uint8List(header.length + reversedAudio.length);
    output.setAll(0, header);
    output.setAll(header.length, reversedAudio);
    await reversedFile.writeAsBytes(output);

    return _currentReversedPath!;
  }

  /// Apply effect to audio and return processed file path
  Future<String> _applyEffect(String inputPath, EffectType effect) async {
    if (effect == EffectType.none) {
      return inputPath;
    }

    final file = File(inputPath);
    if (!await file.exists()) {
      return inputPath;
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return inputPath;

    // Parse WAV to get audio data
    final wavData = _parseWav(bytes);
    if (wavData == null) return inputPath;

    final header = wavData['header'] as Uint8List;
    final audioData = wavData['audioData'] as Uint8List;

    Uint8List processedAudio;

    switch (effect) {
      case EffectType.chipmunk:
        processedAudio = _resampleAudio(audioData, 1.5);
        break;
      case EffectType.demon:
        processedAudio = _resampleAudio(audioData, 0.6);
        break;
      case EffectType.robot:
        processedAudio = _applyRobotEffect(audioData);
        break;
      case EffectType.echo:
        processedAudio = _applyEchoEffect(audioData);
        break;
      case EffectType.underwater:
        processedAudio = _applyUnderwaterEffect(audioData);
        break;
      case EffectType.radio:
        processedAudio = _applyRadioEffect(audioData);
        break;
      case EffectType.ghost:
        processedAudio = _applyGhostEffect(audioData);
        break;
      case EffectType.none:
        processedAudio = audioData;
        break;
    }

    // Update header with new data size
    final newHeader = _updateWavHeader(header, processedAudio.length);

    // Save processed file
    final directory = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    final processedPath = path.join(directory.path, 'effect_$id.wav');

    final output = Uint8List(newHeader.length + processedAudio.length);
    output.setAll(0, newHeader);
    output.setAll(newHeader.length, processedAudio);

    await File(processedPath).writeAsBytes(output);
    return processedPath;
  }

  /// Parse WAV file and return header and audio data
  Map<String, dynamic>? _parseWav(Uint8List bytes) {
    if (bytes.length < 12) return null;

    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') return null;

    int dataChunkPos = 12;
    int dataSize = 0;

    while (dataChunkPos < bytes.length - 8) {
      final chunkId = String.fromCharCodes(
        bytes.sublist(dataChunkPos, dataChunkPos + 4),
      );
      final chunkSize =
          bytes[dataChunkPos + 4] |
          (bytes[dataChunkPos + 5] << 8) |
          (bytes[dataChunkPos + 6] << 16) |
          (bytes[dataChunkPos + 7] << 24);

      if (chunkId == 'data') {
        dataSize = chunkSize;
        break;
      }
      dataChunkPos += 8 + chunkSize;
    }

    if (dataSize == 0) return null;

    final headerSize = dataChunkPos + 8;
    return {
      'header': Uint8List.fromList(bytes.sublist(0, headerSize)),
      'audioData': Uint8List.fromList(
        bytes.sublist(headerSize, headerSize + dataSize),
      ),
    };
  }

  /// Update WAV header with new data size
  Uint8List _updateWavHeader(Uint8List header, int newDataSize) {
    final newHeader = Uint8List.fromList(header);

    // Update file size (offset 4, little endian)
    final fileSize = newDataSize + header.length - 8;
    newHeader[4] = fileSize & 0xFF;
    newHeader[5] = (fileSize >> 8) & 0xFF;
    newHeader[6] = (fileSize >> 16) & 0xFF;
    newHeader[7] = (fileSize >> 24) & 0xFF;

    // Update data chunk size (last 4 bytes of header)
    final dataSizeOffset = header.length - 4;
    newHeader[dataSizeOffset] = newDataSize & 0xFF;
    newHeader[dataSizeOffset + 1] = (newDataSize >> 8) & 0xFF;
    newHeader[dataSizeOffset + 2] = (newDataSize >> 16) & 0xFF;
    newHeader[dataSizeOffset + 3] = (newDataSize >> 24) & 0xFF;

    return newHeader;
  }

  /// Resample audio for pitch shifting with Linear Interpolation
  Uint8List _resampleAudio(Uint8List audioData, double factor) {
    // 16-bit signed integer stereo/mono handling
    // Assuming mono for now based on recording settings (numChannels: 1)
    final numSamples = audioData.length ~/ 2;
    final newNumSamples = (numSamples / factor).floor();
    final result = Uint8List(newNumSamples * 2);

    for (int i = 0; i < newNumSamples; i++) {
      final double srcIndex = i * factor;
      final int index0 = srcIndex.floor();
      final int index1 = (index0 + 1).clamp(0, numSamples - 1);
      final double t = srcIndex - index0;

      // Read 16-bit samples
      int val0 = audioData[index0 * 2] | (audioData[index0 * 2 + 1] << 8);
      if (val0 > 32767) val0 -= 65536;

      int val1 = audioData[index1 * 2] | (audioData[index1 * 2 + 1] << 8);
      if (val1 > 32767) val1 -= 65536;

      // Linear Interpolation
      final double interpolated = val0 + (val1 - val0) * t;
      final int finalVal = interpolated.toInt().clamp(-32768, 32767);

      result[i * 2] = finalVal & 0xFF;
      result[i * 2 + 1] = (finalVal >> 8) & 0xFF;
    }

    return result;
  }

  /// Apply robot effect using Sine Wave Ring Modulation
  Uint8List _applyRobotEffect(Uint8List audioData) {
    final result = Uint8List(audioData.length);
    const double frequency =
        50.0; // Higher frequency for more "metallic" robot sound
    const double sampleRate = 44100.0;

    for (int i = 0; i < audioData.length ~/ 2; i++) {
      int sample = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;

      // Ring Modulation with Sine Wave
      // Multiplies the signal by a sine wave carrier
      final double modulator = math.sin(
        2 * math.pi * frequency * i / sampleRate,
      );

      // Mix original with modulated for intelligible robot voice
      // 0.8 modulated + 0.2 original
      final int newSample = (sample * modulator * 0.9).toInt().clamp(
        -32768,
        32767,
      );

      result[i * 2] = newSample & 0xFF;
      result[i * 2 + 1] = (newSample >> 8) & 0xFF;
    }

    return result;
  }

  /// Apply echo effect with Feedback Loop
  Uint8List _applyEchoEffect(Uint8List audioData) {
    const int delayMs = 300;
    const int delaySamples = (44100 * delayMs) ~/ 1000;
    const double decay = 0.4;

    // We need a buffer to store the output for feedback
    // Creating a copy of input to work on
    final Int16List samples = Int16List(audioData.length ~/ 2);
    for (int i = 0; i < samples.length; i++) {
      int val = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
      if (val > 32767) val -= 65536;
      samples[i] = val;
    }

    // Apply delay with feedback
    for (int i = 0; i < samples.length; i++) {
      if (i >= delaySamples) {
        // sample = current + processed_sample_from_past * decay
        double processed = samples[i] + samples[i - delaySamples] * decay;
        samples[i] = processed.toInt().clamp(-32768, 32767);
      }
    }

    // Convert back to bytes
    final result = Uint8List(audioData.length);
    for (int i = 0; i < samples.length; i++) {
      result[i * 2] = samples[i] & 0xFF;
      result[i * 2 + 1] = (samples[i] >> 8) & 0xFF;
    }

    return result;
  }

  /// Apply underwater effect using Biquad Low Pass Filter
  Uint8List _applyUnderwaterEffect(Uint8List audioData) {
    const double cutoff = 400.0; // Cut off everything above 400Hz
    const double sampleRate = 44100.0;
    const double q = 1.0; // Quality factor

    // Biquad coefficients for Low Pass
    // Based on RBJ Cookbook formulas
    final w0 = 2 * math.pi * cutoff / sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final cosW0 = math.cos(w0);

    final b0 = (1 - cosW0) / 2;
    final b1 = 1 - cosW0;
    final b2 = (1 - cosW0) / 2;
    final a0 = 1 + alpha;
    final a1 = -2 * cosW0;
    final a2 = 1 - alpha;

    // Normalize coefficients
    final nb0 = b0 / a0;
    final nb1 = b1 / a0;
    final nb2 = b2 / a0;
    final na1 = a1 / a0;
    final na2 = a2 / a0;

    double x1 = 0, x2 = 0; // Previous inputs
    double y1 = 0, y2 = 0; // Previous outputs

    final result = Uint8List(audioData.length);

    for (int i = 0; i < audioData.length ~/ 2; i++) {
      int sample = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;

      // Difference equation
      double output = nb0 * sample + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2;

      // Shift states
      x2 = x1;
      x1 = sample.toDouble();
      y2 = y1;
      y1 = output;

      // Amplify slightly to compensate for volume loss
      int finalVal = (output * 2.0).toInt().clamp(-32768, 32767);
      result[i * 2] = finalVal & 0xFF;
      result[i * 2 + 1] = (finalVal >> 8) & 0xFF;
    }

    return result;
  }

  /// Apply radio effect (Band Pass + Noise + Distortion)
  Uint8List _applyRadioEffect(Uint8List audioData) {
    // 1. Band Pass Filter (keep 500Hz - 3000Hz)
    // Simplified State Variable Filter approximation for bandpass
    double low = 0, band = 0;
    const double f = 0.15; // Tuning related to cutoff
    const double q = 0.5; // Resonance

    final result = Uint8List(audioData.length);
    final random = math.Random();

    for (int i = 0; i < audioData.length ~/ 2; i++) {
      int sample = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;

      // 1. Add white noise (static)
      // noise is quiet, random value between -800 and 800
      double noise = (random.nextDouble() - 0.5) * 1000;
      double noisySample = sample + noise;

      // 2. Bandpass Filter
      low += f * band;
      double high = noisySample - low - q * band;
      band += f * high;
      // band is the bandpass output

      // 3. Distortion / Clipping (Overdrive)
      // Hard clipping anything above threshold
      double distorted = band * 3.5; // Gain up
      if (distorted > 20000) distorted = 20000;
      if (distorted < -20000) distorted = -20000;

      int finalVal = distorted.toInt().clamp(-32768, 32767);

      result[i * 2] = finalVal & 0xFF;
      result[i * 2 + 1] = (finalVal >> 8) & 0xFF;
    }

    return result;
  }

  /// Apply ghost effect (Chain: Radio -> Demon -> Echo)
  Uint8List _applyGhostEffect(Uint8List audioData) {
    // 1. Add noise and distortion
    final noisy = _applyRadioEffect(audioData);

    // 2. Pitch down (Demon) - make it slower/creepier
    final pitched = _resampleAudio(noisy, 0.75);

    // 3. Add heavy reverb/echo
    return _applyEchoEffect(pitched);
  }

  /// Play audio file with optional effect
  Future<void> playAudio(String filePath, EffectType effect) async {
    await _player.stop();

    // Apply effect to audio file
    final processedPath = await _applyEffect(filePath, effect);

    await _player.setFilePath(processedPath);
    await _player.setSpeed(1.0);
    _player.play();
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  /// Get player stream for completion events
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Get current reversed path
  String? get currentReversedPath => _currentReversedPath;

  /// Dispose resources
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
