#!/bin/bash

# Exit on error
set -e

echo "Starting Moodle installation..."

# Stop any running containers
echo "Stopping existing containers..."
docker compose down -v

# Clean up old directories
echo "Cleaning up old directories..."
rm -rf moodle moodledata

# Clone Moodle repository
echo "Cloning Moodle repository..."
git clone -b MOODLE_402_STABLE git://git.moodle.org/moodle.git

# Create moodledata directory
echo "Creating moodledata directory..."
mkdir -p moodledata

# Copy config file
echo "Copying configuration file..."
cp -f config.php moodle/

# Start containers
echo "Starting Docker containers..."
docker compose up -d --build

# Wait for database to be ready
echo "Waiting for database to be ready (30 seconds)..."
sleep 30

# Set initial permissions
echo "Setting initial permissions..."
docker compose exec -T php chown -R www-data:www-data /var/www/html
docker compose exec -T php chown -R www-data:www-data /var/www/moodledata
docker compose exec -T php chmod -R 755 /var/www/html
docker compose exec -T php chmod -R 777 /var/www/moodledata

# Install Moodle database
echo "Installing Moodle..."
docker compose exec -T php php /var/www/html/admin/cli/install.php \
    --agree-license \
    --non-interactive \
    --lang=en \
    --wwwroot=http://10.40.0.71 \
    --dataroot=/var/www/moodledata \
    --dbtype=mysqli \
    --dbhost=db \
    --dbname=moodle \
    --dbuser=moodleuser \
    --dbpass=MoodlePass@123 \
    --fullname="Moodle Site" \
    --shortname="Moodle" \
    --summary="Moodle LMS" \
    --adminuser=admin \
    --adminpass=Admin@123 \
    --adminemail=admin@example.com

# Clear all caches
echo "Clearing caches..."
docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php

# Fix permissions one last time
echo "Final permission setup..."
docker compose exec -T php chown -R www-data:www-data /var/www/html
docker compose exec -T php chown -R www-data:www-data /var/www/moodledata
docker compose exec -T php chmod -R 755 /var/www/html
docker compose exec -T php chmod -R 777 /var/www/moodledata

# Create installation completion flag
docker compose exec -T php touch /var/www/moodledata/installation_completed

echo
echo "Installation complete! Please follow these steps:"
echo "1. Open http://10.40.0.71 in your browser"
echo "2. Login with:"
echo "   Username: admin"
echo "   Password: Admin@123"
echo
 
