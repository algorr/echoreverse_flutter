import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/subscription_service.dart';
import '../services/rate_service.dart';
import '../screens/paywall_screen.dart';
import '../screens/settings_screen.dart';
import '../data/challenge_words.dart';
import '../utils/snackbar_helper.dart';
import 'visualizer.dart';
import 'effects_panel.dart';
import 'library_modal.dart';

/// Main recorder screen matching the React MainRecorder component
class MainRecorder extends StatefulWidget {
  const MainRecorder({super.key});

  @override
  State<MainRecorder> createState() => _MainRecorderState();
}

class _MainRecorderState extends State<MainRecorder>
    with TickerProviderStateMixin {
  // State
  AppState _appState = AppState.idle;
  AppMode _appMode = AppMode.standard; // Add mode state
  int? _challengeScore; // New score state
  String? _error;
  String? _playbackType; // 'original' or 'reversed'
  double _recordingDuration = 0;

  // Library
  final List<StoredRecording> _library = [];
  String? _currentRecordingId;

  // Challenge Mode
  late List<String> _challenges;
  late String _currentChallenge;

  // Effects
  EffectType _selectedEffect = EffectType.none;
  bool _showEffects = false;

  // Audio
  late AudioService _audioService;
  Timer? _timer;

  // Speech Recognition for Challenge mode
  late SpeechService _speechService;
  String _recognizedText = '';

  // Subscription
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RateService _rateService = RateService();

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _effectsPanelController;
  late AnimationController _ghostController;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _speechService = SpeechService();
    _speechService.initialize(); // Pre-initialize speech recognition

    _challenges = List<String>.from(ChallengeWords.english);
    _challenges.shuffle();
    _currentChallenge = _challenges.first;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _effectsPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for playback completion
    _audioService.playerStateStream.listen((state) {
      if (state.processingState.name == 'completed') {
        setState(() {
          _appState = AppState.ready;
          _playbackType = null;
        });
      }
    });

    // Ghost Radar Animation
    _ghostController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Load localized challenge words
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChallengeWords();
    });
  }

  void _loadChallengeWords() {
    final locale = View.of(context).platformDispatcher.locale;
    final languageCode = locale.languageCode;
    setState(() {
      _challenges = List<String>.from(ChallengeWords.getWords(languageCode));
      _challenges.shuffle();
      _currentChallenge = _challenges.first;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _effectsPanelController.dispose();
    _ghostController.dispose();
    _audioService.dispose();
    _speechService.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _getStatusText() {
    switch (_appState) {
      case AppState.idle:
        return 'TAP TO RECORD';
      case AppState.recording:
        return 'LISTENING...';
      case AppState.processing:
        return 'INVERTING TIME...';
      case AppState.ready:
        return 'SESSION CAPTURED';
      case AppState.playing:
        return _playbackType == 'reversed'
            ? 'PLAYING REVERSED'
            : 'PLAYING ORIGINAL';
    }
  }

  Future<void> _startRecording() async {
    // Check subscription based on mode
    if (_appMode == AppMode.standard) {
      final canRecord = await _subscriptionService.canRecord();
      if (!canRecord) {
        _showPaywall();
        return;
      }
    } else if (_appMode == AppMode.challenge) {
      final canPlay = await _subscriptionService.canPlayChallenge();
      if (!canPlay) {
        _showPaywall();
        return;
      }
    }

    // Optimistic UI update to remove delay
    setState(() {
      _appState = AppState.recording;
      _error = null;
      _playbackType = null;
      _currentRecordingId = null;
      _recordingDuration = 0;
      _challengeScore = null; // Reset score
      _recognizedText = ''; // Reset recognized text
    });

    try {
      // Check permission
      final hasPermission = await _audioService.hasPermission();
      if (!hasPermission) {
        setState(() {
          _appState = AppState.idle;
          _error = 'Please allow microphone access in Settings.';
        });
        return;
      }

      await _audioService.startRecording();

      // Start speech recognition for Challenge mode
      if (_appMode == AppMode.challenge) {
        // Get locale for speech recognition
        if (!mounted) return;
        final locale = View.of(context).platformDispatcher.locale;
        final localeId =
            '${locale.languageCode}-${locale.countryCode ?? locale.languageCode.toUpperCase()}';

        await _speechService.startListening(
          onResult: (text) {
            setState(() {
              _recognizedText = text;
            });
          },
          localeId: localeId,
        );
      }

      // Start timer
      final startTime = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {
          _recordingDuration =
              DateTime.now().difference(startTime).inMilliseconds / 1000;
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Recording failed: $e';
        _appState = AppState.idle;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_appState != AppState.recording) return;

    setState(() {
      _appState = AppState.processing;
    });

    _timer?.cancel();

    // Stop speech recognition for Challenge mode
    if (_appMode == AppMode.challenge) {
      await _speechService.stopListening();
    }

    try {
      final originalPath = await _audioService.stopRecording();
      if (originalPath == null) throw Exception('No audio data');

      final reversedPath = await _audioService.reverseAudio(originalPath);

      // Save to library
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final recording = StoredRecording(
        id: newId,
        timestamp: DateTime.now(),
        duration: _recordingDuration,
        originalPath: originalPath,
        reversedPath: reversedPath,
      );

      // Increment usage counter based on mode
      if (_appMode == AppMode.standard) {
        await _subscriptionService.incrementStudioRecordCount();
      } else if (_appMode == AppMode.challenge) {
        await _subscriptionService.incrementChallengePlayCount();
      }

      // Track action and show rate dialog if needed
      await _rateService.trackActionAndShowRateIfNeeded();

      setState(() {
        _library.insert(0, recording);
        _currentRecordingId = newId;
        _appState = AppState.ready;

        _selectedEffect = EffectType.none;

        // Calculate Challenge Score using real speech recognition
        if (_appMode == AppMode.challenge) {
          // Use the recognized text to calculate similarity with challenge word
          _challengeScore = SpeechService.calculateSimilarity(
            _recognizedText,
            _currentChallenge,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Recording failed: $e';
        _appState = AppState.idle;
      });
    }
  }

  Future<void> _playAudio(String type) async {
    final recording = _library.firstWhere(
      (r) => r.id == _currentRecordingId,
      orElse: () => throw Exception('Recording not found'),
    );

    setState(() {
      _playbackType = type;
      _appState = AppState.playing;
    });

    final path = type == 'reversed'
        ? recording.reversedPath
        : recording.originalPath;

    await _audioService.playAudio(path, _selectedEffect);
  }

  Future<void> _stopPlayback() async {
    await _audioService.stopPlayback();
    setState(() {
      _appState = AppState.ready;
      _playbackType = null;
    });
  }

  Future<void> _handleReset() async {
    // Stop playback directly service to avoid state conflict
    await _audioService.stopPlayback();

    // Cancel any active timer
    _timer?.cancel();

    setState(() {
      _currentRecordingId = null;
      _recordingDuration = 0;
      _appState = AppState.idle;
      _error = null;
      _playbackType = null;
      _showEffects = false;
      _selectedEffect = EffectType.none;
    });
  }

  void _showPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PaywallScreen(),
      ),
    );
  }

  Future<void> _saveToArchive() async {
    if (_currentRecordingId == null) return;
    if (_selectedEffect == EffectType.none) {
      AppSnackBar.show(context, message: 'Please select an effect first', type: SnackBarType.warning);
      return;
    }

    final recording = _library.firstWhere(
      (r) => r.id == _currentRecordingId,
      orElse: () => throw Exception('Recording not found'),
    );

    try {
      // Export reversed audio with current effect
      final exportedReversedPath = await _audioService.exportWithEffect(
        recording.reversedPath,
        _selectedEffect,
      );

      // Export original audio with current effect
      final exportedOriginalPath = await _audioService.exportWithEffect(
        recording.originalPath,
        _selectedEffect,
      );

      // Create new recording entry with effect label
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRecording = StoredRecording(
        id: newId,
        timestamp: DateTime.now(),
        duration: recording.duration,
        originalPath: exportedOriginalPath,
        reversedPath: exportedReversedPath,
        effectLabel: _selectedEffect.label,
      );

      setState(() {
        _library.insert(0, newRecording);
      });

      if (mounted) {
        AppSnackBar.show(context, message: 'Saved with ${_selectedEffect.label} effect', type: SnackBarType.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: 'Save failed: $e', type: SnackBarType.error);
      }
    }
  }

  void _loadRecording(StoredRecording recording) {
    _stopPlayback();
    setState(() {
      _currentRecordingId = recording.id;
      _recordingDuration = recording.duration;
      _appState = AppState.ready;
    });
    Navigator.pop(context);
  }

  void _deleteRecording(String id) {
    setState(() {
      _library.removeWhere((r) => r.id == id);
      if (_currentRecordingId == id) {
        _handleReset();
      }
    });
  }

  void _showLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LibraryModal(
        recordings: _library,
        currentRecordingId: _currentRecordingId,
        onRecordingSelected: _loadRecording,
        onDeleteRecording: _deleteRecording,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Background blobs
          _buildBackgroundBlobs(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Challenge Card (Overlay)
                if (_appMode == AppMode.challenge) _buildChallengeCard(),

                // Score Overlay
                if (_appMode == AppMode.challenge &&
                    _appState == AppState.ready &&
                    _challengeScore != null)
                  _buildScoreResult(),

                // Wave Share Card
                if (_appMode == AppMode.waveShare) _buildWaveShareCard(),

                // Visualizer (hidden in Wave Share mode and Challenge score view)
                if (_appMode != AppMode.waveShare &&
                    !(_appMode == AppMode.challenge &&
                        _appState == AppState.ready &&
                        _challengeScore != null))
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Visualizer (Always visible but styled differently in Ghost mode)
                        Visualizer(
                          isActive:
                              _appState == AppState.recording ||
                              _appState == AppState.playing,
                        ),
                      ],
                    ),
                  ),

                // Effects Panel
                if (_showEffects)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, (1 - value) * 40),
                        child: Opacity(
                          opacity: value,
                          child: EffectsPanel(
                            selectedEffect: _selectedEffect,
                            onEffectSelected: (effect) async {
                              setState(() {
                                _selectedEffect = effect;
                              });
                              // Track effect usage for rate dialog (only non-none effects)
                              if (effect != EffectType.none) {
                                await _rateService.trackActionAndShowRateIfNeeded();
                              }
                            },
                            onClose: () {
                              setState(() {
                                _showEffects = false;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Controls (hidden in Encoder mode - has its own UI)
                if (_appMode != AppMode.waveShare) _buildControls(),

                if (_appMode != AppMode.waveShare) const SizedBox(height: 40),
              ],
            ),
          ),

          // Error notification
          if (_error != null) _buildErrorNotification(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(AppMode.standard, Icons.mic_rounded, 'STUDIO'),
            _buildNavItem(
              AppMode.challenge,
              Icons.emoji_events_rounded,
              'CHALLENGE',
            ),
            _buildNavItem(AppMode.waveShare, Icons.graphic_eq_rounded, 'WAVE'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(AppMode mode, IconData icon, String label) {
    final isSelected = _appMode == mode;
    Color activeColor;
    Color glowColor;
    switch (mode) {
      case AppMode.standard:
        activeColor = const Color(0xFF22D3EE);
        glowColor = const Color(0xFF0891B2);
        break;
      case AppMode.challenge:
        activeColor = const Color(0xFFF59E0B);
        glowColor = const Color(0xFFD97706);
        break;
      case AppMode.waveShare:
        activeColor = const Color(0xFFD946EF); // Purple/Magenta
        glowColor = const Color(0xFFA855F7);
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _appMode = mode;
          _error = null;
          _challengeScore = null; // Reset score on mode switch
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 10,
          vertical: 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    activeColor.withValues(alpha: 0.25),
                    activeColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: isSelected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withValues(alpha: 0.15),
                      )
                    : null,
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : Colors.grey.shade600,
                  size: isSelected ? 24 : 22,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey.shade600,
                fontSize: isSelected ? 9 : 8,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    Color primaryColor;
    Color secondaryColor;

    switch (_appMode) {
      case AppMode.standard:
        primaryColor = const Color(0xFF22D3EE); // Cyan
        secondaryColor = const Color(0xFFD946EF); // Magenta
        break;
      case AppMode.challenge:
        primaryColor = const Color(0xFFF59E0B); // Amber
        secondaryColor = const Color(0xFFEF4444); // Red
        break;
      case AppMode.waveShare:
        primaryColor = const Color(0xFFD946EF); // Purple
        secondaryColor = const Color(0xFF06B6D4); // Cyan
        break;
    }

    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: AnimatedContainer(
            duration: const Duration(seconds: 1),
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _appState == AppState.recording
                      ? Colors.red.withValues(alpha: 0.3)
                      : secondaryColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: AnimatedContainer(
            duration: const Duration(seconds: 1),
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _appState == AppState.playing
                      ? primaryColor.withValues(alpha: 0.3)
                      : primaryColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Settings, Logo, Library buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Settings button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF22D3EE),
                    size: 22,
                  ),
                ),
              ),

              const Spacer(),

              // Logo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.waves, color: Color(0xFF22D3EE), size: 20),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF22D3EE), Color(0xFFD946EF)],
                      ).createShader(bounds),
                      child: const Text(
                        'REVERSO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Library button
              GestureDetector(
                onTap: _showLibrary,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Color(0xFF22D3EE),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Status text
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: const Color(0xFF22D3EE).withValues(alpha: 0.6),
            ),
          ),

          // Timer
          if (_appState != AppState.idle)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _formatTime(_recordingDuration),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        if (_appState == AppState.idle ||
            _appState == AppState.recording ||
            _appState == AppState.processing)
          _buildRecordButton()
        else
          _buildPlaybackControls(),
      ],
    );
  }

  Widget _buildRecordButton() {
    final isRecording = _appState == AppState.recording;

    return GestureDetector(
      onTap: isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isRecording
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
              ),
              boxShadow: isRecording
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(
                          alpha: 0.3 + _pulseController.value * 0.2,
                        ),
                        blurRadius: 30 + _pulseController.value * 20,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 30,
                      ),
                    ],
            ),
            child: Center(
              child: isRecording
                  ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.8),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          colors: [Color(0xFF22D3EE), Color(0xFFD946EF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFD946EF,
                            ).withValues(alpha: 0.8),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reverse play
        _buildPlayButton(
          'reversed',
          Icons.arrow_back,
          const Color(0xFFD946EF),
          'REV',
        ),

        const SizedBox(width: 12),

        // Effects toggle
        _buildSmallButton(
          icon: Icons.auto_fix_high,
          isActive: _showEffects || _selectedEffect != EffectType.none,
          label: _selectedEffect != EffectType.none
              ? _selectedEffect.label.toUpperCase()
              : 'FX',
          onTap: () {
            setState(() {
              _showEffects = !_showEffects;
            });
          },
        ),

        const SizedBox(width: 6),

        // Save to Archive
        _buildSmallButton(
          icon: Icons.save_alt,
          isActive: false,
          label: 'SAVE',
          onTap: _saveToArchive,
        ),

        const SizedBox(width: 6),

        // Reset
        _buildSmallButton(
          icon: Icons.refresh,
          isActive: false,
          label: 'NEW',
          onTap: _handleReset,
        ),

        const SizedBox(width: 12),

        // Original play
        _buildPlayButton(
          'original',
          Icons.play_arrow,
          const Color(0xFF22D3EE),
          'ORG',
        ),
      ],
    );
  }

  Widget _buildPlayButton(
    String type,
    IconData icon,
    Color color,
    String label,
  ) {
    final isActive = _appState == AppState.playing && _playbackType == type;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => isActive ? _stopPlayback() : _playAudio(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isActive
                  ? color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive ? color : Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 40,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isActive ? Icons.stop : icon,
              size: 24,
              color: isActive ? color : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.2)
                  : const Color(0xFF18181B),
              border: Border.all(
                color: isActive ? const Color(0xFF22D3EE) : Colors.grey[800]!,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF22D3EE) : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard() {
    final bool isCompact = _challengeScore != null;

    if (isCompact) {
      // Compact version when score is shown
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD946EF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TARGET: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '"$_currentChallenge"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD946EF),
              ),
            ),
          ],
        ),
      );
    }

    // Full version
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B2E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFD946EF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'HIDDEN MESSAGE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Can you reverse it right?',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD946EF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'TARGET PHRASE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD946EF),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '"$_currentChallenge"',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentChallenge = (_challenges..shuffle()).first;
                  });
                },
                child: Icon(
                  Icons.refresh,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              AppSnackBar.show(context, message: 'Playing target audio (Simulated)...', type: SnackBarType.info);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD946EF), Color(0xFFF43F5E)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD946EF).withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Listen Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreResult() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: (_challengeScore ?? 0) / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF10B981),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_challengeScore%',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'MATCH!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _handleReset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveShareCard() {
    final selectedRecording = _library.isNotEmpty
        ? _library.firstWhere(
            (r) => r.id == _currentRecordingId,
            orElse: () => _library.first,
          )
        : null;

    return Expanded(
      child: _library.isEmpty
          ? _buildEmptyLibraryState()
          : Column(
              children: [
                // Big Spectral Visualization
                if (selectedRecording != null)
                  _buildBigSpectralVisualization(selectedRecording),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD946EF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.graphic_eq,
                              color: Color(0xFFD946EF),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SELECT TO SHARE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD946EF),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_library.length} recording${_library.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Recordings List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _library.length,
                    itemBuilder: (context, index) {
                      final recording = _library[index];
                      final isSelected = _currentRecordingId == recording.id;
                      return _buildWaveRecordingItem(recording, isSelected);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBigSpectralVisualization(StoredRecording recording) {
    return Container(
      height: 220,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD946EF).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD946EF).withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                    const Color(0xFF0A0A0F),
                  ],
                ),
              ),
            ),
          ),
          // Organic Wave Mesh Visualization
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AnimatedBuilder(
                animation: _ghostController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WaveMeshPainter(
                      animationValue: _ghostController.value,
                      seed: recording.id.hashCode,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          // Share button overlay
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                AppSnackBar.show(context, message: 'Share feature coming soon!', type: SnackBarType.info);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD946EF), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD946EF).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.share, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Duration badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatTime(recording.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibraryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD946EF).withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: Color(0xFFD946EF),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Recordings Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record in STUDIO mode first,\nthen share your fun waveforms!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _appMode = AppMode.standard),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD946EF), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Go to Studio',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveRecordingItem(StoredRecording recording, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRecordingId = recording.id;
          _appState = AppState.ready;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD946EF).withValues(alpha: 0.15)
              : const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD946EF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Waveform Preview
                Expanded(child: _buildMiniWaveform(recording, isSelected)),
                const SizedBox(width: 12),
                // Duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(recording.duration),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFFD946EF)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(recording.timestamp),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _playAudio('reversed'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AppSnackBar.show(context, message: 'Share feature coming soon!', type: SnackBarType.info);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD946EF), Color(0xFFA855F7)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.share, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniWaveform(StoredRecording recording, bool isSelected) {
    return SizedBox(
      height: 40,
      width: 120,
      child: AnimatedBuilder(
        animation: _ghostController,
        builder: (context, child) {
          return CustomPaint(
            painter: _WeirdShapePainter(
              seed: recording.id.hashCode,
              animationValue: _ghostController.value,
              isPlaying: isSelected && _appState == AppState.playing,
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildErrorNotification() {
    return Positioned.fill(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SYSTEM ERROR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _error = null),
                child: Text(
                  'DISMISS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveMeshPainter extends CustomPainter {
  final double animationValue;
  final int seed;

  _WaveMeshPainter({required this.animationValue, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centerY = size.height / 2;

    // Create organic mesh effect with multiple sine waves
    for (int i = 0; i < 12; i++) {
      // Calculate color based on index for rainbow effect
      final hue = (i / 12) * 360;
      final color = HSVColor.fromAHSV(0.8, hue, 0.8, 1.0).toColor();
      paint.color = color;

      final path = Path();
      final phaseOffset = (i * 0.5) + (seed % 10);

      // Draw horizontal wave lines
      for (double x = 0; x <= size.width; x += 5) {
        // Complex wave formula for organic look
        final normalizedX = x / size.width;

        // Primary wave component
        final y1 =
            30 *
            math.sin(
              (normalizedX * 4 * math.pi) +
                  (animationValue * 2 * math.pi) +
                  phaseOffset,
            );

        // Secondary wave component for complexity
        final y2 =
            15 *
            math.sin(
              (normalizedX * 8 * math.pi) -
                  (animationValue * 4 * math.pi) +
                  (i * 0.2),
            );

        // Vertical modulation (makes it look like a 3D sphere/shape)
        final envelope = math.sin(
          normalizedX * math.pi,
        ); // 0 at ends, 1 in center

        final y = centerY + ((y1 + y2) * envelope);

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }

    // Draw vertical mesh lines for 3D effect
    paint.strokeWidth = 0.5;
    paint.color = Colors.white.withValues(alpha: 0.1);

    for (double x = 20; x < size.width; x += 20) {
      final path = Path();
      final normalizedX = x / size.width;
      final envelope = math.sin(normalizedX * math.pi);

      if (envelope < 0.1) continue; // Skip edges for cleaner look

      for (int i = 0; i <= 12; i++) {
        final phaseOffset = (i * 0.5) + (seed % 10);
        final y1 =
            30 *
            math.sin(
              (normalizedX * 4 * math.pi) +
                  (animationValue * 2 * math.pi) +
                  phaseOffset,
            );
        final y2 =
            15 *
            math.sin(
              (normalizedX * 8 * math.pi) -
                  (animationValue * 4 * math.pi) +
                  (i * 0.2),
            );
        final y = centerY + ((y1 + y2) * envelope);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveMeshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.seed != seed;
  }
}

class _WeirdShapePainter extends CustomPainter {
  final int seed;
  final double animationValue;
  final bool isPlaying;

  _WeirdShapePainter({
    required this.seed,
    this.animationValue = 0,
    this.isPlaying = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final shapeType = random.nextInt(
      5,
    ); // 0: Spiral, 1: Star, 2: Blob, 3: Noise, 4: Geometric
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(size.width, size.height) / 2;

    // Unique Color Palette
    final hue = random.nextDouble() * 360;
    final color1 = HSVColor.fromAHSV(1.0, hue, 0.8, 1.0).toColor();
    final color2 = HSVColor.fromAHSV(
      1.0,
      (hue + 180) % 360,
      0.8,
      1.0,
    ).toColor();

    paint.shader = LinearGradient(
      colors: [color1, color2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    if (shapeType == 0) {
      // SPIRAL
      final path = Path();
      final turns = 3 + random.nextInt(3);
      for (double i = 0; i < maxRadius; i += 0.5) {
        final angle =
            (i / maxRadius) * turns * 2 * math.pi +
            (isPlaying ? animationValue * 5 : 0);
        final x = centerX + i * math.cos(angle);
        final y = centerY + i * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    } else if (shapeType == 1) {
      // STAR / POLYGON
      final path = Path();
      final points = 3 + random.nextInt(8);
      final innerRadius = maxRadius * (0.3 + random.nextDouble() * 0.4);
      final rotation = isPlaying ? animationValue * 2 * math.pi : 0.0;

      for (int i = 0; i < points * 2; i++) {
        final radius = i.isEven ? maxRadius : innerRadius;
        final angle = (i / (points * 2)) * 2 * math.pi + rotation;
        final x = centerX + radius * math.cos(angle);
        final y = centerY + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 2) {
      // BLOB
      final path = Path();
      final points = 8 + random.nextInt(8);

      for (int i = 0; i <= points; i++) {
        final angle =
            (i / points) * 2 * math.pi + (isPlaying ? animationValue : 0);
        // Noise in radius
        final rNoise = math.sin(angle * 3 + seed) * 10;
        final radius = maxRadius * 0.8 + rNoise;

        final x = centerX + radius * math.cos(angle);
        final y = centerY + radius * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 3) {
      // NOISE WAVE
      final path = Path();
      paint.strokeWidth = 1.5;

      for (double x = 0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;
        final yBase = centerY;
        final noise =
            math.sin(normalizedX * 10 + seed) *
            math.cos(normalizedX * 20 + (isPlaying ? animationValue * 10 : 0));
        final y = yBase + (noise * maxRadius * 0.8);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    } else {
      // GEOMETRIC RANDOM
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);

      // Add a circle
      canvas.drawCircle(Offset(centerX, centerY), maxRadius * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_WeirdShapePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}
