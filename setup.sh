#!/bin/bash

# Exit on error
set -e

# Update system
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt-get install -y \
    docker.io \
    docker-compose \
    git \
    nginx \
    certbot \
    python3-certbot-nginx

# Start and enable Docker
echo "Setting up Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/ZachRC/DeskSoftwareTest1.git webapp
cd webapp

# Create necessary directories
echo "Creating directories..."
mkdir -p nginx/conf.d
mkdir -p certbot/conf
mkdir -p certbot/www

# Copy configuration files
echo "Setting up configuration files..."
cp nginx/nginx.conf nginx/conf.d/

# Create .env file
echo "Creating .env file..."
cat > .env << EOL
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
DJANGO_DEBUG=0
DATABASE_URL=postgres://postgres.bhryplxtproznrmtvvri:Zc1269zc!zc1269zc@aws-0-us-east-2.pooler.supabase.com:6543/postgres
DOMAIN=solforge.live
EOL

# Initialize SSL certificates
echo "Initializing SSL certificates..."
sudo certbot certonly --nginx -d solforge.live -d www.solforge.live

# Start the application
echo "Starting the application..."
sudo docker-compose up -d

echo "Setup completed successfully!"
echo "Please ensure your DNS settings are configured correctly:"
echo "A Record: @ -> 18.116.81.42"
echo "A Record: www -> 18.116.81.42"
echo "AAAA Record: @ -> 2600:1f16:851:b900:3e63:6d69:e839:1a2b"
echo "AAAA Record: www -> 2600:1f16:851:b900:3e63:6d69:e839:1a2b" 