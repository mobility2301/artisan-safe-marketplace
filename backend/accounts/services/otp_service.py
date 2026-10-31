
# DESTINATION: accounts/services/otp_service.py
"""
OTP Service for Artisan Safe Marketplace Nsukka
"""
import hmac
import logging
from datetime import timedelta
 
from django.conf import settings
from django.core.cache import cache
from django.core.mail import send_mail
from django.utils import timezone
 
logger = logging.getLogger(__name__)
 
OTP_EXPIRY_MINUTES = 10
MAX_WRONG_GUESSES = 5      # after this many wrong codes the OTP is cancelled
 
 
def _attempt_key(kind, user):
    return f"otp_attempts:{kind}:{user.pk}"
 
 
def send_email_otp(user):
    otp = user.generate_email_otp()
    cache.delete(_attempt_key('email', user))          # new code = fresh set of guesses
    if getattr(settings, "SHOW_DEV_CODES", settings.DEBUG):
        print(f"[DEV] Email OTP for {user.email}: {otp}")   # never printed in production
 
    subject = "Your Verification Code - Artisan Safe Nsukka"
    message = (f"Hello {user.first_name},\n\nYour code is: {otp}\n"
               f"Expires in {OTP_EXPIRY_MINUTES} mins.\n\n- Artisan Safe Team")
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)
        logger.info("Email OTP sent to user %s", user.pk)
        return True, otp
    except Exception:
        logger.exception("Email OTP failed for user %s", user.pk)
        # In development the code is already on the console, so carry on.
        # In production the user must be told that nothing was sent.
        return (True, otp) if getattr(settings, 'SHOW_DEV_CODES', settings.DEBUG) else (False, None)
 
 
def _verify_otp(user, kind, otp_input, success_message):
    """The model fields follow the pattern <kind>_otp, <kind>_otp_created_at, is_<kind>_verified."""
    otp_field = f"{kind}_otp"
    created_field = f"{kind}_otp_created_at"
    flag_field = f"is_{kind}_verified"
    verified_at_field = f"{kind}_verified_at"
 
    stored = getattr(user, otp_field)
    created = getattr(user, created_field)
    if not stored or not created:
        return False, "No OTP found. Request a new code."
    if timezone.now() > created + timedelta(minutes=OTP_EXPIRY_MINUTES):
        return False, "OTP expired."
 
    if not hmac.compare_digest(str(stored).strip(), str(otp_input).strip()):
        key = _attempt_key(kind, user)
        cache.add(key, 0, timeout=OTP_EXPIRY_MINUTES * 60)
        if cache.incr(key) >= MAX_WRONG_GUESSES:
            # Too many wrong guesses: cancel this code so it cannot be brute-forced
            setattr(user, otp_field, None)
            setattr(user, created_field, None)
            user.save(update_fields=[otp_field, created_field])
            cache.delete(key)
            return False, "Too many wrong attempts. Request a new code."
        return False, "Invalid OTP."
 
    setattr(user, flag_field, True)
    setattr(user, verified_at_field, timezone.now())
    setattr(user, otp_field, None)
    setattr(user, created_field, None)
    user.save(update_fields=[flag_field, verified_at_field, otp_field, created_field])
    cache.delete(_attempt_key(kind, user))
    user.update_verification_level()
    return True, success_message
 
 
def verify_email_otp(user, otp_input):
    return _verify_otp(user, 'email', otp_input, "Email verified!")