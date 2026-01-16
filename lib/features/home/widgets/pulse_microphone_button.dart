import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';

class PulseMicrophoneButton extends StatefulWidget {
  final Function(String) onResult;
  final VoidCallback onlisteningStart;
  final VoidCallback onListeningEnd;

  const PulseMicrophoneButton({
    super.key,
    required this.onResult,
    required this.onlisteningStart,
    required this.onListeningEnd,
  });

  @override
  State<PulseMicrophoneButton> createState() => _PulseMicrophoneButtonState();
}

class _PulseMicrophoneButtonState extends State<PulseMicrophoneButton>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      // 1. Request Permission explicitly via permission_handler for robustness
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        // Handle denied permission (optional: show snackbar)
        return; // Early exit
      }

      // 2. Initialize STT
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            widget.onListeningEnd();
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          widget.onListeningEnd();
        },
      );

      if (available) {
        setState(() => _isListening = true);
        widget.onlisteningStart();

        _speech.listen(
          onResult: (val) {
            if (val.hasConfidenceRating && val.confidence > 0) {
              // Send partial or final results
              widget.onResult(val.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      widget.onListeningEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _listen,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          double scale = 1.0;
          double glowOpacity = 0.0;

          if (_isListening) {
            scale = 1.0 + (_pulseController.value * 0.2); // Pulse 1.0 -> 1.2
            glowOpacity =
                0.3 + (_pulseController.value * 0.4); // Glow 0.3 -> 0.7
          }

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? AppColors.zestyLime : Colors.white10,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: AppColors.zestyLime.withOpacity(glowOpacity),
                        blurRadius: 15 * scale,
                        spreadRadius: 2 * scale,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppColors.deepCharcoal : Colors.white54,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}
