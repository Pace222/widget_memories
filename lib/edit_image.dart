import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';

const int finalWidth = 1080;

Future<File> saveImageWithText(
    Uint8List imageBytes, String text, String filename) async {
  // Reduce the resolution
  final resizedBytes = await FlutterImageCompress.compressWithList(
    imageBytes,
    minWidth: finalWidth,
    minHeight: 0,
  );
  // Decode the image bytes into an Image
  final codec = await ui.instantiateImageCodec(resizedBytes);
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
      style: GoogleFonts.lato(
        color: Colors.red,
        fontSize: finalWidth / 10,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();

  // Position the text at the center bottom of the image
  final textX =
      (originalImage.width - textPainter.width) / 2; // center horizontally
  final textY = originalImage.height -
      textPainter.height -
      finalWidth ~/ 15; // padding from bottom

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
