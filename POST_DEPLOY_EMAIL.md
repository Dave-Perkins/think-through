Email notification: feature notes
================================

The project provides a minimal notification endpoint for sending short, templated emails.

- Environment variables (recommended):
  - `DEFAULT_FROM_EMAIL` (e.g. `noreply@example.com`)
  - `EMAIL_BACKEND` (default for local dev: `django.core.mail.backends.console.EmailBackend`)
  - `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_USE_TLS`
  - `NOTIFICATION_EMAILS` — comma-separated list of recipients. Defaults to `ananab.tilps@gmail.com`.

Testing locally: set `EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend` or run tests which use `locmem`.

Endpoint: `POST /api/send-notification/` accepts JSON with the following fields: `title`, `summary`, `author_name`, `created_at`, `url`.

The endpoint sends a templated email to the addresses in `NOTIFICATION_EMAILS`.
