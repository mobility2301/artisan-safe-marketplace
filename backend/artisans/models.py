# ===== PASTE THIS INTO:  artisans/models.py   (the ARTISAN PROFILE model) =====
from django.db import models
from django.conf import settings
 
 
def artisan_profile_path(instance, filename):
    return f"users/{instance.user_id}/artisan_profile/{filename}"
 
 
class ArtisanProfile(models.Model):
    CATEGORY = [
        ('basket', 'Basket'),
        ('wood', 'Wood'),
        ('pottery', 'Pottery'),
        ('tailoring', 'Tailoring'),
        ('painting', 'Painting'),
        ('plumbing', 'Plumbing'),
        ('electrical', 'Electrical'),
        ('carpentry', 'Carpentry'),
        ('tiling', 'Tiling'),
        ('welding', 'Welding'),
        ('mechanic', 'Mechanic'),
    ]
    ARTISAN_TYPE = [
        ('onsite', 'On-site (travels to the client)'),
        ('delivery', 'Delivery (works remotely, delivers the product)'),
    ]
 
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='artisan_profile',
    )
 
    # Fields the frontend uses
    business_name = models.CharField(max_length=255, blank=True)
    display_name = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True, default="")
    category = models.CharField(max_length=50, choices=CATEGORY)
    price = models.CharField(max_length=50, default="₦3000")
    profile_image = models.ImageField(upload_to=artisan_profile_path, null=True, blank=True)
 
    # On-site artisans go through check-in/checkout; delivery artisans do not
    artisan_type = models.CharField(max_length=10, choices=ARTISAN_TYPE, default='onsite')
 
    # Location and status
    lga = models.CharField(max_length=50, default='Nsukka')
    town = models.CharField(max_length=100, default='Nsukka')
    is_available = models.BooleanField(default=True)
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    created_at = models.DateTimeField(auto_now_add=True)
 
    # phone and is_verified are NOT stored here. They always come from the
    # user, so they can never go out of date or be edited on the profile.
    @property
    def phone(self):
        return self.user.phone_number
 
    @property
    def is_verified(self):
        return self.user.is_fully_verified
 
    def save(self, *args, **kwargs):
        # Auto-fill names from the user if empty
        if not self.business_name:
            self.business_name = getattr(self.user, 'full_name', str(self.user))
        if not self.display_name:
            self.display_name = self.business_name
        super().save(*args, **kwargs)
 
    def __str__(self):
        return f"{self.display_name} - {self.category}"