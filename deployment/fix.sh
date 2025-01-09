#!/bin/bash

# Exit on error
set -e

echo "Starting deployment fix..."

# Stop services
sudo systemctl stop nginx
sudo systemctl stop gunicorn

# Fix directory structure
sudo rm -rf /var/www/solforge/*
sudo mkdir -p /var/www/solforge
cd /var/www/solforge

# Copy files from setup
sudo cp -r ~/setup/* .
sudo chown -R ubuntu:www-data /var/www/solforge
sudo chmod -R 755 /var/www/solforge

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install gunicorn psycopg2-binary whitenoise

# Fix Gunicorn socket directory
sudo mkdir -p /run/gunicorn
sudo chown ubuntu:www-data /run/gunicorn
sudo chmod 775 /run/gunicorn

# Update Gunicorn service with memory limits
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service' << 'EOL'
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/solforge
RuntimeDirectory=gunicorn
Environment="PATH=/var/www/solforge/venv/bin"
ExecStart=/var/www/solforge/venv/bin/gunicorn \
    --access-logfile - \
    --workers 2 \
    --threads 2 \
    --worker-class=gthread \
    --worker-tmp-dir=/dev/shm \
    --bind unix:/run/gunicorn/gunicorn.sock \
    tiktok_commenter.wsgi:application

# Memory limits
MemoryAccounting=true
MemoryHigh=512M
MemoryMax=1G

# Restart on failure
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Update Nginx config
sudo cp deployment/nginx.conf /etc/nginx/sites-available/solforge.live
sudo ln -sf /etc/nginx/sites-available/solforge.live /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Create static files directory and collect static files
mkdir -p staticfiles
python manage.py collectstatic --noinput

# Apply migrations
python manage.py migrate

# Reload systemd and restart services
sudo systemctl daemon-reload
sudo systemctl restart gunicorn
sudo systemctl restart nginx

# Show status
echo "Checking Gunicorn status..."
sudo systemctl status gunicorn

echo "Checking Nginx status..."
sudo systemctl status nginx

echo "Fix completed! Check the logs for any errors:"
echo "sudo journalctl -u gunicorn --since '5 minutes ago'"
echo "sudo tail -f /var/log/nginx/error.log" 