server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html index.htm;

    client_max_body_size 100M;
    fastcgi_read_timeout 600;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 600;
    }

    location ~ /\. {
        deny all;
    }
} 
