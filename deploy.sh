#!/bin/bash

set -e  # Exit on error

# Pull latest changes from git
git pull origin main

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Please update .env file with your production settings"
    exit 1
fi

# Install necessary packages
sudo yum update -y
sudo yum remove -y curl curl-minimal
sudo yum install -y nginx wget

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    # Reload user groups
    newgrp docker
fi

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install certbot
sudo yum install -y certbot python3-certbot-nginx

# Stop services
sudo systemctl stop nginx
docker-compose down -v

# Get SSL certificate using standalone mode
if [ ! -d "/etc/letsencrypt/live/kingfakes.college" ]; then
    sudo certbot certonly --standalone -d kingfakes.college -d www.kingfakes.college --agree-tos --email zacharyrcherney@gmail.com --non-interactive
fi

# Create SSL directory and copy certificates with proper permissions
sudo mkdir -p /etc/nginx/ssl/live/kingfakes.college
sudo cp /etc/letsencrypt/live/kingfakes.college/fullchain.pem /etc/nginx/ssl/live/kingfakes.college/
sudo cp /etc/letsencrypt/live/kingfakes.college/privkey.pem /etc/nginx/ssl/live/kingfakes.college/
sudo chmod -R 755 /etc/nginx/ssl
sudo chown -R nginx:nginx /etc/nginx/ssl

# Create static directory if it doesn't exist
mkdir -p static
sudo chown -R $USER:$USER static

# Build and start Docker containers
echo "Building and starting Docker containers..."
docker-compose build --no-cache
docker-compose up -d

# Wait for web container to be ready
echo "Waiting for web container to be ready..."
sleep 20

# Check container status
docker ps
docker-compose logs web

# Run migrations
docker-compose exec -T web python manage.py migrate

# Collect static files
docker-compose exec -T web python manage.py collectstatic --noinput

# Set proper permissions for static files
sudo chown -R nginx:nginx staticfiles

# Install crontab if not installed
if ! command -v crontab &> /dev/null; then
    sudo yum install -y cronie
    sudo systemctl start crond
    sudo systemctl enable crond
fi

# Set up automatic certificate renewal
(crontab -l 2>/dev/null | grep -v "certbot renew" ; echo "0 0 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

# Verify services are running
echo "Checking service status..."
docker-compose ps
docker-compose logs --tail=50

echo "Deployment completed successfully!"

# Print important information
echo "
Important:
1. Make sure your domain DNS is pointing to: $(curl -s ifconfig.me)
2. Check if the site is accessible at: https://kingfakes.college
3. SSL certificates are in: /etc/letsencrypt/live/kingfakes.college/
4. Logs can be viewed with: docker-compose logs
" 