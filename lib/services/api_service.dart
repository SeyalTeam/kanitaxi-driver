import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String baseUrl = 'https://kanitaxi.com/api';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _client.post(
        Uri.parse('$baseUrl/users/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'password': password}),
      );

      final decoded = _decodeObject(response.body);

      if (response.statusCode != 200) {
        final serverMessage = _extractErrorMessage(decoded);
        final incorrectCreds =
            serverMessage == 'The email or password provided is incorrect.';

        return {
          'success': false,
          'message': incorrectCreds
              ? 'Invalid login. Use a Users account email/password (not driver master data). If needed, ask admin to create/reset your user login.'
              : (serverMessage ?? 'Login failed'),
        };
      }

      final token = decoded['token']?.toString();
      final user = _asMap(decoded['user']);

      if (token == null || token.isEmpty || user == null) {
        return {
          'success': false,
          'message': 'Invalid login response from server.',
        };
      }

      final driverId = await resolveDriverId(user: user, token: token);
      if (driverId == null || driverId.isEmpty) {
        return {
          'success': false,
          'message': 'This account is not linked to a driver profile.',
        };
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));
      await prefs.setString('driverId', driverId);

      return {'success': true, 'user': user, 'driverId': driverId};
    } catch (error) {
      debugPrint('Login error: $error');
      return {
        'success': false,
        'message': 'Unable to login. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> createDriverProfile({
    required String name,
    required String phone,
    required String address,
    required int experience,
    String? aadharNo,
    String? panNo,
    String? license,
    String? photoMediaId,
    String status = 'available',
  }) async {
    try {
      final normalizedPhone = phone.trim();
      final payload = <String, dynamic>{
        'name': name.trim(),
        'phone': normalizedPhone,
        'address': address.trim(),
        'experience': experience,
        'status': status,
      };

      final trimmedAadhar = aadharNo?.trim() ?? '';
      final trimmedPan = panNo?.trim() ?? '';
      final trimmedLicense = license?.trim() ?? '';

      if (trimmedAadhar.isNotEmpty) {
        payload['aadharNo'] = trimmedAadhar;
      }
      if (trimmedPan.isNotEmpty) {
        payload['panNo'] = trimmedPan;
      }
      if (trimmedLicense.isNotEmpty) {
        payload['license'] = trimmedLicense;
      }
      final trimmedPhoto = photoMediaId?.trim() ?? '';
      if (trimmedPhoto.isNotEmpty) {
        payload['photo'] = trimmedPhoto;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/drivers'),
        headers: await _buildHeaders(withAuth: true),
        body: jsonEncode(payload),
      );

      final decoded = _decodeObject(response.body);
      final isAcceptedResponse =
          response.statusCode >= 200 && response.statusCode < 300;

      if (!isAcceptedResponse || _hasPayloadErrors(decoded)) {
        return {
          'success': false,
          'message':
              _extractErrorMessage(decoded) ??
              'Could not create driver profile.',
        };
      }

      var createdDriverId = _extractDriverIdFromCreateResponse(
        decoded: decoded,
        headers: response.headers,
      );

      if (createdDriverId.isEmpty && normalizedPhone.isNotEmpty) {
        final byPhone = await _findDriverIdByField(
          field: 'phone',
          equalsValue: normalizedPhone,
          token: await getToken(),
        );
        if (byPhone != null && byPhone.isNotEmpty) {
          createdDriverId = byPhone;
        }
      }

      if (createdDriverId.isEmpty) {
        return {
          'success': false,
          'message':
              'Driver details were not saved. Please retry and check CMS.',
        };
      }

      return {'success': true, 'driverId': createdDriverId};
    } catch (error) {
      debugPrint('Create driver profile error: $error');
      return {
        'success': false,
        'message': 'Unable to save driver details. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> uploadMedia({
    required List<int> fileBytes,
    required String fileName,
    required String alt,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/media'),
      );

      final headers = await _buildHeaders(withAuth: true);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      final normalizedAlt = alt.trim().isEmpty ? 'Driver photo' : alt.trim();
      request.fields['alt'] = normalizedAlt;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: _sanitizeUploadName(fileName),
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final decoded = _decodeObject(response.body);

      final isAcceptedResponse =
          response.statusCode >= 200 && response.statusCode < 300;
      if (isAcceptedResponse) {
        if (_hasPayloadErrors(decoded)) {
          return {
            'success': false,
            'message':
                _extractErrorMessage(decoded) ?? 'Could not upload photo.',
          };
        }

        final mediaId = _extractMediaIdFromUploadResponse(
          decoded: decoded,
          headers: response.headers,
        );
        if (mediaId.isNotEmpty) {
          return {'success': true, 'mediaId': mediaId};
        }

        final fallbackMediaId = await _findMediaIdByAlt(
          altValue: normalizedAlt,
          token: await getToken(),
        );
        if (fallbackMediaId != null && fallbackMediaId.isNotEmpty) {
          return {'success': true, 'mediaId': fallbackMediaId};
        }

        return {
          'success': false,
          'message': 'Photo upload response was invalid.',
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(decoded) ?? 'Could not upload photo.',
      };
    } catch (error) {
      debugPrint('Upload media error: $error');
      return {
        'success': false,
        'message': 'Unable to upload photo. Please try again.',
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('driverId');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('driverId');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final user = await getUser();
    final token = await getToken();
    if (user == null) {
      return null;
    }

    final resolved = await resolveDriverId(user: user, token: token);
    if (resolved != null && resolved.isNotEmpty) {
      await prefs.setString('driverId', resolved);
    }
    return resolved;
  }

  Future<String?> resolveDriverId({
    required Map<String, dynamic> user,
    String? token,
  }) async {
    final directCandidates = [
      _extractId(user['driver']),
      _extractId(user['driverId']),
      _extractId(user['driverProfile']),
      _extractId(user['profile']),
      _extractId(user),
    ];

    for (final candidate in directCandidates) {
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    final userId = _extractId(user);
    if (userId.isNotEmpty) {
      final byUser = await _findDriverIdByField(
        field: 'user',
        equalsValue: userId,
        token: token,
      );
      if (byUser != null && byUser.isNotEmpty) {
        return byUser;
      }
    }

    final phone = user['phone']?.toString();
    if (phone != null && phone.isNotEmpty) {
      final byPhone = await _findDriverIdByField(
        field: 'phone',
        equalsValue: phone,
        token: token,
      );
      if (byPhone != null && byPhone.isNotEmpty) {
        return byPhone;
      }
    }

    return null;
  }

  Future<List<Booking>> getAssignedBookings(String driverId) async {
    if (driverId.isEmpty) {
      return const [];
    }

    try {
      final queryUri = Uri.parse(
        '$baseUrl/bookings?where%5Bdriver%5D%5Bequals%5D=${Uri.encodeQueryComponent(driverId)}&depth=2&limit=100&sort=-pickupDateTime',
      );

      final queryResponse = await _client.get(
        queryUri,
        headers: await _buildHeaders(withAuth: true),
      );

      List<Booking> parsed = _parseBookings(queryResponse);

      if (parsed.isEmpty && queryResponse.statusCode != 200) {
        final fallbackResponse = await _client.get(
          Uri.parse('$baseUrl/bookings?depth=2&limit=100&sort=-pickupDateTime'),
          headers: await _buildHeaders(withAuth: true),
        );
        parsed = _parseBookings(fallbackResponse);
      }

      return parsed.where((booking) => booking.isAssignedTo(driverId)).toList();
    } catch (error) {
      debugPrint('Assigned bookings error: $error');
      return const [];
    }
  }

  Future<Booking?> getBooking(String bookingId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/bookings/$bookingId?depth=2'),
        headers: await _buildHeaders(withAuth: true),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = _decodeObject(response.body);
      return Booking.fromJson(decoded);
    } catch (error) {
      debugPrint('Get booking error: $error');
      return null;
    }
  }

  Future<bool> confirmBooking({
    required String bookingId,
    required String driverId,
  }) async {
    try {
      final bookingResponse = await _client.patch(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: await _buildHeaders(withAuth: true),
        body: jsonEncode({'status': 'confirmed'}),
      );

      if (bookingResponse.statusCode != 200) {
        return false;
      }

      await _client.patch(
        Uri.parse('$baseUrl/drivers/$driverId'),
        headers: await _buildHeaders(withAuth: true),
        body: jsonEncode({'status': 'driving'}),
      );

      return true;
    } catch (error) {
      debugPrint('Confirm booking error: $error');
      return false;
    }
  }

  Future<bool> completeBooking({
    required String bookingId,
    required String driverId,
  }) async {
    try {
      final bookingResponse = await _client.patch(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: await _buildHeaders(withAuth: true),
        body: jsonEncode({'status': 'completed'}),
      );

      if (bookingResponse.statusCode != 200) {
        return false;
      }

      await _client.patch(
        Uri.parse('$baseUrl/drivers/$driverId'),
        headers: await _buildHeaders(withAuth: true),
        body: jsonEncode({'status': 'available'}),
      );

      return true;
    } catch (error) {
      debugPrint('Complete booking error: $error');
      return false;
    }
  }

  Future<String?> _findDriverIdByField({
    required String field,
    required String equalsValue,
    String? token,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/drivers?where%5B$field%5D%5Bequals%5D=${Uri.encodeQueryComponent(equalsValue)}&limit=1',
      );

      final response = await _client.get(
        uri,
        headers: await _buildHeaders(token: token, withAuth: token != null),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = _decodeObject(response.body);
      final docs = decoded['docs'];
      if (docs is List && docs.isNotEmpty) {
        final first = docs.first;
        if (first is Map<String, dynamic>) {
          final id = _extractId(first);
          if (id.isNotEmpty) {
            return id;
          }
        }
      }
    } catch (error) {
      debugPrint('Find driver error: $error');
    }
    return null;
  }

  Future<String?> _findMediaIdByAlt({
    required String altValue,
    String? token,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/media?where%5Balt%5D%5Bequals%5D=${Uri.encodeQueryComponent(altValue)}&limit=1&sort=-createdAt',
      );

      final response = await _client.get(
        uri,
        headers: await _buildHeaders(token: token, withAuth: token != null),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = _decodeObject(response.body);
      final docs = decoded['docs'];
      if (docs is List && docs.isNotEmpty) {
        final id = _extractId(docs.first);
        if (id.isNotEmpty) {
          return id;
        }
      }
    } catch (error) {
      debugPrint('Find media error: $error');
    }
    return null;
  }

  List<Booking> _parseBookings(http.Response response) {
    if (response.statusCode != 200) {
      return const [];
    }

    final decoded = _decodeObject(response.body);
    final docs = decoded['docs'];
    if (docs is! List) {
      return const [];
    }

    return docs
        .whereType<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();
  }

  Future<Map<String, String>> _buildHeaders({
    String? token,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (!withAuth) {
      return headers;
    }

    final authToken = token ?? await getToken();
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'JWT $authToken';
    }
    return headers;
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed JSON and return empty map.
    }
    return <String, dynamic>{};
  }

  String? _extractErrorMessage(Map<String, dynamic> payload) {
    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map<String, dynamic>) {
        final message = first['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }

    final message = payload['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return null;
  }

  String _extractId(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      final direct = value['id']?.toString();
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }

      final rawMongo = value['_id'];
      if (rawMongo is String && rawMongo.isNotEmpty) {
        return rawMongo;
      }

      if (rawMongo is Map<String, dynamic>) {
        final oid = rawMongo['\$oid']?.toString();
        if (oid != null && oid.isNotEmpty) {
          return oid;
        }
      }
    }

    return '';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  String _sanitizeUploadName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return 'driver_photo.jpg';
    }
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  bool _hasPayloadErrors(Map<String, dynamic> payload) {
    final errors = payload['errors'];
    return errors is List && errors.isNotEmpty;
  }

  String _extractDriverIdFromCreateResponse({
    required Map<String, dynamic> decoded,
    required Map<String, String> headers,
  }) {
    final candidates = <dynamic>[
      decoded,
      decoded['doc'],
      decoded['data'],
      decoded['result'],
      (decoded['result'] is Map<String, dynamic>)
          ? (decoded['result'] as Map<String, dynamic>)['doc']
          : null,
    ];

    for (final candidate in candidates) {
      final id = _extractId(candidate);
      if (id.isNotEmpty) {
        return id;
      }
    }

    final location = headers['location'] ?? headers['Location'];
    if (location != null && location.isNotEmpty) {
      final match = RegExp(r'/drivers/([^/?#]+)').firstMatch(location);
      final id = match?.group(1);
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return '';
  }

  String _extractMediaIdFromUploadResponse({
    required Map<String, dynamic> decoded,
    required Map<String, String> headers,
  }) {
    final candidates = <dynamic>[
      decoded,
      decoded['doc'],
      decoded['data'],
      decoded['result'],
      (decoded['result'] is Map<String, dynamic>)
          ? (decoded['result'] as Map<String, dynamic>)['doc']
          : null,
    ];

    for (final candidate in candidates) {
      final id = _extractId(candidate);
      if (id.isNotEmpty) {
        return id;
      }
    }

    final docs = decoded['docs'];
    if (docs is List && docs.isNotEmpty) {
      final id = _extractId(docs.first);
      if (id.isNotEmpty) {
        return id;
      }
    }

    final location = headers['location'] ?? headers['Location'];
    if (location != null && location.isNotEmpty) {
      final match = RegExp(r'/media/([^/?#]+)').firstMatch(location);
      final id = match?.group(1);
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return '';
  }
}
