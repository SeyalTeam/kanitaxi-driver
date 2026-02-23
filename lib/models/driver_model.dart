class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.status,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String? status;
  final String? photoUrl;

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: _extractId(json),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      status: json['status']?.toString(),
      photoUrl: _readPhotoUrl(json['photo']),
    );
  }

  static String _extractId(dynamic value) {
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

      final mongo = value['_id'];
      if (mongo is String && mongo.isNotEmpty) {
        return mongo;
      }
      if (mongo is Map<String, dynamic>) {
        final oid = mongo['\$oid']?.toString();
        if (oid != null && oid.isNotEmpty) {
          return oid;
        }
      }
    }

    return '';
  }

  static String? _readPhotoUrl(dynamic photo) {
    if (photo is Map<String, dynamic>) {
      final url = photo['url']?.toString();
      return (url == null || url.isEmpty) ? null : url;
    }
    return null;
  }
}
