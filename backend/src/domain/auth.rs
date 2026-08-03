use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String, // user_id Uuid
    pub username: Option<String>,
    pub exp: usize,
}

pub fn hash_password(password: &str) -> Result<String, String> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    argon2
        .hash_password(password.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| e.to_string())
}

pub fn verify_password(password: &str, password_hash: &str) -> bool {
    let parsed_hash = match PasswordHash::new(password_hash) {
        Ok(h) => h,
        Err(_) => return false,
    };
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok()
}

pub fn create_jwt_token(user_id: Uuid, username: &str, secret: &str) -> Result<String, String> {
    let expiration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_secs() as usize
        + (24 * 3600); // 24 hours expiry

    let claims = Claims {
        sub: user_id.to_string(),
        username: Some(username.to_string()),
        exp: expiration,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| e.to_string())
}

pub fn verify_jwt_token(token: &str, secret: &str) -> Result<Claims, String> {
    let mut validation = Validation::default();
    validation.validate_aud = false; // Supabase adds 'aud': 'authenticated' which fails default validation

    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &validation,
    )
    .map_err(|e| e.to_string())?;

    Ok(token_data.claims)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_password_hashing_and_verification() {
        let password = "SuperSecretPassword123!";
        let hash = hash_password(password).expect("Hashing failed");

        assert!(verify_password(password, &hash));
        assert!(!verify_password("WrongPassword!", &hash));
    }

    #[test]
    fn test_jwt_token_creation_and_verification() {
        let user_id = Uuid::new_v4();
        let username = "ApexStriker";
        let secret = "jwt_secret_key_for_testing";

        let token = create_jwt_token(user_id, username, secret).expect("JWT encoding failed");
        let claims = verify_jwt_token(&token, secret).expect("JWT decoding failed");

        assert_eq!(claims.sub, user_id.to_string());
        assert_eq!(claims.username.as_deref(), Some(username));
    }
}
