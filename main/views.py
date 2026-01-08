from django.http import HttpResponse, JsonResponse
import os
import socket
import subprocess
from datetime import datetime


def index(request):
    return HttpResponse('Hello from think_through!', content_type='text/plain')


def healthz(request):
    # Lightweight health check
    return HttpResponse('OK', content_type='text/plain')


def deploy_test(request):
    """Return a small JSON payload useful for verifying a deploy and environment.

    Fields:
    - timestamp: ISO 8601 UTC
    - host: server hostname
    - git_sha: short commit SHA if available
    """
    # timestamp
    ts = datetime.utcnow().isoformat() + 'Z'

    # hostname
    host = socket.gethostname()

    # git SHA (best-effort): prefer an atomic file written at deploy-time, fall back to git
    git_sha_full = None
    git_sha_short = None
    try:
        repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        sha_file = os.path.join(repo_dir, '.GIT_SHA')
        if os.path.exists(sha_file):
            try:
                with open(sha_file, 'r') as f:
                    val = f.read().strip()
                    if val:
                        git_sha_full = val
                        git_sha_short = val[:12]
            except Exception:
                git_sha_full = None

        # fallback to reading from git if no file present
        if not git_sha_full:
            # full
            try:
                git_sha_full = subprocess.check_output(
                    ['git', 'rev-parse', 'HEAD'], cwd=repo_dir, stderr=subprocess.DEVNULL
                ).decode().strip()
            except Exception:
                git_sha_full = None

        if not git_sha_short and git_sha_full:
            git_sha_short = git_sha_full[:12]
        elif not git_sha_short:
            try:
                git_sha_short = subprocess.check_output(
                    ['git', 'rev-parse', '--short', 'HEAD'], cwd=repo_dir, stderr=subprocess.DEVNULL
                ).decode().strip()
            except Exception:
                git_sha_short = None
    except Exception:
        git_sha_full = None
        git_sha_short = None

    payload = {
        'timestamp': ts,
        'host': host,
        'git_sha_full': git_sha_full,
        'git_sha_short': git_sha_short,
    }
    return JsonResponse(payload)
