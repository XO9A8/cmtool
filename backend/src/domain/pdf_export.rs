use printpdf::*;
use std::io::Cursor;

use crate::infrastructure::postgres_adapter::TMatchRow;

pub fn generate_matchday_pdf(
    tournament_name: &str,
    matchday_number: i32,
    matches: &[TMatchRow],
    include_results: bool,
) -> Vec<u8> {
    let title_type = if include_results { "Results" } else { "Fixtures" };
    let (doc, page1, layer1) = PdfDocument::new(
        format!("{} - Matchday {} {}", tournament_name, matchday_number, title_type),
        Mm(210.0),
        Mm(297.0),
        "Layer 1",
    );

    let font = doc.add_builtin_font(BuiltinFont::Helvetica).unwrap();
    let font_bold = doc.add_builtin_font(BuiltinFont::HelveticaBold).unwrap();

    let chunks: Vec<&[TMatchRow]> = if matches.is_empty() {
        vec![&[]]
    } else {
        matches.chunks(10).collect()
    };

    let total_pages = chunks.len();

    for (chunk_idx, chunk) in chunks.iter().enumerate() {
        let (_current_page, current_layer) = if chunk_idx == 0 {
            (page1, doc.get_page(page1).get_layer(layer1))
        } else {
            let (p, l) = doc.add_page(Mm(210.0), Mm(297.0), format!("Layer {}", chunk_idx + 1));
            (p, doc.get_page(p).get_layer(l))
        };

        let page_num = chunk_idx + 1;

        // ── Header Masthead ──────────────────────────────────────────────────
        // Title
        current_layer.use_text(
            tournament_name.to_uppercase(),
            16.0,
            Mm(20.0),
            Mm(275.0),
            &font_bold,
        );

        // Subtitle / Info
        let mode_str = if include_results { "OFFICIAL RESULTS" } else { "OFFICIAL FIXTURES" };
        let md_str = if matchday_number == 0 {
            format!("ALL MATCHDAYS | {}", mode_str)
        } else {
            format!("MATCHDAY {} | {}", matchday_number, mode_str)
        };
        current_layer.use_text(md_str, 10.0, Mm(20.0), Mm(268.0), &font);

        // Top horizontal divider rule
        let line_top = Line {
            points: vec![
                (Point::new(Mm(20.0), Mm(263.0)), false),
                (Point::new(Mm(190.0), Mm(263.0)), false),
            ],
            is_closed: false,
            has_fill: false,
            has_stroke: true,
            is_clipping_path: false,
        };
        current_layer.add_shape(line_top);

        // ── Matches (Fixed 10 per page, evenly structured) ───────────────────
        let mut y = 248.0;
        let row_height = 20.0;

        if chunk.is_empty() {
            current_layer.use_text(
                "No matches scheduled for this matchday.",
                12.0,
                Mm(20.0),
                Mm(230.0),
                &font,
            );
        } else {
            for (i, m) in chunk.iter().enumerate() {
                let match_index = chunk_idx * 10 + i + 1;
                let p1 = m.player_1_name.clone().unwrap_or_else(|| "TBD".to_string());
                let p2 = m.player_2_name.clone().unwrap_or_else(|| "TBD".to_string());

                // Index and stage label
                let stage = match &m.group_name {
                    Some(grp) => format!("#{:02} | GRP {} | RD {}", match_index, grp, m.round_number),
                    None => format!("#{:02} | ROUND {}", match_index, m.round_number),
                };

                let time_str = if let Some(sched) = &m.scheduled_at {
                    sched.format("%H:%M UTC").to_string()
                } else {
                    "18:00 UTC".to_string()
                };

                current_layer.use_text(&stage, 7.5, Mm(22.0), Mm(y + 3.0), &font_bold);
                current_layer.use_text(&format!("KO: {}", time_str), 7.5, Mm(160.0), Mm(y + 3.0), &font);

                // Match details
                let score_str = if include_results && m.status == "completed" {
                    format!("{} - {}", m.player_1_score.unwrap_or(0), m.player_2_score.unwrap_or(0))
                } else {
                    "VS".to_string()
                };

                let p1_display = if p1.len() > 18 { format!("{}...", &p1[..15]) } else { p1 };
                let p2_display = if p2.len() > 18 { format!("{}...", &p2[..15]) } else { p2 };

                current_layer.use_text(&p1_display, 11.0, Mm(22.0), Mm(y - 4.0), &font_bold);
                current_layer.use_text(&score_str, 11.0, Mm(100.0), Mm(y - 4.0), &font_bold);
                current_layer.use_text(&p2_display, 11.0, Mm(130.0), Mm(y - 4.0), &font_bold);

                if let Some(reason) = &m.reschedule_reason {
                    current_layer.use_text(
                        format!("Note: {}", reason),
                        6.5,
                        Mm(22.0),
                        Mm(y - 8.5),
                        &font,
                    );
                }

                // Row divider
                let row_line = Line {
                    points: vec![
                        (Point::new(Mm(20.0), Mm(y - 10.0)), false),
                        (Point::new(Mm(190.0), Mm(y - 10.0)), false),
                    ],
                    is_closed: false,
                    has_fill: false,
                    has_stroke: true,
                    is_clipping_path: false,
                };
                current_layer.add_shape(row_line);

                y -= row_height;
            }

            // If < 10 matches on the page, fill the bottom area with official tournament guidelines
            if chunk.len() < 10 {
                let notice_y = y - 5.0;
                current_layer.use_text(
                    "OFFICIAL MATCHDAY REGULATIONS & INTEGRITY NOTICE",
                    8.0,
                    Mm(22.0),
                    Mm(notice_y),
                    &font_bold,
                );
                current_layer.use_text(
                    "All participants must adhere to scheduled kickoff windows and submit match records upon completion.",
                    7.0,
                    Mm(22.0),
                    Mm(notice_y - 5.0),
                    &font,
                );
                current_layer.use_text(
                    "Fair play, network integrity, and sportsmanship regulations apply to all tournament fixtures.",
                    7.0,
                    Mm(22.0),
                    Mm(notice_y - 9.0),
                    &font,
                );
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        let line_bottom = Line {
            points: vec![
                (Point::new(Mm(20.0), Mm(22.0)), false),
                (Point::new(Mm(190.0), Mm(22.0)), false),
            ],
            is_closed: false,
            has_fill: false,
            has_stroke: true,
            is_clipping_path: false,
        };
        current_layer.add_shape(line_bottom);

        current_layer.use_text(
            "eFootball Club Manager | Official Matchday Export",
            7.0,
            Mm(20.0),
            Mm(16.0),
            &font,
        );

        let page_str = format!("PAGE {} OF {}", page_num, total_pages);
        current_layer.use_text(page_str, 7.0, Mm(165.0), Mm(16.0), &font_bold);
    }

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut buf = std::io::BufWriter::new(&mut cursor);
        doc.save(&mut buf).unwrap();
    }
    cursor.into_inner()
}
