import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FunLoadingTips extends StatefulWidget {
  const FunLoadingTips({super.key});

  @override
  State<FunLoadingTips> createState() => _FunLoadingTipsState();
}

class _FunLoadingTipsState extends State<FunLoadingTips> {
  final List<String> _tips = [
    "Chopping onions? Chewing gum might stop the tears!",
    "A dull knife is more dangerous than a sharp one.",
    "Letting meat rest after cooking keeps it juicy.",
    "Salt your pasta water until it tastes like the ocean.",
    "Baking is a science, cooking is an art.",
    "Don't wash mushrooms! Wipe them with a damp cloth.",
    "Garlic burns easily—add it late to the pan.",
    "Fresh herbs are best added at the end of cooking.",
    "Room temperature eggs whip up better than cold ones.",
    "Clean as you go to keep your kitchen stress-free.",
    "Taste as you cook!",
  ];

  late Timer _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tips.shuffle(); // Randomize order on start
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.zestyLime),
            const SizedBox(height: 24),
            Text(
              "Whipping up your recipes...",
              style: TextStyle(
                color: AppColors.zestyLime,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _tips[_currentIndex],
                key: ValueKey<String>(_tips[_currentIndex]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
