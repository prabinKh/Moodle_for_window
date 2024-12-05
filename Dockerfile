FROM php:8.1-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libxml2-dev \
    libicu-dev \
    libpq-dev \
    git \
    zip \
    unzip

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    intl \
    zip \
    soap \
    opcache \
    pdo_mysql \
    mysqli \
    gd \
    exif

# Set recommended PHP.ini settings
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Add custom PHP settings
RUN { \
    echo 'memory_limit=512M'; \
    echo 'max_execution_time=600'; \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=64M'; \
    echo 'max_input_vars=5000'; \
    echo 'include_path=.:/usr/local/lib/php:/var/www/html:/var/www/html/lib'; \
    } > /usr/local/etc/php/conf.d/custom.ini

WORKDIR /var/www/html

# Create moodledata directory
RUN mkdir -p /var/www/moodledata

# Set permissions
RUN chown -R www-data:www-data /var/www/html /var/www/moodledata && \
    chmod -R 755 /var/www/html && \
    chmod -R 777 /var/www/moodledata

# Keep running as root for initial setup
