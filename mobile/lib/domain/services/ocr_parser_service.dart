import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParsedResult {
  final int? goalsHome;
  final int? goalsAway;
  final double? possessionHome;
  final double? possessionAway;
  final int? shotsTotalHome;
  final int? shotsTotalAway;
  final int? shotsTargetHome;
  final int? shotsTargetAway;
  final int? foulsHome;
  final int? foulsAway;
  final int? offsidesHome;
  final int? offsidesAway;
  final int? cornersHome;
  final int? cornersAway;
  final int? freeKicksHome;
  final int? freeKicksAway;
  final int? passesAttHome;
  final int? passesAttAway;
  final int? passesCompHome;
  final int? passesCompAway;
  final int? crossesHome;
  final int? crossesAway;
  final int? interceptionsHome;
  final int? interceptionsAway;
  final int? tacklesHome;
  final int? tacklesAway;
  final int? savesHome;
  final int? savesAway;
  final Set<String> assumedFields;

  OcrParsedResult({
    this.goalsHome, this.goalsAway,
    this.possessionHome, this.possessionAway,
    this.shotsTotalHome, this.shotsTotalAway,
    this.shotsTargetHome, this.shotsTargetAway,
    this.foulsHome, this.foulsAway,
    this.offsidesHome, this.offsidesAway,
    this.cornersHome, this.cornersAway,
    this.freeKicksHome, this.freeKicksAway,
    this.passesAttHome, this.passesAttAway,
    this.passesCompHome, this.passesCompAway,
    this.crossesHome, this.crossesAway,
    this.interceptionsHome, this.interceptionsAway,
    this.tacklesHome, this.tacklesAway,
    this.savesHome, this.savesAway,
    this.assumedFields = const {},
  });
}

class OcrElement {
  final String text;
  final double dx;
  final double dy;
  final double height;
  OcrElement({required this.text, required this.dx, required this.dy, required this.height});
}

class OcrParserService {
  static Future<OcrParsedResult> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode image");

    int w = image.width;
    int h = image.height;

    // Boundaries: Left (20-45%), Middle (45-57%), Right (57-85%)
    int leftX = (w * 0.15).toInt();
    int leftW = (w * 0.45).toInt() - leftX;
    
    int rightX = (w * 0.58).toInt();
    int rightW = (w * 0.90).toInt() - rightX;

    final tempDir = await getTemporaryDirectory();
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    List<OcrElement> allElements = [];

    Future<void> processSlice(int xOffset, int width, String suffix, {int yOffset = 0, int? sliceHeight}) async {
      int hToUse = sliceHeight ?? h;
      final slice = img.copyCrop(image, x: xOffset, y: yOffset, width: width, height: hToUse);
      final slicePath = '${tempDir.path}/slice_$suffix.png';
      await File(slicePath).writeAsBytes(img.encodePng(slice));
      
      final inputImage = InputImage.fromFilePath(slicePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          for (var element in line.elements) {
            allElements.add(OcrElement(
              text: element.text,
              dx: element.boundingBox.center.dx + xOffset,
              dy: element.boundingBox.center.dy + yOffset,
              height: element.boundingBox.height,
            ));
          }
        }
      }
    }

    // Hybrid Pipeline:
    // 1. Full image: Guarantees Score and Labels are extracted perfectly without being cut by slice boundaries.
    await processSlice(0, w, 'full');
    
    // 2. Side Slices (Bottom 75%): Strips the central UI progress bars, forcing ML Kit to extract tiny isolated
    // numbers (like 0) that it normally drops as background noise.
    int topH = (h * 0.25).toInt();
    int botH = h - topH;
    await processSlice(leftX, leftW, 'left', yOffset: topH, sliceHeight: botH);
    await processSlice(rightX, rightW, 'right', yOffset: topH, sliceHeight: botH);

    textRecognizer.close();
    
    return _parseInternal(allElements);
  }

  static OcrParsedResult _parseInternal(List<OcrElement> allElements) {
    // Sort elements by Y coordinate to process top-to-bottom
    allElements.sort((a, b) => a.dy.compareTo(b.dy));

    List<List<OcrElement>> rows = [];

    // Calculate dynamic tolerance based on font size to perfectly separate rows.
    // We filter out tiny noise (height < 10) to avoid skewing the median.
    List<double> heights = allElements.where((e) => e.height > 10).map((e) => e.height).toList();
    heights.sort();
    double medianHeight = heights.isNotEmpty ? heights[heights.length ~/ 2] : 20.0;
    double tolerance = (medianHeight * 0.5).clamp(10.0, 24.0);

    // Group elements into rows using anchor-based clustering to prevent drifting
    for (var element in allElements) {
      bool added = false;
      for (var row in rows) {
        double rowY = row.first.dy;
        if ((element.dy - rowY).abs() < tolerance) {
          row.add(element);
          added = true;
          break;
        }
      }
      if (!added) {
        rows.add([element]);
      }
    }

    // Sort each row by X coordinate (left-to-right)
    for (var row in rows) {
      row.sort((a, b) => a.dx.compareTo(b.dx));
    }

    // Helper to safely parse numbers, handling common OCR mistakes like 'O' for '0'
    num? parseNum(String text, bool isDouble) {
      String t = text.trim();
      String lower = t.toLowerCase();
      
      if (lower == 'o' || lower == 'o%') {
        t = lower.replaceAll('o', '0');
      } else if (lower == 'i' || lower == 'l' || lower == '|') {
        t = '1';
      } else if (lower == 's') {
        t = '5';
      } else if (lower == 'z') {
        t = '2';
      }

      String clean = t.replaceAll(RegExp(r'[^0-9.]'), '');
      if (clean.isEmpty || clean == '.') return null;
      return isDouble ? double.tryParse(clean) : int.tryParse(clean);
    }

    // Find the global center X of the stats column based on text labels
    List<OcrElement> allLabels = allElements.where((e) => parseNum(e.text, false) == null).toList();
    double globalCenterX = allElements.isNotEmpty ? allElements.first.dx : 0;
    if (allLabels.isNotEmpty) {
      globalCenterX = allLabels.map((e) => e.dx).reduce((a, b) => a + b) / allLabels.length;
    }

    // Group only labels to form robust anchors (immune to number drift)
    List<List<OcrElement>> labelRows = [];
    double labelTolerance = (medianHeight * 0.5).clamp(10.0, 24.0);
    
    for (var element in allLabels) {
      bool added = false;
      for (var row in labelRows) {
        double rowY = row.first.dy;
        // Label anchors must be tight dynamically to prevent vertical bleeding
        if ((element.dy - rowY).abs() < labelTolerance) {
          row.add(element);
          added = true;
          break;
        }
      }
      if (!added) {
        labelRows.add([element]);
      }
    }

    // Map each number to its closest label on the Y axis (True Voronoi Partition)
    Map<OcrElement, List<OcrElement>> labelToNumbers = {};
    for (var labelRow in labelRows) {
      labelToNumbers[labelRow.first] = [];
    }

    for (var n in allElements) {
      if (parseNum(n.text, false) == null) continue; // Only process numbers here
      
      OcrElement? closestLabel;
      double minDiff = double.infinity;
      
      for (var labelRow in labelRows) {
        double diff = (n.dy - labelRow.first.dy).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestLabel = labelRow.first;
        }
      }
      
      // Ensure the number isn't completely orphaned (max distance is 2.5x font height)
      if (closestLabel != null && minDiff < medianHeight * 2.5) {
        labelToNumbers[closestLabel]!.add(n);
      }
    }

    Set<String> assumedFields = {};

    // Helper to extract left (Home) and right (Away) stats for a given row keyword
    List<num?> extractStats(String statId, List<String> keywords, {List<String> excludes = const [], bool isDouble = false}) {
      for (var labelRow in labelRows) {
        // Join without spaces to ignore OCR word-splitting errors like "C ompleted"
        String rowText = labelRow.map((e) => e.text.toLowerCase()).join('');
        if (keywords.any((k) => rowText.contains(k)) && !excludes.any((e) => rowText.contains(e))) {
          
          List<OcrElement> numbers = labelToNumbers[labelRow.first] ?? [];
          numbers.sort((a, b) => a.dx.compareTo(b.dx));
          
          var leftNumbers = numbers.where((n) => n.dx < globalCenterX).toList();
          var rightNumbers = numbers.where((n) => n.dx >= globalCenterX).toList();
          
          num? finalLeft;
          num? finalRight;
          
          if (leftNumbers.isNotEmpty) {
            finalLeft = parseNum(leftNumbers.last.text, isDouble);
          }
          if (rightNumbers.isNotEmpty) {
            finalRight = parseNum(rightNumbers.first.text, isDouble);
          }
          
          if (finalLeft == null && !isDouble) assumedFields.add('${statId}Home');
          if (finalRight == null && !isDouble) assumedFields.add('${statId}Away');
          
          // If a row was found but ML Kit completely dropped the number on one side, 
          // it is invariably because it was a "0" that was misclassified as a UI bullet point.
          return [
            finalLeft ?? (isDouble ? null : 0), 
            finalRight ?? (isDouble ? null : 0)
          ];
        }
      }
      return [null, null];
    }

    // Parse score (goals)
    int? goalsHome;
    int? goalsAway;
    
    // Look at the top 8 rows to find the score
    for (int i = 0; i < (rows.length < 8 ? rows.length : 8); i++) {
      var row = rows[i];
      List<OcrElement> numElements = [];
      for (var element in row) {
        if (parseNum(element.text, false) != null) {
          numElements.add(element);
        }
      }
      
      if (numElements.length >= 2) {
        // eFootball scores are typically dead center. We find the two numbers closest to the row's center X.
        double centerX = row.map((e) => e.dx).reduce((a, b) => a + b) / row.length;
        numElements.sort((a, b) => (a.dx - centerX).abs().compareTo((b.dx - centerX).abs()));
        
        var score1 = numElements[0];
        var score2 = numElements[1];
        
        // Ensure home is left and away is right
        if (score1.dx > score2.dx) {
          var temp = score1;
          score1 = score2;
          score2 = temp;
        }
        
        goalsHome = parseNum(score1.text, false)?.toInt();
        goalsAway = parseNum(score2.text, false)?.toInt();
        
        // Sanity check: scores are rarely above 50, unlike possession or pass counts
        if ((goalsHome ?? 0) < 50 && (goalsAway ?? 0) < 50) {
          break; // Found the score!
        } else {
          goalsHome = null;
          goalsAway = null;
        }
      }
    }

    // Fallback for score parsing if the above fails
    if (goalsHome == null || goalsAway == null) {
      for (int i = 0; i < (rows.length < 8 ? rows.length : 8); i++) {
        var row = rows[i];
        String rowText = row.map((e) => e.text).join(' ');
        final match = RegExp(r'^.*?(\d+)\s*[-:]\s*(\d+).*$').firstMatch(rowText);
        if (match != null) {
          goalsHome = int.tryParse(match.group(1)!);
          goalsAway = int.tryParse(match.group(2)!);
          break;
        }
      }
    }

    // Parse stats
    final possession = extractStats('possession', ['possession'], isDouble: true);
    
    // Auto-correct possession if missing or sum is slightly off
    double? possH = possession[0]?.toDouble();
    double? possA = possession[1]?.toDouble();
    if (possH != null && possA != null && (possH + possA != 100.0)) {
      if ((possH + possA - 100.0).abs() < 20) {
        possA = 100.0 - possH; // Trust the home value
        assumedFields.add('possessionAway');
      }
    } else if (possH != null && possA == null) {
      possA = 100.0 - possH;
      assumedFields.add('possessionAway');
    } else if (possA != null && possH == null) {
      possH = 100.0 - possA;
      assumedFields.add('possessionHome');
    }

    final shots = extractStats('shotsTotal', ['totalshots', 'shots'], excludes: ['target']);
    final shotsTarget = extractStats('shotsTarget', ['target']);
    final fouls = extractStats('fouls', ['fouls']);
    final offsides = extractStats('offsides', ['offsides']);
    final corners = extractStats('corners', ['corner']);
    final freeKicks = extractStats('freeKicks', ['freekick']);
    final passes = extractStats('passesAtt', ['passes'], excludes: ['uccess', 'completed']);
    final successfulPasses = extractStats('passesComp', ['uccess', 'completed']);
    final crosses = extractStats('crosses', ['crosses']);
    final interceptions = extractStats('interceptions', ['interceptions']);
    final tackles = extractStats('tackles', ['tackles']);
    final saves = extractStats('saves', ['saves']);

    return OcrParsedResult(
      goalsHome: goalsHome,
      goalsAway: goalsAway,
      possessionHome: possH,
      possessionAway: possA,
      shotsTotalHome: shots[0]?.toInt(),
      shotsTotalAway: shots[1]?.toInt(),
      shotsTargetHome: shotsTarget[0]?.toInt(),
      shotsTargetAway: shotsTarget[1]?.toInt(),
      foulsHome: fouls[0]?.toInt(),
      foulsAway: fouls[1]?.toInt(),
      offsidesHome: offsides[0]?.toInt(),
      offsidesAway: offsides[1]?.toInt(),
      cornersHome: corners[0]?.toInt(),
      cornersAway: corners[1]?.toInt(),
      freeKicksHome: freeKicks[0]?.toInt(),
      freeKicksAway: freeKicks[1]?.toInt(),
      passesAttHome: passes[0]?.toInt(),
      passesAttAway: passes[1]?.toInt(),
      passesCompHome: successfulPasses[0]?.toInt(),
      passesCompAway: successfulPasses[1]?.toInt(),
      crossesHome: crosses[0]?.toInt(),
      crossesAway: crosses[1]?.toInt(),
      interceptionsHome: interceptions[0]?.toInt(),
      interceptionsAway: interceptions[1]?.toInt(),
      tacklesHome: tackles[0]?.toInt(),
      tacklesAway: tackles[1]?.toInt(),
      savesHome: saves[0]?.toInt(),
      savesAway: saves[1]?.toInt(),
      assumedFields: assumedFields,
    );
  }
}

