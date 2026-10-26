"""Settings for the local educational Django client."""
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = "local-educational-demo-only"
DEBUG = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost", "testserver"]
ROOT_URLCONF = "client.urls"
MIDDLEWARE = ["django.middleware.csrf.CsrfViewMiddleware"]
INSTALLED_APPS = []
TEMPLATES = [{"BACKEND": "django.template.backends.django.DjangoTemplates",
              "DIRS": [BASE_DIR / "client" / "templates"], "APP_DIRS": True,
              "OPTIONS": {"context_processors": []}}]
USE_TZ = True
