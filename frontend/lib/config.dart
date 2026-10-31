
// ===== SAVE AS:  C:\dev\artisan_app\lib\config.dart   (REPLACE whole file) =====
/// Where the Django server runs. Chrome on the same laptop reaches it at 127.0.0.1.
/// (A real phone would need your laptop's Wi-Fi address here instead.)
const String kServerRoot = 'http://127.0.0.1:8000';
const String kApiBase = '$kServerRoot/api';
 
/// Must match ArtisanProfile.CATEGORY in artisans/models.py
const Map<String, String> kCategories = {
  'basket': 'Basket',
  'wood': 'Wood',
  'pottery': 'Pottery',
  'tailoring': 'Tailoring',
  'painting': 'Painting',
  'plumbing': 'Plumbing',
  'electrical': 'Electrical',
  'carpentry': 'Carpentry',
  'tiling': 'Tiling',
  'welding': 'Welding',
  'mechanic': 'Mechanic',
};
 
/// Must match ArtisanProfile.ARTISAN_TYPE
const Map<String, String> kArtisanTypes = {
  'onsite': 'On-site (I travel to the client)',
  'delivery': 'Delivery (I make it and deliver it)',
};
 
/// Must match CustomUser.ID_TYPE_CHOICES in accounts/models.py
const Map<String, String> kIdTypes = {
  'national_id': 'National ID card',
  'drivers_license': "Driver's licence",
  'voters_card': "Voter's card",
  'passport': 'International passport',
};
 
/// Must match Job.STATUS_CHOICES in jobs/models.py
const Map<String, String> kJobStatus = {
  'requested': 'Requested',
  'accepted': 'Accepted',
  'rejected': 'Declined',
  'cancelled': 'Cancelled',
  'checked_in': 'Checked in',
  'checked_out': 'Checked out',
  'completed': 'Completed',
  'sos_triggered': 'SOS triggered',
};