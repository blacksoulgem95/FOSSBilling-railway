# Stage 1: immagine ufficiale FossBilling
FROM fossbilling/fossbilling:latest AS foss

# Stage 2: nostra immagine Railway / PHP-FPM
FROM php:8.5-fpm

# Copia tutto da /var/www/html dell'immagine FossBilling
COPY --from=foss /var/www/html /var/www/html

# Permessi corretti
RUN chown -R www-data:www-data /var/www/html

# Cron opzionale (puoi anche usare Railway scheduler)
RUN echo '*/5 * * * * /usr/local/bin/php /var/www/html/cron.php >> /var/log/cron.log 2>&1' \
    > /tmp/www-data.cron && crontab -u www-data /tmp/www-data.cron

# Espone porta FPM
EXPOSE 9000

CMD ["php-fpm"]
