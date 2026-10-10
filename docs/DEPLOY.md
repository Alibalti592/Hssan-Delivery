# Production on your own server

Everything runs from `deploy/` with Docker:

| Service    | What it is                                                        |
|------------|-------------------------------------------------------------------|
| `caddy`    | The only thing open to the internet (80/443). HTTPS certificates from Let's Encrypt, renewed by itself. |
| `backend`  | The Symfony API (image built by GitHub on every merge to `main`). Runs pending migrations on start. |
| `admin`    | The admin dashboard (same).                                       |
| `postgres` | The database. Not reachable from outside.                         |
| `backup`   | Every night at 03:00: the database and the photos into `deploy/backups/`, kept 14 days. |

Two domains point at the server:

- `api.your-domain.tn`: the API the mobile app calls.
- `admin.your-domain.tn`: the admin dashboard. Its `/api` and `/uploads` go to the backend on the same domain, so the login cookie stays first-party.

The examples below use `api.example.tn` and `admin.example.tn`: use yours.

---

## 0. Before the server: give the app a domain of its own

The app has its API address built in. Today that's the `…up.railway.app`
address, so if Railway goes away, every installed app stops working until
people install a new one.

Do this first, while Railway still runs everything:

1. In Railway: **Hssan-Delivery service → Settings → Networking → Custom
   Domain**, add `api.example.tn`. Create the DNS record Railway shows you
   (a CNAME) at your domain provider.
2. Once `https://api.example.tn` answers, set the repository variable
   **`API_BASE_URL`** = `https://api.example.tn` (GitHub → Settings →
   Secrets and variables → Actions → **Variables** tab). The next APK and
   iOS builds use it.
3. Have everyone install that new APK.

From then on, moving to your server is only a DNS change: nobody has to
reinstall anything.

## 1. The server

- Ubuntu 24.04. **2 vCPU and 4 GB RAM** is plenty to start; 40 GB of disk or more.
- Log in as root once (on OVHcloud: `ssh ubuntu@<server-ip>` then `sudo -i`), then:

```bash
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh

# A user for the app and for deploys, allowed to run Docker.
adduser --disabled-password --gecos "" deploy
usermod -aG docker deploy
# The SSH key you log in with (OVHcloud puts it on the "ubuntu" user).
mkdir -p /home/deploy/.ssh
cp /home/ubuntu/.ssh/authorized_keys /home/deploy/.ssh/ 2>/dev/null || cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh

# Firewall: SSH and the web only. Postgres is never opened.
ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 443/udp
ufw --force enable

mkdir -p /opt/hssan-delivery && chown deploy:deploy /opt/hssan-delivery
```

From here on, work as `deploy` (`ssh deploy@your-server`).

### On OVHcloud

- **Product:** a **VPS** is the simplest choice: a fixed monthly price, with
  the IP and disk included. Pick a plan with at least 2 vCores and 4 GB RAM.
  Public Cloud instances also work, but bill by the hour and have more knobs.
- **Location:** a datacenter in France (Gravelines, Roubaix or Strasbourg),
  the closest to Tunisia.
- **Image:** Ubuntu 24.04. Add your SSH public key when ordering. OVH's
  Ubuntu logs you in as `ubuntu` (with `sudo`), not as `root`.
- **DNS:** if your domain is at OVH, go to **Web Cloud → Domain names → your
  domain → DNS zone → Add an entry → A**, once for `api` and once for
  `admin`, each pointing to the VPS's IPv4 (step 3). If the domain is
  elsewhere, create the same two A records there.
- **Off-site backups:** OVH **Object Storage** (S3-compatible) works with
  `rclone` (step 8; choose the S3 / OVHcloud provider in `rclone config`).
  Put the bucket in a **different region** from the VPS.
- OVH's paid **automated backup** option for the VPS snapshots the whole
  server. It's a nice extra, but it doesn't replace the nightly database
  dumps: those restore just the data, to any of the last 14 days.

## 2. The code and the settings

```bash
git clone https://github.com/Alibalti592/Hssan-Delivery.git /opt/hssan-delivery
cd /opt/hssan-delivery/deploy
cp .env.example .env
chmod 600 .env
nano .env
```

In `.env`:

- **`API_DOMAIN`**, **`ADMIN_DOMAIN`**: your two domains.
- **`ACME_EMAIL`**: your email, for certificate warnings.
- **`POSTGRES_PASSWORD`**, **`APP_SECRET`**: new random values, each from `openssl rand -hex 32`.
- **`JWT_PASSPHRASE`**:
  - moving from Railway (step 4): copy Railway's value, from the **Hssan-Delivery service → Variables** page;
  - starting fresh: a new random value.
- **`SENTRY_DSN`**: copy it from Railway if you use Sentry.
- **Push notifications**:
  1. Put the Firebase service-account JSON in `deploy/secrets/firebase.json`, and protect it:
     ```bash
     mkdir -p secrets && chmod 700 secrets
     chmod 600 secrets/firebase.json
     ```
  2. Uncomment `FIREBASE_CREDENTIALS=/run/secrets/firebase.json`.

  It's the same file whose content Railway holds in `FIREBASE_CREDENTIALS`.

Copy secrets straight from the Railway dashboard into the server's `.env`.
Don't send them over chat or email, and never commit `.env` (git ignores it).

The images are public on GitHub's registry. If you ever make them private,
log the server in once:
`docker login ghcr.io -u <github-user>`, with a token that has `read:packages`.

## 3. Point the domains at the server

At your domain provider, create **A records** for both `api.example.tn` and
`admin.example.tn` → the server's IP address.

If you did step 0, `api.example.tn` is currently a CNAME to Railway: **leave
it** until step 4 is done, then change it.

## 4a. Moving from Railway (keeping all the data)

Pick a quiet moment: orders placed on Railway after the copy would not come
across. Install the Railway CLI on the server (`npm i -g @railway/cli` or see
docs.railway.com/cli), then run `railway login` and `railway link` to this
project.

```bash
cd /opt/hssan-delivery/deploy
mkdir -p backups

# 1. The database, dumped inside Railway's Postgres container (it has no
#    public address) and streamed here. Same Postgres version (18) as the
#    server below, so it restores as is.
railway ssh -s Postgres -- sh -c 'pg_dump -Fc --no-owner -h 127.0.0.1 -U "$PGUSER" -d "$PGDATABASE"' > backups/railway.dump
head -c 5 backups/railway.dump; echo                # must print PGDMP

# 2. The photos and the sign-in keys (the backend's volume).
railway ssh -s Hssan-Delivery -- tar -czf - -C /var/www/html/var/storage . > backups/railway-storage.tar.gz
tar -tzf backups/railway-storage.tar.gz | head    # expect ./uploads/... and ./jwt/...

# 3. Into the new server.
docker compose -f docker-compose.prod.yml up -d postgres
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_restore -U hssan -d hssan_delivery --no-owner < backups/railway.dump
docker compose -f docker-compose.prod.yml run --rm --no-deps --entrypoint sh \
  -v "$PWD/backups:/in:ro" backend -c 'tar -xzf /in/railway-storage.tar.gz -C var/storage'

# 4. Start everything.
docker compose -f docker-compose.prod.yml up -d
```

Then switch the DNS of `api.example.tn` from the Railway CNAME to the
server's A record (step 3). Apps follow within the DNS refresh time.

Keep Railway running for a few days, without using it, before deleting it.

If `railway ssh` asks for a database password, it's `POSTGRES_PASSWORD`
on Railway's **Postgres service → Variables** page.

If the volume copy isn't possible, start without it:

- **Sign-in keys:** they're recreated automatically. The app renews its session by itself; admins just log in again.
- **Photos:** menu, product and promotion photos would have to be uploaded again from the admin.

## 4b. Starting fresh (empty database)

```bash
cd /opt/hssan-delivery/deploy
sed -i 's/^SEED_FIXTURES=.*/SEED_FIXTURES=true/' .env
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml logs -f backend   # wait for "resuming normal operations"
```

This creates the admin account **20000000 / admin1234**:

1. Log in to `https://admin.example.tn` and **change that password immediately** (sidebar → "Change password").
2. Turn seeding off and restart:
   ```bash
   sed -i 's/^SEED_FIXTURES=.*/SEED_FIXTURES=false/' .env
   docker compose -f docker-compose.prod.yml up -d
   ```

## 5. Check it works

```bash
docker compose -f docker-compose.prod.yml ps        # all "running" / "healthy"
curl -s -o /dev/null -w '%{http_code}\n' https://api.example.tn/api/auth/me   # 401: the API answers (it wants a login)
```

- Open `https://admin.example.tn`, log in, and open a restaurant with photos.
- On a phone with the app: log in, place an order, check the push notification.

If HTTPS fails, `docker compose -f docker-compose.prod.yml logs caddy`
usually says why. Most often a domain doesn't point at the server yet, or
port 80 is closed: Let's Encrypt needs it to issue the certificate.

## 6. The admin dashboard

The server serves it at `https://admin.example.tn`. Once that works, the
Vercel project can be removed.

If you'd rather keep Vercel, change both destinations in `admin/vercel.json`
from the Railway address to `https://api.example.tn`. In that case also set
`JWT_COOKIE_SAMESITE=none` in the backend's environment (in
`docker-compose.prod.yml`), since admin and API are then on different sites.

## 7. Automatic deploys

Every merge to `main` builds new images. To have GitHub also update the
server:

1. **Make a key just for GitHub.** On your own computer:
   ```bash
   ssh-keygen -t ed25519 -f hssan-deploy -N ""
   ```
   This creates `hssan-deploy` (private) and `hssan-deploy.pub` (public).
2. **Let it into the server.** Add the content of `hssan-deploy.pub` to `/home/deploy/.ssh/authorized_keys`.
3. **Give GitHub the secrets.** GitHub → Settings → Secrets and variables → Actions → **Secrets**:
   - `PROD_SSH_HOST`: the server's IP or hostname;
   - `PROD_SSH_USER`: `deploy`;
   - `PROD_SSH_KEY`: the full content of the private `hssan-deploy` file.
4. **Delete the private key** from your computer.

The deploy runs, in `/opt/hssan-delivery`:

1. `git pull`;
2. in `deploy/`: `docker compose pull backend admin` then `docker compose up -d`.

Migrations run when the backend starts.

## 8. Backups

The `backup` service writes every night to `deploy/backups/`:

- `db-<date>.dump`: the whole database;
- `storage-<date>.tar.gz`: photos and sign-in keys.

They're kept `BACKUP_KEEP_DAYS` days (14 by default).

To take one right now:

```bash
docker compose -f docker-compose.prod.yml exec backup sh /backup.sh now
```

**Copy them off the server.** A backup on the same disk is lost with it. For
example, with [rclone](https://rclone.org) set up once (`rclone config`) for
a Backblaze B2, Google Drive or other remote, add to `deploy`'s crontab
(`crontab -e`):

```
30 4 * * * rclone copy /opt/hssan-delivery/deploy/backups remote:hssan-backups --max-age 48h
```

The files hold customers' data and the sign-in keys: keep the remote private.

**Restore** (test it once, so you know it works before you need it):

```bash
cd /opt/hssan-delivery/deploy
docker compose -f docker-compose.prod.yml stop backend
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_restore -U hssan -d hssan_delivery --no-owner --clean --if-exists < backups/db-YYYY-MM-DD_HHMM.dump
docker compose -f docker-compose.prod.yml run --rm --no-deps --entrypoint sh \
  -v "$PWD/backups:/in:ro" backend -c 'tar -xzf /in/storage-YYYY-MM-DD_HHMM.tar.gz -C var/storage'
docker compose -f docker-compose.prod.yml up -d
```

## 9. Day to day

All from `/opt/hssan-delivery/deploy`:

```bash
docker compose -f docker-compose.prod.yml logs -f backend    # API logs
docker compose -f docker-compose.prod.yml restart backend
docker compose -f docker-compose.prod.yml pull && docker compose -f docker-compose.prod.yml up -d   # update by hand

# Roll back to an earlier version: IMAGE_TAG=<commit sha> in .env, then
docker compose -f docker-compose.prod.yml up -d
```

Server updates: `sudo apt update && sudo apt upgrade` now and then. Restart
the server after kernel updates; every service restarts by itself.
