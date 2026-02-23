import 'driver_model.dart';

class Booking {
  const Booking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.tripType,
    required this.pickupLocationName,
    required this.pickupDateTime,
    required this.status,
    required this.paymentStatus,
    this.dropoffLocationName,
    this.dropDateTime,
    this.estimatedFare,
    this.distanceKm,
    this.tourLocations,
    this.paymentAmount,
    this.paymentType,
    this.bookingCode,
    this.vehicleName,
    this.driver,
    this.driverId,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String tripType;
  final String pickupLocationName;
  final String? dropoffLocationName;
  final DateTime pickupDateTime;
  final DateTime? dropDateTime;
  final double? estimatedFare;
  final double? distanceKm;
  final List<String>? tourLocations;
  final String status;
  final String paymentStatus;
  final double? paymentAmount;
  final String? paymentType;
  final String? bookingCode;
  final String? vehicleName;
  final Driver? driver;
  final String? driverId;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final parsedDriver = _parseDriver(json['driver']);

    return Booking(
      id: _extractId(json),
      customerName: (json['customerName'] ?? '').toString(),
      customerPhone: (json['customerPhone'] ?? '').toString(),
      tripType: (json['tripType'] ?? 'oneway').toString(),
      pickupLocationName: (json['pickupLocationName'] ?? '').toString(),
      dropoffLocationName: _asNullableString(json['dropoffLocationName']),
      pickupDateTime: _parseDateTime(json['pickupDateTime']) ?? DateTime.now(),
      dropDateTime: _parseDateTime(json['dropDateTime']),
      estimatedFare: _toDouble(json['estimatedFare']),
      distanceKm: _toDouble(json['distanceKm']),
      tourLocations: _parseTourLocations(json['tourLocations']),
      status: (json['status'] ?? 'pending').toString(),
      paymentStatus: (json['paymentStatus'] ?? 'unpaid').toString(),
      paymentAmount: _toDouble(json['paymentAmount']),
      paymentType: _asNullableString(json['paymentType']),
      bookingCode: _asNullableString(json['bookingCode']),
      vehicleName: _parseVehicleName(json['vehicle']),
      driver: parsedDriver,
      driverId: _extractId(json['driver']),
    );
  }

  String get shortId {
    final raw = id.trim();
    if (raw.isEmpty) {
      return '#NA';
    }
    return raw.length > 8 ? '#${raw.substring(raw.length - 8).toUpperCase()}' : '#${raw.toUpperCase()}';
  }

  String get effectiveDropoffName {
    if (tripType == 'multilocation' && tourLocations != null && tourLocations!.isNotEmpty) {
      return tourLocations!.last;
    }
    return (dropoffLocationName == null || dropoffLocationName!.isEmpty) ? 'TBD' : dropoffLocationName!;
  }

  bool isAssignedTo(String currentDriverId) {
    if (currentDriverId.isEmpty) {
      return false;
    }

    final assignedId = (driverId ?? driver?.id ?? '').trim();
    return assignedId.isNotEmpty && assignedId == currentDriverId;
  }

  bool get isPending => status.toLowerCase() == 'pending';

  bool get isConfirmed => status.toLowerCase() == 'confirmed';

  bool get isCompleted => status.toLowerCase() == 'completed';

  static Driver? _parseDriver(dynamic driver) {
    if (driver is Map<String, dynamic>) {
      return Driver.fromJson(driver);
    }
    return null;
  }

  static String? _parseVehicleName(dynamic vehicle) {
    if (vehicle is Map<String, dynamic>) {
      final value = vehicle['name']?.toString();
      return (value == null || value.isEmpty) ? null : value;
    }
    return null;
  }

  static List<String>? _parseTourLocations(dynamic value) {
    if (value is! List) {
      return null;
    }

    final locations = value
        .map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString();
            if (name != null && name.isNotEmpty) {
              return name;
            }
          }
          if (item is String && item.isNotEmpty) {
            return item;
          }
          return null;
        })
        .whereType<String>()
        .toList();

    return locations.isEmpty ? null : locations;
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final raw =
        value is Map<String, dynamic> ? value['\$date']?.toString() : value.toString();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
