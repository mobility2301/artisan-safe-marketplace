
# ===== PASTE THIS INTO:  artisans/admin.py   (replaces your current artisans/admin.py) =====
from django.contrib import admin
 
from .models import ArtisanProfile
 
 
@admin.register(ArtisanProfile)
class ArtisanProfileAdmin(admin.ModelAdmin):
    list_display = ('display_name', 'category', 'artisan_type', 'town',
                    'is_available', 'average_rating', 'verified', 'created_at')
    list_filter = ('category', 'artisan_type', 'is_available', 'lga', 'user__is_fully_verified')
    search_fields = ('business_name', 'display_name', 'user__email', 'user__phone_number')
    list_select_related = ('user',)
    raw_id_fields = ('user',)
    readonly_fields = ('average_rating', 'created_at', 'verified')
 
    @admin.display(boolean=True, description='Verified', ordering='user__is_fully_verified')
    def verified(self, obj):
        # Read from the user's account, so it can never disagree with it
        return obj.user.is_fully_verified