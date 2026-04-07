# Stage 1: copia FossBilling
FROM fossbilling/fossbilling:latest AS foss

# Stage 2: PHP-FPM + Nginx + cron + supervisor
FROM php:8.5-fpm

# Installa Nginx, cron e supervisor
USER root
RUN apt-get update && apt-get install -y \
    nginx cron supervisor vim less \
    && rm -rf /var/lib/apt/lists/*

# Copia FossBilling
COPY --from=foss /var/www/html /app

# Permessi sicuri per utente non root
RUN chown -R 1001:1001 /app \
    && chmod -R 755 /app

# Configura cron per utente 1001
RUN echo "*/5 * * * * php /app/cron.php >> /app/cron.log 2>&1" > /etc/cron.d/fossbilling \
    && chmod 0644 /etc/cron.d/fossbilling \
    && crontab -u 1001 /etc/cron.d/fossbilling

# Configura nginx usando heredoc
RUN rm /etc/nginx/sites-enabled/default && \
    cat <<'EOF' > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;

    root /app;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php8.5-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;
    }

    access_log /proc/self/fd/1;
    error_log /proc/self/fd/2;
}
EOF

# Configurazione supervisord per avviare cron + PHP-FPM + Nginx
RUN cat <<'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:php-fpm]
command=/usr/local/sbin/php-fpm

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"

[program:cron]
command=/usr/sbin/cron -f
EOF

# Espone porta HTTP
EXPOSE 80

# Esegui tutto come utente non root
USER 1001
CMD ["/usr/bin/supervisord", "-n"]
