#!/usr/bin/env bash
set -euo pipefail

# harden_droplet.sh
# Usage: ./harden_droplet.sh [DROPLET_IP]
# Runs basic hardening on the remote droplet (unattended-upgrades, UFW, fail2ban).

DROPLET=${1:-161.35.248.143}
SSH_ROOT="root@${DROPLET}"

echo "Target droplet: ${DROPLET}"

# quick check for ssh
if ! command -v ssh >/dev/null 2>&1; then
  echo "ssh is required on this machine to run the script." >&2
  exit 1
fi

echo "Testing SSH connectivity to ${SSH_ROOT}..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_ROOT}" 'echo OK' >/dev/null 2>&1; then
  echo "Unable to connect to ${SSH_ROOT} with key-based auth. Ensure you can SSH as root or run this on the droplet directly." >&2
  echo "You can try: ssh ${SSH_ROOT}" >&2
  exit 2
fi

cat <<'EOF' | ssh "${SSH_ROOT}"
set -euo pipefail

echo "Updating package lists and installing packages..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades ufw fail2ban || true

# Enable unattended-upgrades via systemd and minimal config
cat > /etc/apt/apt.conf.d/20auto-upgrades <<AUTO
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
AUTO

systemctl enable --now unattended-upgrades || true

# UFW: allow SSH and Nginx Full (HTTP+HTTPS) then enable
ufw allow OpenSSH || true
# If Nginx is installed, the profile exists; allow it safely
if ufw app list | grep -q "Nginx"; then
  ufw allow 'Nginx Full' || true
fi
ufw --force enable

# Install/enable fail2ban
systemctl enable --now fail2ban || true

# Basic fail2ban config: ensure ssh jail enabled (default usually present)
if [ -f /etc/fail2ban/jail.local ]; then
  echo "Using existing /etc/fail2ban/jail.local"
else
  cat > /etc/fail2ban/jail.local <<JAIL
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
JAIL
fi

systemctl restart fail2ban || true

# Report status
echo "--- unattended-upgrades status ---"
systemctl status unattended-upgrades --no-pager || true

echo "--- ufw status ---"
ufw status verbose || true

echo "--- fail2ban status ---"
fail2ban-client status || true

EOF

echo "Done. The droplet at ${DROPLET} has basic hardening enabled (unattended-upgrades, UFW, fail2ban)."

echo "If you prefer to run the commands manually on the droplet instead of via SSH, SSH into the droplet and run the same package/install commands."
