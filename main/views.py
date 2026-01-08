from django.http import HttpResponse, JsonResponse, HttpResponseBadRequest
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from django.conf import settings
import os
import socket
import subprocess
from datetime import datetime
import json


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


def send_notification(request):
    """POST endpoint that accepts JSON payload and sends a templated email.

    Expected JSON fields (MVP):
    - title (string)
    - summary (string)
    - author_name (string)
    - created_at (ISO timestamp string)
    - url (string)

    The endpoint sends to `settings.NOTIFICATION_EMAILS` (env-driven). Returns 202 on success.
    """
    if request.method != 'POST':
        return HttpResponseBadRequest('POST required')

    try:
        payload = json.loads(request.body.decode('utf-8'))
    except Exception:
        return HttpResponseBadRequest('Invalid JSON')

    required = ['title', 'summary', 'author_name', 'created_at', 'url']
    missing = [f for f in required if not payload.get(f)]
    if missing:
        return HttpResponseBadRequest('Missing fields: ' + ','.join(missing))

    subject = f"Think Through: {payload.get('title')[:78]}"
    context = {
        'title': payload.get('title'),
        'summary': payload.get('summary'),
        'author_name': payload.get('author_name'),
        'created_at': payload.get('created_at'),
        'url': payload.get('url'),
    }

    # Render templates
    text_body = render_to_string('main/notification.txt', context)
    try:
        html_body = render_to_string('main/notification.html', context)
    except Exception:
        html_body = None

    recipients = getattr(settings, 'NOTIFICATION_EMAILS', [])
    if not recipients:
        return HttpResponseBadRequest('No recipients configured')

    from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', None)

    msg = EmailMultiAlternatives(subject=subject, body=text_body, from_email=from_email, to=recipients)
    if html_body:
        msg.attach_alternative(html_body, 'text/html')

    try:
        msg.send()
    except Exception as exc:
        return HttpResponse(status=500, content=f'Failed to send email: {exc}')

    return HttpResponse(status=202)
