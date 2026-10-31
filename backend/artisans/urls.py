# ===== PASTE THIS INTO:  artisans/urls.py =====
from django.urls import path
from .views import artisan_list, artisan_detail, artisan_categories, my_profile
 
urlpatterns = [
    path('', artisan_list, name='artisan-list'),
    path('categories/', artisan_categories, name='artisan-categories'),
    path('me/', my_profile, name='artisan-me'),          # must stay above <int:pk>/
    path('<int:pk>/', artisan_detail, name='artisan-detail'),
]