fn main() {
    let r1_matches = 2;
    let total_rounds = (r1_matches as f64).log2().ceil() as i32 + 1;
    println!("total_rounds: {}", total_rounds);
}
