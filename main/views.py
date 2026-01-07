from django.http import HttpResponse


def index(request):
    return HttpResponse('Hello from think_through!', content_type='text/plain')


def healthz(request):
    # Lightweight health check
    return HttpResponse('OK', content_type='text/plain')
