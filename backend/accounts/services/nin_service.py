# ===== PASTE THIS INTO:  accounts/services/nin_service.py   (NEW file - create it) =====
"""
NIN Service - checks a National Identification Number (NIN).
 
HONEST STATUS OF THIS MODULE
----------------------------
A live NIN lookup (against the NIMC database) is only available through licensed
verification providers, and those need a registered business. Until the project
has one, this module runs in 'format_only' mode:
 
    * the NIN must look like a Nigerian NIN (exactly 11 digits, not an obvious fake
      such as 11111111111 or 12345678901), and
    * the same NIN cannot be used on two accounts.
 
It does NOT confirm that the NIN exists or belongs to the person. Every
verified user is marked with nin_check_method = 'format_only' so this limitation
is visible in the data, and the report/demo must say so.
 
To go live later, set NIN_PROVIDER in settings.py and fill in lookup_with_provider()
below; nothing else in the project has to change.
 
PRIVACY: the full NIN is never saved. Only a keyed hash (to block reuse) and the
last 4 digits (to show "NIN ending 1234") are stored.
"""
import hashlib
import hmac
import logging
import re
 
from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
 
from accounts.models import CustomUser
 
logger = logging.getLogger(__name__)
 
NIN_PATTERN = re.compile(r'^\d{11}$')
 
 
def clean_nin(raw):
    """Remove spaces and dashes people type, e.g. '123 4567 8901'."""
    return re.sub(r'[\s\-]', '', str(raw or ''))
 
 
def looks_like_nin(nin):
    """Returns (ok, message). Format checks only - there is no public check digit for NINs."""
    if not NIN_PATTERN.match(nin):
        return False, "A NIN has exactly 11 digits."
    if len(set(nin)) == 1:
        return False, "That does not look like a real NIN."
    if nin in "01234567890123456789" or nin in "98765432109876543210":
        return False, "That does not look like a real NIN."
    return True, None
 
 
def hash_nin(nin):
    """Keyed hash (HMAC-SHA256). Without the key, the 11-digit NINs cannot be guessed back from it."""
    key = getattr(settings, 'NIN_HASH_KEY', settings.SECRET_KEY)
    return hmac.new(key.encode(), nin.encode(), hashlib.sha256).hexdigest()
 
 
def lookup_with_provider(nin, user):
    """
    PLACEHOLDER for a real NIN provider (for example Dojah, Smile ID, Prembly).
    When one is connected, call it here and return (ok, message). The provider's
    sandbox can be used first, and the live keys swapped in later.
    """
    raise NotImplementedError("No live NIN provider is connected yet.")
 
 
def submit_nin(user, raw_nin):
    """
    Check a NIN for this user and, if it passes, mark them NIN-verified.
    Returns (ok, message). Never raises.
    """
    if user.is_nin_verified:
        return False, "A NIN has already been submitted for this account."
 
    nin = clean_nin(raw_nin)
    ok, why = looks_like_nin(nin)
    if not ok:
        return False, why
 
    method = getattr(settings, 'NIN_PROVIDER', 'format_only')
    if method != 'format_only':
        try:
            ok, why = lookup_with_provider(nin, user)
        except Exception:
            logger.exception("NIN provider check failed")
            # Fails closed: if a real check was requested but cannot run, nobody passes
            return False, "NIN verification is unavailable right now. Please try again later."
        if not ok:
            return False, why or "NIN could not be verified."
 
    try:
        with transaction.atomic():
            user.nin_hash = hash_nin(nin)
            user.nin_last4 = nin[-4:]
            user.is_nin_verified = True
            user.nin_check_method = method
            user.nin_verified_at = timezone.now()
            user.save(update_fields=['nin_hash', 'nin_last4', 'is_nin_verified',
                                     'nin_check_method', 'nin_verified_at'])
    except IntegrityError:
        # nin_hash is unique: this NIN is already attached to another account
        user.refresh_from_db()
        return False, "This NIN is already registered to another account."
 
    user.update_verification_level()
    return True, "NIN accepted."