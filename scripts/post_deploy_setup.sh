#!/usr/bin/env bash
set -euo pipefail
# Post-deploy setup: run on the server from the repo directory
#  - show .env (redacted)
#  - create scripts/pg_backup.sh and install daily cron
#  - generate self-signed cert for Floating IP
#  - add nginx site for IP TLS and reload nginx

REPO_DIR="/home/deploy/think_through"
FLOATING_IP=161.35.248.143

cd "$REPO_DIR"
echo "---OWNER/PERMS---"
ls -l .env 2>/dev/null || true
echo "---.env (redacted)---"
if [ -f .env ]; then
  sed -E "s#(DATABASE_URL=postgres://[^:]+:)[^@]+(@.*)#\1REDACTED\2#" .env || true
else
  echo ".env not found"
fi

mkdir -p scripts logs backups ssl
chown -R deploy:deploy scripts logs backups ssl || true
chmod 700 scripts || true

cat > scripts/pg_backup.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
DIR=$(dirname "$0")/..
cd "$DIR"
if [ ! -f .env ]; then
  echo ".env missing; cannot run backup"
  exit 1
fi
source .env || true
if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL not set in .env"
  exit 1
fi
# Use python to parse DATABASE_URL robustly and call pg_dump
python3 - <<'PY'
import os,subprocess,sys
from urllib.parse import urlparse
url=os.environ.get('DATABASE_URL')
if not url:
    print('DATABASE_URL missing',file=sys.stderr); sys.exit(1)
u=urlparse(url)
user=u.username or ''
pw=u.password or ''
host=u.hostname or 'localhost'
port=str(u.port or 5432)
dbname=u.path.lstrip('/')
fname='backups/%s.dump' % ( __import__('datetime').datetime.utcnow().strftime('%Y%m%dT%H%M%SZ') )
env=dict(os.environ)
env['PGPASSWORD']=pw
cmd=['pg_dump','-Fc','-h',host,'-p',port,'-U',user,dbname,'-f',fname]
print('Running:', ' '.join(cmd))
subprocess.check_call(cmd, env=env)
print('Wrote', fname)
PY
find backups -type f -mtime +7 -name '*.dump' -delete || true
echo "Backup finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
SH

chmod +x scripts/pg_backup.sh
chown deploy:deploy scripts/pg_backup.sh || true

# install crontab for deploy user (idempotent)
CRON_ENTRY="0 3 * * * /home/deploy/think_through/scripts/pg_backup.sh >> /home/deploy/think_through/logs/pg_backup.log 2>&1"
crontab -l 2>/dev/null | grep -F "$CRON_ENTRY" >/dev/null 2>&1 || (crontab -l 2>/dev/null || true; echo "$CRON_ENTRY") | crontab -

# create self-signed cert for the Floating IP (dev only)
SSL_DIR="$REPO_DIR/ssl"
if [ ! -f "$SSL_DIR/privkey.pem" ] || [ ! -f "$SSL_DIR/fullchain.pem" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" \
    -subj "/CN=$FLOATING_IP" || true
  chmod 640 "$SSL_DIR"/* || true
  chown deploy:deploy "$SSL_DIR"/* || true
fi

# configure nginx site for IP TLS (write using sudo + tee to avoid shell expansion)
NG_AVAIL=/etc/nginx/sites-available/think_through_ip
NG_ENABLED=/etc/nginx/sites-enabled/think_through_ip
if [ -d /etc/nginx/sites-available ]; then
  if [ ! -f "$NG_AVAIL" ]; then
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak 2>/dev/null || true
    sudo tee "$NG_AVAIL" > /dev/null <<'NG'
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_certificate /home/deploy/think_through/ssl/fullchain.pem;
    ssl_certificate_key /home/deploy/think_through/ssl/privkey.pem;

    location / {
        proxy_pass http://unix:/run/think_through.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NG
    sudo ln -sf "$NG_AVAIL" "$NG_ENABLED" || true
    sudo nginx -t || true
    sudo systemctl reload nginx || true
  fi
fi

echo "POST-DEPLOY SETUP: done"
echo "Verify: ls -l .env; sudo ls -l /etc/nginx/sites-enabled; crontab -l"

exit 0
