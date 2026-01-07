#!/usr/bin/env bash
set -euo pipefail

# cleanup_do_sshkey.sh
# Usage: ./cleanup_do_sshkey.sh [DROPLET_IP] [DO_KEY_ID]
# Defaults: DROPLET_IP=161.35.248.143 DO_KEY_ID=53111848

DROPLET_IP=${1:-161.35.248.143}
DO_KEY_ID=${2:-53111848}
LOCAL_PUB=${HOME}/.ssh/id_rsa.pub
SAVED_DO_KEY=${HOME}/do_sshkey_${DO_KEY_ID}.pub

echo "Target droplet: $DROPLET_IP"
echo "DO key id: $DO_KEY_ID"

# Preflight checks
if ! command -v doctl >/dev/null 2>&1; then
  echo "doctl not found. Install and authenticate doctl before running this script." >&2
  exit 1
fi
if [ ! -f "$LOCAL_PUB" ]; then
  echo "Local public key $LOCAL_PUB not found. Create or use an existing public key and retry." >&2
  exit 1
fi

# Fetch and save the DO public key (if present)
set +e
doctl compute ssh-key get "$DO_KEY_ID" --format PublicKey --no-header > "$SAVED_DO_KEY" 2>/dev/null
rc=$?
set -e
if [ $rc -ne 0 ]; then
  echo "Warning: could not fetch public key for DO key id $DO_KEY_ID (it may already be missing)." >&2
fi

echo "Saved DO key (if available) to: $SAVED_DO_KEY"
ls -l "$SAVED_DO_KEY" || true

# Back up remote authorized_keys
echo "Backing up remote authorized_keys files..."
ssh root@"$DROPLET_IP" 'sudo mkdir -p /root/.ssh; sudo cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak.$(date +%s) || true; sudo cp /home/deploy/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys.bak.$(date +%s) 2>/dev/null || true'

# Append local public key to root authorized_keys
echo "Appending your local public key ($LOCAL_PUB) to root's authorized_keys..."
cat "$LOCAL_PUB" | ssh root@"$DROPLET_IP" 'umask 077; mkdir -p /root/.ssh; cat >> /root/.ssh/authorized_keys; sudo chmod 700 /root/.ssh; sudo chmod 600 /root/.ssh/authorized_keys'

# Append to deploy
echo "Appending your local public key ($LOCAL_PUB) to deploy's authorized_keys..."
cat "$LOCAL_PUB" | ssh root@"$DROPLET_IP" 'umask 077; sudo mkdir -p /home/deploy/.ssh; sudo bash -c "cat >> /home/deploy/.ssh/authorized_keys"; sudo chown -R deploy:deploy /home/deploy/.ssh; sudo chmod 700 /home/deploy/.ssh; sudo chmod 600 /home/deploy/.ssh/authorized_keys'

# Verify access from a new local session
echo "\nPlease open a new terminal tab and run the following to verify access before we delete anything:" 
echo "  ssh root@$DROPLET_IP 'echo root OK'"
echo "  ssh deploy@$DROPLET_IP 'echo deploy OK'"
read -p "Did both commands succeed? (yes/no) " proceed
if [ "$proceed" != "yes" ]; then
  echo "Aborting — verification failed. No DO account changes made." >&2
  exit 2
fi

# Delete the DO account key
read -p "Delete DO account SSH key ID $DO_KEY_ID now? (yes/no) " delok
if [ "$delok" = "yes" ]; then
  echo "Deleting DO key id $DO_KEY_ID from DigitalOcean account..."
  doctl compute ssh-key delete "$DO_KEY_ID" --force
else
  echo "Skipping DO account key deletion." 
fi

# If we saved a DO public key, upload it and remove matching lines from root's authorized_keys
if [ -s "$SAVED_DO_KEY" ]; then
  echo "Removing matching lines from /root/.ssh/authorized_keys on the droplet..."
  scp "$SAVED_DO_KEY" root@"$DROPLET_IP":/tmp/do_key_to_remove.pub
  ssh root@"$DROPLET_IP" 'sudo grep -v -Ff /tmp/do_key_to_remove.pub /root/.ssh/authorized_keys > /root/.ssh/authorized_keys.new && sudo mv /root/.ssh/authorized_keys.new /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys && sudo rm /tmp/do_key_to_remove.pub'
  echo "Removed matching lines from root's authorized_keys (if any)."
else
  echo "No DO public key saved; skipping removal from remote authorized_keys. If you want to remove specific lines manually, use the saved backup files in /root/.ssh/." 
fi

# Show final state
echo "\nFinal remote authorized_keys content:" 
ssh root@"$DROPLET_IP" 'echo "--- root ---"; sudo cat /root/.ssh/authorized_keys || true; echo "--- deploy ---"; cat /home/deploy/.ssh/authorized_keys 2>/dev/null || true'

echo "\nRemaining DO account keys:" 
doctl compute ssh-key list || true

echo "Done. If you want me to generate the GitHub Actions deploy workflow next, say so." 
