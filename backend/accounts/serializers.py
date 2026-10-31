
# DESTINATION: accounts/serializers.py
import re
 
from django.contrib.auth.password_validation import validate_password as run_password_validators
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
 
from django.db import transaction
 
from artisans.models import ArtisanProfile
from django.db import transaction
 
from artisans.models import ArtisanProfile
from .models import CustomUser
 
MAX_IMAGE_MB = 5
 
 
class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Login with email + password. The email is lowercased and trimmed first,
    because phone keyboards often capitalize the first letter."""
    def validate(self, attrs):
        attrs[self.username_field] = str(attrs.get(self.username_field, '')).strip().lower()
        return super().validate(attrs)
 
 
def normalize_phone(raw):
    """
    Store every phone number in one format so the same person cannot register
    twice as 08012345678 and +2348012345678.
    """
    cleaned = re.sub(r'[\s\-()]', '', str(raw))
    if cleaned.startswith('+'):
        return cleaned
    if cleaned.startswith('234'):
        return '+' + cleaned
    if cleaned.startswith('0') and len(cleaned) == 11:
        return '+234' + cleaned[1:]
    return cleaned
 
 
class UserSerializer(serializers.ModelSerializer):
    """Output only. Nothing here can be written through the API."""
    class Meta:
        model = CustomUser
        fields = [
            'id', 'email', 'first_name', 'last_name', 'phone_number', 'user_type',
            'verification_level', 'trust_score', 'is_fully_verified',
            'is_email_verified', 'is_nin_verified', 'nin_last4', 'nin_check_method',
            'is_photo_verified', 'is_live_verified',
            'photo_match_score', 'live_match_score',
            'profile_photo', 'id_photo', 'live_photo',
            'emergency_contact_name', 'emergency_contact_phone', 'emergency_contact_email',
        ]
        read_only_fields = fields
 
 
class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6, style={'input_type': 'password'})
 
    # Only used when user_type is 'artisan'. They are not stored on the user:
    # they create the artisan's profile in the same step as the account.
    category = serializers.ChoiceField(choices=ArtisanProfile.CATEGORY, required=False, write_only=True)
    artisan_type = serializers.ChoiceField(choices=ArtisanProfile.ARTISAN_TYPE, required=False, write_only=True)
    town = serializers.CharField(max_length=100, required=False, write_only=True)
 
    class Meta:
        model = CustomUser
        fields = ['email', 'password', 'first_name', 'last_name', 'phone_number', 'user_type',
                  'category', 'artisan_type', 'town',
                  'emergency_contact_name', 'emergency_contact_phone', 'emergency_contact_email']
 
    def to_internal_value(self, data):
        # Clean email and phone BEFORE the uniqueness checks run
        data = data.copy()
        if 'email' in data:
            data['email'] = str(data['email']).strip().lower()
        if 'phone_number' in data:
            data['phone_number'] = normalize_phone(data['phone_number'])
        if data.get('emergency_contact_phone'):
            data['emergency_contact_phone'] = normalize_phone(data['emergency_contact_phone'])
        if data.get('emergency_contact_email'):
            data['emergency_contact_email'] = str(data['emergency_contact_email']).strip().lower()
        return super().to_internal_value(data)
 
    def validate_password(self, value):
        # Uses the rules in AUTH_PASSWORD_VALIDATORS (settings.py)
        run_password_validators(value)
        return value
 
    def validate(self, attrs):
        # An artisan must say what they do, otherwise they could never be found
        if attrs.get('user_type', 'artisan') == 'artisan' and not attrs.get('category'):
            raise serializers.ValidationError({'category': 'Artisans must choose a category.'})
        return attrs
 
    def create(self, validated_data):
        password = validated_data.pop('password')
        category = validated_data.pop('category', None)
        artisan_type = validated_data.pop('artisan_type', None)
        town = validated_data.pop('town', None)
 
        # One transaction: either the account AND the profile exist, or neither does
        with transaction.atomic():
            user = CustomUser.objects.create_user(password=password, **validated_data)
            if user.user_type == 'artisan':
                extra = {}
                if artisan_type:
                    extra['artisan_type'] = artisan_type
                if town:
                    extra['town'] = town.strip()
                ArtisanProfile.objects.create(user=user, category=category, **extra)
        return user
 
 
class OTPVerifySerializer(serializers.Serializer):
    otp = serializers.CharField(max_length=6)
 
 
class NINSubmitSerializer(serializers.Serializer):
    # max_length leaves room for spaces/dashes people type; the service cleans them
    nin = serializers.CharField(max_length=20, trim_whitespace=True)
 
 
class PhotoUploadSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ['profile_photo', 'id_photo', 'live_photo', 'id_type']
 
    @staticmethod
    def _check_size(image):
        if image and image.size > MAX_IMAGE_MB * 1024 * 1024:
            raise serializers.ValidationError(f"Image must be {MAX_IMAGE_MB}MB or smaller.")
        return image
 
    def validate_profile_photo(self, value):
        return self._check_size(value)
 
    def validate_id_photo(self, value):
        return self._check_size(value)
 
    def validate_live_photo(self, value):
        return self._check_size(value)
 
 
class VerificationStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            'verification_level', 'trust_score', 'is_fully_verified',
            'is_email_verified', 'is_nin_verified',
            'nin_last4', 'nin_check_method',
            'is_photo_verified', 'is_live_verified',
            'photo_match_score', 'live_match_score',
            'email_verified_at', 'nin_verified_at',
            'photo_verified_at', 'live_verified_at'
        ]
        read_only_fields = fields
 
 
class EmergencyContactSerializer(serializers.Serializer):
    """Who receives the SOS email. All three are saved together."""
    emergency_contact_name = serializers.CharField(max_length=100)
    emergency_contact_phone = serializers.CharField(max_length=16, required=False, allow_blank=True)
    emergency_contact_email = serializers.EmailField()
 
    def validate_emergency_contact_email(self, value):
        return value.strip().lower()
 
    def validate_emergency_contact_phone(self, value):
        return normalize_phone(value) if value else ''
 