
# DESTINATION: jobs/reviews.py
"""
POST /api/jobs/<id>/review/   client only, after the job is completed.
 
Body: {"rating": 1-5, "comment": "optional text"}
One review per job. The artisan's average_rating is recalculated from all of
their reviews, so it can never drift from the real data.
"""
from django.db import transaction
from django.db.models import Avg
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
 
from .models import Job, Review
from .utils import notify
from .views import error, job_json
 
 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def job_review(request, pk):
    try:
        rating = int(request.data.get('rating'))
    except (TypeError, ValueError):
        return error("Choose a rating from 1 to 5.")
    if rating < 1 or rating > 5:
        return error("Choose a rating from 1 to 5.")
    comment = str(request.data.get('comment') or '').strip()[:500]
 
    with transaction.atomic():
        job = get_object_or_404(Job.objects.select_for_update(), pk=pk, client=request.user)
        if job.status != 'completed':
            return error("You can review a job only after it is completed.")
        if Review.objects.filter(job=job).exists():
            return error("You have already reviewed this job.")
        Review.objects.create(job=job, client=request.user, artisan=job.artisan,
                              rating=rating, comment=comment)
        profile = job.artisan_profile
        if profile is not None:
            avg = Review.objects.filter(artisan=job.artisan).aggregate(a=Avg('rating'))['a'] or 0
            profile.average_rating = round(avg, 2)
            profile.save(update_fields=['average_rating'])
        notify(job.artisan, "New review",
               f"{request.user.full_name} rated your job {rating} out of 5.", job)
 
    job = Job.objects.get(pk=pk)
    return Response(job_json(job, request))