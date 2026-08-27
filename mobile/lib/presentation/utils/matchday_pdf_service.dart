import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class MatchdayPdfService {
  // ─────────────────────────────────────────────────────────────────────────────
  // DESIGN: Premium Sports Programme — clean editorial palette
  // Inspired by Champions League & top-tier football match programmes.
  // ─────────────────────────────────────────────────────────────────────────────

  // Base
  static const PdfColor _ink         = PdfColor.fromInt(0xFF0D0D0D); // near-black
  static const PdfColor _paper       = PdfColor.fromInt(0xFFF5F3EE); // warm off-white
  static const PdfColor _paperMid    = PdfColor.fromInt(0xFFEAE7DF); // slightly deeper off-white
  static const PdfColor _paperDark   = PdfColor.fromInt(0xFFD9D4C8); // divider/border tone

  // Brand primaries
  static const PdfColor _scarlet     = PdfColor.fromInt(0xFFD90429); // strong red
  static const PdfColor _navy        = PdfColor.fromInt(0xFF0A1628); // deep navy
  static const PdfColor _gold        = PdfColor.fromInt(0xFFC9A84C); // rich gold

  // Status
  static const PdfColor _emerald     = PdfColor.fromInt(0xFF1B7A3E); // result green
  static const PdfColor _amber       = PdfColor.fromInt(0xFFB45309); // reschedule amber

  // Typography helpers
  static const PdfColor _textPrimary = _ink;
  static const PdfColor _textSecond  = PdfColor.fromInt(0xFF4A4A4A);
  static const PdfColor _textMuted   = PdfColor.fromInt(0xFF888888);

  // ─────────────────────────────────────────────────────────────────────────────
  // SVG — Minimal Abstract Background
  // Geometric diagonal slash stripes + corner motifs, fully monochrome/subtle
  // ─────────────────────────────────────────────────────────────────────────────

  /// Full-page background: warm paper texture suggestion via diagonal lines
  static const String _svgBackground = '''
<svg viewBox="0 0 595 842" width="595" height="842" xmlns="http://www.w3.org/2000/svg">
  <!-- Warm paper base -->
  <rect width="595" height="842" fill="#F5F3EE"/>

  <!-- Subtle diagonal stripe texture (repeating) -->
  <line x1="-20" y1="0"   x2="200"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="60"  y1="0"   x2="280"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="140" y1="0"   x2="360"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="220" y1="0"   x2="440"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="300" y1="0"   x2="520"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="380" y1="0"   x2="600"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>
  <line x1="460" y1="0"   x2="680"  y2="220"  stroke="#EAE7DF" stroke-width="18"/>

  <!-- Navy accent block top-left -->
  <polygon points="0,0 120,0 0,90" fill="#0A1628" opacity="0.92"/>
  <!-- Scarlet slash accent inside navy -->
  <polygon points="0,0 40,0 0,30" fill="#D90429" opacity="0.85"/>

  <!-- Bottom right decorative block -->
  <polygon points="595,842 595,760 475,842" fill="#0A1628" opacity="0.92"/>
  <polygon points="595,842 595,810 545,842" fill="#D90429" opacity="0.85"/>

  <!-- Top border rule (navy) -->
  <rect x="0" y="0" width="595" height="4" fill="#0A1628"/>
  <!-- Bottom border rule (scarlet) -->
  <rect x="0" y="838" width="595" height="4" fill="#D90429"/>

  <!-- Mid-page faint geometric ring (watermark feel) -->
  <circle cx="297" cy="530" r="220" fill="none" stroke="#D9D4C8" stroke-width="1.2"/>
  <circle cx="297" cy="530" r="160" fill="none" stroke="#D9D4C8" stroke-width="0.7"/>
  <line x1="77"  y1="530" x2="517" y2="530" stroke="#D9D4C8" stroke-width="0.7"/>
  <line x1="297" y1="310" x2="297" y2="750" stroke="#D9D4C8" stroke-width="0.7"/>

  <!-- Four corner bracket marks -->
  <path d="M 28 28 L 28 46 M 28 28 L 46 28" stroke="#C9A84C" stroke-width="1.8" fill="none"/>
  <path d="M 567 28 L 567 46 M 567 28 L 549 28" stroke="#C9A84C" stroke-width="1.8" fill="none"/>
  <path d="M 28 814 L 28 796 M 28 814 L 46 814" stroke="#C9A84C" stroke-width="1.8" fill="none"/>
  <path d="M 567 814 L 567 796 M 567 814 L 549 814" stroke="#C9A84C" stroke-width="1.8" fill="none"/>
</svg>''';

  /// Small diamond bullet SVG for inline accents
  static const String _svgDiamond = '''
<svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">
  <polygon points="5,0 10,5 5,10 0,5" fill="#D90429"/>
</svg>''';

  // ─────────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────────

  /// Generates a premium sports-programme style PDF for a matchday or date
  /// with a fixed 10 match details per page and structured layout.
  static Future<Uint8List> generateMatchdayPdf({
    required String tournamentName,
    required String formatType,
    required dynamic selectedMatchday,
    required List<dynamic> allFixtures,
    required bool includeResults,
    String? clubName,
  }) async {
    final titleType = includeResults ? 'Results' : 'Fixtures';
    final pdf = pw.Document(
      title: '$tournamentName - Matchday $titleType Programme',
      author: 'eFootball Club Manager',
    );

    final isAll = selectedMatchday == null || selectedMatchday['id']?.toString() == 'all';
    final mdNum = isAll ? 'ALL' : (selectedMatchday['matchday_number']?.toString() ?? '1');
    final targetDateStr = isAll ? null : selectedMatchday['scheduled_date']?.toString();
    final selectedMdId = isAll ? null : selectedMatchday['id']?.toString();

    DateTime? targetDate;
    if (targetDateStr != null && targetDateStr.isNotEmpty) {
      try { targetDate = DateTime.parse(targetDateStr); } catch (_) {}
    }

    // ── Filter fixtures ──────────────────────────────────────────────────────
    final List<Map<String, dynamic>> targetMatches = [];
    for (final raw in allFixtures) {
      if (raw is! Map) continue;
      final f = Map<String, dynamic>.from(raw);
      final fMdId = f['matchday_id']?.toString();
      final isGenuinelyRescheduled = f['is_rescheduled'] == true ||
          (f['status'] ?? '').toString().toLowerCase() == 'rescheduled';

      final schedStr = f['scheduled_at']?.toString();
      DateTime? fSchedDate;
      if (schedStr != null && schedStr.isNotEmpty) {
        try { fSchedDate = DateTime.parse(schedStr).toLocal(); } catch (_) {}
      }

      if (isAll) {
        targetMatches.add(f);
      } else {
        if (fMdId == selectedMdId) {
          targetMatches.add(f);
        } else if (isGenuinelyRescheduled &&
                   targetDate != null &&
                   fSchedDate != null &&
                   _isSameDay(fSchedDate, targetDate)) {
          bool currentMdIsOnTargetDate = false;
          final currentMdDateStr = f['matchday_scheduled_date']?.toString();
          if (currentMdDateStr != null && currentMdDateStr.isNotEmpty) {
            try {
              final d = DateTime.parse(currentMdDateStr);
              if (_isSameDay(d, targetDate)) {
                currentMdIsOnTargetDate = true;
              }
            } catch (_) {}
          }

          if (!currentMdIsOnTargetDate) {
            int? minMdNum;
            String? minMdId;
            for (final fix in allFixtures) {
              if (fix is Map) {
                final mdDateStr = fix['matchday_scheduled_date']?.toString();
                if (mdDateStr != null && mdDateStr.isNotEmpty) {
                  try {
                    final d = DateTime.parse(mdDateStr);
                    if (_isSameDay(d, targetDate)) {
                      final mdNum = (fix['matchday_number'] as num?)?.toInt();
                      if (mdNum != null && (minMdNum == null || mdNum < minMdNum)) {
                        minMdNum = mdNum;
                        minMdId = fix['matchday_id']?.toString();
                      }
                    }
                  } catch (_) {}
                }
              }
            }
            if (minMdId == null || selectedMdId == minMdId) {
              f['rescheduled_into_this_matchday'] = true;
              targetMatches.add(f);
            }
          }
        }
      }
    }

    targetMatches.sort((a, b) {
      final gA = a['group_name']?.toString() ?? '';
      final gB = b['group_name']?.toString() ?? '';
      if (gA != gB) return gA.compareTo(gB);
      final rA = (a['round_number'] as num?)?.toInt() ?? 0;
      final rB = (b['round_number'] as num?)?.toInt() ?? 0;
      if (rA != rB) return rA.compareTo(rB);
      final tA = a['scheduled_at']?.toString() ?? '';
      final tB = b['scheduled_at']?.toString() ?? '';
      return tA.compareTo(tB);
    });

    // ── Stats ────────────────────────────────────────────────────────────────
    final totalMatches  = targetMatches.length;
    final completedCount = targetMatches
        .where((m) => (m['status'] ?? '').toString().toLowerCase() == 'completed')
        .length;
    final reschedCount = targetMatches.where((m) =>
        m['is_rescheduled'] == true ||
        (m['status'] ?? '').toString().toLowerCase() == 'rescheduled' ||
        m['rescheduled_into_this_matchday'] == true).length;

    int totalGoals = 0;
    if (includeResults) {
      for (final m in targetMatches) {
        final s1 = (m['player_1_score'] as num?)?.toInt() ?? 0;
        final s2 = (m['player_2_score'] as num?)?.toInt() ?? 0;
        totalGoals += s1 + s2;
      }
    }

    final formattedDate = targetDate != null
        ? '${_formatWeekday(targetDate).toUpperCase()}  ${_pad(targetDate.day)} ${_monthName(targetDate.month).toUpperCase()} ${targetDate.year}'
        : 'DATE TBD';

    String formatLabel;
    final fLower = formatType.toLowerCase();
    if (fLower.contains('round_robin') || fLower == 'league') {
      formatLabel = 'LEAGUE';
    } else if (fLower == 'group_knockout') {
      formatLabel = 'GROUPS + PLAYOFFS';
    } else if (fLower == 'knockout') {
      formatLabel = 'KNOCKOUT';
    } else {
      formatLabel = formatType.replaceAll('_', ' ').toUpperCase();
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.SvgImage(svg: _svgBackground, fit: pw.BoxFit.fill),
      ),
    );

    // ── Chunk matches into fixed 10 matches per page ──────────────────────────
    final List<List<Map<String, dynamic>>> matchChunks = [];
    if (targetMatches.isEmpty) {
      matchChunks.add([]);
    } else {
      for (int i = 0; i < targetMatches.length; i += 10) {
        final end = (i + 10 < targetMatches.length) ? i + 10 : targetMatches.length;
        matchChunks.add(targetMatches.sublist(i, end));
      }
    }

    final totalPages = matchChunks.length;

    for (int chunkIdx = 0; chunkIdx < totalPages; chunkIdx++) {
      final pageMatches = matchChunks[chunkIdx];
      final pageNum = chunkIdx + 1;
      final pageStartIndex = chunkIdx * 10;

      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(
                  tournamentName: tournamentName,
                  formatLabel: formatLabel,
                  mdNum: mdNum,
                  formattedDate: formattedDate,
                  includeResults: includeResults,
                  clubName: clubName,
                  totalMatches: totalMatches,
                  completedCount: completedCount,
                  reschedCount: reschedCount,
                  totalGoals: totalGoals,
                  currentPage: pageNum,
                  totalPages: totalPages,
                ),
                pw.SizedBox(height: 5),
                if (pageMatches.isEmpty)
                  pw.Expanded(child: _buildEmptyState())
                else
                  pw.Expanded(
                    child: _buildMatchPageContent(
                      matches: pageMatches,
                      startIndex: pageStartIndex,
                      includeResults: includeResults,
                      formatType: formatType,
                    ),
                  ),
                _buildFooter(
                  pageNum: pageNum,
                  totalPages: totalPages,
                  tournamentName: tournamentName,
                  includeResults: includeResults,
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Converts PDF to PNG(s) and shares via share sheet (single matchday).
  static Future<void> exportAndShare({
    required String tournamentName,
    required String formatType,
    required dynamic selectedMatchday,
    required List<dynamic> allFixtures,
    required bool includeResults,
    String? clubName,
  }) async {
    final pdfBytes = await generateMatchdayPdf(
      tournamentName: tournamentName,
      formatType: formatType,
      selectedMatchday: selectedMatchday,
      allFixtures: allFixtures,
      includeResults: includeResults,
      clubName: clubName,
    );

    final isAll  = selectedMatchday == null || selectedMatchday['id']?.toString() == 'all';
    final mdNum  = isAll ? 'all' : (selectedMatchday['matchday_number']?.toString() ?? '1');
    final typeStr = includeResults ? 'results' : 'fixtures';
    final cleanTourney = tournamentName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final tempDir = await getTemporaryDirectory();
    final List<XFile> pngFiles = [];

    int pageIndex = 1;
    await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
      final pngBytes = await page.toPng();
      final pageSuffix = pageIndex > 1 ? '_page_$pageIndex' : '';
      final fileName = '${cleanTourney}_matchday_${mdNum}_$typeStr$pageSuffix.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);
      pngFiles.add(XFile(file.path, mimeType: 'image/png', name: fileName));
      pageIndex++;
    }

    if (pngFiles.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(
        text: '$tournamentName - Matchday $mdNum ${includeResults ? "Results" : "Fixtures"}',
        files: pngFiles,
      ));
    } else {
      final fileName = '${cleanTourney}_matchday_${mdNum}_$typeStr.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await SharePlus.instance.share(ShareParams(
        text: '$tournamentName - Matchday $mdNum ${includeResults ? "Results" : "Fixtures"}',
        files: [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
      ));
    }
  }

  /// Exports one image per matchday for every matchday that shares the same
  /// calendar date as [selectedMatchday]. This is the primary export entry-point
  /// for the in-app "Export Fixtures" button.
  static Future<int> exportAndShareForDate({
    required String tournamentName,
    required String formatType,
    required dynamic selectedMatchday,
    required List<dynamic> allFixtures,
    required bool includeResults,
    String? clubName,
  }) async {
    final targetDateStr = selectedMatchday?['scheduled_date']?.toString();
    DateTime? targetDate;
    if (targetDateStr != null && targetDateStr.isNotEmpty) {
      try { targetDate = DateTime.parse(targetDateStr); } catch (_) {}
    }

    final Map<String, List<Map<String, dynamic>>> byMatchday = {};
    final Map<String, int> matchdayNumbers = {};
    final Map<String, String> matchdayDates = {};

    for (final raw in allFixtures) {
      if (raw is! Map) continue;
      final f = Map<String, dynamic>.from(raw);
      final fMdId = f['matchday_id']?.toString();
      if (fMdId == null) continue;

      final mdDateStr = f['matchday_scheduled_date']?.toString();
      DateTime? mdDate;
      if (mdDateStr != null && mdDateStr.isNotEmpty) {
        try { mdDate = DateTime.parse(mdDateStr); } catch (_) {}
      }

      final bool onTargetDate = targetDate == null ||
          (mdDate != null && _isSameDay(mdDate, targetDate));

      if (onTargetDate) {
        byMatchday.putIfAbsent(fMdId, () => []).add(f);
        matchdayNumbers[fMdId] = (f['matchday_number'] as num?)?.toInt() ?? 0;
        matchdayDates[fMdId] = mdDateStr ?? targetDateStr ?? '';
      }
    }

    if (byMatchday.isEmpty) {
      await exportAndShare(
        tournamentName: tournamentName,
        formatType: formatType,
        selectedMatchday: selectedMatchday,
        allFixtures: allFixtures,
        includeResults: includeResults,
        clubName: clubName,
      );
      return 1;
    }

    final sortedMdIds = byMatchday.keys.toList()
      ..sort((a, b) => (matchdayNumbers[a] ?? 0).compareTo(matchdayNumbers[b] ?? 0));

    final cleanTourney = tournamentName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final typeStr = includeResults ? 'results' : 'fixtures';
    final tempDir = await getTemporaryDirectory();
    final List<XFile> allPngFiles = [];

    for (final mdId in sortedMdIds) {
      final mdNum = matchdayNumbers[mdId] ?? 0;

      final syntheticMd = <String, dynamic>{
        'id': mdId,
        'matchday_number': mdNum,
        'scheduled_date': matchdayDates[mdId] ?? targetDateStr ?? '',
      };

      final pdfBytes = await generateMatchdayPdf(
        tournamentName: tournamentName,
        formatType: formatType,
        selectedMatchday: syntheticMd,
        allFixtures: allFixtures,
        includeResults: includeResults,
        clubName: clubName,
      );

      int pageIndex = 1;
      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        final pngBytes = await page.toPng();
        final pageSuffix = pageIndex > 1 ? '_page_$pageIndex' : '';
        final fileName = '${cleanTourney}_matchday_${mdNum}_$typeStr$pageSuffix.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pngBytes);
        allPngFiles.add(XFile(file.path, mimeType: 'image/png', name: fileName));
        pageIndex++;
      }
    }

    if (allPngFiles.isNotEmpty) {
      final dateLabel = targetDate != null
          ? '${_pad(targetDate.day)} ${_monthName(targetDate.month)} ${targetDate.year}'
          : '';
      await SharePlus.instance.share(ShareParams(
        text: '$tournamentName - $dateLabel ${includeResults ? "Results" : "Fixtures"} '
              '(${sortedMdIds.length} matchday${sortedMdIds.length > 1 ? "s" : ""})',
        files: allPngFiles,
      ));
    }

    return sortedMdIds.length;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HEADER — full-bleed magazine masthead style
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required String tournamentName,
    required String formatLabel,
    required String mdNum,
    required String formattedDate,
    required bool includeResults,
    required String? clubName,
    required int totalMatches,
    required int completedCount,
    required int reschedCount,
    required int totalGoals,
    required int currentPage,
    required int totalPages,
  }) {
    final modeLabel = includeResults ? 'RESULTS' : 'FIXTURES';
    final modeColor = includeResults ? _emerald : _scarlet;
    final mdLabel   = mdNum == 'ALL' ? 'ALL MATCHDAYS' : 'MATCHDAY $mdNum';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Masthead block ────────────────────────────────────────────────────
        pw.Container(
          decoration: const pw.BoxDecoration(
            color: _navy,
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Left: mode stripe + tournament info
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (clubName != null && clubName.isNotEmpty) ...[
                      pw.Text(
                        clubName.toUpperCase(),
                        style: const pw.TextStyle(
                          color: _gold,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                    ],
                    pw.Text(
                      tournamentName.toUpperCase(),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: const pw.TextStyle(
                        color: _paper,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        // MODE badge
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          color: modeColor,
                          child: pw.Text(
                            modeLabel,
                            style: const pw.TextStyle(
                              color: _paper,
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        // Format label
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _gold, width: 0.6),
                          ),
                          child: pw.Text(
                            formatLabel,
                            style: const pw.TextStyle(
                              color: _gold,
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        // Deadline badge
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _paper, width: 0.6),
                          ),
                          child: pw.Text(
                            'DEADLINE: 12:59 PM BST',
                            style: const pw.TextStyle(
                              color: _paper,
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: date + matchday callout
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    mdLabel,
                    style: const pw.TextStyle(
                      color: _paper,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: pw.BoxDecoration(
                      color: _paper,
                      border: pw.Border.all(color: _gold, width: 0.7),
                    ),
                    child: pw.Text(
                      formattedDate,
                      style: const pw.TextStyle(
                        color: _navy,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Scarlet accent rule ───────────────────────────────────────────────
        pw.Container(height: 2.5, color: _scarlet),

        // ── Stats strip on paper ──────────────────────────────────────────────
        pw.Container(
          color: _paperMid,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('MATCHES', '$totalMatches', _navy),
              _buildStatDivider(),
              _buildStatItem(
                includeResults ? 'COMPLETED' : 'SCHEDULED',
                includeResults ? '$completedCount / $totalMatches' : '$totalMatches',
                _emerald,
              ),
              _buildStatDivider(),
              if (includeResults)
                _buildStatItem('TOTAL GOALS', '$totalGoals', _scarlet)
              else
                _buildStatItem('PENDING', '${totalMatches - completedCount}', _textSecond),
              _buildStatDivider(),
              _buildStatItem(
                'RESCHEDULED',
                '$reschedCount',
                reschedCount > 0 ? _amber : _textMuted,
              ),
            ],
          ),
        ),

        // ── Bottom rule ───────────────────────────────────────────────────────
        pw.Container(height: 0.8, color: _paperDark),
      ],
    );
  }

  static pw.Widget _buildStatItem(String label, String value, PdfColor valueColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(
            color: _textMuted,
            fontSize: 5.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatDivider() {
    return pw.Container(
      width: 0.6,
      height: 18,
      color: _paperDark,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MATCH PAGE CONTENT (Fixed 10 matches per page with balanced height)
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildMatchPageContent({
    required List<Map<String, dynamic>> matches,
    required int startIndex,
    required bool includeResults,
    required String formatType,
  }) {
    final List<pw.Widget> matchWidgets = [];

    for (int i = 0; i < matches.length; i++) {
      matchWidgets.add(
        _buildMatchCard(
          matches[i],
          startIndex + i + 1,
          includeResults,
          formatType,
        ),
      );
      if (i < matches.length - 1) {
        matchWidgets.add(pw.SizedBox(height: 5.5));
      }
    }

    if (matches.length == 10) {
      // 10 matches completely fill the page without awkward empty space
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: matchWidgets,
      );
    } else {
      // For pages with < 10 matches, maintain exact card heights and balance the bottom
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          ...matchWidgets,
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: _buildOfficialNoticeCard(includeResults),
          ),
        ],
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MATCH CARD — Clean two-column layout with fixed height proportions
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildMatchCard(
    Map<String, dynamic> m,
    int index,
    bool includeResults,
    String formatType,
  ) {
    final p1Id    = m['player_1_id']?.toString() ?? '';
    final p2Id    = m['player_2_id']?.toString() ?? '';
    final p1Name  = m['player_1_name']?.toString() ??
        (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
    final p2Name  = m['player_2_name']?.toString() ??
        (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
    final p1Rating = m['player_1_rating']?.toString();
    final p2Rating = m['player_2_rating']?.toString();

    final roundNum  = (m['round_number'] as num?)?.toInt() ?? 1;
    final groupName = m['group_name']?.toString();
    final status    = (m['status'] ?? 'scheduled').toString().toLowerCase();
    final isCompleted   = status == 'completed';
    final isReschedInto = m['rescheduled_into_this_matchday'] == true;
    final isRescheduled = m['is_rescheduled'] == true ||
        status == 'rescheduled' ||
        isReschedInto;

    final p1Score  = includeResults ? m['player_1_score'] : null;
    final p2Score  = includeResults ? m['player_2_score'] : null;
    final winnerId = includeResults ? m['winner_player_id']?.toString() : null;
    final isDraw   = includeResults && isCompleted && winnerId == null && p1Score != null && p1Score == p2Score;
    final p1Wins   = includeResults && isCompleted && winnerId != null && winnerId == p1Id;
    final p2Wins   = includeResults && isCompleted && winnerId != null && winnerId == p2Id;

    final schedStr = m['scheduled_at']?.toString();
    String timeStr = '6:00 PM';
    if (schedStr != null && schedStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(schedStr).toLocal();
        final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ap = dt.hour >= 12 ? 'PM' : 'AM';
        
        final mdDateStr = m['matchday_scheduled_date']?.toString();
        DateTime? mdDate;
        if (mdDateStr != null && mdDateStr.isNotEmpty) {
          try { mdDate = DateTime.parse(mdDateStr); } catch (_) {}
        }
        
        if (isRescheduled && !isReschedInto && mdDate != null && !_isSameDay(dt, mdDate)) {
          timeStr = '${_pad(dt.day)} ${_monthName(dt.month).toUpperCase()} | $h:${_pad(dt.minute)} $ap';
        } else {
          timeStr = '$h:${_pad(dt.minute)} $ap';
        }
      } catch (_) {}
    }

    final reason = m['reschedule_reason']?.toString();

    String stageLabel;
    final origMdNum = m['matchday_number'];
    if (isReschedInto && origMdNum != null) {
      if (groupName != null && groupName.isNotEmpty) {
        stageLabel = 'MD $origMdNum | GRP $groupName | RD $roundNum';
      } else {
        stageLabel = 'MD $origMdNum | RD $roundNum';
      }
    } else if (groupName != null && groupName.isNotEmpty) {
      stageLabel = 'GRP $groupName | RD $roundNum';
    } else {
      stageLabel = _getRoundTitle(roundNum, formatType);
    }

    final PdfColor accentLeft  = isRescheduled ? _amber : _navy;
    final PdfColor accentRight = isRescheduled ? _amber : _scarlet;

    final PdfColor cardBg = isRescheduled
        ? const PdfColor.fromInt(0xFFFFF8F0)
        : _paper;
    final PdfColor cardBorder = isRescheduled ? _amber : _paperDark;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: cardBg,
        border: pw.Border.all(color: cardBorder, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Top metadata bar ─────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            color: isRescheduled ? const PdfColor.fromInt(0xFFFFF3E0) : _paperMid,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      _pad(index),
                      style: const pw.TextStyle(
                        color: _scarlet,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Container(width: 0.5, height: 8, color: _paperDark),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      stageLabel,
                      style: const pw.TextStyle(
                        color: _textSecond,
                        fontSize: 6.8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (isRescheduled && reason != null && reason.isNotEmpty) ...[
                      pw.SizedBox(width: 4),
                      pw.Container(width: 0.5, height: 8, color: _amber),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'NOTE: $reason',
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        style: const pw.TextStyle(
                          color: _amber,
                          fontSize: 6.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                if (isRescheduled)
                  pw.Row(
                    children: [
                      _buildTag('RESCHEDULED', _amber, _navy),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        timeStr,
                        style: const pw.TextStyle(
                          color: _amber,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else if (includeResults && isCompleted)
                  _buildTag('FULL TIME', _emerald, _paper)
                else
                  pw.Row(
                    children: [
                      pw.Text(
                        'KO ',
                        style: const pw.TextStyle(
                          color: _textMuted,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.Text(
                        timeStr,
                        style: const pw.TextStyle(
                          color: _textPrimary,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          pw.Container(height: 0.5, color: cardBorder),

          // ── Main matchup row ─────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 3, height: 44, color: accentLeft),

              // Player 1
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              p1Name,
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                color: p1Wins
                                    ? _emerald
                                    : (includeResults && isCompleted && !isDraw
                                        ? _textMuted
                                        : _textPrimary),
                                fontSize: 11.5,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (p1Rating != null) ...[
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'ELO $p1Rating',
                                style: const pw.TextStyle(
                                  color: _textMuted,
                                  fontSize: 6.2,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (p1Wins) ...[
                        pw.SizedBox(width: 4),
                        _buildWinnerBadge(),
                      ],

                      if (includeResults && isCompleted && p1Score != null) ...[
                        pw.SizedBox(width: 4),
                        _buildScoreBox('$p1Score', p1Wins, isDraw),
                      ],
                    ],
                  ),
                ),
              ),

              // Centre divider
              pw.Container(
                width: 32,
                height: 44,
                color: _navy,
                child: pw.Center(
                  child: pw.Text(
                    includeResults && isCompleted ? '-' : 'VS',
                    style: const pw.TextStyle(
                      color: _paper,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // Player 2
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (includeResults && isCompleted && p2Score != null) ...[
                        _buildScoreBox('$p2Score', p2Wins, isDraw),
                        pw.SizedBox(width: 4),
                      ],

                      if (p2Wins) ...[
                        _buildWinnerBadge(),
                        pw.SizedBox(width: 4),
                      ],

                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              p2Name,
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                color: p2Wins
                                    ? _emerald
                                    : (includeResults && isCompleted && !isDraw
                                        ? _textMuted
                                        : _textPrimary),
                                fontSize: 11.5,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (p2Rating != null) ...[
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'ELO $p2Rating',
                                style: const pw.TextStyle(
                                  color: _textMuted,
                                  fontSize: 6.2,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.Container(width: 3, height: 44, color: accentRight),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // OFFICIAL NOTICE CARD (Balances layout when a page has < 10 matches)
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildOfficialNoticeCard(bool includeResults) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEDE9DF),
        border: pw.Border.all(color: _paperDark, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3, height: 12, color: _scarlet),
              pw.SizedBox(width: 6),
              pw.Text(
                includeResults ? 'OFFICIAL RESULT CERTIFICATION' : 'MATCHDAY REGULATIONS & FAIR PLAY CODE',
                style: const pw.TextStyle(
                  color: _navy,
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            includeResults
                ? 'All scores and results documented in this official matchday programme are validated and finalized. Any result disputes or appeals must be submitted with match screenshot evidence via the club management console within the designated review window.'
                : 'All participants must report to scheduled kickoff lobbies on time. Matches rescheduled by mutual consent must follow the official tournament rescheduling procedure. Fair play, sportsmanship, and network integrity regulations apply to all fixtures.',
            style: const pw.TextStyle(
              color: _textSecond,
              fontSize: 6.8,
              lineSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'eFootball Mobile Management System',
                style: const pw.TextStyle(color: _textMuted, fontSize: 6.0),
              ),
              pw.Text(
                'VERIFIED OFFICIAL SCHEDULE',
                style: const pw.TextStyle(
                  color: _gold,
                  fontSize: 6.0,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FOOTER — Anchored at bottom of every page
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter({
    required int pageNum,
    required int totalPages,
    required String tournamentName,
    required bool includeResults,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(height: 0.8, color: _paperDark),
          pw.SizedBox(height: 3.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.SvgImage(svg: _svgDiamond, width: 6, height: 6),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    'eFOOTBALL CLUB MANAGER',
                    style: const pw.TextStyle(
                      color: _navy,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    '| OFFICIAL ${includeResults ? "RESULTS" : "FIXTURES"} PROGRAMME',
                    style: const pw.TextStyle(
                      color: _textMuted,
                      fontSize: 6.0,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  'PAGE $pageNum OF $totalPages',
                  style: const pw.TextStyle(
                    color: _paper,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SMALL WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildTag(String label, PdfColor bg, PdfColor fg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      color: bg,
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: fg,
          fontSize: 6.2,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _buildScoreBox(String score, bool isWinner, bool isDraw) {
    final PdfColor bg = isWinner
        ? _emerald
        : (isDraw ? _navy : _paperMid);
    final PdfColor fg = (isWinner || isDraw) ? _paper : _textSecond;
    return pw.Container(
      width: 22,
      height: 22,
      alignment: pw.Alignment.center,
      color: bg,
      child: pw.Text(
        score,
        style: pw.TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildWinnerBadge() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
      color: _emerald,
      child: pw.Text(
        'W',
        style: const pw.TextStyle(
          color: _paper,
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildEmptyState() {
    return pw.Center(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 48),
        padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: pw.BoxDecoration(
          color: _paperMid,
          border: pw.Border.all(color: _paperDark, width: 1),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(width: 32, height: 2, color: _scarlet),
            pw.SizedBox(height: 8),
            pw.Text(
              'NO FIXTURES SCHEDULED',
              style: const pw.TextStyle(
                color: _navy,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'No active or pending matches found for this matchday.',
              style: const pw.TextStyle(color: _textMuted, fontSize: 8.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Container(width: 32, height: 2, color: _scarlet),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPER UTILITIES
  // ─────────────────────────────────────────────────────────────────────────────

  static String _getRoundTitle(int roundNum, String formatType) {
    final fLower = formatType.toLowerCase();
    if (fLower == 'knockout' || (fLower == 'group_knockout' && roundNum >= 10)) {
      if (roundNum == 99 || roundNum >= 50) return 'GRAND FINAL';
      if (roundNum >= 20) return 'SEMI-FINAL';
      if (roundNum >= 10) return 'QUARTER-FINAL';
      return 'ROUND $roundNum | KNOCKOUT';
    }
    return 'ROUND $roundNum';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatWeekday(DateTime dt) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return (dt.weekday >= 1 && dt.weekday <= 7) ? days[dt.weekday] : '';
  }

  static String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return (month >= 1 && month <= 12) ? months[month] : '';
  }
}
