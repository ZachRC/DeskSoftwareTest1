FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DATABASE_URL postgres://postgres.bhryplxtproznrmtvvri:Zc1269zc!zc1269zc@aws-0-us-east-2.pooler.supabase.com:6543/postgres
ENV DJANGO_DEBUG 0
ENV DJANGO_SETTINGS_MODULE tiktok_commenter.settings

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# Copy project
COPY . .

# Create directories for static and media files
RUN mkdir -p /app/staticfiles /app/media /app/static

# Set permissions
RUN chown -R root:root /app \
    && chmod -R 755 /app

# Generate a temporary secret key for collectstatic
ENV DJANGO_SECRET_KEY "temporary-key-for-collectstatic"

# Collect static files
RUN python manage.py collectstatic --noinput --clear

# Run as non-root user
RUN useradd -m myuser
RUN chown -R myuser:myuser /app/staticfiles /app/media
USER myuser 