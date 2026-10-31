
# DESTINATION: jobs/utils.py
import logging
import math
 
from django.conf import settings
from django.core.mail import send_mail
 
from .models import Notification
 
logger = logging.getLogger(__name__)
 
 
def notify(user, title, body, job=None):
    """
    Save an in-app notification for a user (the app reads them from
    GET /api/jobs/notifications/). Every message to clients and artisans goes
    through here; email is used only for the registration code and the SOS alert.
    """
    return Notification.objects.create(user=user, job=job, title=title, body=body)
 
 
def distance_m(lat1, lng1, lat2, lng2):
    """Straight-line distance in metres between two GPS points (haversine formula)."""
    r = 6371000.0
    p1, p2 = math.radians(float(lat1)), math.radians(float(lat2))
    dp = p2 - p1
    dl = math.radians(float(lng2) - float(lng1))
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))
 
 
def send_sos_email(alert, triggered_by, other):
    """
    Email the emergency contact. Returns True only if the mail system accepted it.
    The message carries both identities, the job address and the live location,
    which is exactly what someone needs to find and help the person.
    """
    if not alert.emergency_contact_email:
        return False
    role = 'artisan' if triggered_by.pk == alert.job.artisan_id else 'client'
    maps = f"https://www.google.com/maps?q={alert.live_lat},{alert.live_lng}"
    when = alert.triggered_at.strftime('%d %b %Y, %H:%M UTC')
    body = (
        f"Hello {alert.emergency_contact_name or 'there'},\n\n"
        f"{triggered_by.full_name} pressed the SOS emergency button in the Artisan Safe app "
        f"and may need urgent help. Please call them right away"
        f"{' on ' + triggered_by.phone_number if triggered_by.phone_number else ''}.\n\n"
        f"Time: {when}\n"
        f"Who pressed it: {triggered_by.full_name} (the {role})\n"
        f"Artisan: {alert.artisan_full_name}\n"
        f"Client: {alert.client_full_name}\n"
        f"Other person's phone: {other.phone_number or 'not available'}\n"
        f"Job address: {alert.job_address_snapshot}\n"
        f"Live location: {maps}\n\n"
        f"If you cannot reach them, contact the police or other emergency services.\n\n"
        f"- Artisan Safe Team"
    )
    try:
        send_mail(f"EMERGENCY: {triggered_by.full_name} pressed SOS", body,
                  settings.DEFAULT_FROM_EMAIL, [alert.emergency_contact_email], fail_silently=False)
        return True
    except Exception:
        logger.exception("SOS email failed for alert %s", alert.pk)
        return False