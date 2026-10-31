
# ===== PASTE THIS INTO:  artisans/views.py =====
from decimal import Decimal, InvalidOperation
 
from django.conf import settings
from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
 
from .models import ArtisanProfile
from .serializers import ArtisanListSerializer, ArtisanProfileSerializer
 
 
def public_artisans():
    """
    Artisans that clients are allowed to see.
    Only active accounts are listed, and by default only fully verified ones
    (email + phone + photo-vs-ID + liveness all passed).
 
    While you are still building the verification flow, add this to settings.py
    so the list is not empty:   LISTING_REQUIRES_VERIFIED = False
    Set it back to True (or remove it) before testing with real users.
    """
    qs = ArtisanProfile.objects.select_related('user').filter(user__is_active=True)
    if getattr(settings, 'LISTING_REQUIRES_VERIFIED', True):
        qs = qs.filter(user__is_fully_verified=True)
    return qs
 
 
@api_view(['GET'])
@permission_classes([AllowAny])
def artisan_list(request):
    """
    GET /api/artisans/
    Optional query parameters:
      q            search in business name, display name and description
      category     one of the category keys (e.g. plumbing)
      artisan_type onsite | delivery
      town, lga    exact match, case-insensitive
      available    true  -> only artisans currently available
      min_rating   e.g. 4.0
    Results are ordered by rating (best first), then newest.
    """
    params = request.query_params
    artisans = public_artisans()
 
    q = params.get('q', '').strip()
    if q:
        artisans = artisans.filter(
            Q(business_name__icontains=q)
            | Q(display_name__icontains=q)
            | Q(description__icontains=q)
        )
 
    category = params.get('category', '').strip().lower()
    if category:
        valid = [key for key, _ in ArtisanProfile.CATEGORY]
        if category not in valid:
            return Response(
                {'error': f"Invalid category. Choose from: {', '.join(valid)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        artisans = artisans.filter(category=category)
 
    artisan_type = params.get('artisan_type', '').strip().lower()
    if artisan_type:
        if artisan_type not in ('onsite', 'delivery'):
            return Response(
                {'error': "Invalid artisan_type. Choose 'onsite' or 'delivery'."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        artisans = artisans.filter(artisan_type=artisan_type)
 
    town = params.get('town', '').strip()
    if town:
        artisans = artisans.filter(town__iexact=town)
 
    lga = params.get('lga', '').strip()
    if lga:
        artisans = artisans.filter(lga__iexact=lga)
 
    if params.get('available', '').strip().lower() in ('true', '1', 'yes'):
        artisans = artisans.filter(is_available=True)
 
    min_rating = params.get('min_rating', '').strip()
    if min_rating:
        try:
            artisans = artisans.filter(average_rating__gte=Decimal(min_rating))
        except InvalidOperation:
            return Response(
                {'error': 'min_rating must be a number, e.g. 4.0'},
                status=status.HTTP_400_BAD_REQUEST,
            )
 
    artisans = artisans.order_by('-average_rating', '-created_at')
    serializer = ArtisanListSerializer(artisans, many=True, context={'request': request})
    return Response(serializer.data)
 
 
@api_view(['GET'])
@permission_classes([AllowAny])
def artisan_detail(request, pk):
    """GET /api/artisans/<id>/ - full public profile of one artisan."""
    artisan = get_object_or_404(public_artisans(), pk=pk)
    serializer = ArtisanProfileSerializer(artisan, context={'request': request})
    return Response(serializer.data)
 
 
@api_view(['GET'])
@permission_classes([AllowAny])
def artisan_categories(request):
    """GET /api/artisans/categories/ - category keys and labels for the app's filter menu."""
    return Response([{'key': key, 'label': label} for key, label in ArtisanProfile.CATEGORY])
 
 
@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def my_profile(request):
    """
    GET   /api/artisans/me/   - the logged-in artisan's own profile (includes their phone)
    PATCH /api/artisans/me/   - update description, price, category, availability, image...
    is_verified, average_rating and phone cannot be changed here.
    """
    profile = get_object_or_404(ArtisanProfile, user=request.user)
 
    if request.method == 'PATCH':
        serializer = ArtisanProfileSerializer(
            profile, data=request.data, partial=True, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
 
    serializer = ArtisanProfileSerializer(profile, context={'request': request})
    return Response(serializer.data)