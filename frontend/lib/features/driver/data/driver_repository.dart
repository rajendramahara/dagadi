import '../../../core/network/api_client.dart';

class DriverRepository {
  DriverRepository(this._client);
  final ApiClient _client;

  Future<List<dynamic>> savedRoutes() async {
    final res = await _client.get('/api/v1/driver/routes/saved');
    return (res.data['data'] as List?) ?? [];
  }

  Future<List<dynamic>> activeJourneys() async {
    final res = await _client.get('/api/v1/driver/journeys/active');
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> createRoute({
    required String name,
    required bool isSaved,
    required List<Map<String, dynamic>> stops,
    required DateTime scheduledAt,
  }) async {
    final res = await _client.post('/api/v1/driver/routes', data: {
      'name': name,
      'is_saved': isSaved,
      'stops': stops,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> deleteRoute(String routeId) =>
      _client.delete('/api/v1/driver/routes/$routeId');

  Future<Map<String, dynamic>> updateRoute({
    required String id,
    required String name,
    required List<Map<String, dynamic>> stops,
    required DateTime scheduledAt,
  }) async {
    final res = await _client.put('/api/v1/driver/routes/$id', data: {
      'name': name,
      'is_saved': true,
      'stops': stops,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startJourney({
    required String routeId,
    required String vehicleId,
    DateTime? departureTime,
  }) async {
    final res = await _client.post('/api/v1/driver/journeys', data: {
      'route_id': routeId,
      'vehicle_id': vehicleId,
      'departure_time':
          (departureTime ?? DateTime.now()).toUtc().toIso8601String(),
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateJourneyPosition({
    required String journeyId,
    required double latitude,
    required double longitude,
  }) =>
      _client.post('/api/v1/driver/journeys/$journeyId/position', data: {
        'latitude': latitude,
        'longitude': longitude,
      });

  Future<void> updateAvailability(String availability) async {
    await _client.patch('/api/v1/driver/availability',
        data: {'availability': availability});
  }

  Future<Map<String, dynamic>> profile() async {
    final res = await _client.get('/api/v1/driver/profile');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> incomingRequests() async {
    final res = await _client.get('/api/v1/driver/requests');
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> acceptBooking(String bookingId) async {
    final res = await _client.post('/api/v1/driver/bookings/$bookingId/accept');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> rejectBooking(String bookingId) async {
    await _client.post('/api/v1/driver/bookings/$bookingId/reject');
  }

  Future<List<dynamic>> pendingTickets() async {
    final res = await _client.get('/api/v1/driver/tickets/pending');
    return (res.data['data'] as List?) ?? [];
  }

  Future<void> completeTicket({
    required String ticketId,
    required int farePaise,
    required String paymentMethod,
    String notes = '',
  }) async {
    await _client.post('/api/v1/driver/tickets/$ticketId/complete', data: {
      'fare_paise': farePaise,
      'payment_method': paymentMethod,
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> revenueDashboard() async {
    final res = await _client.get('/api/v1/driver/revenue');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listVehicles() async {
    final res = await _client.get('/api/v1/driver/vehicles');
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> createVehicle({
    required String registrationNo,
    required String model,
    required String color,
    int capacity = 4,
  }) async {
    final res = await _client.post('/api/v1/driver/vehicles', data: {
      'registration_no': registrationNo,
      'model': model,
      'color': color,
      'capacity': capacity,
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateVehicle({
    required String id,
    required String registrationNo,
    required String model,
    required String color,
    int capacity = 4,
  }) async {
    final res = await _client.put('/api/v1/driver/vehicles/$id', data: {
      'registration_no': registrationNo,
      'model': model,
      'color': color,
      'capacity': capacity,
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createFleet(String name) async {
    final res =
        await _client.post('/api/v1/driver/fleets', data: {'name': name});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateFleet({required String id, required String name}) =>
      _client.put('/api/v1/driver/fleets/$id', data: {'name': name});

  Future<List<dynamic>> fleets() async {
    final res = await _client.get('/api/v1/driver/fleets');
    return (res.data['data'] as List?) ?? [];
  }

  Future<void> deleteFleet(String id) =>
      _client.delete('/api/v1/driver/fleets/$id');

  Future<void> assignDriverByPhone(
          {required String vehicleId, required String phone}) =>
      _client.post('/api/v1/driver/fleets/assign-by-phone',
          data: {'vehicle_id': vehicleId, 'phone': phone});

  Future<void> assignDriverToFleet(
          {required String fleetId, required String phone}) =>
      _client.post('/api/v1/driver/fleets/assign-driver',
          data: {'fleet_id': fleetId, 'phone': phone});

  Future<void> addVehicleToFleet(
          {required String vehicleId, required String fleetId}) =>
      _client.post('/api/v1/driver/fleets/add-vehicle',
          data: {'vehicle_id': vehicleId, 'fleet_id': fleetId});
}
