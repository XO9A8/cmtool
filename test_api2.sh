#!/bin/bash
set -e

echo "--- 1. Register User 2 ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testplayer2", "password": "securepassword123"}')
echo $RES
USER_ID=$(echo $RES | jq -r '.user_id')
TOKEN=$(echo $RES | jq -r '.token')

echo -e "\n--- 3. Fetch Player Analytics ---"
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/players/$USER_ID/analytics | jq .

echo -e "\n--- 4. Create Club ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/clubs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "FC Test 2", "invite_code": "TEST12345"}')
echo $RES | jq .

