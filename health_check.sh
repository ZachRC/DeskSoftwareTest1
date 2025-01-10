#!/bin/bash

# Function to check if gunicorn is running
check_gunicorn() {
    pgrep -f "gunicorn" > /dev/null
    return $?
}

# Function to check the health endpoint
check_health() {
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health/)
    if [ "$response" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Main health check
if check_gunicorn; then
    if check_health; then
        exit 0
    else
        echo "Health check failed with status: $response"
        exit 1
    fi
else
    echo "Gunicorn is not running"
    exit 1
fi 