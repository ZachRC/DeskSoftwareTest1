#!/bin/bash

# Exit on error
set -e

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    sudo docker-compose down -v 2>/dev/null || true
    sudo docker system prune -af --volumes
    
    # Clean up directories with proper permissions
    if [ -d "webapp" ]; then
        sudo rm -rf webapp
    fi
}

# Error handler
handle_error() {
    echo "An error occurred on line $1"
    cleanup
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

echo "Starting setup..."

# Clean up any previous installation
cleanup
cd ~

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
    python3-certbot-nginx \
    ufw \
    curl

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Stop and disable system Nginx
echo "Stopping system Nginx..."
sudo systemctl stop nginx
sudo systemctl disable nginx

# Start and enable Docker
echo "Setting up Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/ZachRC/DeskSoftwareTest1.git webapp
cd webapp

# Create necessary directories with proper permissions
echo "Creating directories..."
sudo mkdir -p nginx/conf.d \
         certbot/conf \
         certbot/www

# Set proper permissions
echo "Setting permissions..."
sudo chown -R $USER:$USER .
sudo chmod -R 755 .
sudo chmod g+s .

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
STRIPE_PUBLISHABLE_KEY=pk_test_51Qf59sQ7s3yogV6Hy36945QjOpHOOr2dRnre5KizxYsNloySglmBlQKQNszXCKwc1mYM6lOnAAFCrUCHUwg3tQaX00ZR7T9HAs
STRIPE_SECRET_KEY=sk_test_51Qf59sQ7s3yogV6Heyj8Ow7cMLVZqMnMImarJ4EWQ8cO4aqHvndg6JEp4EzgE3iX07BPruJ438EG0Eno4B3KaEgy00ODJ1udAW
EOL

# Check if ports 80 and 443 are in use
echo "Checking ports..."
if sudo lsof -i :80 || sudo lsof -i :443; then
    echo "Ports 80 or 443 are in use. Attempting to free them..."
    sudo fuser -k 80/tcp
    sudo fuser -k 443/tcp
    sleep 5
fi

# Create SSL configuration files first
echo "Creating SSL configuration files..."
sudo mkdir -p certbot/conf
sudo openssl dhparam -out certbot/conf/ssl-dhparams.pem 2048
sudo chown -R $USER:$USER certbot

# Create Nginx SSL options file
cat > certbot/conf/options-ssl-nginx.conf << EOL
ssl_session_cache shared:le_nginx_SSL:1m;
ssl_session_timeout 1440m;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOL

# Create Docker volumes
echo "Creating Docker volumes..."
sudo docker volume create webapp_static_volume
sudo docker volume create webapp_media_volume

# Pull Docker images
echo "Pulling Docker images..."
sudo docker-compose pull

# Build the images
echo "Building Docker images..."
sudo docker-compose build --no-cache

# Start Nginx container first for certbot
echo "Starting Nginx for SSL setup..."
sudo docker-compose up -d nginx

# Wait for Nginx to start
sleep 5

# Run certbot
echo "Setting up SSL certificates..."
sudo docker-compose run --rm certbot certonly --webroot -w /var/www/certbot --email your-email@example.com -d solforge.live -d www.solforge.live --agree-tos --no-eff-email --force-renewal

# Ensure proper permissions for SSL certificates
sudo chown -R $USER:$USER certbot/conf
sudo chmod -R 755 certbot/conf

# Start the remaining services
echo "Starting remaining services..."
sudo docker-compose up -d web redis

# Wait for services to be up
echo "Waiting for services to start..."
sleep 15

# Check container status
echo "Checking container status..."
if ! sudo docker-compose ps | grep "Up" | grep -q "web"; then
    echo "Web container failed to start. Checking logs..."
    sudo docker-compose logs web
    cleanup
    exit 1
fi

if ! sudo docker-compose ps | grep "Up" | grep -q "nginx"; then
    echo "Nginx container failed to start. Checking logs..."
    sudo docker-compose logs nginx
    cleanup
    exit 1
fi

# Restart Nginx to apply SSL configuration
echo "Restarting Nginx..."
sudo docker-compose restart nginx

# Final status check
echo -e "\nFinal container status:"
sudo docker-compose ps

# Test HTTPS connection
echo "Testing HTTPS connection..."
sleep 5
if ! curl -k -s -o /dev/null -w "%{http_code}" https://localhost | grep -q "200\|301\|302"; then
    echo "HTTPS connection test failed. Checking logs..."
    sudo docker-compose logs
    cleanup
    exit 1
fi

echo "Setup completed successfully!"
echo "Please ensure your DNS settings are configured correctly:"
echo "A Record: @ -> 18.116.81.42"
echo "A Record: www -> 18.116.81.42"
echo "AAAA Record: @ -> 2600:1f16:851:b900:3e63:6d69:e839:1a2b"
echo "AAAA Record: www -> 2600:1f16:851:b900:3e63:6d69:e839:1a2b" 