import '../../../core/network/api_client.dart';
import 'models.dart';

class PassengerRepository {
  PassengerRepository(this._client);
  final ApiClient _client;

  Future<List<JourneyMatch>> searchDrivers({
    required LatLngPoint pickup,
    required LatLngPoint drop,
    String bookingType = 'ride',
    DateTime? requestedTime,
  }) async {
    final res = await _client.post('/api/v1/passenger/search', data: {
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'drop_lat': drop.lat,
      'drop_lng': drop.lng,
      'booking_type': bookingType,
      if (requestedTime != null) 'requested_time': requestedTime.toIso8601String(),
    });
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => JourneyMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BookingResult> createRequest({
    required String journeyId,
    required String bookingType,
    required String pickupName,
    required LatLngPoint pickup,
    required int pickupSequence,
    required String dropName,
    required LatLngPoint drop,
    required int dropSequence,
    String note = '',
    int passengerCount = 1,
    double? parcelWeightKg,
    String parcelSize = '',
    String parcelImageData = '',
  }) async {
    final res = await _client.post('/api/v1/passenger/requests', data: {
      'journey_id': journeyId,
      'booking_type': bookingType,
      'pickup_name': pickupName,
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'pickup_sequence': pickupSequence,
      'drop_name': dropName,
      'drop_lat': drop.lat,
      'drop_lng': drop.lng,
      'drop_sequence': dropSequence,
      'note': note,
      'passenger_count': passengerCount,
      if (parcelWeightKg != null) 'parcel_weight_kg': parcelWeightKg,
      'parcel_size': parcelSize,
      'parcel_image_data': parcelImageData,
    });
    return BookingResult.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<dynamic>> bookings() async {
    final res = await _client.get('/api/v1/passenger/bookings');
    return (res.data['data'] as List?) ?? [];
  }
}
