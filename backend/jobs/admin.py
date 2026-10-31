
# ===== PASTE THIS INTO:  jobs/admin.py   (replaces your current jobs/admin.py) =====
from django.contrib import admin
 
from .models import CheckIn, Checkout, Job, Notification, Payment, Review, SOSAlert
 
 
@admin.register(Job)
class JobAdmin(admin.ModelAdmin):
    list_display = ('id', 'category', 'client', 'artisan', 'status', 'estimated_amount', 'created_at')
    list_filter = ('status', 'category', 'job_address_lga')
    search_fields = ('client__email', 'artisan__email', 'description', 'job_address_text')
    raw_id_fields = ('client', 'artisan')
    readonly_fields = ('created_at', 'updated_at', 'completed_at', 'artisan_accept_timestamp')
    list_select_related = ('client', 'artisan')
 
 
class EvidenceAdmin(admin.ModelAdmin):
    """Safety records are evidence, so they can be read but not edited or added by hand."""
    def has_add_permission(self, request):
        return False
 
    def has_change_permission(self, request, obj=None):
        return False
 
 
@admin.register(CheckIn)
class CheckInAdmin(EvidenceAdmin):
    list_display = ('id', 'job', 'artisan', 'is_verified', 'liveness_passed',
                    'face_match_score', 'location_ok', 'checkin_timestamp')
    list_filter = ('is_verified', 'liveness_passed', 'location_ok')
    raw_id_fields = ('job', 'artisan')
 
 
@admin.register(SOSAlert)
class SOSAlertAdmin(admin.ModelAdmin):
    """SOS alerts can be marked resolved, nothing else."""
    list_display = ('id', 'job', 'triggered_by', 'triggered_at', 'emergency_contact_notified', 'is_resolved')
    list_filter = ('is_resolved', 'emergency_contact_notified')
    raw_id_fields = ('job', 'triggered_by')
    readonly_fields = [f.name for f in SOSAlert._meta.fields if f.name not in ('is_resolved', 'resolved_at')]
 
    def has_add_permission(self, request):
        return False
 
 
@admin.register(Checkout)
class CheckoutAdmin(EvidenceAdmin):
    list_display = ('id', 'job', 'artisan', 'client_confirmed', 'artisan_confirmed', 'checkout_timestamp')
    raw_id_fields = ('job', 'artisan')
 
 
@admin.register(Payment)
class PaymentAdmin(EvidenceAdmin):
    list_display = ('payment_reference', 'job', 'amount', 'payment_status', 'paid_at')
    list_filter = ('payment_status',)
    search_fields = ('payment_reference',)
    raw_id_fields = ('job', 'client', 'artisan')
 
 
@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('id', 'job', 'artisan', 'rating', 'created_at')
    list_filter = ('rating',)
    raw_id_fields = ('job', 'client', 'artisan')
 
 
@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'title', 'is_read', 'created_at')
    list_filter = ('is_read',)
    raw_id_fields = ('user', 'job')