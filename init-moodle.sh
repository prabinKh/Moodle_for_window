#!/bin/bash

# Exit on error
set -e

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

echo "Starting Moodle installation..."

# Stop any running containers and clean up
echo "Stopping existing containers and cleaning up..."
docker compose down -v
docker volume rm moodle_for_window_mysql_data moodle_for_window_moodledata 2>/dev/null || true

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

# Set proper permissions for host files
echo "Setting initial permissions..."
chown -R www-data:www-data moodle moodledata
chmod -R 755 moodle
chmod -R 777 moodledata

# Start database container first
echo "Starting database container..."
docker compose up -d db
echo "Waiting for database to initialize..."
sleep 20

# Function to check container health
check_container_health() {
    local service_name=$1
    local max_attempts=30
    local attempt=1

    echo "Checking health of $service_name..."
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps $service_name | grep -q "healthy"; then
            echo "$service_name is healthy!"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: Waiting for $service_name to be healthy..."
        sleep 10
        attempt=$((attempt + 1))
    done

    echo "Error: $service_name failed to become healthy"
    docker compose logs $service_name
    return 1
}

# Wait for database to be healthy
check_container_health "db"

# Start remaining containers
echo "Starting remaining containers..."
docker compose up -d

# Wait for other containers to be healthy
check_container_health "php"
check_container_health "nginx"

# Verify MySQL connection
echo "Verifying MySQL connection..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if docker compose exec -T db mysql -h 127.0.0.1 -u root -pAdmin@123 -e "SELECT 1;" >/dev/null 2>&1; then
        echo "MySQL connection verified!"
        break
    fi
    echo "Attempt $attempt/$max_attempts: Waiting for MySQL connection..."
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "Error: Could not establish MySQL connection"
    docker compose logs db
    exit 1
fi

# Fix permissions inside containers
echo "Setting container permissions..."
docker compose exec -T php bash -c "chown -R www-data:www-data /var/www/html /var/www/moodledata"
docker compose exec -T nginx bash -c "chown -R www-data:www-data /var/www/html /var/www/moodledata"

# Install Moodle database
echo "Installing Moodle..."
docker compose exec -T -u www-data php bash -c "cd /var/www/html && php admin/cli/install.php \
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
    --fullname='Moodle Site' \
    --shortname='Moodle' \
    --summary='Moodle LMS' \
    --adminuser=admin \
    --adminpass=Admin@123 \
    --adminemail=admin@example.com"

# Fix permissions again
echo "Final permission setup..."
docker compose exec -T php bash -c "chown -R www-data:www-data /var/www/html /var/www/moodledata"
docker compose exec -T nginx bash -c "chown -R www-data:www-data /var/www/html /var/www/moodledata"

echo
echo "Installation complete! Please follow these steps:"
echo "1. Open http://10.40.0.71 in your browser"
echo "2. Login with:"
echo "   Username: admin"
echo "   Password: Admin@123"
echo
 
