import 'dart:io';
import 'package:image/image.dart';

void main() async {
  print('Loading Image...');
  final File file = File('assets/logo_ios.png');
  if (!file.existsSync()) {
    print('Error: assets/logo_ios.png not found');
    exit(1);
  }

  final Image? original = decodeImage(file.readAsBytesSync());
  if (original == null) {
    print('Error: Could not decode image');
    exit(1);
  }

  print('Original size: ${original.width}x${original.height}');

  final int targetSize = 400;

  // Resize first
  Image resized = copyResize(original,
      width: targetSize,
      height: targetSize,
      interpolation: Interpolation.linear);

  // Create a new image with alpha channel
  Image rounded = Image(width: targetSize, height: targetSize, numChannels: 4);

  // Calculate radius
  double r = targetSize / 2;

  // Walk pixels and copy only those within radius
  for (var y = 0; y < targetSize; y++) {
    for (var x = 0; x < targetSize; x++) {
      double dx = x - r + 0.5; // center offset
      double dy = y - r + 0.5;
      if (dx * dx + dy * dy <= r * r) {
        rounded.setPixel(x, y, resized.getPixel(x, y));
      } else {
        // Transparent
        rounded.setPixel(x, y, ColorInt8.rgba(0, 0, 0, 0));
      }
    }
  }

  // Save it
  final outputFile = File('assets/logo_ios_rounded.png');
  outputFile.writeAsBytesSync(encodePng(rounded));

  print('Saved rounded image to assets/logo_ios_rounded.png');
}
