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

# Create virtual environment
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
sudo cp deploy/nginx.conf /etc/nginx/sites-available/solforge
sudo ln -s /etc/nginx/sites-available/solforge /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Set up systemd service
sudo cp deploy/gunicorn.service /etc/systemd/system/gunicorn.service
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

# Set up SSL
sudo certbot --nginx -d solforge.live -d www.solforge.live --non-interactive --agree-tos --email zacharyrcherney@gmail.com

# Collect static files
python manage.py collectstatic --noinput

# Apply migrations
python manage.py migrate

# Restart services
sudo systemctl restart gunicorn
sudo systemctl restart nginx

echo "Setup completed successfully!" 