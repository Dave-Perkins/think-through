POST-DEPLOY SETUP
=================

Purpose
- Document the minimal sudoers requirement and verification steps for the repo's post-deploy automation (`scripts/post_deploy_setup.sh` and `.github/workflows/post_deploy_setup.yml`).

Sudoers requirement (why)
- The CI-run post-deploy script performs a small number of privileged operations on the droplet (write an Nginx site file with `sudo tee`, create a symlink in `/etc/nginx/sites-enabled`, and reload Nginx). To run those non-interactively from GitHub Actions as the `deploy` user, a narrow `NOPASSWD` sudoers entry is required.

Example sudoers entry (place on the droplet at `/etc/sudoers.d/deploy-postdeploy`):

```
deploy ALL=(ALL) NOPASSWD: /usr/bin/tee, /bin/ln, /bin/mv, /usr/bin/mv, /bin/rm, /usr/bin/systemctl, /usr/sbin/nginx, /usr/sbin/nginx -t
```

Commands to add the file safely (run as root or with an account that can write to `/etc/sudoers.d`):

```bash
sudo tee /etc/sudoers.d/deploy-postdeploy > /dev/null <<'EOF'
deploy ALL=(ALL) NOPASSWD: /usr/bin/tee, /bin/ln, /bin/mv, /usr/bin/mv, /bin/rm, /usr/bin/systemctl, /usr/sbin/nginx, /usr/sbin/nginx -t
EOF
sudo chmod 440 /etc/sudoers.d/deploy-postdeploy
sudo visudo -cf /etc/sudoers.d/deploy-postdeploy
```

Minimal post-deploy flow
- The repo contains `.github/workflows/post_deploy_setup.yml` (manual `workflow_dispatch`) which SSHes to the droplet and runs `scripts/post_deploy_setup.sh` as `deploy`.
- The script creates:
  - `scripts/pg_backup.sh` (daily pg_dump wrapper)
  - installs a cron entry for daily backups
  - `ssl/` self-signed cert files for the Floating IP (dev only)
  - an nginx site file at `/etc/nginx/sites-available/think_through_ip` and a symlink in `sites-enabled`, then `nginx -t` and reloads Nginx

Verification steps (run on the droplet as `deploy` or via CI SSH):

```bash
cd /home/deploy/think_through
ls -l .env
sed -n '1,200p' .env | sed -e 's/^SECRET_KEY=.*/SECRET_KEY=***REDACTED***/'
ls -l scripts/pg_backup.sh
crontab -l
ls -l ssl/privkey.pem ssl/fullchain.pem
sudo ls -l /etc/nginx/sites-available/think_through_ip /etc/nginx/sites-enabled/think_through_ip
sudo nginx -t
sudo systemctl status think_through --no-pager --lines=20
```

Notes & recommendations
- `SECRET_KEY` is generated and stored in `.env` by the provisioning flow if it was missing. For production, store secrets in a secrets manager or a vault rather than a file.
- The SSL certs created by the script are self-signed and intended for development on the Floating IP. Use Let's Encrypt (requires DNS) for production.
- Keep the sudoers entry minimal and only include commands the script actually uses. Remove or tighten the file after initial provisioning if you prefer stricter control.
- To test backups immediately, run the backup script once and inspect `logs/pg_backup.log` and `backups/`.

Reverting or tightening privileges
- To remove the `NOPASSWD` entry:

```bash
sudo rm /etc/sudoers.d/deploy-postdeploy
sudo visudo -cf /etc/sudoers.d || true
```

Questions or follow-ups
- Want me to add this as `POST_DEPLOY.md` in the repository root and open a commit/PR? (I can create a commit locally and push if you want.)
