FROM fossbilling/fossbilling:latest

# Disabilita i moduli MPM conflittanti
RUN a2dismod mpm_worker mpm_event 2>/dev/null || true

# Abilita mpm_prefork (il modulo standard per PHP)
RUN a2enmod mpm_prefork

# Reindirizza i log di Apache a stdout/stderr per Railway
RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/2 /var/log/apache2/error.log

# Assicura che Apache parta in foreground
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

# Espone la porta 80
EXPOSE 80

# Comando di avvio
CMD ["apache2-foreground"]
