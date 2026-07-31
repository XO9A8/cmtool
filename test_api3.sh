#!/bin/bash
set -e

echo "--- 1. Register User 4 ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testplayer4", "password": "securepassword123"}')
echo $RES
USER_ID=$(echo $RES | jq -r '.user_id')

echo -e "\n--- 2. Login User 4 ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testplayer4", "password": "securepassword123"}')
echo $RES
TOKEN=$(echo $RES | jq -r '.token')

echo -e "\n--- 3. Fetch Player Analytics ---"
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/players/$USER_ID/analytics | jq .

echo -e "\n--- 4. Create Club ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/clubs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "FC Test 4", "invite_code": "TEST4444"}')
echo $RES | jq .

