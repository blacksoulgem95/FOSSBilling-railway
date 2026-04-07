FROM fossbilling/fossbilling:latest

# Disabilita apache completamente
RUN service apache2 stop || true

# Assicurati che PHP-FPM sia installato e attivo
CMD ["php-fpm"]
EXPOSE 9000
