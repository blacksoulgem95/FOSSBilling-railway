FROM fossbilling/fossbilling:latest

# Disabilita i moduli MPM conflittanti, Railway aggiunge il suo
RUN a2dismod mpm_worker mpm_event mpm_prefork 2>/dev/null || true

# Rimuovi i file di configurazione Apache che caricano i moduli MPM
RUN rm -f /etc/apache2/mods-enabled/mpm_*.load && \
    rm -f /etc/apache2/mods-available/mpm_*.load


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
