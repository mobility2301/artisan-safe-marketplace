
# DESTINATION: accounts/views.py
"""
Phase 4 Views - OTP + Face Verification APIs
"""
from django.conf import settings
from rest_framework import status, permissions
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
 
from .serializers import (
    EmailTokenObtainPairSerializer,
    UserSerializer,
    RegisterSerializer,
    NINSubmitSerializer,
    OTPVerifySerializer,
    PhotoUploadSerializer,
    VerificationStatusSerializer,
    EmergencyContactSerializer,
)
from .services.nin_service import submit_nin
from .services.otp_service import send_email_otp, verify_email_otp
from .services.face_service import verify_id_with_profile, verify_live_with_profile, run_full_auto_verification
 
 
# ---------------------------------------------------------------------------
# Throttles - slow down guessing of OTP codes and repeated face-match attempts.
# The rates are defined here so no change to settings.py is needed.
# ---------------------------------------------------------------------------
class OTPThrottle(UserRateThrottle):
    scope = 'otp'
    rate = '5/min'
 
 
class FaceVerificationThrottle(UserRateThrottle):
    scope = 'face'
    rate = '20/hour'
 
 
class NINThrottle(UserRateThrottle):
    scope = 'nin'
    rate = '10/hour'
 
 
class LoginThrottle(AnonRateThrottle):
    scope = 'login'
    rate = '10/min'      # per IP address - slows password guessing
 
 
class RegisterThrottle(AnonRateThrottle):
    scope = 'register'
    rate = '20/hour'     # per IP address - registration sends an email, so limit abuse
 
 
def dev_code_note(otp):
    """The OTP is only revealed in the API response while DEBUG is True.
    In production the code must arrive by email only, otherwise anyone
    could 'verify' an email address or phone number they do not own."""
    return f" DEV code: {otp}" if getattr(settings, "SHOW_DEV_CODES", settings.DEBUG) else ""
 
 
def reset_stale_verification(user, changed_fields):
    """
    If someone replaces their profile photo or ID photo, the earlier photo and
    liveness approvals no longer apply to the new images, so they are cleared and
    the user must be verified again. Replacing the live photo clears liveness only.
    """
    reset_photo = bool(changed_fields & {'profile_photo', 'id_photo'})
    reset_live = reset_photo or 'live_photo' in changed_fields
    update_fields = []
 
    if reset_photo:
        user.is_photo_verified = False
        user.photo_match_score = 0.0
        user.photo_verified_at = None
        user.photo_verification_data = {}
        update_fields += ['is_photo_verified', 'photo_match_score',
                          'photo_verified_at', 'photo_verification_data']
    if reset_live:
        user.is_live_verified = False
        user.live_match_score = 0.0
        user.live_verified_at = None
        user.liveness_data = {}
        update_fields += ['is_live_verified', 'live_match_score',
                          'live_verified_at', 'liveness_data']
 
    if update_fields:
        user.save(update_fields=update_fields)
        user.update_verification_level()
 
 
# 0. LOGIN - email + password -> access and refresh tokens (JWT)
class LoginView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer
    throttle_classes = [LoginThrottle]
 
 
# 1. REGISTER - Creates user and sends email OTP automatically
class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []          # an old or expired token must not block sign-up
    throttle_classes = [RegisterThrottle]
 
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            # Auto send email OTP after registration
            sent, _ = send_email_otp(user)
            return Response({
                "message": ("Account created. OTP sent to email." if sent else
                            "Account created, but the OTP email could not be sent. Request a new code."),
                "user": UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
 
 
# 2. SEND EMAIL OTP
class SendEmailOTPView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [OTPThrottle]
 
    def post(self, request):
        ok, otp = send_email_otp(request.user)
        if ok:
            return Response({"message": f"OTP sent to {request.user.email}.{dev_code_note(otp)}"})
        return Response({"error": "Failed to send"}, status=status.HTTP_400_BAD_REQUEST)
 
 
# 3. VERIFY EMAIL OTP
class VerifyEmailOTPView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [OTPThrottle]
 
    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        if serializer.is_valid():
            ok, msg = verify_email_otp(request.user, serializer.validated_data['otp'])
            if ok:
                return Response({"message": msg, "status": VerificationStatusSerializer(request.user).data})
            return Response({"error": msg}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
 
 
# 4. UPLOAD PHOTOS (profile, id, live)
class PhotoUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [FaceVerificationThrottle]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
 
    def patch(self, request):
        serializer = PhotoUploadSerializer(request.user, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
 
        changed = set(serializer.validated_data.keys())
        serializer.save()
        # New photo means the old approval no longer applies
        reset_stale_verification(request.user, changed)
 
        # Auto try verification if photos complete
        result = run_full_auto_verification(request.user)
        return Response({
            "message": "Photos uploaded",
            "user": UserSerializer(request.user).data,
            "auto_verification": result,
            "status": VerificationStatusSerializer(request.user).data
        })
 
 
# 7. VERIFY ID vs PROFILE (Level 3)
class VerifyPhotoIDView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [FaceVerificationThrottle]
 
    def post(self, request):
        ok, msg, score = verify_id_with_profile(request.user)
        if ok:
            return Response({"message": msg, "score": score, "status": VerificationStatusSerializer(request.user).data})
        return Response({"error": msg, "score": score}, status=status.HTTP_400_BAD_REQUEST)
 
 
# 8. VERIFY LIVE vs PROFILE (Level 4)
class VerifyLiveView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [FaceVerificationThrottle]
 
    def post(self, request):
        ok, msg, score = verify_live_with_profile(request.user)
        if ok:
            return Response({"message": msg, "score": score, "status": VerificationStatusSerializer(request.user).data})
        return Response({"error": msg, "score": score}, status=status.HTTP_400_BAD_REQUEST)
 
 
# 8b. SUBMIT NIN (Level 3)
class SubmitNINView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [NINThrottle]
 
    def post(self, request):
        serializer = NINSubmitSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        ok, msg = submit_nin(request.user, serializer.validated_data['nin'])
        if ok:
            return Response({"message": msg, "status": VerificationStatusSerializer(request.user).data})
        return Response({"error": msg}, status=status.HTTP_400_BAD_REQUEST)
 
 
# 9. GET VERIFICATION STATUS
class VerificationStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]
 
    def get(self, request):
        return Response(VerificationStatusSerializer(request.user).data)
 
 
# 10. GET ME
class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]
 
    def get(self, request):
        return Response(UserSerializer(request.user).data)
 
    def patch(self, request):
        """Save the emergency contact that will receive the SOS email."""
        serializer = EmergencyContactSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        for field, value in serializer.validated_data.items():
            setattr(user, field, value)
        user.save(update_fields=list(serializer.validated_data.keys()))
        return Response(UserSerializer(user).data)