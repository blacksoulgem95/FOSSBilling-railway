# Stage 1: immagine ufficiale FossBilling
FROM fossbilling/fossbilling:latest AS foss

FROM php:8.5-fpm

# Installa cron e utilities base nello stage finale
RUN apt-get update && apt-get install -y cron vim less && rm -rf /var/lib/apt/lists/*

# Copia tutto da /var/www/html dell'immagine FossBilling
COPY --from=fossbilling/fossbilling:latest /var/www/html /var/www/html

# Permessi corretti
RUN chown -R www-data:www-data /var/www/html

# Imposta cron
RUN echo '*/5 * * * * /usr/local/bin/php /var/www/html/cron.php >> /var/log/cron.log 2>&1' \
    > /tmp/www-data.cron && crontab -u www-data /tmp/www-data.cron

# Espone porta FPM
EXPOSE 9000

CMD ["php-fpm"]
