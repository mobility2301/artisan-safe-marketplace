
# ===== PASTE INTO:  accounts/urls.py   (REPLACE the whole file) =====
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    LoginView, RegisterView, SendEmailOTPView, VerifyEmailOTPView,
    SubmitNINView, PhotoUploadView, VerifyPhotoIDView, VerifyLiveView,
    VerificationStatusView, MeView
)
# DESTINATION: accounts/urls.py
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    LoginView, RegisterView, SendEmailOTPView, VerifyEmailOTPView,
    SubmitNINView, PhotoUploadView, VerifyPhotoIDView, VerifyLiveView,
    VerificationStatusView, MeView
)
 
urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('me/', MeView.as_view(), name='me'),
    path('otp/email/send/', SendEmailOTPView.as_view(), name='send-email-otp'),
    path('otp/email/verify/', VerifyEmailOTPView.as_view(), name='verify-email-otp'),
    path('nin/submit/', SubmitNINView.as_view(), name='submit-nin'),
    path('photo/upload/', PhotoUploadView.as_view(), name='photo-upload'),
    path('photo/verify-id/', VerifyPhotoIDView.as_view(), name='verify-photo-id'),
    path('photo/verify-live/', VerifyLiveView.as_view(), name='verify-live'),
    path('status/', VerificationStatusView.as_view(), name='verification-status'),
]