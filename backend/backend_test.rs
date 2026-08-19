use sqlx::postgres::PgPoolOptions;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let database_url = "postgresql://postgres.ypsrkdefgbghvluuyynm:CmT00l_Supabase_2026!@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres";
    let pool = PgPoolOptions::new().max_connections(2).connect(database_url).await?;

    // Try inserting round 8 match 1
    let tm_id = uuid::Uuid::new_v4();
    let t_id = uuid::Uuid::parse_str("b05bae39-c094-4317-8cf4-34685dcda086")?;
    
    // Check if matchdays exist for round 8
    let md_res = sqlx::query!("SELECT id FROM matchdays WHERE tournament_id = $1 AND matchday_number = 8", t_id)
        .fetch_optional(&pool).await?;
        
    println!("Matchday 8 exists: {:?}", md_res.is_some());
    
    if let Some(md) = md_res {
        let res = sqlx::query(
            "INSERT INTO t_matches (id, tournament_id, round_number, match_number, matchday_id, status) VALUES ($1, $2, 8, 1, $3, 'scheduled')"
        )
        .bind(tm_id)
        .bind(t_id)
        .bind(md.id)
        .execute(&pool)
        .await;
        
        println!("Insert result: {:?}", res);
    }
    
    Ok(())
}
