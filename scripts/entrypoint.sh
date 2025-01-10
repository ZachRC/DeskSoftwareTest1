#!/bin/sh

# Wait for postgres
echo "Waiting for PostgreSQL..."
while ! nc -z aws-0-us-east-2.pooler.supabase.com 6543; do
    sleep 0.1
done
echo "PostgreSQL started"

python manage.py migrate
python manage.py collectstatic --noinput

exec "$@" 