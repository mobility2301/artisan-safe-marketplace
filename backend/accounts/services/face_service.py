# DESTINATION: accounts/services/face_service.py
"""
Face Service - AI Auto Verification (DeepFace)
 
Level 4: profile photo  vs  ID photo
Level 5: live selfie    vs  ID photo   (plus an anti-spoofing check on the live selfie)
 
Safe import - the server starts even if DeepFace is not installed.
 
All tuning values can be changed in settings.py (see the FACE_* block there):
FACE_MODEL, FACE_DETECTOR, FACE_THRESHOLD_PHOTO, FACE_THRESHOLD_LIVE, FACE_ANTISPOOF.
The threshold is the largest "distance" still accepted as the same person.
Smaller = stricter. 0.30 is DeepFace's published value for Facenet512 with cosine
distance; tune it with real ID photos from your test users.
"""
import logging
import os
 
from django.conf import settings
from django.utils import timezone
 
logger = logging.getLogger(__name__)
 
# Safe import
try:
    from deepface import DeepFace
    DEEPFACE_AVAILABLE = True
except ImportError:
    DeepFace = None
    DEEPFACE_AVAILABLE = False
    print("[WARNING] DeepFace not installed. Run: pip install deepface")
 
NOT_INSTALLED_MSG = "Face verification is not available on the server."
 
 
def _cfg(name, default):
    return getattr(settings, name, default)
 
 
def _get_path(file_field):
    if not file_field:
        return None
    try:
        return file_field.path
    except (ValueError, NotImplementedError, AttributeError):
        return None
 
 
def _error_kind(exc):
    """
    DeepFace often wraps the real problem inside a generic
    ValueError("Exception while processing img1_path"), so look through the whole
    chain of causes, not just the top message.
    Returns 'spoof', 'no_face', or 'other'.
    """
    chain, err = [], exc
    while err is not None and len(chain) < 6:
        chain.append(err)
        err = err.__cause__ or err.__context__
    names = {type(e).__name__ for e in chain}
    text = " ".join(str(e) for e in chain)
    if 'SpoofDetected' in names or 'Spoof detected' in text:
        return 'spoof'
    if 'FaceNotDetected' in names or 'Face could not be detected' in text:
        return 'no_face'
    return 'other'
 
 
def _compare(path1, label1, path2, label2, threshold):
    """
    Compare two face images.
    Returns (matched, message, score, distance). Never raises, and never returns
    internal error text to the caller (details go to the server log).
    """
    try:
        result = DeepFace.verify(
            img1_path=path1,
            img2_path=path2,
            model_name=_cfg('FACE_MODEL', 'Facenet512'),
            detector_backend=_cfg('FACE_DETECTOR', 'opencv'),
            enforce_detection=True,
            align=True,
        )
    except Exception as exc:
        kind = _error_kind(exc)
        if kind == 'no_face':
            # DeepFace says which image failed ("img1_path" / "img2_path")
            text = " ".join(str(e) for e in (exc, exc.__cause__) if e)
            which = label1 if 'img1_path' in text else label2 if 'img2_path' in text else None
            if which:
                return False, f"No face detected in the {which}. Upload a clear, front-facing photo.", 0.0, None
            return False, "No face detected. Upload clear photos.", 0.0, None
        logger.exception("DeepFace comparison failed")
        return False, "Face verification failed. Please try again.", 0.0, None
 
    distance = float(result.get('distance', 1.0))
    score = max(0.0, (1 - distance) * 100)
    # We decide with OUR threshold (from settings), not DeepFace's default one
    return distance <= threshold, None, float(score), distance
 
 
def _live_photo_is_real(path):
    """
    Anti-spoofing check on the live selfie ONLY. It is deliberately not run on
    the ID photo: a photo of an ID card would itself look like a 'spoof'.
    Fails closed: if the check cannot run, the live photo is NOT accepted.
    Returns (ok, message).
    """
    if not _cfg('FACE_ANTISPOOF', True):
        return True, None
    try:
        faces = DeepFace.extract_faces(
            img_path=path,
            detector_backend=_cfg('FACE_DETECTOR', 'opencv'),
            enforce_detection=True,
            align=True,
            anti_spoofing=True,
        )
    except Exception as exc:
        kind = _error_kind(exc)
        if kind == 'spoof':
            return False, "The live photo looks like a photo of a photo or a screen. Take a new live selfie."
        if kind == 'no_face':
            return False, "No face detected in the live photo."
        logger.exception("Anti-spoofing check could not run")
        return False, "Liveness check is unavailable right now. Please try again later."
 
    if not faces:
        return False, "No face detected in the live photo."
 
    # Judge the biggest face in the picture (the person holding the phone)
    main = max(faces, key=lambda f: f['facial_area']['w'] * f['facial_area']['h'])
    is_real = main.get('is_real')
    if is_real is None:
        logger.error("DeepFace returned no 'is_real' value; check your DeepFace version")
        return False, "Liveness check is unavailable right now. Please try again later."
    if not is_real:
        return False, "The live photo looks like a photo of a photo or a screen. Take a new live selfie."
    return True, None
 
 
def verify_id_with_profile(user):
    """Level 4: profile photo vs ID photo."""
    if not DEEPFACE_AVAILABLE:
        return False, NOT_INSTALLED_MSG, 0
 
    p1 = _get_path(user.profile_photo)
    p2 = _get_path(user.id_photo)
    if not p1 or not p2:
        return False, "Both photos required", 0
    if not os.path.exists(p1) or not os.path.exists(p2):
        return False, "Photo files not found", 0
 
    threshold = _cfg('FACE_THRESHOLD_PHOTO', 0.30)
    matched, error, score, distance = _compare(p1, "profile photo", p2, "ID photo", threshold)
    if error:
        return False, error, 0
 
    logger.info("Photo check user=%s distance=%.3f threshold=%.2f matched=%s",
                user.pk, distance, threshold, matched)
    user.photo_match_score = score
    user.photo_verification_data = {
        "distance": distance, "threshold": threshold,
        "model": _cfg('FACE_MODEL', 'Facenet512'),
        "detector": _cfg('FACE_DETECTOR', 'opencv'),
        "time": str(timezone.now()),
    }
    if matched:
        user.is_photo_verified = True
        user.photo_verified_at = timezone.now()
        user.save(update_fields=['is_photo_verified', 'photo_match_score',
                                 'photo_verified_at', 'photo_verification_data'])
        user.update_verification_level()
        return True, "Photo verified", score
 
    user.is_photo_verified = False
    user.save(update_fields=['is_photo_verified', 'photo_match_score', 'photo_verification_data'])
    user.update_verification_level()
    return False, "Your photo does not match your ID. Use a clear, front-facing photo in good light.", score
 
 
def verify_live_with_id(user):
    """
    Level 5: the live selfie must (1) look like a real person and (2) match the ID photo.
    """
    if not DEEPFACE_AVAILABLE:
        return False, NOT_INSTALLED_MSG, 0
 
    p_id = _get_path(user.id_photo)
    p_live = _get_path(user.live_photo)
    if not p_id or not p_live:
        return False, "Both photos required", 0
    if not os.path.exists(p_id) or not os.path.exists(p_live):
        return False, "Photo files not found", 0
 
    user.last_liveness_check = timezone.now()
 
    real, why_not = _live_photo_is_real(p_live)
    if not real:
        user.is_live_verified = False
        user.liveness_data = {"spoof_check": "failed", "time": str(timezone.now())}
        user.save(update_fields=['is_live_verified', 'last_liveness_check', 'liveness_data'])
        user.update_verification_level()
        return False, why_not, 0
 
    threshold = _cfg('FACE_THRESHOLD_LIVE', 0.30)
    matched, error, score, distance = _compare(p_live, "live photo", p_id, "ID photo", threshold)
    if error:
        user.save(update_fields=['last_liveness_check'])
        return False, error, 0
 
    logger.info("Live check user=%s distance=%.3f threshold=%.2f matched=%s",
                user.pk, distance, threshold, matched)
    user.live_match_score = score
    user.liveness_data = {
        "distance": distance, "threshold": threshold, "spoof_check": "passed" if _cfg('FACE_ANTISPOOF', True) else "skipped",
        "model": _cfg('FACE_MODEL', 'Facenet512'),
        "detector": _cfg('FACE_DETECTOR', 'opencv'),
        "time": str(timezone.now()),
    }
    if matched:
        user.is_live_verified = True
        user.live_verified_at = timezone.now()
        user.save(update_fields=['is_live_verified', 'live_match_score', 'live_verified_at',
                                 'last_liveness_check', 'liveness_data'])
        user.update_verification_level()
        return True, "Live verification passed", score
 
    user.is_live_verified = False
    user.save(update_fields=['is_live_verified', 'live_match_score',
                             'last_liveness_check', 'liveness_data'])
    user.update_verification_level()
    return False, "Your live selfie does not match your ID. Face the camera in good light.", score
 
 
def check_live_against_id(user, selfie_path):
    """
    Used by the job check-in. Same two tests as the registration live check
    (real face first, then match against the ID photo), but it does NOT change the
    user's verification status.
    Returns (liveness_passed, matched, score, message). message is None on success.
    Fails closed on every problem.
    """
    if not DEEPFACE_AVAILABLE:
        return False, False, 0.0, NOT_INSTALLED_MSG
    p_id = _get_path(user.id_photo)
    if not p_id or not os.path.exists(p_id):
        return False, False, 0.0, "No ID photo is on file for this artisan."
    if not selfie_path or not os.path.exists(selfie_path):
        return False, False, 0.0, "The selfie file was not saved."
 
    real, why_not = _live_photo_is_real(selfie_path)
    if not real:
        return False, False, 0.0, why_not
 
    matched, error, score, distance = _compare(
        selfie_path, "selfie", p_id, "ID photo", _cfg('FACE_THRESHOLD_LIVE', 0.30))
    if error:
        return True, False, 0.0, error
    logger.info("Check-in face check user=%s distance=%.3f matched=%s", user.pk, distance, matched)
    if matched:
        return True, True, float(score), None
    return True, False, float(score), "The face in the selfie does not match the artisan's verified ID photo."
 
 
# Old name kept so views.py and urls.py keep working. It now compares the live
# selfie with the ID photo (not with the profile photo).
verify_live_with_profile = verify_live_with_id
 
 
def run_full_auto_verification(user):
    if not DEEPFACE_AVAILABLE:
        return {"error": NOT_INSTALLED_MSG}
    results = {}
    if user.profile_photo and user.id_photo and not user.is_photo_verified:
        ok, msg, score = verify_id_with_profile(user)
        results['photo'] = {"ok": ok, "msg": msg, "score": score}
    if user.id_photo and user.live_photo and not user.is_live_verified and user.is_photo_verified:
        ok, msg, score = verify_live_with_id(user)
        results['live'] = {"ok": ok, "msg": msg, "score": score}
    return results