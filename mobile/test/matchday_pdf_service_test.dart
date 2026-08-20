import 'package:flutter_test/flutter_test.dart';
import 'package:cmtool_mobile/presentation/utils/matchday_pdf_service.dart';

void main() {
  group('MatchdayPdfService Tests', () {
    final sampleFixtures = [
      {
        'id': 'match-1',
        'matchday_id': 'md-1',
        'round_number': 1,
        'group_name': 'A',
        'status': 'completed',
        'player_1_id': 'p1',
        'player_1_name': 'Alice',
        'player_1_score': 3,
        'player_1_rating': 1500,
        'player_2_id': 'p2',
        'player_2_name': 'Bob',
        'player_2_score': 1,
        'player_2_rating': 1420,
        'winner_player_id': 'p1',
        'is_rescheduled': false,
        'scheduled_at': '2026-08-21T14:00:00Z',
      },
      {
        'id': 'match-2',
        'matchday_id': 'md-1',
        'round_number': 1,
        'group_name': 'A',
        'status': 'scheduled',
        'player_1_id': 'p3',
        'player_1_name': 'Charlie',
        'player_1_rating': 1380,
        'player_2_id': 'p4',
        'player_2_name': 'David',
        'player_2_rating': 1410,
        'is_rescheduled': false,
        'scheduled_at': '2026-08-21T15:30:00Z',
      },
      {
        'id': 'match-3',
        'matchday_id': 'md-2',
        'round_number': 2,
        'group_name': 'B',
        'status': 'rescheduled',
        'player_1_id': 'p5',
        'player_1_name': 'Eve',
        'player_1_rating': 1600,
        'player_2_id': 'p6',
        'player_2_name': 'Frank',
        'player_2_rating': 1550,
        'is_rescheduled': true,
        'reschedule_reason': 'Player requested delay due to travel',
        'scheduled_at': '2026-08-21T18:00:00Z',
        'original_scheduled_at': '2026-08-22T18:00:00Z',
      },
    ];

    test('generates valid PDF bytes for Matchday 1 fixtures', () async {
      final selectedMd = {
        'id': 'md-1',
        'matchday_number': 1,
        'scheduled_date': '2026-08-21',
      };

      final pdfBytes = await MatchdayPdfService.generateMatchdayPdf(
        tournamentName: 'Summer Esports Championship',
        formatType: 'single_round_robin',
        selectedMatchday: selectedMd,
        allFixtures: sampleFixtures,
        includeResults: false,
        clubName: 'Black Falcons',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25);
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });

    test('generates valid PDF bytes for Matchday 1 results', () async {
      final selectedMd = {
        'id': 'md-1',
        'matchday_number': 1,
        'scheduled_date': '2026-08-21',
      };

      final pdfBytes = await MatchdayPdfService.generateMatchdayPdf(
        tournamentName: 'Summer Esports Championship',
        formatType: 'single_round_robin',
        selectedMatchday: selectedMd,
        allFixtures: sampleFixtures,
        includeResults: true,
        clubName: 'Black Falcons',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      expect(pdfBytes[0], 0x25);
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });

    test('generates valid PDF bytes for ALL matchdays', () async {
      final pdfBytes = await MatchdayPdfService.generateMatchdayPdf(
        tournamentName: 'Summer Esports Championship',
        formatType: 'single_round_robin',
        selectedMatchday: {'id': 'all', 'matchday_number': 'ALL'},
        allFixtures: sampleFixtures,
        includeResults: false,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25);
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });
  });
}
