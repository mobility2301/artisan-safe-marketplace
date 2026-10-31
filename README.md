# Artisan Safe Marketplace (Nsukka)

Design and Implementation of a Security-Sensitive Online Marketplace for Local Artisans.

- backend: Django REST API (SQLite)
- frontend: Flutter app (run in Chrome)

## Run the backend
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver

## Run the frontend
cd frontend
flutter pub get
flutter run -d chrome --no-web-resources-cdn
