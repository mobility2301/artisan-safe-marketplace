
# DESTINATION: artisans/serializers.py
from rest_framework import serializers
from .models import ArtisanProfile
 
 
def verified_photo_url(user, request):
    """
    The face photo the person registered with. It is shown only for fully verified
    users, because that photo was matched to their ID and their live selfie.
    The ID document itself is never exposed.
    """
    if user is None or not user.is_fully_verified or not user.profile_photo:
        return None
    url = user.profile_photo.url
    return request.build_absolute_uri(url) if request is not None else url
 
 
class ArtisanProfileSerializer(serializers.ModelSerializer):
    """
    Full profile (detail view and the artisan editing their own profile).
    is_verified, average_rating, created_at and phone can never be written
    through this serializer.
    """
    is_verified = serializers.BooleanField(read_only=True)
    phone = serializers.CharField(read_only=True)
    photo = serializers.SerializerMethodField()
 
    def get_photo(self, obj):
        return verified_photo_url(obj.user, self.context.get('request'))
 
    class Meta:
        model = ArtisanProfile
        fields = [
            'id',
            'business_name',
            'display_name',
            'description',
            'category',
            'artisan_type',
            'price',
            'phone',
            'is_verified',
            'profile_image',
            'lga',
            'town',
            'is_available',
            'average_rating',
            'created_at',
            'photo',
        ]
        read_only_fields = ['id', 'average_rating', 'created_at']
 
    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Only the artisan themselves sees their phone number here.
        # Clients get it only after a job is accepted (handled in the jobs app),
        # so that bookings stay inside the platform's check-in and SOS flow.
        request = self.context.get('request')
        is_owner = (
            request is not None
            and request.user.is_authenticated
            and request.user.pk == instance.user_id
        )
        if not is_owner:
            data.pop('phone', None)
        return data
 
 
class ArtisanListSerializer(serializers.ModelSerializer):
    """Lightweight card shown in search results. Never includes phone."""
    is_verified = serializers.BooleanField(read_only=True)
    photo = serializers.SerializerMethodField()
 
    def get_photo(self, obj):
        return verified_photo_url(obj.user, self.context.get('request'))
 
    class Meta:
        model = ArtisanProfile
        fields = [
            'id',
            'business_name',
            'display_name',
            'description',
            'category',
            'artisan_type',
            'price',
            'is_available',
            'average_rating',
            'profile_image',
            'is_verified',
            'photo',
        ]
        read_only_fields = fields