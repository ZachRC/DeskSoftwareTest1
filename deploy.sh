#!/bin/bash

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
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Install certbot and its nginx plugin
sudo yum install -y certbot python3-certbot-nginx

# Stop nginx temporarily for cert installation
sudo systemctl stop nginx

# Get SSL certificate using standalone mode
if [ ! -d "/etc/letsencrypt/live/kingfakes.college" ]; then
    sudo certbot certonly --standalone -d kingfakes.college -d www.kingfakes.college --agree-tos --email zacharyrcherney@gmail.com --non-interactive
fi

# Create SSL directory and copy certificates
sudo mkdir -p /etc/nginx/ssl/live/kingfakes.college
sudo cp /etc/letsencrypt/live/kingfakes.college/fullchain.pem /etc/nginx/ssl/live/kingfakes.college/
sudo cp /etc/letsencrypt/live/kingfakes.college/privkey.pem /etc/nginx/ssl/live/kingfakes.college/
sudo chmod -R 755 /etc/nginx/ssl

# Create static directory if it doesn't exist
mkdir -p static

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Build and start Docker containers
docker-compose down
docker-compose build
docker-compose up -d

# Wait for web container to be ready
sleep 10

# Run migrations
docker-compose exec web python manage.py migrate

# Collect static files
docker-compose exec web python manage.py collectstatic --noinput

echo "Deployment completed successfully!"

# Set up automatic certificate renewal
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab - 