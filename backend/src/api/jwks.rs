use axum::http::StatusCode;
use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{decode, decode_header, DecodingKey, Validation};
use reqwest::Client;
use std::sync::OnceLock;
use tokio::sync::RwLock;

use crate::domain::auth::Claims;

static JWKS_CACHE: OnceLock<RwLock<Option<JwkSet>>> = OnceLock::new();

fn get_jwks_cache() -> &'static RwLock<Option<JwkSet>> {
    JWKS_CACHE.get_or_init(|| RwLock::new(None))
}

pub async fn verify_supabase_token(token: &str, supabase_url: &str) -> Result<Claims, String> {
    let header = decode_header(token).map_err(|e| e.to_string())?;
    
    // If it's HS256, verify using the JWT_SECRET (for local testing / anon keys)
    if header.alg == jsonwebtoken::Algorithm::HS256 {
        let secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "default_cmtool_jwt_secret_key_2026".to_string());
        return crate::domain::auth::verify_jwt_token(token, &secret);
    }

    // Otherwise, assume it's ES256/RS256 and fetch JWKS
    let cache = get_jwks_cache();
    let mut jwks_opt = cache.read().await.clone();
    
    if jwks_opt.is_none() {
        let client = Client::new();
        let url = format!("{}/auth/v1/jwks", supabase_url);
        let jwks: JwkSet = client.get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch JWKS: {}", e))?
            .json()
            .await
            .map_err(|e| format!("Failed to parse JWKS: {}", e))?;
            
        *cache.write().await = Some(jwks.clone());
        jwks_opt = Some(jwks);
    }
    
    let jwks = jwks_opt.unwrap();
    let kid = header.kid.ok_or_else(|| "Missing kid in JWT header".to_string())?;
    
    let jwk = jwks.find(&kid).ok_or_else(|| "JWK not found".to_string())?;
    let decoding_key = DecodingKey::from_jwk(jwk).map_err(|e| e.to_string())?;
    
    let mut validation = Validation::new(header.alg);
    validation.validate_aud = false;
    
    let token_data = decode::<Claims>(token, &decoding_key, &validation).map_err(|e| e.to_string())?;
    Ok(token_data.claims)
}
