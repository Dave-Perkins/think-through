from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),
    path('healthz', views.healthz, name='healthz'),
    path('deploy-test', views.deploy_test, name='deploy_test'),
]
