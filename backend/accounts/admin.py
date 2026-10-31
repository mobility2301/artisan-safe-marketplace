
# DESTINATION: accounts/admin.py
from django.conf import settings
from django.contrib import admin, messages
 
from .models import CustomUser
 
 
@admin.register(CustomUser)
class CustomUserAdmin(admin.ModelAdmin):
    """
    Users are created through the app's registration screen (which hashes the
    password), so adding users here is switched off. Verification results are
    read-only, because they must come from the OTP, NIN and DeepFace checks.
    """
    list_display = ('email', 'full_name', 'phone_number', 'user_type',
                    'verification_level', 'is_fully_verified', 'is_active', 'date_joined')
    list_filter = ('user_type', 'verification_level', 'is_fully_verified',
                   'is_nin_verified', 'is_active')
    search_fields = ('email', 'first_name', 'last_name', 'phone_number')
    ordering = ('-date_joined',)
    list_per_page = 25
 
    # never shown: password hash, one-time codes, the NIN hash, permission pickers
    exclude = ('password', 'email_otp', 'nin_hash', 'groups', 'user_permissions')
    readonly_fields = (
        'last_login', 'date_joined',
        'is_email_verified', 'email_otp_created_at', 'email_verified_at',
        'is_nin_verified', 'nin_last4', 'nin_check_method', 'nin_verified_at',
        'is_photo_verified', 'photo_match_score', 'photo_verified_at', 'photo_verification_data',
        'is_live_verified', 'live_match_score', 'live_verified_at', 'last_liveness_check', 'liveness_data',
        'verification_level', 'trust_score', 'is_fully_verified',
    )
    actions = ['demo_mark_fully_verified']
 
    def has_add_permission(self, request):
        return False
 
    def get_actions(self, request):
        actions = super().get_actions(request)
        if not settings.DEBUG:                       # the demo shortcut never exists in production
            actions.pop('demo_mark_fully_verified', None)
        return actions
 
    @admin.action(description="DEMO ONLY: mark selected users as fully verified")
    def demo_mark_fully_verified(self, request, queryset):
        if not settings.DEBUG:
            self.message_user(request, "Only available while DEBUG is on.", messages.ERROR)
            return
        for user in queryset:
            user.is_email_verified = True
            user.is_nin_verified = user.is_photo_verified = user.is_live_verified = True
            if not user.nin_check_method:
                user.nin_check_method = 'admin_demo'
            user.save()
            user.update_verification_level()
        self.message_user(request, f"{queryset.count()} user(s) marked verified (demo).", messages.WARNING)