
# DESTINATION: jobs/safety.py
"""
Jobs API - step 2: the safety features.
 
  POST /api/jobs/<id>/checkin/           artisan   selfie + GPS  -> face match, liveness, location
  POST /api/jobs/<id>/checkout/          artisan   GPS           -> leaves the job
  POST /api/jobs/<id>/confirm-checkout/  client                  -> job completed
  POST /api/jobs/<id>/sos/               either    GPS           -> email to the emergency contact
  POST /api/jobs/<id>/sos/resolve/       the person who pressed SOS -> "I am safe"
 
Every status change goes through Job.can_move_to(), so a job can never skip a step.
"""
import logging
 
from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes, throttle_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
 
from accounts.services.face_service import check_live_against_id
from .models import CheckIn, Checkout, Job, SOSAlert
from .serializers import CheckInSerializer, LocationSerializer
from .utils import distance_m, notify, send_sos_email
from .views import error, job_json, my_jobs
 
logger = logging.getLogger(__name__)
 
 
class CheckInThrottle(UserRateThrottle):
    scope = 'checkin'
    rate = '20/hour'
 
 
def _fresh(request, pk):
    return get_object_or_404(my_jobs(request.user), pk=pk)
 
 
# ---------------------------------------------------------------------------
# CHECK-IN
# ---------------------------------------------------------------------------
@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
@throttle_classes([CheckInThrottle])
def job_checkin(request, pk):
    user = request.user
    job = get_object_or_404(Job.objects.select_related('client', 'artisan'), pk=pk, artisan=user)
    if not job.can_move_to('checked_in'):
        return error(f"You cannot check in: this job is {job.get_status_display().lower()}.")
 
    serializer = CheckInSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
 
    # One row per attempt, saved BEFORE the checks so even a failed attempt is on record
    attempt = CheckIn.objects.create(
        job=job, artisan=user,
        checkin_lat=data['lat'], checkin_lng=data['lng'],
        selfie_image=data['selfie'],
    )
 
    # 1 + 2: real face (anti-spoofing) and match with the ID photo
    liveness, matched, score, why_face = check_live_against_id(user, attempt.selfie_image.path)
 
    # 3: is the artisan at the job location? (only when the client shared GPS)
    distance = None
    location_ok = True
    why_place = ''
    if job.client_lat is not None and job.client_lng is not None:
        distance = distance_m(data['lat'], data['lng'], job.client_lat, job.client_lng)
        limit = getattr(settings, 'CHECKIN_MAX_DISTANCE_M', 500)
        location_ok = distance <= limit
        if not location_ok:
            why_place = f"The artisan is about {round(distance)} m from the job location (limit {limit} m)."
 
    verified = bool(liveness and matched and location_ok)
    reason = '' if verified else (why_face or why_place or "Check-in failed.")
    if not verified and why_face and why_place:
        reason = f"{why_face} {why_place}"
 
    with transaction.atomic():
        attempt.liveness_passed = liveness
        attempt.face_match_score = score
        attempt.distance_from_client_m = distance
        attempt.location_ok = location_ok
        attempt.is_verified = verified
        attempt.failure_reason = reason[:200]
        attempt.save()
 
        if verified:
            locked = Job.objects.select_for_update().get(pk=job.pk)
            if not locked.can_move_to('checked_in'):
                attempt.is_verified = False
                attempt.failure_reason = "The job changed while you were checking in."
                attempt.save(update_fields=['is_verified', 'failure_reason'])
                return error("The job changed while you were checking in. Refresh and try again.")
            locked.status = 'checked_in'
            locked.save()
            place = f" and is about {round(distance)} m from your address" if distance is not None else ""
            notify(job.client, "Artisan identity verified",
                   f"{user.full_name}'s live selfie matched their ID photo ({score:.0f}%){place}. "
                   f"You can let them in.", job)
        else:
            notify(job.client, "WARNING: identity check failed",
                   f"{user.full_name} tried to check in but the check failed. "
                   f"Do not let them in until this is sorted out. Reason: {reason}", job)
 
    if not verified:
        return Response({'verified': False, 'error': reason, 'match_score': round(score, 1),
                         'attempt_id': attempt.pk}, status=status.HTTP_400_BAD_REQUEST)
 
    return Response({
        'verified': True,
        'match_score': round(score, 1),
        'distance_m': None if distance is None else round(distance),
        'location_checked': distance is not None,
        'attempt_id': attempt.pk,
        'job': job_json(_fresh(request, pk), request),
    })
 
 
# ---------------------------------------------------------------------------
# CHECKOUT (artisan leaves) and CONFIRMATION (client agrees)
# ---------------------------------------------------------------------------
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_checkout(request, pk):
    serializer = LocationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
    user = request.user
 
    with transaction.atomic():
        job = get_object_or_404(Job.objects.select_for_update(), pk=pk, artisan=user)
        if not job.can_move_to('checked_out') or job.status != 'checked_in':
            return error("You can only check out of a job you have checked in to.")
        Checkout.objects.create(
            job=job, artisan=user,
            checkout_lat=data['lat'], checkout_lng=data['lng'],
            artisan_confirmed=True, artisan_confirmed_at=timezone.now(),
        )
        job.status = 'checked_out'
        job.save()
        notify(job.client, "Artisan has finished",
               f"{user.full_name} says the job is done and has left. Please confirm in the app.", job)
    return Response(job_json(_fresh(request, pk), request))
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_confirm_checkout(request, pk):
    user = request.user
    with transaction.atomic():
        job = get_object_or_404(Job.objects.select_for_update(), pk=pk, client=user)
        if job.status != 'checked_out' or not job.can_move_to('completed'):
            return error("There is nothing to confirm yet. The artisan must check out first.")
        checkout = job.checkout
        checkout.client_confirmed = True
        checkout.client_confirmed_at = timezone.now()
        checkout.save()
        job.status = 'completed'
        job.completed_at = timezone.now()
        job.save()
        notify(job.artisan, "Job completed",
               f"{user.full_name} confirmed that the job is complete. It is now closed.", job)
    return Response(job_json(_fresh(request, pk), request))
 
 
# ---------------------------------------------------------------------------
# SOS
# ---------------------------------------------------------------------------
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_sos(request, pk):
    serializer = LocationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
    user = request.user
 
    job = get_object_or_404(my_jobs(user), pk=pk)
    with transaction.atomic():
        locked = Job.objects.select_for_update().get(pk=job.pk)
        if not locked.can_move_to('sos_triggered'):
            return error("An SOS can only be sent for a job that is in progress and has no active SOS.")
        alert = SOSAlert.objects.create(
            job=locked, triggered_by=user,
            artisan_full_name=locked.artisan.full_name,
            client_full_name=locked.client.full_name,
            job_address_snapshot=f"{locked.job_address_text}, {locked.job_address_lga}",
            live_lat=data['lat'], live_lng=data['lng'],
            emergency_contact_name=user.emergency_contact_name or '',
            emergency_contact_phone=user.emergency_contact_phone or '',
            emergency_contact_email=user.emergency_contact_email or '',
        )
        locked.status = 'sos_triggered'
        locked.save()
        other = locked.client if user.pk == locked.artisan_id else locked.artisan
        notify(other, "SOS alert",
               f"{user.full_name} pressed the SOS button for this job. Their emergency contact has been alerted.", locked)
 
    sent = send_sos_email(alert, user, other)
    alert.emergency_contact_notified = sent
    alert.save(update_fields=['emergency_contact_notified'])
 
    if sent:
        message = f"SOS sent. An email with your location was sent to {alert.emergency_contact_name or 'your emergency contact'}."
    elif not alert.emergency_contact_email:
        message = ("SOS recorded and the other person was told, but you have no emergency contact "
                   "email saved, so nobody was emailed. Add one in your profile and call someone now.")
    else:
        message = "SOS recorded, but the email could not be sent. Call your emergency contact or the police now."
    return Response({'notified': sent, 'message': message, 'job': job_json(_fresh(request, pk), request)},
                    status=status.HTTP_201_CREATED)
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_sos_resolve(request, pk):
    user = request.user
    with transaction.atomic():
        job = get_object_or_404(Job.objects.select_for_update().select_related('client', 'artisan'), pk=pk)
        if user.pk not in (job.client_id, job.artisan_id):
            return error("Not found.", status.HTTP_404_NOT_FOUND)
        alerts = job.sos_alerts.filter(is_resolved=False, triggered_by=user)
        if not alerts.exists():
            return error("You have no active SOS alert on this job.")
        alerts.update(is_resolved=True, resolved_at=timezone.now())
        if job.can_move_to('cancelled'):
            job.status = 'cancelled'
            job.save()
        other = job.client if user.pk == job.artisan_id else job.artisan
        notify(other, "SOS resolved",
               f"{user.full_name} says they are safe. The SOS alert was closed and the job is cancelled.", job)
    return Response(job_json(_fresh(request, pk), request))