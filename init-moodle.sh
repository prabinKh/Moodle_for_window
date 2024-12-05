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

# Set proper permissions for host files
echo "Setting initial permissions..."
chown -R www-data:www-data moodle moodledata
chmod -R 755 moodle
chmod -R 777 moodledata

# Start containers
echo "Starting Docker containers..."
docker compose up -d --build

# Function to check if container is ready
wait_for_container() {
    local container_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $container_name to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps $container_name | grep -q "Up"; then
            echo "$container_name is ready!"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: $container_name is not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "Error: $container_name failed to start properly"
    return 1
}

# Wait for containers to be ready
wait_for_container "php"
wait_for_container "db"
wait_for_container "nginx"

# Additional wait for MySQL to be fully ready
echo "Waiting for MySQL to be fully ready..."
for i in {1..30}; do
    if docker compose exec -T db mysqladmin ping -h localhost -u root -pAdmin@123 --silent; then
        echo "MySQL is ready!"
        break
    fi
    echo "Waiting for MySQL... ($i/30)"
    sleep 2
done

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

# No need to restart containers at the end
 
