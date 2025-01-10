#!/bin/bash

# Update system
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt-get install -y \
    docker.io \
    docker-compose \
    python3-certbot-nginx

# Stop and disable system nginx if it's running
echo "Stopping system Nginx..."
sudo systemctl stop nginx
sudo systemctl disable nginx

# Start and enable Docker
echo "Starting Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Clean up any existing containers
echo "Cleaning up existing containers..."
sudo docker-compose down -v
sudo docker system prune -f

# Create necessary directories
echo "Creating directories..."
mkdir -p nginx/certbot/conf
mkdir -p nginx/certbot/www

# Generate strong DH parameters for SSL
echo "Generating DH parameters..."
sudo openssl dhparam -out nginx/certbot/conf/ssl-dhparams.pem 2048

# Set up environment variables
echo "Setting up environment variables..."
cat > .env << EOL
DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_DEBUG=0
STRIPE_PUBLISHABLE_KEY=pk_test_51Qf59sQ7s3yogV6Hy36945QjOpHOOr2dRnre5KizxYsNloySglmBlQKQNszXCKwc1mYM6lOnAAFCrUCHUwg3tQaX00ZR7T9HAs
STRIPE_SECRET_KEY=sk_test_51Qf59sQ7s3yogV6Heyj8Ow7cMLVZqMnMImarJ4EWQ8cO4aqHvndg6JEp4EzgE3iX07BPruJ438EG0Eno4B3KaEgy00ODJ1udAW
EOL

# Start the application without nginx first
echo "Starting web and redis services..."
sudo docker-compose up -d web redis

# Wait for web service to be ready
echo "Waiting for web service to be ready..."
sleep 10

# Start nginx
echo "Starting nginx service..."
sudo docker-compose up -d nginx

# Initialize SSL certificates
echo "Initializing SSL certificates..."
read -p "Enter your email for SSL certificate notifications: " EMAIL
sudo certbot certonly --webroot \
    -w nginx/certbot/www \
    -d solforge.live \
    -d www.solforge.live \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal

# Restart nginx container to apply SSL
echo "Restarting nginx..."
sudo docker-compose restart nginx

# Start certbot container
echo "Starting certbot service..."
sudo docker-compose up -d certbot

echo "Deployment complete! Your application should be running at https://solforge.live"

# Show logs
echo "Showing logs (Ctrl+C to exit)..."
sudo docker-compose logs -f 