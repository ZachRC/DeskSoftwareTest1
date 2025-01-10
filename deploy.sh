#!/bin/bash

# Pull latest changes
git pull origin main

# Copy .env file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Please update the .env file with your actual credentials"
    exit 1
fi

# Install or update dependencies
pip install -r requirements.txt

# Add gunicorn and psycopg2-binary to requirements
if ! grep -q "gunicorn" requirements.txt; then
    echo "gunicorn" >> requirements.txt
fi
if ! grep -q "psycopg2-binary" requirements.txt; then
    echo "psycopg2-binary" >> requirements.txt
fi

# Build and start Docker containers
docker-compose down
docker-compose build
docker-compose up -d

# Apply database migrations
docker-compose exec web python manage.py migrate

echo "Deployment completed successfully!" 