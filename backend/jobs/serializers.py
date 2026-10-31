
# DESTINATION: jobs/serializers.py
from decimal import Decimal, InvalidOperation
 
from rest_framework import serializers
 
from artisans.models import ArtisanProfile
from .models import CheckIn, Job, Notification, SOSAlert
 
# Statuses in which the artisan may see the client's address and phone number.
# Before the artisan accepts (and after a rejection or cancellation) they only
# see the area and the job description.
REVEAL_STATUSES = {'accepted', 'checked_in', 'checked_out', 'completed', 'sos_triggered'}
PRIVATE_UNTIL_ACCEPTED = ('job_address_text', 'client_lat', 'client_lng')
 
 
class CoordinateField(serializers.DecimalField):
    """
    Latitude / longitude. Phone GPS gives 12-15 decimal places, which a plain
    DecimalField would reject, so the value is rounded to 8 places instead.
    Sent back to the app as a number (not a string).
    """
    def __init__(self, kind, **kwargs):
        limit = 90 if kind == 'lat' else 180
        kwargs.setdefault('coerce_to_string', False)
        super().__init__(
            max_digits=10 if kind == 'lat' else 11,
            decimal_places=8,
            min_value=Decimal(-limit),
            max_value=Decimal(limit),
            **kwargs,
        )
 
    def to_internal_value(self, data):
        try:
            data = Decimal(str(data).strip()).quantize(Decimal('0.00000001'))
        except (InvalidOperation, ValueError):
            self.fail('invalid')
        return super().to_internal_value(data)
 
 
def _both_or_neither(attrs, lat_key, lng_key):
    if (attrs.get(lat_key) is None) != (attrs.get(lng_key) is None):
        raise serializers.ValidationError("Send both latitude and longitude, or neither.")
 
 
class JobCreateSerializer(serializers.Serializer):
    artisan_profile = serializers.PrimaryKeyRelatedField(queryset=ArtisanProfile.objects.select_related('user'))
    job_address_text = serializers.CharField(max_length=500)
    job_address_lga = serializers.CharField(max_length=50, required=False, default='Nsukka')
    client_lat = CoordinateField('lat', required=False, allow_null=True)
    client_lng = CoordinateField('lng', required=False, allow_null=True)
    description = serializers.CharField(max_length=2000)
    category = serializers.ChoiceField(choices=ArtisanProfile.CATEGORY, required=False)
 
    def validate(self, attrs):
        _both_or_neither(attrs, 'client_lat', 'client_lng')
        return attrs
 
 
class LocationSerializer(serializers.Serializer):
    """GPS position sent with checkout and SOS."""
    lat = CoordinateField('lat')
    lng = CoordinateField('lng')
 
 
MAX_SELFIE_BYTES = 5 * 1024 * 1024
 
 
class CheckInSerializer(serializers.Serializer):
    selfie = serializers.ImageField()
    lat = CoordinateField('lat')
    lng = CoordinateField('lng')
 
    def validate_selfie(self, value):
        if value.size > MAX_SELFIE_BYTES:
            raise serializers.ValidationError("The selfie must be 5 MB or smaller.")
        return value
 
 
class AcceptJobSerializer(serializers.Serializer):
    lat = CoordinateField('lat')
    lng = CoordinateField('lng')
    estimated_amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=0, required=False)
 
 
class ReasonSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=300, required=False, allow_blank=True)
 
 
class JobSerializer(serializers.ModelSerializer):
    my_role = serializers.SerializerMethodField()
    client_name = serializers.CharField(source='client.full_name', read_only=True)
    artisan_name = serializers.CharField(source='artisan.full_name', read_only=True)
    artisan_profile_id = serializers.SerializerMethodField()
    artisan_display_name = serializers.SerializerMethodField()
    client_lat = CoordinateField('lat', read_only=True)
    client_lng = CoordinateField('lng', read_only=True)
    estimated_amount = serializers.DecimalField(max_digits=10, decimal_places=2, coerce_to_string=False, read_only=True)
    other_party_phone = serializers.SerializerMethodField()
    allowed_actions = serializers.SerializerMethodField()
    last_checkin = serializers.SerializerMethodField()
    failed_checkins = serializers.SerializerMethodField()
    checkout = serializers.SerializerMethodField()
    sos_open = serializers.SerializerMethodField()
    review = serializers.SerializerMethodField()
    other_party_photo = serializers.SerializerMethodField()
 
    class Meta:
        model = Job
        fields = [
            'id', 'my_role', 'status', 'allowed_actions',
            'client', 'client_name', 'artisan', 'artisan_name',
            'artisan_profile_id', 'artisan_display_name',
            'category', 'description',
            'job_address_text', 'job_address_lga', 'client_lat', 'client_lng',
            'estimated_amount', 'other_party_phone',
            'artisan_accept_timestamp', 'created_at', 'updated_at', 'completed_at',
            'last_checkin', 'failed_checkins', 'checkout', 'sos_open', 'review', 'other_party_photo',
        ]
        read_only_fields = fields
 
    def _role(self, job):
        request = self.context.get('request')
        if request is not None and request.user.pk == job.artisan_id:
            return 'artisan'
        return 'client'
 
    def get_my_role(self, job):
        return self._role(job)
 
    def get_artisan_profile_id(self, job):
        profile = job.artisan_profile
        return profile.pk if profile else None
 
    def get_artisan_display_name(self, job):
        profile = job.artisan_profile
        return profile.display_name if profile else job.artisan.full_name
 
    def get_other_party_phone(self, job):
        # Phone numbers are shared only once the artisan has accepted, so that
        # bookings stay inside the platform's check-in and SOS protection.
        if job.status not in REVEAL_STATUSES:
            return None
        other = job.client if self._role(job) == 'artisan' else job.artisan
        return other.phone_number
 
    def _open_sos(self, job):
        return job.sos_alerts.filter(is_resolved=False).select_related('triggered_by').first()
 
    def get_allowed_actions(self, job):
        role = self._role(job)
        st = job.status
        actions = []
        if role == 'artisan':
            if st == 'requested':
                actions += ['accept', 'reject']
            if st == 'accepted':
                actions.append('checkin')
            if st == 'checked_in':
                actions.append('checkout')
        else:
            if st == 'checked_out':
                actions.append('confirm_checkout')
            if st == 'completed' and not hasattr(job, 'review'):
                actions.append('review')
        if st in ('requested', 'accepted'):
            actions.append('cancel')
        if st in ('accepted', 'checked_in', 'checked_out'):
            actions.append('sos')
        if st == 'sos_triggered':
            alert = self._open_sos(job)
            request = self.context.get('request')
            if alert and request is not None and alert.triggered_by_id == request.user.pk:
                actions.append('resolve_sos')
        return actions
 
    def get_last_checkin(self, job):
        c = job.checkins.first()      # newest attempt (model ordering is newest first)
        if not c:
            return None
        return {
            'is_verified': c.is_verified,
            'match_score': round(c.face_match_score, 1),
            'distance_m': None if c.distance_from_client_m is None else round(c.distance_from_client_m),
            'reason': c.failure_reason,
            'time': c.checkin_timestamp,
        }
 
    def get_failed_checkins(self, job):
        return job.checkins.filter(is_verified=False).count()
 
    def get_checkout(self, job):
        c = getattr(job, 'checkout', None)
        if not c:
            return None
        return {
            'time': c.checkout_timestamp,
            'artisan_confirmed': c.artisan_confirmed,
            'client_confirmed': c.client_confirmed,
        }
 
    def get_other_party_photo(self, job):
        # The verified face photo of the person you are about to meet. A client sees the
        # artisan's photo at once; an artisan sees the client's photo only after accepting.
        from artisans.serializers import verified_photo_url
        request = self.context.get('request')
        if self._role(job) == 'client':
            return verified_photo_url(job.artisan, request)
        if job.status not in REVEAL_STATUSES:
            return None
        return verified_photo_url(job.client, request)
 
    def get_review(self, job):
        r = getattr(job, 'review', None)
        if not r:
            return None
        return {'rating': r.rating, 'comment': r.comment, 'time': r.created_at}
 
    def get_sos_open(self, job):
        return self._open_sos(job) is not None
 
    def to_representation(self, job):
        data = super().to_representation(job)
        if self._role(job) == 'artisan' and job.status not in REVEAL_STATUSES:
            for field in PRIVATE_UNTIL_ACCEPTED:
                data.pop(field, None)
        return data
 
 
class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'job', 'title', 'body', 'is_read', 'created_at']
        read_only_fields = fields