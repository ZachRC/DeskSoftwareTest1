FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND=noninteractive

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    netcat-traditional \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories
RUN mkdir -p staticfiles

# Copy project
COPY . .

# Make the health check script executable
COPY ./health_check.sh /health_check.sh
RUN chmod +x /health_check.sh

# Collect static files
RUN python manage.py collectstatic --noinput

# Expose port
EXPOSE 8000

# Create gunicorn config
RUN echo 'import multiprocessing\n\
bind = "0.0.0.0:8000"\n\
workers = 3\n\
timeout = 120\n\
keepalive = 5\n\
worker_class = "sync"\n\
worker_connections = 1000\n\
accesslog = "-"\n\
errorlog = "-"\n\
loglevel = "info"\n\
' > /app/gunicorn.conf.py

# Run gunicorn with config
CMD ["gunicorn", "--config", "/app/gunicorn.conf.py", "tiktok_commenter.wsgi:application"] 