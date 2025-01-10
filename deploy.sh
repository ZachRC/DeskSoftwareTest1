#!/bin/bash

set -e  # Exit on error

echo "Starting deployment process..."

# Pull latest changes from git
git pull origin main

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Please update .env file with your production settings"
    exit 1
fi

# Install necessary packages without removing system packages
echo "Installing necessary packages..."
sudo yum update -y
sudo yum install -y nginx

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo wget "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -O /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install certbot
echo "Installing Certbot..."
sudo yum install -y certbot python3-certbot-nginx

# Stop services
echo "Stopping services..."
sudo systemctl stop nginx || true
docker-compose down || true

# Clean up any old containers and volumes
echo "Cleaning up old containers and volumes..."
docker system prune -f
docker volume prune -f

# Get SSL certificate using standalone mode
echo "Setting up SSL certificates..."
if [ ! -d "/etc/letsencrypt/live/kingfakes.college" ]; then
    sudo certbot certonly --standalone -d kingfakes.college -d www.kingfakes.college --agree-tos --email zacharyrcherney@gmail.com --non-interactive
fi

# Create SSL directory and copy certificates with proper permissions
sudo mkdir -p /etc/nginx/ssl/live/kingfakes.college
sudo cp /etc/letsencrypt/live/kingfakes.college/fullchain.pem /etc/nginx/ssl/live/kingfakes.college/
sudo cp /etc/letsencrypt/live/kingfakes.college/privkey.pem /etc/nginx/ssl/live/kingfakes.college/
sudo chmod -R 755 /etc/nginx/ssl
sudo chown -R nginx:nginx /etc/nginx/ssl

# Create directories and set permissions
echo "Setting up directories and permissions..."
mkdir -p static staticfiles
sudo chown -R $USER:$USER static staticfiles

# Build and start Docker containers
echo "Building and starting Docker containers..."
docker-compose build --no-cache
docker-compose up -d

# Wait for web container to be ready
echo "Waiting for web container to be ready..."
attempt=1
max_attempts=5
until docker-compose ps | grep "web" | grep "(healthy)" || [ $attempt -gt $max_attempts ]
do
    echo "Attempt $attempt of $max_attempts: Waiting for web service to be healthy..."
    sleep 30
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "Web service failed to become healthy. Checking logs:"
    docker-compose logs web
    exit 1
fi

echo "Web service is healthy. Running database migrations..."
docker-compose exec -T web python manage.py migrate

echo "Collecting static files..."
docker-compose exec -T web python manage.py collectstatic --noinput

# Set proper permissions for static files
sudo chown -R nginx:nginx staticfiles

# Install and configure cron
echo "Setting up cron jobs..."
sudo yum install -y cronie
sudo systemctl start crond
sudo systemctl enable crond

# Set up automatic certificate renewal
(crontab -l 2>/dev/null | grep -v "certbot renew" ; echo "0 0 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

# Final status check
echo "Checking final deployment status..."
docker-compose ps
docker-compose logs --tail=50

echo "Deployment completed successfully!"

# Print important information
echo "
Important Information:
---------------------
1. Domain DNS should point to: $(curl -s ifconfig.me)
2. Website URL: https://kingfakes.college
3. SSL certificates location: /etc/letsencrypt/live/kingfakes.college/
4. View logs with: docker-compose logs

To check container status: docker-compose ps
To view logs: docker-compose logs
To restart services: docker-compose restart
"

# Verify nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t

# Start nginx if it's not running
echo "Starting Nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

echo "Deployment process complete!" 