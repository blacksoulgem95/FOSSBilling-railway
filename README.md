# FOSSBilling on Railway

A Railway-optimised Docker image for [FOSSBilling](https://fossbilling.org/), bundling Nginx, PHP-FPM, and cron into a single container managed by Supervisor.

## What's inside

| Component | Details |
|-----------|---------|
| FOSSBilling | Latest (`fossbilling/fossbilling`) |
| PHP | 8.4-FPM |
| Web server | Nginx |
| Process manager | Supervisor |
| Cron | System cron, runs `cron.php` every 5 minutes |

## Deploy on Railway

Click the button below to deploy in one click:

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/fossbilling?referralCode=YljGzR&utm_medium=integration&utm_source=template&utm_campaign=generic)

### One-click (Railway template)

1. Click **Deploy on Railway** and sign in.
2. Confirm the new project. The template ships with **MySQL** already provisioned and connected — you do not need to add a database service yourself.
3. Wait for the Docker build and deploy to finish.
4. Open your service’s public URL and complete the [FOSSBilling](https://fossbilling.org/) setup wizard. Use the database host, name, user, and password from your Railway **MySQL** service (or the variables the template exposes to the app).

### Deploy from this Git repository

Use this path if you are not using the template button (for example your own fork):

1. Fork or clone this repository.
2. In Railway: **New project** → **Deploy from GitHub** (or Git provider) and select this repo.
3. Add a **MySQL** or **MariaDB** service, link it to the web service, and configure credentials / env vars so FOSSBilling can connect (see the [FOSSBilling documentation](https://fossbilling.org/docs)).
4. Deploy. Railway sets **`PORT`** automatically; Nginx listens on that port inside the container.
5. Open your app URL and run the FOSSBilling setup wizard.

### Updating

- **On Railway:** push changes to the connected branch, or trigger a **Redeploy** from the service dashboard to rebuild from the latest commit.
- **Locally:** `git pull` in your clone of this repo, then push if Railway is connected to your fork.

### GitHub Actions (digest pinning PRs)

The workflow **Pin Docker base image digests** uses the default `GITHUB_TOKEN` to open pull requests. In the repository **Settings → Actions → General**, set **Workflow permissions** to **Read and write permissions** and turn on **Allow GitHub Actions to create and approve pull requests**. If this repo lives under an organization, an org owner may need to allow the same under **Organization settings → Actions → General**.

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
