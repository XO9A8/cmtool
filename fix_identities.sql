INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid(),
    id,
    id::text, -- Some Supabase versions use the user id as provider_id for email, some use email.
    jsonb_build_object('sub', id, 'email', email),
    'email',
    created_at,
    created_at,
    updated_at
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM auth.identities);
