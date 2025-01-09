#!/bin/bash

# Exit on error
set -e

# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y python3-pip python3-venv nginx postgresql postgresql-contrib certbot python3-certbot-nginx

# Create project directory
sudo mkdir -p /var/www/solforge
sudo chown $USER:$USER /var/www/solforge

# Clone the repository
cd /var/www/solforge
git clone https://github.com/ZachRC/DeskSoftwareTest1.git .

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
pip install gunicorn psycopg2-binary whitenoise

# Create environment file
cat > .env << EOL
DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_DEBUG=False
STRIPE_PUBLISHABLE_KEY=pk_test_51Qf59sQ7s3yogV6Hy36945QjOpHOOr2dRnre5KizxYsNloySglmBlQKQNszXCKwc1mYM6lOnAAFCrUCHUwg3tQaX00ZR7T9HAs
STRIPE_SECRET_KEY=sk_test_51Qf59sQ7s3yogV6Heyj8Ow7cMLVZqMnMImarJ4EWQ8cO4aqHvndg6JEp4EzgE3iX07BPruJ438EG0Eno4B3KaEgy00ODJ1udAW
EOL

# Set up Nginx
sudo bash -c 'cat > /etc/nginx/sites-available/solforge.live' << 'EOL'
server {
    server_name solforge.live www.solforge.live;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root /var/www/solforge;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOL

# Enable the site
sudo ln -s /etc/nginx/sites-available/solforge.live /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Set up Gunicorn service
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service' << 'EOL'
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/solforge
RuntimeDirectory=gunicorn
ExecStart=/var/www/solforge/venv/bin/gunicorn \
    --access-logfile - \
    --workers 3 \
    --bind unix:/run/gunicorn/gunicorn.sock \
    tiktok_commenter.wsgi:application

[Install]
WantedBy=multi-user.target
EOL

# Create static files directory
mkdir -p staticfiles

# Collect static files
python manage.py collectstatic --noinput

# Apply migrations
python manage.py migrate

# Set correct permissions
sudo chown -R $USER:www-data /var/www/solforge
sudo chmod -R 755 /var/www/solforge

# Start and enable Gunicorn service
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Set up SSL with Certbot
sudo certbot --nginx -d solforge.live -d www.solforge.live --non-interactive --agree-tos --email zacharyrcherney@gmail.com

echo "Setup completed successfully!" 