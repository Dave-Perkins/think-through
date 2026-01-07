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

    # git SHA (best-effort)
    git_sha = None
    try:
        repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        git_sha = subprocess.check_output(
            ['git', 'rev-parse', '--short', 'HEAD'], cwd=repo_dir, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        git_sha = None

    payload = {
        'timestamp': ts,
        'host': host,
        'git_sha': git_sha,
    }
    return JsonResponse(payload)
