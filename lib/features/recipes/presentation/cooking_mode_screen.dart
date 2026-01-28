import 'dart:async';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class CookingModeScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final int servings;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;

  int _currentStep = 0;
  List<String> _steps = [];
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _ttsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSteps();
    _initWakelock();
    _initTts();
    _initSpeech();
  }

  void _loadSteps() {
    final raw = widget.recipe['instructions'];
    if (raw is List) {
      _steps = raw.map((e) => e.toString()).toList();
    }
  }

  Future<void> _initWakelock() async {
    await WakelockPlus.enable();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slower for instructions
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      // Auto-listen after speaking? Maybe annoying. Let user trigger.
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });

    // Auto-speak first step after a delay
    Future.delayed(const Duration(seconds: 1), _speakCurrentStep);
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (mounted) {
            // print('onStatus: $val');
            if (val == 'done' || val == 'notListening') {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
          // print('onError: $val');
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              _processVoiceCommand(val.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 3),
        );
      } else {
        if (mounted)
          NanoToast.showInfo(context, "Speech recognition not available");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _processVoiceCommand(String text) {
    final cmd = text.toLowerCase();
    if (cmd.contains('next')) {
      _nextStep();
    } else if (cmd.contains('back') || cmd.contains('previous')) {
      _prevStep();
    } else if (cmd.contains('repeat') || cmd.contains('again')) {
      _speakCurrentStep();
    } else if (cmd.contains('stop') || cmd.contains('quiet')) {
      _stopSpeaking();
    }
  }

  Future<void> _speakCurrentStep() async {
    if (!_ttsEnabled || _steps.isEmpty) return;
    _stopSpeaking(); // Stop distinct previous

    String textToSpeak = "Step ${_currentStep + 1}. ${_steps[_currentStep]}";
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _speakCurrentStep();
    } else {
      // Done?
      NanoToast.showSuccess(context, "Recipe Completed! Bon Appétit!");
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _speakCurrentStep();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.recipe['title'] ?? 'Cooking',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off,
                color: _ttsEnabled ? AppColors.zestyLime : Colors.white54),
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) _stopSpeaking();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / (_steps.isEmpty ? 1 : _steps.length),
            backgroundColor: Colors.white10,
            color: AppColors.zestyLime,
            minHeight: 4,
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Step Image (Main Recipe Image as Visual Anchor)

                      Text(
                        "Step ${_currentStep + 1} of ${_steps.length}",
                        style: const TextStyle(
                            color: AppColors.zestyLime,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _steps.isNotEmpty
                            ? _steps[_currentStep]
                            : "No instructions found.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28, // Large text for distance reading
                            fontWeight: FontWeight.w500,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voice Listening Indicator
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic,
                            color: AppColors.electricBlue, size: 20),
                        const SizedBox(width: 8),
                        const Text("Listening for 'Next'...",
                            style: TextStyle(color: AppColors.electricBlue)),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Back logic
                    IconButton.filledTonal(
                      onPressed: _currentStep > 0 ? _prevStep : null,
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          iconSize: 32),
                    ),

                    // Mic / Replay logic
                    GestureDetector(
                      onLongPress: _listen, // Long press to force listen?
                      child: FloatingActionButton.large(
                        heroTag: 'cooking_fab',
                        onPressed: _listen,
                        backgroundColor: _isListening
                            ? AppColors.electricBlue
                            : AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                        child: Icon(_isListening
                            ? Icons.mic
                            : (_isSpeaking
                                ? Icons.graphic_eq
                                : Icons.mic_none)),
                      ),
                    ),

                    // Next logic
                    IconButton.filledTonal(
                      onPressed: _currentStep < _steps.length - 1
                          ? _nextStep
                          : () => Navigator.pop(context),
                      icon: Icon(_currentStep < _steps.length - 1
                          ? Icons.arrow_forward
                          : Icons.check),
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.zestyLime,
                          foregroundColor: AppColors.deepCharcoal,
                          padding: const EdgeInsets.all(16),
                          iconSize: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isListening
                      ? "Say 'Next', 'Back', or 'Repeat'"
                      : "Tap Mic or say commands",
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
