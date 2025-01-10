#!/bin/bash

# Pull latest changes from git
git pull origin main

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Please update .env file with your production settings"
    exit 1
fi

# Install or update certbot if needed
if ! command -v certbot &> /dev/null; then
    sudo yum install -y certbot python3-certbot-nginx
fi

# Get SSL certificate if not already present
if [ ! -d "/etc/letsencrypt/live/kingfakes.college" ]; then
    sudo certbot certonly --nginx -d kingfakes.college -d www.kingfakes.college
fi

# Create SSL directory in nginx config if it doesn't exist
sudo mkdir -p /etc/nginx/ssl/live/kingfakes.college
sudo cp /etc/letsencrypt/live/kingfakes.college/fullchain.pem /etc/nginx/ssl/live/kingfakes.college/
sudo cp /etc/letsencrypt/live/kingfakes.college/privkey.pem /etc/nginx/ssl/live/kingfakes.college/

# Build and start Docker containers
docker-compose down
docker-compose build
docker-compose up -d

# Run migrations
docker-compose exec web python manage.py migrate

echo "Deployment completed successfully!" 