# Stage 1: copia FossBilling
FROM fossbilling/fossbilling:latest@sha256:6bad10f60c9a49360e2c63d63027827bf72c6abcbd3a06e0faf93506377f75c3 AS foss

# Stage 2: PHP-FPM + Nginx + cron + supervisor
FROM php:8.4-fpm@sha256:eec2a132b91271dcf51e86119311ec4b22105736af704997a690594b8f88af31

# Installa Nginx, cron, supervisor e libcap2-bin (per setcap)
RUN apt-get update && apt-get install -y \
    nginx cron supervisor vim less libcap2-bin gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Estensioni PHP: intl, pdo_mysql, gd, bz2, imagick
RUN apt-get update && apt-get install -y \
    libicu-dev \
    default-libmysqlclient-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libxpm-dev libavif-dev \
    libbz2-dev \
    libmagickwand-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
        --with-xpm \
        --with-avif \
    && docker-php-ext-install intl pdo_mysql gd bz2 \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && rm -rf /var/lib/apt/lists/*

# Crea utente non root 1001
RUN groupadd -g 1001 appuser && useradd -u 1001 -g 1001 -m appuser

# Permetti a nginx di bindare porte privilegiate senza root
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Copia FossBilling in directory intermedia (Railway monta /app come volume)
COPY --from=foss /var/www/html /fossbilling-src

# Registrar OpenProvider (domini) — https://github.com/vicedomini-softworks/fossbilling-registrar-openprovider
ARG OPENPROVIDER_REF=main
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && git clone --depth 1 --branch "${OPENPROVIDER_REF}" \
        https://github.com/vicedomini-softworks/fossbilling-registrar-openprovider.git /tmp/openprovider \
    && cp -a /tmp/openprovider/library/Registrar/Adapter/OpenProvider.php \
        /fossbilling-src/library/Registrar/Adapter/ \
    && rm -rf /tmp/openprovider \
    && apt-get purge -y --auto-remove git \
    && rm -rf /var/lib/apt/lists/*

# Permessi per utente non root
RUN chown -R 1001:1001 /fossbilling-src \
    && chmod -R 755 /fossbilling-src

# Crea /app vuota (verrà popolata dall'entrypoint se Railway monta un volume)
RUN mkdir -p /app && chown 1001:1001 /app

# Directory runtime per nginx (writable da worker appuser)
RUN mkdir -p /var/log/nginx /var/lib/nginx/body \
    && chown -R 1001:1001 /var/log/nginx /var/lib/nginx \
    && chmod -R 755 /var/log/nginx

# Configura cron per utente appuser
RUN echo "*/5 * * * * appuser php /app/cron.php >> /app/cron.log 2>&1" > /etc/cron.d/fossbilling \
    && chmod 0644 /etc/cron.d/fossbilling

# Configura nginx (template con ${PORT} per Railway)
RUN rm -f /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* && \
    mkdir -p /etc/nginx/templates && \
    cat <<'EOF' > /etc/nginx/templates/fossbilling.conf.template
server {
    listen ${PORT};
    server_name _;

    root /app;
    index index.php index.html;
    sendfile off;

    # Block config at exact URI so try_files cannot serve it as a static (non-PHP) file
    location = /config.php {
        return 404;
    }
    location = /config-sample.php {
        return 404;
    }

    # FOSSBilling expects clean URLs via ?_url= (see official NGINX examples)
    location ~* \.(ini|sh|inc|bak|twig|sql)$ {
        return 404;
    }
    location ~ /\.(?!well-known/) {
        return 404;
    }
    location ^~ /vendor/ {
        return 404;
    }
    location ~* /uploads/.*\.php$ {
        return 404;
    }
    location ~* /data/(?!(assets/gateways/)) {
        return 404;
    }

    location / {
        try_files $uri $uri/ @fossbilling_rewrite;
    }

    # Internal router: pass path to index.php as _url (FOSSBilling front controller)
    location @fossbilling_rewrite {
        rewrite ^/page/(.*)$ /index.php?_url=/custompages/$1;
        rewrite ^/(.*)$ /index.php?_url=/$1;
    }

    location ~ \.php {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
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

# Log errori PHP nel path usato da FOSSBilling (stesso file inoltrato a stdout per Railway)
RUN printf '%s\n' \
    'error_log = /app/data/log/php_error.log' \
    'log_errors = On' \
    > /usr/local/etc/php/conf.d/fossbilling-errorlog.ini

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

; Stream FOSSBilling PHP error log to container stdout (Railway / monitoring)
[program:php-error-log]
command=/bin/sh -c "mkdir -p /app/data/logs; : >> /app/data/logs/php_error.log; exec tail -n0 -F /app/data/log/php_error.log"
user=appuser
autostart=true
autorestart=true
startretries=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Entrypoint: sostituisce ${PORT} nel template nginx e avvia supervisord
RUN cat <<'EOF' > /entrypoint.sh
#!/bin/sh
# Se /app è vuota (volume Railway montato), copia i file da /fossbilling-src
if [ ! -f /app/index.php ]; then
    echo "Populating /app from /fossbilling-src..."
    cp -a /fossbilling-src/. /app/ && echo "Copy done." || echo "ERROR: copy failed!"
    chown -R 1001:1001 /app
    chmod -R 755 /app
    echo "index.php present: $(test -f /app/index.php && echo yes || echo NO)"
fi

mkdir -p /app/data/log
touch /app/data/log/php_error.log
chown 1001:1001 /app/data/log /app/data/log/php_error.log 2>/dev/null || true

PORT=${PORT:-8080}
export PORT
envsubst '${PORT}' < /etc/nginx/templates/fossbilling.conf.template > /etc/nginx/sites-enabled/fossbilling.conf
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
EOF
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
