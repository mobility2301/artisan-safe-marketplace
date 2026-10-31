# DESTINATION: jobs/urls.py
from django.urls import path
from .safety import job_checkin, job_checkout, job_confirm_checkout, job_sos, job_sos_resolve
from .reviews import job_review
from .views import (
    job_list_create, job_detail, job_accept, job_reject, job_cancel,
    notification_list, notification_read,
)
 
urlpatterns = [
    path('', job_list_create, name='job-list-create'),
    path('notifications/', notification_list, name='notification-list'),
    path('notifications/<int:pk>/read/', notification_read, name='notification-read'),
    path('<int:pk>/', job_detail, name='job-detail'),
    path('<int:pk>/accept/', job_accept, name='job-accept'),
    path('<int:pk>/reject/', job_reject, name='job-reject'),
    path('<int:pk>/cancel/', job_cancel, name='job-cancel'),
    path('<int:pk>/checkin/', job_checkin, name='job-checkin'),
    path('<int:pk>/checkout/', job_checkout, name='job-checkout'),
    path('<int:pk>/confirm-checkout/', job_confirm_checkout, name='job-confirm-checkout'),
    path('<int:pk>/review/', job_review, name='job-review'),
    path('<int:pk>/sos/', job_sos, name='job-sos'),
    path('<int:pk>/sos/resolve/', job_sos_resolve, name='job-sos-resolve'),
]