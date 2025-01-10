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
    nginx \
    python3-certbot-nginx

# Start and enable Docker
echo "Starting Docker..."
sudo systemctl start docker
sudo systemctl enable docker

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

# Start the application
echo "Starting application..."
sudo docker-compose up -d

# Initialize SSL certificates
echo "Initializing SSL certificates..."
sudo certbot certonly --webroot \
    -w nginx/certbot/www \
    -d solforge.live \
    -d www.solforge.live \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email \
    --force-renewal

# Restart nginx container to apply SSL
echo "Restarting nginx..."
sudo docker-compose restart nginx

echo "Deployment complete! Your application should be running at https://solforge.live" 