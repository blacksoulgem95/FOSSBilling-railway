# Stage 1: copia FossBilling
FROM fossbilling/fossbilling:latest AS foss

# Stage 2: PHP-FPM + Nginx + cron + supervisor
FROM php:8.5-fpm

# Installa Nginx, cron, supervisor e libcap2-bin (per setcap)
RUN apt-get update && apt-get install -y \
    nginx cron supervisor vim less libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Crea utente non root 1001
RUN groupadd -g 1001 appuser && useradd -u 1001 -g 1001 -m appuser

# Permetti a nginx di bindare porte privilegiate senza root
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Copia FossBilling
COPY --from=foss /var/www/html /app

# Permessi per utente non root
RUN chown -R 1001:1001 /app \
    && chmod -R 755 /app

# Directory runtime per nginx (writable da worker appuser)
RUN mkdir -p /var/log/nginx /var/lib/nginx/body \
    && chown -R 1001:1001 /var/log/nginx /var/lib/nginx \
    && chmod -R 755 /var/log/nginx

# Configura cron per utente appuser
RUN echo "*/5 * * * * appuser php /app/cron.php >> /app/cron.log 2>&1" > /etc/cron.d/fossbilling \
    && chmod 0644 /etc/cron.d/fossbilling

# Configura nginx
RUN rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf && \
    cat <<'EOF' > /etc/nginx/sites-enabled/fossbilling.conf
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
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;
    }

    access_log /proc/self/fd/1;
    error_log /proc/self/fd/2;
}
EOF

# Configura nginx per girare come appuser
RUN sed -i 's/user www-data;/user appuser;/' /etc/nginx/nginx.conf || true && \
    echo "user appuser;" > /tmp/nginx_user.conf

# Configura php-fpm per girare come appuser
RUN sed -i 's/user = www-data/user = appuser/' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's/group = www-data/group = appuser/' /usr/local/etc/php-fpm.d/www.conf

# Configurazione supervisord
RUN mkdir -p /var/log/supervisor && \
    cat <<'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
user=root

[program:php-fpm]
command=/usr/local/sbin/php-fpm --nodaemonize
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:cron]
command=/usr/sbin/cron -f
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Espone porta HTTP
EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
