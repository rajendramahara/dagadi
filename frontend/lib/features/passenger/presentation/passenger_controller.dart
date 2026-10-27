import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/models.dart';
import '../data/passenger_repository.dart';

final passengerRepositoryProvider = Provider<PassengerRepository>((ref) {
  return PassengerRepository(ref.watch(apiClientProvider));
});

final passengerBookingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(passengerRepositoryProvider).bookings();
});

class SearchFormState {
  const SearchFormState({
    this.fromName = '',
    this.toName = '',
    this.pickup,
    this.drop,
    this.requestedTime,
    this.bookingType = 'ride',
  });

  final String fromName;
  final String toName;
  final LatLngPoint? pickup;
  final LatLngPoint? drop;
  final DateTime? requestedTime;
  final String bookingType; // 'ride' | 'parcel'

  SearchFormState copyWith({
    String? fromName,
    String? toName,
    LatLngPoint? pickup,
    LatLngPoint? drop,
    DateTime? requestedTime,
    String? bookingType,
  }) {
    return SearchFormState(
      fromName: fromName ?? this.fromName,
      toName: toName ?? this.toName,
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      requestedTime: requestedTime ?? this.requestedTime,
      bookingType: bookingType ?? this.bookingType,
    );
  }

  bool get isReady => pickup != null && drop != null;
}

final searchFormProvider = StateProvider<SearchFormState>((ref) => const SearchFormState());

enum SearchStatus { idle, loading, success, empty, error }

class SearchResultsState {
  const SearchResultsState({this.status = SearchStatus.idle, this.matches = const [], this.error});
  final SearchStatus status;
  final List<JourneyMatch> matches;
  final String? error;
}

class SearchResultsController extends StateNotifier<SearchResultsState> {
  SearchResultsController(this._repo) : super(const SearchResultsState());
  final PassengerRepository _repo;

  Future<void> search(SearchFormState form) async {
    if (!form.isReady) return;
    state = const SearchResultsState(status: SearchStatus.loading);
    try {
      final matches = await _repo.searchDrivers(
        pickup: form.pickup!,
        drop: form.drop!,
        bookingType: form.bookingType,
        requestedTime: form.requestedTime,
      );
      state = SearchResultsState(
        status: matches.isEmpty ? SearchStatus.empty : SearchStatus.success,
        matches: matches,
      );
    } catch (e) {
      state = SearchResultsState(status: SearchStatus.error, error: e.toString());
    }
  }
}

final searchResultsProvider = StateNotifierProvider<SearchResultsController, SearchResultsState>((ref) {
  return SearchResultsController(ref.watch(passengerRepositoryProvider));
});
