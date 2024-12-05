#!/bin/bash

# Exit on error
set -e

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

echo "Starting Moodle installation..."

# Stop any running containers
echo "Stopping existing containers..."
docker compose down -v

# Clean up old directories
echo "Cleaning up old directories..."
rm -rf moodle moodledata

# Clone Moodle repository
echo "Cloning Moodle repository..."
git clone -b MOODLE_402_STABLE https://github.com/moodle/moodle.git

# Create moodledata directory
echo "Creating moodledata directory..."
mkdir -p moodledata

# Copy config file
echo "Copying configuration file..."
cp -f config.php moodle/

# Set proper permissions
echo "Setting initial permissions..."
chown -R www-data:www-data moodle moodledata
chmod -R 755 moodle
chmod -R 777 moodledata

# Start containers
echo "Starting Docker containers..."
docker compose up -d --build

# Wait for database to be ready
echo "Waiting for database to be ready (30 seconds)..."
sleep 30

# Install Moodle database
echo "Installing Moodle..."
docker compose exec -T php php /var/www/html/admin/cli/install_database.php \
    --agree-license \
    --adminuser=admin \
    --adminpass=Admin@123 \
    --adminemail=admin@example.com \
    --fullname="Moodle Site" \
    --shortname="Moodle" \
    --summary="Moodle LMS"

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
 