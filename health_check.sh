#!/bin/bash
set -e

# Wait for a response from the health check endpoint
# Allow redirects and accept any status code between 200-399
response=$(curl -s -o /dev/null -w "%{http_code}" -L http://localhost:8000/health/)
if [ $response -ge 200 ] && [ $response -lt 400 ]; then
    exit 0
else
    exit 1
fi 