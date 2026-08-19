use std::str::FromStr;

fn main() {
    let mut players = Vec::new();
    for i in 1..=15 {
        players.push(cmtool_backend::domain::tournament::TournamentPlayer {
            id: uuid::Uuid::new_v4(),
            username: format!("P{}", i),
            skill_rating: 1000,
        });
    }

    let fixtures = cmtool_backend::domain::tournament::generate_round_robin_fixtures(uuid::Uuid::new_v4(), players, 1);
    println!("Total fixtures: {}", fixtures.len());
    
    let mut rounds = std::collections::HashMap::new();
    for f in &fixtures {
        *rounds.entry(f.round_number).or_insert(0) += 1;
    }
    
    let mut keys: Vec<_> = rounds.keys().collect();
    keys.sort();
    for k in keys {
        println!("Round {}: {} matches", k, rounds[k]);
    }
}
