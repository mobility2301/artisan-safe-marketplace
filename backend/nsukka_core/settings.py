# DESTINATION: nsukka_core/settings.py
from datetime import timedelta
from pathlib import Path
import os
 
from django.core.exceptions import ImproperlyConfigured
 
BASE_DIR = Path(__file__).resolve().parent.parent
 
# --- Environment-based settings -------------------------------------------
# On your laptop none of these need to be set: the defaults below are for
# development. For deployment, set DJANGO_DEBUG=False, DJANGO_SECRET_KEY and
# DJANGO_ALLOWED_HOSTS as environment variables.
DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'
 
SECRET_KEY = os.environ.get(
    'DJANGO_SECRET_KEY',
    'django-insecure-nsukka-artisan-safe-marketplace-chapter3-key',
)
if not DEBUG and SECRET_KEY.startswith('django-insecure'):
    raise ImproperlyConfigured("Set DJANGO_SECRET_KEY before running with DEBUG=False.")
 
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')
 
# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
 
    # Chapter 3 Apps - Table 1-10
    'accounts',
    'artisans',
    'jobs',
 
    # For API + Payment + Message Sender later
    'rest_framework',
    'corsheaders',
]
 
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
 
ROOT_URLCONF = 'nsukka_core.urls'
 
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
 
WSGI_APPLICATION = 'nsukka_core.wsgi.application'
 
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
 
# Custom User - Table 1 (Objective 2 & 3)
AUTH_USER_MODEL = 'accounts.CustomUser'
 
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
 
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Africa/Lagos'
USE_I18N = True
USE_TZ = True
 
STATIC_URL = 'static/'
 
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
 
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
 
# CORS for Flutter (fine for development; restrict to your real domains in production)
CORS_ALLOW_ALL_ORIGINS = True
 
# REST Framework
# JWT is listed first because the Flutter app logs in with /api/auth/login/ and
# sends "Authorization: Bearer <token>". Without JWTAuthentication here every
# protected endpoint would reject the app's requests.
# Endpoints now require login by default; public ones (register, login, artisan
# browsing) say AllowAny explicitly in their views.
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}
 
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}
 
# Artisan listing: while developing (DEBUG=True) every active artisan is listed so
# you can test without finishing verification. With DEBUG=False only fully
# verified artisans are shown to clients.
LISTING_REQUIRES_VERIFIED = not DEBUG
 
# NIN verification - see accounts/services/nin_service.py
# 'format_only' = the NIN must look like a Nigerian NIN (11 digits) and be unused.
# It does NOT check the NIMC database. Change to a provider name once the project
# has a registered business and live NIN API access.
NIN_PROVIDER = 'format_only'
NIN_HASH_KEY = os.environ.get('NIN_HASH_KEY', SECRET_KEY)   # set a separate key in production
 
# Face verification (DeepFace) - see accounts/services/face_service.py
FACE_MODEL = 'Facenet512'
FACE_DETECTOR = 'opencv'          # try 'retinaface' if ID-card photos fail to be detected
FACE_THRESHOLD_PHOTO = 0.30       # profile photo vs ID  (smaller = stricter)
FACE_THRESHOLD_LIVE = 0.30        # live selfie vs ID    (smaller = stricter)
# Checks that the live selfie is a real face, not a photo/screen held to the camera.
# Fails closed: if the anti-spoofing model cannot run, the live photo is rejected.
# While developing you may set this to False, but then liveness is NOT being checked.
FACE_ANTISPOOF = True
 
# Email is used for two things only: the registration code and the SOS alert to the
# emergency contact. Everything else reaches users as in-app notifications.
#
# To send REAL email (for example from a Gmail account), set these environment
# variables in the terminal that runs the server (never put the password in code):
#   EMAIL_HOST_USER      your Gmail address
#   EMAIL_HOST_PASSWORD  a Gmail "app password" (not your normal password)
# With them set, mail is really sent and the code is no longer shown on screen.
# Without them, in development, the email is printed in the server console.
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
REAL_EMAIL = bool(EMAIL_HOST_USER and EMAIL_HOST_PASSWORD)
 
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER if REAL_EMAIL else 'noreply@artisansafe.nsukka'
if REAL_EMAIL or not DEBUG:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
    EMAIL_USE_TLS = True
else:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
 
# The OTP is shown in the API reply / server console only while developing without
# real email. With real email it must arrive by email only.
SHOW_DEV_CODES = DEBUG and not REAL_EMAIL
 
# Check-in: the artisan must be within this many metres of the job location
# (only checked when the client shared GPS coordinates with the request).
# Laptop browsers give a rough location, so the limit is generous.
CHECKIN_MAX_DISTANCE_M = 500