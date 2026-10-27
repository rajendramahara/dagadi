class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class JourneyMatch {
  JourneyMatch({
    required this.journeyId,
    required this.driverName,
    required this.driverRating,
    required this.vehicleModel,
    required this.vehicleRegNo,
    required this.availability,
    required this.distanceMeters,
    required this.pickupSequence,
    required this.dropSequence,
    required this.departureTime,
    required this.estimatedPickupTime,
  });

  final String journeyId;
  final String driverName;
  final double driverRating;
  final String vehicleModel;
  final String vehicleRegNo;
  final String availability;
  final double distanceMeters;
  final int pickupSequence;
  final int dropSequence;
  final DateTime departureTime;
  final DateTime estimatedPickupTime;

  factory JourneyMatch.fromJson(Map<String, dynamic> json) {
    final journey = json['journey'] as Map<String, dynamic>;
    return JourneyMatch(
      journeyId: journey['id'] as String,
      driverName: json['driver_name'] as String,
      driverRating: (json['driver_rating'] as num).toDouble(),
      vehicleModel: json['vehicle_model'] as String,
      vehicleRegNo: json['vehicle_reg_no'] as String,
      availability: json['availability'] as String,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      pickupSequence: json['pickup_sequence'] as int,
      dropSequence: json['drop_sequence'] as int,
      departureTime:
          DateTime.parse(journey['departure_time'] as String).toLocal(),
      estimatedPickupTime:
          DateTime.parse(json['estimated_pickup_time'] as String),
    );
  }

  double get distanceKm => distanceMeters / 1000;
}

class BookingResult {
  BookingResult({required this.id, required this.status});
  final String id;
  final String status;

  factory BookingResult.fromJson(Map<String, dynamic> json) =>
      BookingResult(id: json['id'] as String, status: json['status'] as String);
}
