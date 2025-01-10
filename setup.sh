#!/bin/bash

# Exit on error
set -e

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    sudo docker-compose down 2>/dev/null || true
    sudo docker system prune -f 2>/dev/null || true
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
rm -rf webapp

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

# Create necessary directories
echo "Creating directories..."
mkdir -p nginx/conf.d
mkdir -p certbot/conf
mkdir -p certbot/www
mkdir -p static
mkdir -p media
mkdir -p staticfiles

# Set proper permissions
echo "Setting permissions..."
sudo chown -R $USER:$USER .
sudo chmod -R 755 .

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

# Build and start the application with HTTP only
echo "Building and starting the application..."
sudo docker-compose build --no-cache
sudo docker-compose up -d

# Wait for services to be up
echo "Waiting for services to start..."
sleep 10

# Check if services are running
echo "Checking service status..."
if ! sudo docker-compose ps | grep "Up" | grep -q "web"; then
    echo "Web service failed to start. Checking logs..."
    sudo docker-compose logs web
    cleanup
    exit 1
fi

if ! sudo docker-compose ps | grep "Up" | grep -q "nginx"; then
    echo "Nginx service failed to start. Checking logs..."
    sudo docker-compose logs nginx
    cleanup
    exit 1
fi

# Test the connection
echo "Testing connection..."
if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200\|301\|302"; then
    echo "Connection test failed. Checking logs..."
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

# Print service status
echo -e "\nService Status:"
sudo docker-compose ps

# Generate SSL certificates
echo "Generating SSL certificates..."
sudo certbot certonly --webroot -w ./certbot/www -d solforge.live -d www.solforge.live --email your-email@example.com --agree-tos --no-eff-email

# Create SSL configuration files
echo "Creating SSL configuration files..."
sudo mkdir -p certbot/conf
sudo openssl dhparam -out certbot/conf/ssl-dhparams.pem 2048
sudo cp /etc/letsencrypt/live/solforge.live/fullchain.pem certbot/conf/
sudo cp /etc/letsencrypt/live/solforge.live/privkey.pem certbot/conf/

# Create Nginx SSL options file
cat > certbot/conf/options-ssl-nginx.conf << EOL
ssl_session_cache shared:le_nginx_SSL:1m;
ssl_session_timeout 1440m;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOL

# Enable HTTPS in Nginx config
echo "Enabling HTTPS..."
sed -i 's/# listen 443 ssl/listen 443 ssl/' nginx/conf.d/nginx.conf
sed -i 's/# server {/server {/' nginx/conf.d/nginx.conf

# Restart containers
echo "Restarting containers with HTTPS enabled..."
sudo docker-compose restart nginx 