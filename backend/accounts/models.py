
# DESTINATION: accounts/models.py
import uuid
import secrets
 
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.utils import timezone
from django.core.validators import RegexValidator
 
 
def user_profile_path(instance, filename):
    return f"users/{instance.id}/profile/{filename}"
 
 
def user_id_path(instance, filename):
    return f"users/{instance.id}/id/{filename}"
 
 
def user_live_path(instance, filename):
    return f"users/{instance.id}/live/{filename}"
 
 
class CustomUserManager(BaseUserManager):
    def create_user(self, email, phone_number, first_name, last_name, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        if not phone_number:
            raise ValueError("Phone number is required")
        email = self.normalize_email(email)
 
        user = self.model(
            email=email,
            phone_number=phone_number,
            first_name=first_name,
            last_name=last_name,
            **extra_fields,
        )
        user.set_password(password)
        user.save(using=self._db)
        return user
 
    def create_superuser(self, email, phone_number, first_name, last_name, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        extra_fields.setdefault('is_email_verified', True)
        return self.create_user(email, phone_number, first_name, last_name, password, **extra_fields)
 
 
class CustomUser(AbstractBaseUser, PermissionsMixin):
    ID_TYPE_CHOICES = [
        ('voters_card', 'Voters Card'),
        ('drivers_license', 'Drivers License'),
        ('national_id', 'National ID Card'),
        ('passport', 'International Passport'),
    ]
    USER_TYPE_CHOICES = [
        ('artisan', 'Artisan'),
        ('client', 'Client'),
    ]
    VERIFICATION_LEVELS = [
        (0, 'Unverified'),
        (1, 'Email Verified'),
        (2, 'NIN Submitted'),
        (3, 'Photo Verified (Photo vs ID)'),
        (4, 'Live Verified - Fully Trusted'),
    ]
 
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    phone_number = models.CharField(
        max_length=16,
        unique=True,
        validators=[RegexValidator(r'^\+?\d{9,15}$', 'Enter a valid phone number.')],
    )
    user_type = models.CharField(max_length=10, choices=USER_TYPE_CHOICES, default='artisan')
 
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)
 
    # --- EMERGENCY CONTACT (for SOS - customer & artisan) ---
    emergency_contact_name = models.CharField(max_length=100, blank=True, null=True)
    emergency_contact_phone = models.CharField(max_length=16, blank=True, null=True)
    emergency_contact_email = models.EmailField(blank=True, null=True)   # the SOS alert is emailed here
 
    # --- 1. EMAIL VERIFICATION ---
    is_email_verified = models.BooleanField(default=False)
    email_otp = models.CharField(max_length=6, blank=True, null=True)
    email_otp_created_at = models.DateTimeField(blank=True, null=True)
    email_verified_at = models.DateTimeField(blank=True, null=True)
 
    # --- 3. NIN ---
    # The full NIN is never stored. nin_hash (a keyed hash) stops one NIN being used on
    # two accounts, and nin_last4 is only for showing "NIN ending 1234" in the app.
    # nin_check_method records HOW the NIN was checked, so the limitation is written
    # into the data itself: 'format_only' today (11 digits, not already used);
    # it becomes 'nimc_api' once a real NIN provider is connected.
    nin_hash = models.CharField(max_length=64, unique=True, blank=True, null=True)
    nin_last4 = models.CharField(max_length=4, blank=True)
    is_nin_verified = models.BooleanField(default=False)
    nin_check_method = models.CharField(max_length=20, blank=True)
    nin_verified_at = models.DateTimeField(blank=True, null=True)
 
    # --- 4. PHOTO VERIFICATION (AI Auto with DeepFace) ---
    profile_photo = models.ImageField(upload_to=user_profile_path, blank=True, null=True)
    id_photo = models.ImageField(upload_to=user_id_path, blank=True, null=True)
    id_type = models.CharField(max_length=20, choices=ID_TYPE_CHOICES, blank=True, null=True)
 
    is_photo_verified = models.BooleanField(default=False)
    photo_match_score = models.FloatField(default=0.0)
    photo_verified_at = models.DateTimeField(blank=True, null=True)
    photo_verification_data = models.JSONField(default=dict, blank=True)
 
    # --- 5. LIVENESS CHECK (AI Auto with DeepFace) ---
    live_photo = models.ImageField(upload_to=user_live_path, blank=True, null=True)
    is_live_verified = models.BooleanField(default=False)
    live_match_score = models.FloatField(default=0.0)
    live_verified_at = models.DateTimeField(blank=True, null=True)
    last_liveness_check = models.DateTimeField(blank=True, null=True)
    liveness_data = models.JSONField(default=dict, blank=True)
 
    # --- FINAL SCORE ---
    verification_level = models.IntegerField(choices=VERIFICATION_LEVELS, default=0)
    trust_score = models.IntegerField(default=0)
    is_fully_verified = models.BooleanField(default=False)
 
    # Artisan extra
    skill = models.CharField(max_length=100, blank=True, null=True)
    workshop_address = models.TextField(blank=True, null=True)
    bio = models.TextField(blank=True, null=True)
 
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name', 'phone_number']
 
    objects = CustomUserManager()
 
    def __str__(self):
        return f"{self.first_name} {self.last_name} - {self.email}"
 
    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"
 
    def generate_email_otp(self):
        otp = f"{secrets.randbelow(1_000_000):06d}"
        self.email_otp = otp
        self.email_otp_created_at = timezone.now()
        self.save(update_fields=['email_otp', 'email_otp_created_at'])
        return otp
 
    def update_verification_level(self):
        """
        Level goes up one step at a time (email -> NIN -> photo -> live),
        and stops at the first step that has not been passed.
        trust_score is 25 points for every step passed (four steps, 100 in total).
        """
        steps = [
            self.is_email_verified,
            self.is_nin_verified,
            self.is_photo_verified,
            self.is_live_verified,
        ]
        level = 0
        for passed in steps:
            if not passed:
                break
            level += 1
 
        self.verification_level = level
        self.trust_score = sum(steps) * 25
        self.is_fully_verified = level == len(steps)
        self.save(update_fields=['verification_level', 'trust_score', 'is_fully_verified'])
        return level
 
    def get_badge(self):
        badges = {
            4: "Fully Trusted - Live Verified",
            3: "Photo Verified",
            2: "NIN Submitted",
            1: "Email Verified",
            0: "Unverified",
        }
        return badges[self.verification_level]
 
 
# Alias for backward compatibility - so both work
User = CustomUser