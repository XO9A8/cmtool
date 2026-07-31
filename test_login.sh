#!/bin/bash
echo "--- 1. Register User 3 ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testplayer3", "password": "securepassword123"}')
echo $RES

echo -e "\n--- 2. Login User 3 ---"
RES=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testplayer3", "password": "securepassword123"}')
echo $RES
