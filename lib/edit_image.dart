import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<File> saveImageWithText(Uint8List imageBytes, String text, String filename) async {
  // Decode the image bytes into an Image
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final originalImage = frame.image;

  // Create a canvas to draw on
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();

  // Draw the original image
  canvas.drawImage(originalImage, Offset.zero, paint);

  // Prepare the text to draw
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();

  // Position the text at the center bottom of the image
  final textX = (originalImage.width - textPainter.width) / 2;
  final textY = originalImage.height - textPainter.height - 10; // 10px padding from bottom

  textPainter.paint(canvas, Offset(textX, textY));

  // Convert the canvas back to an image
  final picture = recorder.endRecording();
  final img = await picture.toImage(originalImage.width, originalImage.height);

  // Encode the image to PNG
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  // Save the image to the file
  final file = File(filename);
  await file.writeAsBytes(pngBytes);

  return file;
}
