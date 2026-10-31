
# DESTINATION: jobs/models.py
from django.conf import settings
from django.db import models
 
 
def checkin_selfie_path(instance, filename):
    return f"users/{instance.artisan_id}/checkins/job_{instance.job_id}/{filename}"
 
 
class Job(models.Model):
    STATUS_CHOICES = [
        ('requested', 'Requested'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('cancelled', 'Cancelled'),
        ('checked_in', 'Checked In'),
        ('checked_out', 'Checked Out'),
        ('completed', 'Completed'),
        ('sos_triggered', 'SOS Triggered'),
    ]
 
    # Which status can follow which. Every status change in the views goes through
    # can_move_to(), so a job can never jump from 'requested' straight to 'completed'.
    TRANSITIONS = {
        'requested': {'accepted', 'rejected', 'cancelled'},
        'accepted': {'checked_in', 'cancelled', 'sos_triggered'},
        'checked_in': {'checked_out', 'sos_triggered'},
        'checked_out': {'completed', 'sos_triggered'},
        'sos_triggered': {'completed', 'cancelled'},   # closed once the alert is resolved
        'completed': set(),
        'rejected': set(),
        'cancelled': set(),
    }
    ACTIVE_STATUSES = ('requested', 'accepted', 'checked_in', 'checked_out', 'sos_triggered')
 
    client = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='client_jobs')
    artisan = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='artisan_jobs')
    job_address_text = models.TextField()
    job_address_lga = models.CharField(max_length=50, default='Nsukka')
    client_lat = models.DecimalField(max_digits=10, decimal_places=8, null=True, blank=True)
    client_lng = models.DecimalField(max_digits=11, decimal_places=8, null=True, blank=True)
    # Where the artisan was when they accepted (kept as safety evidence, not shown in the API)
    artisan_accept_lat = models.DecimalField(max_digits=10, decimal_places=8, null=True, blank=True)
    artisan_accept_lng = models.DecimalField(max_digits=11, decimal_places=8, null=True, blank=True)
    artisan_accept_timestamp = models.DateTimeField(null=True, blank=True)
    description = models.TextField()
    category = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='requested')
    estimated_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    completed_at = models.DateTimeField(null=True, blank=True)
 
    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.CheckConstraint(
                condition=~models.Q(client=models.F('artisan')),
                name='job_client_is_not_artisan',
            ),
        ]
 
    def __str__(self):
        return f"Job #{self.pk} {self.category} ({self.status})"
 
    @property
    def artisan_profile(self):
        # The profile is reached through the artisan, so it can never disagree with
        # job.artisan (the old separate artisan_profile column could).
        return getattr(self.artisan, 'artisan_profile', None)
 
    def can_move_to(self, new_status):
        return new_status in self.TRANSITIONS.get(self.status, set())
 
 
class CheckIn(models.Model):
    """
    One row per check-in ATTEMPT. Failed attempts are kept on purpose: a face
    mismatch at the door is exactly the event this project exists to record.
    The check-in counts only when is_verified is True.
    """
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='checkins')
    artisan = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='checkins')
    checkin_lat = models.DecimalField(max_digits=10, decimal_places=8)
    checkin_lng = models.DecimalField(max_digits=11, decimal_places=8)
    checkin_timestamp = models.DateTimeField(auto_now_add=True)
    selfie_image = models.ImageField(upload_to=checkin_selfie_path, blank=True, null=True)
    face_match_score = models.FloatField(default=0.0)
    liveness_passed = models.BooleanField(default=False)
    distance_from_client_m = models.FloatField(null=True, blank=True)   # metres from the job location
    location_ok = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    failure_reason = models.CharField(max_length=200, blank=True)
 
    class Meta:
        ordering = ['-checkin_timestamp']
 
 
class Checkout(models.Model):
    job = models.OneToOneField(Job, on_delete=models.CASCADE, related_name='checkout')
    artisan = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='checkouts')
    checkout_lat = models.DecimalField(max_digits=10, decimal_places=8)
    checkout_lng = models.DecimalField(max_digits=11, decimal_places=8)
    checkout_timestamp = models.DateTimeField(auto_now_add=True)
    client_confirmed = models.BooleanField(default=False)
    client_confirmed_at = models.DateTimeField(null=True, blank=True)
    artisan_confirmed = models.BooleanField(default=False)
    artisan_confirmed_at = models.DateTimeField(null=True, blank=True)
 
 
class SOSAlert(models.Model):
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='sos_alerts')
    triggered_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='triggered_sos')
    # Names and address are copied at the time of the alert, so the record stays
    # accurate even if the profile is edited later.
    artisan_full_name = models.CharField(max_length=200)
    client_full_name = models.CharField(max_length=200)
    job_address_snapshot = models.TextField()
    live_lat = models.DecimalField(max_digits=10, decimal_places=8)
    live_lng = models.DecimalField(max_digits=11, decimal_places=8)
    triggered_at = models.DateTimeField(auto_now_add=True)
    emergency_contact_name = models.CharField(max_length=100, blank=True)
    emergency_contact_phone = models.CharField(max_length=16, blank=True)
    emergency_contact_email = models.EmailField(blank=True)
    # True only if a message really reached the contact (the SOS email is sent once SOS is built)
    emergency_contact_notified = models.BooleanField(default=False)
    is_resolved = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)
 
    class Meta:
        ordering = ['-triggered_at']
 
 
class Payment(models.Model):
    STATUS_CHOICES = [('pending', 'Pending'), ('successful', 'Successful'), ('failed', 'Failed')]
    job = models.OneToOneField(Job, on_delete=models.CASCADE, related_name='payment')
    client = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payments_made')
    artisan = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payments_received')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_reference = models.CharField(max_length=100, unique=True)
    payment_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    payment_channel = models.CharField(max_length=50, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
 
 
class Review(models.Model):
    job = models.OneToOneField(Job, on_delete=models.CASCADE, related_name='review')
    client = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reviews_given')
    artisan = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reviews_received')
    rating = models.IntegerField(choices=[(1, 1), (2, 2), (3, 3), (4, 4), (5, 5)])
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
 
 
class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    title = models.CharField(max_length=200)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
 
    class Meta:
        ordering = ['-created_at']
