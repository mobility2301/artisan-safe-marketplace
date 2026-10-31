// DESTINATION: lib/services/api.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
 
import '../config.dart';
 
/// An error with a message that is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
 
  @override
  String toString() => message;
}
 
/// Talks to the Django backend. One shared instance: Api.instance.
/// Keeps the login tokens, sends them on every request, and quietly gets a
/// new access token (using the refresh token) when the old one has expired.
class Api {
  Api._();
  static final Api instance = Api._();
 
  String? _access;
  String? _refresh;
 
  bool get isLoggedIn => _refresh != null;
 
  // ---------------------------------------------------------------- tokens
 
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString('access');
    _refresh = prefs.getString('refresh');
  }
 
  Future<void> _saveTokens(String? access, String? refresh) async {
    _access = access;
    _refresh = refresh;
    final prefs = await SharedPreferences.getInstance();
    if (access == null) {
      await prefs.remove('access');
    } else {
      await prefs.setString('access', access);
    }
    if (refresh == null) {
      await prefs.remove('refresh');
    } else {
      await prefs.setString('refresh', refresh);
    }
  }
 
  Future<void> logout() => _saveTokens(null, null);
 
  Future<bool> _refreshAccess() async {
    if (_refresh == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refresh}),
      );
      if (res.statusCode == 200) {
        final data = _decode(res) as Map;
        await _saveTokens(
          data['access'] as String,
          (data['refresh'] as String?) ?? _refresh,
        );
        return true;
      }
    } catch (_) {
      // fall through: treated as "could not refresh"
    }
    await _saveTokens(null, null);
    return false;
  }
 
  // --------------------------------------------------------------- plumbing
 
  dynamic _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }
 
  String _nice(String key) => key.replaceAll('_', ' ');
 
  /// Turns the different error shapes the backend sends into one readable string.
  String? _errorText(dynamic body) {
    if (body is Map) {
      if (body['error'] != null) return body['error'].toString();
      if (body['detail'] != null) return body['detail'].toString();
      final parts = <String>[];
      body.forEach((key, value) {
        final text = value is List ? value.join(' ') : value.toString();
        parts.add(key == 'non_field_errors' ? text : '${_nice(key.toString())}: $text');
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    if (body is List && body.isNotEmpty) return body.join(' ');
    return null;
  }
 
  Never _fail(http.Response res) {
    throw ApiException(
      _errorText(_decode(res)) ?? 'Something went wrong (${res.statusCode}).',
      res.statusCode,
    );
  }
 
  bool _ok(http.Response res) => res.statusCode >= 200 && res.statusCode < 300;
 
  /// Runs a request. [call] is given the auth headers and must build a fresh
  /// request each time, because it may be run twice (once more after a refresh).
  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) call, {
    bool auth = true,
  }) async {
    Map<String, String> headers() => {
          if (auth && _access != null) 'Authorization': 'Bearer $_access',
        };
    const wait = Duration(seconds: 180); // the first face check can be slow
    try {
      var res = await call(headers()).timeout(wait);
      if (auth && res.statusCode == 401 && await _refreshAccess()) {
        res = await call(headers()).timeout(wait);
      }
      return res;
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Please try again.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Check that it is running and try again.');
    }
  }
 
  Future<Map<String, dynamic>> _getMap(String path, {bool auth = true}) async {
    final res = await _send(
      (h) => http.get(Uri.parse('$kApiBase$path'), headers: h),
      auth: auth,
    );
    if (_ok(res)) return Map<String, dynamic>.from(_decode(res) as Map);
    _fail(res);
  }
 
  Future<Map<String, dynamic>> _postMap(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _send(
      (h) => http.post(
        Uri.parse('$kApiBase$path'),
        headers: {...h, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      auth: auth,
    );
    if (_ok(res)) return Map<String, dynamic>.from(_decode(res) as Map);
    _fail(res);
  }
 
  // ------------------------------------------------------------------- auth
 
  Future<void> register(Map<String, dynamic> body) async {
    await _postMap('/auth/register/', body: body, auth: false);
  }
 
  Future<void> login(String email, String password) async {
    final data = await _postMap(
      '/auth/login/',
      body: {'email': email.trim().toLowerCase(), 'password': password},
      auth: false,
    );
    await _saveTokens(data['access'] as String, data['refresh'] as String);
  }
 
  Future<Map<String, dynamic>> me() => _getMap('/auth/me/');
 
  Future<Map<String, dynamic>> status() => _getMap('/auth/status/');
 
  // ----------------------------------------------------------- verification
 
  /// [channel] is 'email' or 'phone'. Returns the server's message, which in
  /// development also contains the code (so you can test without SMS).
  Future<String> sendOtp(String channel) async {
    final d = await _postMap('/auth/otp/$channel/send/');
    return (d['message'] ?? 'Code sent.').toString();
  }
 
  Future<String> verifyOtp(String channel, String code) async {
    final d = await _postMap('/auth/otp/$channel/verify/', body: {'otp': code.trim()});
    return (d['message'] ?? 'Verified.').toString();
  }
 
  Future<String> submitNin(String nin) async {
    final d = await _postMap('/auth/nin/submit/', body: {'nin': nin.trim()});
    return (d['message'] ?? 'NIN accepted.').toString();
  }
 
  /// Uploads any of the three photos. The server tries to verify them as soon
  /// as it has what it needs; the answer is in result['auto_verification'].
  Future<Map<String, dynamic>> uploadPhotos({
    Uint8List? profile,
    Uint8List? idPhoto,
    Uint8List? live,
    String? idType,
  }) async {
    final res = await _send((h) async {
      final req = http.MultipartRequest('PATCH', Uri.parse('$kApiBase/auth/photo/upload/'));
      req.headers.addAll(h);
      if (profile != null) {
        req.files.add(http.MultipartFile.fromBytes('profile_photo', profile, filename: 'profile.jpg'));
      }
      if (idPhoto != null) {
        req.files.add(http.MultipartFile.fromBytes('id_photo', idPhoto, filename: 'id.jpg'));
      }
      if (live != null) {
        req.files.add(http.MultipartFile.fromBytes('live_photo', live, filename: 'live.jpg'));
      }
      if (idType != null) req.fields['id_type'] = idType;
      return http.Response.fromStream(await req.send());
    });
    if (_ok(res)) return Map<String, dynamic>.from(_decode(res) as Map);
    _fail(res);
  }
 
  // --------------------------------------------------------------- artisans
 
  Future<List<dynamic>> artisans({String? category, String? query}) async {
    final params = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final uri = Uri.parse('$kApiBase/artisans/')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _send((h) => http.get(uri, headers: h), auth: false);
    if (_ok(res)) return List<dynamic>.from(_decode(res) as List);
    _fail(res);
  }
 
  // ------------------------------------------------------------------- jobs
 
  Future<List<dynamic>> _getList(String path) async {
    final res = await _send((h) => http.get(Uri.parse('$kApiBase$path'), headers: h));
    if (_ok(res)) return List<dynamic>.from(_decode(res) as List);
    _fail(res);
  }
 
  Future<List<dynamic>> jobs() => _getList('/jobs/');
 
  Future<Map<String, dynamic>> job(int id) => _getMap('/jobs/$id/');
 
  Future<Map<String, dynamic>> requestJob(Map<String, dynamic> body) =>
      _postMap('/jobs/', body: body);
 
  /// [action] is 'accept', 'reject' or 'cancel'.
  Future<Map<String, dynamic>> jobAction(int id, String action, {Map<String, dynamic>? body}) =>
      _postMap('/jobs/$id/$action/', body: body);
 
  Future<List<dynamic>> notifications() => _getList('/jobs/notifications/');
 
  Future<void> markNotificationRead(int id) async {
    await _postMap('/jobs/notifications/$id/read/');
  }
 
  // ------------------------------------------------------- safety (job day)
 
  /// Check-in: live selfie + GPS. Returns the server's answer. A failed check
  /// (face mismatch, spoof, too far away) comes back with result['verified'] == false
  /// and result['error'] explaining why, instead of throwing.
  Future<Map<String, dynamic>> checkIn(int id, Uint8List selfie, double lat, double lng) async {
    final res = await _send((h) async {
      final req = http.MultipartRequest('POST', Uri.parse('$kApiBase/jobs/$id/checkin/'));
      req.headers.addAll(h);
      req.files.add(http.MultipartFile.fromBytes('selfie', selfie, filename: 'selfie.jpg'));
      req.fields['lat'] = lat.toString();
      req.fields['lng'] = lng.toString();
      return http.Response.fromStream(await req.send());
    });
    final body = _decode(res);
    if (_ok(res)) return Map<String, dynamic>.from(body as Map);
    if (res.statusCode == 400 && body is Map && body['verified'] == false) {
      return Map<String, dynamic>.from(body);
    }
    _fail(res);
  }
 
  Future<Map<String, dynamic>> checkOut(int id, double lat, double lng) =>
      _postMap('/jobs/$id/checkout/', body: {'lat': lat, 'lng': lng});
 
  Future<Map<String, dynamic>> confirmCheckout(int id) =>
      _postMap('/jobs/$id/confirm-checkout/');
 
  Future<Map<String, dynamic>> reviewJob(int id, int rating, String comment) =>
      _postMap('/jobs/$id/review/', body: {'rating': rating, 'comment': comment});
 
  /// Raises the alarm. The server emails the sender's own emergency contact.
  Future<Map<String, dynamic>> sos(int id, double lat, double lng) =>
      _postMap('/jobs/$id/sos/', body: {'lat': lat, 'lng': lng});
 
  Future<Map<String, dynamic>> resolveSos(int id) => _postMap('/jobs/$id/sos/resolve/');
 
  Future<Map<String, dynamic>> myArtisanProfile() => _getMap('/artisans/me/');
 
  Future<void> updateMyArtisanProfile(String description, String price, bool available) async {
    final res = await _send((h) => http.patch(
          Uri.parse('$kApiBase/artisans/me/'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'description': description.trim(),
            'price': price.trim(),
            'is_available': available,
          }),
        ));
    if (!_ok(res)) _fail(res);
  }
 
  Future<void> updateEmergencyContact(String name, String phone, String email) async {
    final res = await _send((h) => http.patch(
          Uri.parse('$kApiBase/auth/me/'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'emergency_contact_name': name.trim(),
            'emergency_contact_phone': phone.trim(),
            'emergency_contact_email': email.trim(),
          }),
        ));
    if (!_ok(res)) _fail(res);
  }
}