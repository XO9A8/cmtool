use jsonwebtoken::decode_header;
use reqwest::Client;

use crate::domain::auth::Claims;

pub async fn verify_supabase_token(token: &str, supabase_url: &str) -> Result<Claims, String> {
    let header = decode_header(token).map_err(|e| e.to_string())?;
    
    // If it's HS256, verify using the JWT_SECRET (for local testing / anon keys)
    if header.alg == jsonwebtoken::Algorithm::HS256 {
        let secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "default_cmtool_jwt_secret_key_2026".to_string());
        return crate::domain::auth::verify_jwt_token(token, &secret);
    }

    // Call Supabase /auth/v1/user to verify the token
    let anon_key = std::env::var("SUPABASE_ANON_KEY")
        .unwrap_or_else(|_| "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg".to_string());
        
    let client = Client::new();
    let url = format!("{}/auth/v1/user", supabase_url);
    
    let res = client.get(&url)
        .header("apikey", anon_key)
        .header("Authorization", format!("Bearer {}", token))
        .send()
        .await
        .map_err(|e| format!("Failed to verify token with Supabase: {}", e))?;
        
    if !res.status().is_success() {
        return Err("Supabase rejected the token".to_string());
    }
    
    let user_data: serde_json::Value = res.json()
        .await
        .map_err(|e| format!("Failed to parse user data: {}", e))?;
        
    let sub = user_data["id"].as_str().ok_or("Missing id in Supabase response")?.to_string();
    
    Ok(Claims {
        sub,
        username: None,
        exp: 0,
    })
}
