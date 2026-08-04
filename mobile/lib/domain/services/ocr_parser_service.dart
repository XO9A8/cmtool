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
  });
}

class OcrParserService {
  static Future<OcrParsedResult> parse(RecognizedText recognizedText) async {
    // Collect all text blocks with their bounding boxes
    final List<TextLine> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allLines.add(line);
      }
    }

    // Helper to find a line matching a keyword
    TextLine? findLine(List<String> keywords) {
      for (var line in allLines) {
        final text = line.text.toLowerCase();
        if (keywords.any((k) => text.contains(k))) return line;
      }
      return null;
    }

    // Helper to find left and right numbers around a center line
    List<num?> findValuesAround(TextLine? centerLine, {bool isDouble = false}) {
      if (centerLine == null) return [null, null];

      final centerY = centerLine.boundingBox.center.dy;
      
      // Find numbers on the same approximate Y-axis (within 20 pixels)
      final candidates = allLines.where((l) {
        if (l == centerLine) return false;
        final dy = (l.boundingBox.center.dy - centerY).abs();
        return dy < 40;
      }).toList();

      // Sort by X coordinate
      candidates.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

      // Extract numbers
      num? leftVal;
      num? rightVal;

      for (var c in candidates) {
        final text = c.text.replaceAll(RegExp(r'[^0-9.]'), '');
        if (text.isEmpty) continue;
        
        final val = isDouble ? double.tryParse(text) : int.tryParse(text);
        if (val == null) continue;

        if (c.boundingBox.center.dx < centerLine.boundingBox.center.dx) {
          leftVal = val;
        } else {
          rightVal = val;
        }
      }

      return [leftVal, rightVal];
    }

    // Parse stats
    final possession = findValuesAround(findLine(['possession']), isDouble: true);
    
    // Auto-correct possession if missing or sum is slightly off
    double? possH = possession[0]?.toDouble();
    double? possA = possession[1]?.toDouble();
    if (possH != null && possA != null && (possH + possA != 100.0)) {
      if ((possH + possA - 100.0).abs() < 20) {
        possA = 100.0 - possH; // Trust the home value and correct the away value
      }
    } else if (possH != null && possA == null) {
      possA = 100.0 - possH;
    } else if (possA != null && possH == null) {
      possH = 100.0 - possA;
    }

    final shots = findValuesAround(findLine(['shots', 'total shots']));
    final shotsTarget = findValuesAround(findLine(['target']));
    final fouls = findValuesAround(findLine(['fouls']));
    final offsides = findValuesAround(findLine(['offsides']));
    final corners = findValuesAround(findLine(['corner']));
    final freeKicks = findValuesAround(findLine(['free kick']));
    final passes = findValuesAround(findLine(['passes']));
    final successfulPasses = findValuesAround(findLine(['successful passes', 'completed']));
    final crosses = findValuesAround(findLine(['crosses']));
    final interceptions = findValuesAround(findLine(['interceptions']));
    final tackles = findValuesAround(findLine(['tackles']));
    final saves = findValuesAround(findLine(['saves']));

    return OcrParsedResult(
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
    );
  }
}
