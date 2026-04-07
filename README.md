# FOSSBilling on Railway

A Railway-optimised Docker image for [FOSSBilling](https://fossbilling.org/), bundling Nginx, PHP-FPM, and cron into a single container managed by Supervisor.

## What's inside

| Component | Details |
|-----------|---------|
| FOSSBilling | Latest (`fossbilling/fossbilling`) |
| PHP | 8.5-FPM |
| Web server | Nginx |
| Process manager | Supervisor |
| Cron | System cron, runs `cron.php` every 5 minutes |

## Deploy on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/o_VIwH?referralCode=YljGzR&utm_medium=integration&utm_source=template&utm_campaign=generic)

1. Fork or clone this repository.
2. Create a new Railway project and point it at this repo.
3. Add a MySQL or MariaDB service to the project and link it.
4. Railway will build and deploy the image automatically. The app will be available on port `80`.
5. Visit your Railway URL to complete the FOSSBilling setup wizard.

## Security

Worker processes run as an unprivileged user (`appuser`, uid 1001):

- **Nginx workers** — run as `appuser`
- **PHP-FPM workers** — run as `appuser`
- **Cron jobs** — execute as `appuser`
- Nginx is granted `cap_net_bind_service` so it can bind port 80 without full root privileges

The Supervisor process manager and cron daemon run as root (required by the OS), but all request-handling code runs unprivileged.

## Local development

```bash
docker build -t fossbilling-railway .
docker run -p 8080:80 fossbilling-railway
```

Then open `http://localhost:8080` to reach the setup wizard.
