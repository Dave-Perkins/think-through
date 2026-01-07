**Deploy README**

**Purpose**: Quick steps to configure GitHub Actions deployment to your DigitalOcean droplet.

**Workflow file**: The repository contains `.github/workflows/deploy.yml` which runs on `push` to `main` and uses an SSH key to connect to the `deploy` user on the droplet.

**Required GitHub Secrets**:
* **`DEPLOY_HOST`**: Floating IP or hostname (e.g., `161.35.248.143`).
* **`DEPLOY_USER`**: SSH user (default: `deploy`).
* **`DEPLOY_KEY`**: Private SSH key (the private part of the keypair you will add to `/home/deploy/.ssh/authorized_keys`).

**Generate a deploy key (locally)**:
1. Create a new keypair specifically for CI deploys:

```bash
ssh-keygen -t rsa -b 3072 -f ~/.ssh/ci_deploy_key -C "github-actions-deploy" -N ""
```

2. The public key file is `~/.ssh/ci_deploy_key.pub` and the private key is `~/.ssh/ci_deploy_key`.

**Install the public key on the droplet**:

```bash
# as your Mac user (replace IP if different)
ssh root@161.35.248.143 "sudo mkdir -p /home/deploy/.ssh && sudo bash -c 'cat >> /home/deploy/.ssh/authorized_keys'" < ~/.ssh/ci_deploy_key.pub
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

**Add the private key to GitHub Secrets**:

* Via the web UI: Repository → Settings → Secrets → Actions → New repository secret. Name the secret `DEPLOY_KEY` and paste the entire contents of `~/.ssh/ci_deploy_key`.

* Via the `gh` CLI (optional):

```bash
gh secret set DEPLOY_HOST --body "161.35.248.143"
gh secret set DEPLOY_USER --body "deploy"
gh secret set DEPLOY_KEY --body "$(cat ~/.ssh/ci_deploy_key)"
```

**Test the SSH key locally** (before pushing changes):

```bash
ssh -i ~/.ssh/ci_deploy_key deploy@161.35.248.143 'echo OK'
```

**Triggering the workflow**:

* Push a commit to `main` (or open a PR if your workflow triggers on PRs). The Action will run and perform the deploy steps.

**Common adjustments**:
* **Service name**: The workflow restarts `think_through` using `sudo systemctl restart think_through`. If your systemd unit name differs, update `.github/workflows/deploy.yml`.
* **Project path**: The workflow assumes the project lives at `/home/deploy/think_through`. Change the `cd` line in the workflow if your path differs.
* **Pre-deploy tests**: Consider adding a test step that runs `pytest` (or other checks) and aborts the deploy on failures.

**Safety notes**:
* Use a dedicated deploy key (do not re-use your personal private key).
* Keep the private key secret — store it only in GitHub Secrets and your CI environment.
* If you need to revoke the deploy key, remove it from `/home/deploy/.ssh/authorized_keys` on the droplet and delete the secret in GitHub.

**Want help?** I can update the workflow to add tests, use a socket reload instead of `systemctl`, or create a `Makefile` target for local deploy testing.
