import 'package:flutter/material.dart';

class ChefMindWatermark extends StatelessWidget {
  const ChefMindWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RotatedBox(
        quarterTurns: 3, // Rotate 270 degrees (vertical, reading up)
        child: FittedBox(
          fit: BoxFit.contain, // Ensure it fits but stays huge
          child: Text(
            'ChefMindAI',
            style: TextStyle(
              fontSize: 120, // Large base size, FittedBox handles rest
              fontWeight: FontWeight.w900, // Heavy bold
              color: Colors.white
                  .withOpacity(0.03), // Very subtle premium watermark
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}
