@echo off
setlocal EnableDelayedExpansion

REM Stop any running containers
docker compose down -v

REM Clean up old directories if they exist
echo Cleaning up old directories...

REM Kill any processes that might be locking files
taskkill /F /IM git.exe 2>nul
taskkill /F /IM php.exe 2>nul

REM Wait a moment for processes to close
timeout /t 2 /nobreak > nul

REM Remove directories safely using rd command
if exist moodle (
    rd /s /q moodle 2>nul || (
        echo Failed to remove moodle directory. Retrying...
        timeout /t 2 /nobreak > nul
        rd /s /q moodle 2>nul
    )
)

if exist moodledata (
    rd /s /q moodledata 2>nul || (
        echo Failed to remove moodledata directory. Retrying...
        timeout /t 2 /nobreak > nul
        rd /s /q moodledata 2>nul
    )
)

REM Clone Moodle repository
echo Cloning Moodle repository...
git clone -b MOODLE_402_STABLE git://git.moodle.org/moodle.git
if !errorlevel! neq 0 (
    echo Failed to clone Moodle repository
    goto :error
)

REM Create moodledata directory
echo Creating moodledata directory...
mkdir moodledata
if !errorlevel! neq 0 (
    echo Failed to create moodledata directory
    goto :error
)

REM Copy config file
echo Copying configuration file...
copy /y config.php moodle\
if !errorlevel! neq 0 (
    echo Failed to copy config.php
    goto :error
)

REM Start containers
echo Starting Docker containers...
docker compose up -d --build
if !errorlevel! neq 0 (
    echo Failed to start Docker containers
    goto :error
)

REM Wait for database to be ready
echo Waiting for database to be ready...
timeout /t 30 /nobreak > nul

REM Set initial permissions
echo Setting initial permissions...
docker compose exec -T php chown -R www-data:www-data /var/www/html
docker compose exec -T php chown -R www-data:www-data /var/www/moodledata
docker compose exec -T php chmod -R 755 /var/www/html
docker compose exec -T php chmod -R 777 /var/www/moodledata

REM Install Moodle database
echo Installing Moodle...
docker compose exec -T php php /var/www/html/admin/cli/install.php ^
    --agree-license ^
    --non-interactive ^
    --lang=en ^
    --wwwroot=http://10.10.0.45 ^
    --dataroot=/var/www/moodledata ^
    --dbtype=mariadb ^
    --dbhost=db ^
    --dbname=moodle ^
    --dbuser=moodle ^
    --dbpass=moodle ^
    --fullname="Moodle Site" ^
    --shortname="Moodle" ^
    --summary="Moodle LMS" ^
    --adminuser=admin ^
    --adminpass=Admin@123 ^
    --adminemail=admin@example.com
if !errorlevel! neq 0 (
    echo Failed to install Moodle database
    goto :error
)

REM Clear all caches
echo Clearing caches...
docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php

REM Fix permissions one last time
echo Final permission setup...
docker compose exec -T php chown -R www-data:www-data /var/www/html
docker compose exec -T php chown -R www-data:www-data /var/www/moodledata
docker compose exec -T php chmod -R 755 /var/www/html
docker compose exec -T php chmod -R 777 /var/www/moodledata

REM Create a flag file to indicate installation is complete
docker compose exec -T php touch /var/www/moodledata/installation_completed

echo.
echo Installation complete! Please follow these steps:
echo 1. Open http://10.10.0.45 in your browser
echo 2. Login with:
echo    Username: admin
echo    Password: Admin@123
echo.
goto :end

:error
echo.
echo An error occurred during installation.
echo Please check the error messages above.
pause
exit /b 1

:end
echo Press any key to exit...
pause >nul
exit /b 0
