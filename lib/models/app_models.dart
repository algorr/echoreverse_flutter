/// App State enum matching React implementation
enum AppState { idle, recording, processing, ready, playing }

/// Operation Modes
enum AppMode { standard, challenge, waveShare }

/// Extension to get display details for modes
extension AppModeExtension on AppMode {
  String get label {
    switch (this) {
      case AppMode.standard:
        return 'STUDIO';
      case AppMode.challenge:
        return 'CHALLENGE';
      case AppMode.waveShare:
        return 'WAVE';
    }
  }
}

/// Effect types available for audio processing
enum EffectType { none, chipmunk, demon, robot, echo, underwater, radio, ghost }

/// Extension to get display labels for effects
extension EffectTypeExtension on EffectType {
  String get label {
    switch (this) {
      case EffectType.none:
        return 'Clean';
      case EffectType.chipmunk:
        return 'Chipmunk';
      case EffectType.demon:
        return 'Demon';
      case EffectType.robot:
        return 'Robot';
      case EffectType.echo:
        return 'Cosmos';
      case EffectType.underwater:
        return 'Deep Sea';
      case EffectType.radio:
        return 'Radio';
      case EffectType.ghost:
        return 'Ghost';
    }
  }
}

/// Stored recording model
class StoredRecording {
  final String id;
  final DateTime timestamp;
  final double duration;
  final String originalPath;
  final String reversedPath;

  StoredRecording({
    required this.id,
    required this.timestamp,
    required this.duration,
    required this.originalPath,
    required this.reversedPath,
  });
}
