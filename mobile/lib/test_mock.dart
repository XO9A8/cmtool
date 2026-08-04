import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  final block = TextBlock(text: 'test', lines: [], boundingBox: Rect.zero, cornerPoints: [], recognizedLanguages: []);
  debugPrint(block.text);
}
