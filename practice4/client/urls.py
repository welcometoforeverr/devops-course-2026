"""Routes for direct and proxied requests."""
from django.urls import path
from . import views
urlpatterns = [path("", views.index, name="index"),
               path("grpc", views.direct, name="grpc"),
               path("nginx", views.proxy, name="nginx")]
