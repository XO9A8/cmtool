use jsonwebtoken::{encode, decode, Header, Validation, EncodingKey, DecodingKey};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    aud: String,
    exp: usize,
}

fn main() {
    let secret = "rL2TJd7ynmkI5IjDbxL5vIuLM4ZFWLqh2YuNNR9FweLTRgE8qZvZHrrv2W+hJT1jHnKAVHFLmijH4cvqhTROMQ==";
    
    let claims = Claims {
        sub: "test-user-id".to_string(),
        aud: "authenticated".to_string(),
        exp: 2000000000,
    };

    let token = encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_bytes())).unwrap();
    println!("Token: {}", token);

    let mut validation = Validation::default();
    validation.validate_aud = false;

    match decode::<Claims>(&token, &DecodingKey::from_secret(secret.as_bytes()), &validation) {
        Ok(c) => println!("Decoded successfully: {:?}", c.claims),
        Err(e) => println!("Decode error: {:?}", e),
    }
}
