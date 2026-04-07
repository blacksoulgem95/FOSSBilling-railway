# Stage 1: copia FossBilling
FROM fossbilling/fossbilling:latest AS foss

# Stage 2: Nginx + PHP-FPM
FROM bitnami/nginx-php-fpm:latest

# Installa cron
USER root
RUN install_packages cron

# Copia FossBilling
COPY --from=foss /var/www/html /app

# Imposta permessi sicuri per utente non root
RUN chown -R 1001:1001 /app \
    && chmod -R 755 /app

# Configura cron per l'utente non root
RUN echo "*/5 * * * * php /app/cron.php >> /app/cron.log 2>&1" > /etc/cron.d/fossbilling \
    && chmod 0644 /etc/cron.d/fossbilling \
    && crontab -u 1001 /etc/cron.d/fossbilling

# Espone porta HTTP
EXPOSE 80

# Passa a utente non root
USER 1001

# Avvia cron + Nginx + PHP-FPM
CMD ["sh", "-c", "cron && nami start --foreground nginx-php-fpm"]
