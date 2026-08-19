use printpdf::*;
use std::io::Cursor;

use crate::infrastructure::postgres_adapter::TMatchRow;

pub fn generate_matchday_pdf(
    tournament_name: &str,
    matchday_number: i32,
    matches: &[TMatchRow],
    include_results: bool,
) -> Vec<u8> {
    let (doc, page1, layer1) = PdfDocument::new(
        format!("{} - Matchday {}", tournament_name, matchday_number),
        Mm(210.0),
        Mm(297.0),
        "Layer 1",
    );
    
    let current_layer = doc.get_page(page1).get_layer(layer1);

    let font = doc.add_builtin_font(BuiltinFont::Helvetica).unwrap();
    let font_bold = doc.add_builtin_font(BuiltinFont::HelveticaBold).unwrap();

    // Title
    current_layer.use_text(
        format!("{} - Matchday {}", tournament_name, matchday_number),
        24.0,
        Mm(20.0),
        Mm(270.0),
        &font_bold,
    );

    let mut y = 250.0;
    
    for m in matches {
        let p1 = m.player_1_name.clone().unwrap_or_else(|| "TBD".to_string());
        let p2 = m.player_2_name.clone().unwrap_or_else(|| "TBD".to_string());
        
        let score_str = if include_results && m.status == "completed" {
            format!(" {} - {} ", m.player_1_score.unwrap_or(0), m.player_2_score.unwrap_or(0))
        } else {
            " vs ".to_string()
        };

        let match_text = format!("{} {} {}", p1, score_str, p2);
        
        current_layer.use_text(match_text, 14.0, Mm(20.0), Mm(y), &font);
        
        if let Some(reason) = &m.reschedule_reason {
            y -= 6.0;
            current_layer.use_text(format!("Note: {}", reason), 10.0, Mm(25.0), Mm(y), &font);
        }

        y -= 15.0;
    }

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut buf = std::io::BufWriter::new(&mut cursor);
        doc.save(&mut buf).unwrap();
    }
    cursor.into_inner()
}
