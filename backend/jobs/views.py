
# DESTINATION: jobs/views.py
"""
Jobs API - step 1: requesting, accepting, rejecting and cancelling a job,
plus in-app notifications.
(Check-in, check-out, SOS, payment and reviews come in the next steps.)
"""
from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
 
from artisans.models import ArtisanProfile
from .models import Job, Notification
from .serializers import (
    AcceptJobSerializer,
    JobCreateSerializer,
    JobSerializer,
    NotificationSerializer,
    ReasonSerializer,
)
from .utils import notify
 
 
class JobRequestThrottle(UserRateThrottle):
    """Limits job REQUESTS (POST) only, so listing jobs is never blocked."""
    scope = 'job_request'
    rate = '20/hour'
 
    def allow_request(self, request, view):
        if request.method != 'POST':
            return True
        return super().allow_request(request, view)
 
 
def verification_required():
    # Same switch as the artisan listing: relaxed while DEBUG=True, strict in production
    return getattr(settings, 'LISTING_REQUIRES_VERIFIED', True)
 
 
def my_jobs(user):
    """Only jobs the user takes part in. Anything else behaves as 'not found'."""
    return (Job.objects.filter(Q(client=user) | Q(artisan=user))
            .select_related('client', 'artisan', 'artisan__artisan_profile'))
 
 
def job_json(job, request):
    return JobSerializer(job, context={'request': request}).data
 
 
def error(message, code=status.HTTP_400_BAD_REQUEST):
    return Response({'error': message}, status=code)
 
 
# ---------------------------------------------------------------------------
# GET /api/jobs/   - my jobs        POST /api/jobs/  - request an artisan
# ---------------------------------------------------------------------------
@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([JobRequestThrottle])
def job_list_create(request):
    if request.method == 'GET':
        return list_jobs(request)
    return create_job(request)
 
 
def list_jobs(request):
    """Optional filters: ?status=accepted  ?role=client|artisan"""
    jobs = my_jobs(request.user)
 
    wanted_status = request.query_params.get('status', '').strip()
    if wanted_status:
        if wanted_status not in dict(Job.STATUS_CHOICES):
            return error("Invalid status.")
        jobs = jobs.filter(status=wanted_status)
 
    role = request.query_params.get('role', '').strip()
    if role == 'client':
        jobs = jobs.filter(client=request.user)
    elif role == 'artisan':
        jobs = jobs.filter(artisan=request.user)
    elif role:
        return error("role must be 'client' or 'artisan'.")
 
    return Response(JobSerializer(jobs, many=True, context={'request': request}).data)
 
 
def create_job(request):
    user = request.user
    if user.user_type != 'client':
        return error("Only client accounts can request a job.", status.HTTP_403_FORBIDDEN)
    if verification_required() and not user.is_email_verified:
        return error("Verify your email before requesting a job.", status.HTTP_403_FORBIDDEN)
 
    serializer = JobCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
 
    profile = data['artisan_profile']
    artisan = profile.user
    if not artisan.is_active or not profile.is_available:
        return error("This artisan is not available right now.")
    if verification_required() and not artisan.is_fully_verified:
        return error("This artisan has not completed verification yet.")
 
    already_open = Job.objects.filter(
        client=user, artisan=artisan,
        status__in=('requested', 'accepted', 'checked_in', 'checked_out'),
    ).exists()
    if already_open:
        return error("You already have an open job with this artisan.")
 
    with transaction.atomic():
        job = Job.objects.create(
            client=user,
            artisan=artisan,
            job_address_text=data['job_address_text'],
            job_address_lga=data['job_address_lga'],
            client_lat=data.get('client_lat'),
            client_lng=data.get('client_lng'),
            description=data['description'],
            category=data.get('category') or profile.category,
        )
        # The notification leaves out the address on purpose
        category_label = dict(ArtisanProfile.CATEGORY).get(job.category, job.category)
        notify(artisan, "New job request",
               f"{user.full_name} requested a {category_label.lower()} job in {job.job_address_lga}.", job)
 
    return Response(job_json(job, request), status=status.HTTP_201_CREATED)
 
 
# ---------------------------------------------------------------------------
# GET /api/jobs/<id>/
# ---------------------------------------------------------------------------
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def job_detail(request, pk):
    job = get_object_or_404(my_jobs(request.user), pk=pk)
    return Response(job_json(job, request))
 
 
# ---------------------------------------------------------------------------
# POST /api/jobs/<id>/accept/   (artisan)
# body: {"lat": .., "lng": .., "estimated_amount": 5000 (optional)}
# ---------------------------------------------------------------------------
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_accept(request, pk):
    serializer = AcceptJobSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
 
    user = request.user
    if verification_required() and not user.is_fully_verified:
        return error("Complete your verification before accepting jobs.", status.HTTP_403_FORBIDDEN)
 
    with transaction.atomic():
        # select_for_update: two quick taps cannot accept the same job twice
        job = get_object_or_404(Job.objects.select_for_update(), pk=pk, artisan=user)
        if not job.can_move_to('accepted'):
            return error(f"This job is already {job.get_status_display().lower()}.")
 
        job.status = 'accepted'
        job.artisan_accept_lat = data['lat']
        job.artisan_accept_lng = data['lng']
        job.artisan_accept_timestamp = timezone.now()
        if 'estimated_amount' in data:
            job.estimated_amount = data['estimated_amount']
        job.save()
        notify(job.client, "Job accepted",
               f"{user.full_name} accepted your job request.", job)
 
    job = get_object_or_404(my_jobs(user), pk=pk)
    return Response(job_json(job, request))
 
 
# ---------------------------------------------------------------------------
# POST /api/jobs/<id>/reject/   (artisan)     body: {"reason": "..." (optional)}
# POST /api/jobs/<id>/cancel/   (client or artisan)
# ---------------------------------------------------------------------------
def _close_job(request, pk, new_status, who, title, verb):
    serializer = ReasonSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    reason = serializer.validated_data.get('reason', '').strip()
 
    user = request.user
    with transaction.atomic():
        job = get_object_or_404(Job.objects.select_for_update().filter(Q(client=user) | Q(artisan=user)), pk=pk)
        if who == 'artisan' and job.artisan_id != user.pk:
            return error("Only the artisan can do this.", status.HTTP_403_FORBIDDEN)
        if not job.can_move_to(new_status):
            return error(f"This job is already {job.get_status_display().lower()}, so it cannot be {verb}.")
 
        job.status = new_status
        job.save()
        other = job.client if user.pk == job.artisan_id else job.artisan
        body = f"{user.full_name} {verb} the job."
        if reason:
            body += f" Reason: {reason}"
        notify(other, title, body, job)
 
    job = get_object_or_404(my_jobs(user), pk=pk)
    return Response(job_json(job, request))
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_reject(request, pk):
    return _close_job(request, pk, 'rejected', 'artisan', "Job declined", "declined")
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_cancel(request, pk):
    return _close_job(request, pk, 'cancelled', 'either', "Job cancelled", "cancelled")
 
 
# ---------------------------------------------------------------------------
# Notifications
# GET  /api/jobs/notifications/            (?unread=true)
# POST /api/jobs/notifications/<id>/read/
# ---------------------------------------------------------------------------
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def notification_list(request):
    items = Notification.objects.filter(user=request.user)
    if request.query_params.get('unread', '').lower() in ('true', '1', 'yes'):
        items = items.filter(is_read=False)
    return Response(NotificationSerializer(items[:50], many=True).data)
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def notification_read(request, pk):
    item = get_object_or_404(Notification, pk=pk, user=request.user)
    item.is_read = True
    item.save(update_fields=['is_read'])
    return Response(NotificationSerializer(item).data)