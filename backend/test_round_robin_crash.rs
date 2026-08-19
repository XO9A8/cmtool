use cmtool_backend::domain::tournament::{generate_round_robin_fixtures, TournamentPlayer};
use uuid::Uuid;

fn main() {
    let mut players = Vec::new();
    for i in 1..=15 {
        players.push(TournamentPlayer {
            id: Uuid::new_v4(),
            username: format!("P{}", i),
            skill_rating: 1000,
        });
    }

    let fixtures = generate_round_robin_fixtures(Uuid::new_v4(), players, 2);
    println!("Fixtures generated: {}", fixtures.len());
}
