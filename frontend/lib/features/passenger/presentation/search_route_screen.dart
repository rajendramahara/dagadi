import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_picker_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../presentation/passenger_controller.dart';

class SearchRouteScreen extends ConsumerStatefulWidget {
  const SearchRouteScreen({super.key});

  @override
  ConsumerState<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends ConsumerState<SearchRouteScreen> {
  LocationSelection? _from;
  LocationSelection? _to;
  bool _travelLater = false;
  DateTime? _requestedTime;

  Future<void> _choose({required bool pickup}) async {
    final selection =
        await Navigator.of(context).push<LocationSelection>(MaterialPageRoute(
      builder: (_) => LocationPickerScreen(
          title: pickup ? 'Choose pickup location' : 'Choose destination',
          initial: pickup ? _from : _to,
          allowMapSelection: pickup),
    ));
    if (selection != null && mounted) {
      setState(() {
        if (pickup) {
          _from = selection;
        } else {
          _to = selection;
        }
      });
    }
  }

  Future<void> _chooseTravelTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 90)),
        initialDate: _requestedTime ?? now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_requestedTime ?? now));
    if (time != null && mounted)
      setState(() => _requestedTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final form = ref.watch(searchFormProvider);
    final results = ref.watch(searchResultsProvider);
    final canSearch = results.status != SearchStatus.loading &&
        _from != null &&
        _to != null &&
        (!_travelLater || _requestedTime != null);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan your journey')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Where and when?',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _LocationField(
              label: l10n.from,
              icon: Icons.trip_origin,
              value: _from?.name,
              onTap: () => _choose(pickup: true)),
          const SizedBox(height: 12),
          _LocationField(
              label: l10n.to,
              icon: Icons.location_on_outlined,
              value: _to?.name,
              onTap: () => _choose(pickup: false)),
          const SizedBox(height: 8),
          Text(
              'For pickup, you can search, use the map, or use your current location.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Text(l10n.travelTime, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.now)),
                ButtonSegment(value: true, label: Text(l10n.later))
              ],
              selected: {
                _travelLater
              },
              onSelectionChanged: (value) => setState(() {
                    _travelLater = value.first;
                    if (!_travelLater) _requestedTime = null;
                  })),
          if (_travelLater) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: _chooseTravelTime,
                icon: const Icon(Icons.schedule),
                label: Text(_requestedTime == null
                    ? 'Choose travel date and time'
                    : 'Travel: ${MaterialLocalizations.of(context).formatMediumDate(_requestedTime!)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_requestedTime!))}')),
            const SizedBox(height: 4),
            Text(
                'We show drivers whose journey timing can serve your selected time.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (results.status == SearchStatus.error)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.networkError,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton.icon(
            style:
                FilledButton.styleFrom(shape: const RoundedRectangleBorder()),
            onPressed: !canSearch
                ? null
                : () async {
                    final updated = form.copyWith(
                        fromName: _from!.name,
                        toName: _to!.name,
                        pickup: _from!.point,
                        drop: _to!.point,
                        requestedTime: _requestedTime);
                    ref.read(searchFormProvider.notifier).state = updated;
                    await ref
                        .read(searchResultsProvider.notifier)
                        .search(updated);
                    if (context.mounted)
                      context.push('/passenger/nearby-drivers');
                  },
            icon: results.status == SearchStatus.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(results.status == SearchStatus.loading
                ? 'Finding drivers…'
                : 'See matching drivers')),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onTap});
  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextField(
        readOnly: true,
        onTap: onTap,
        controller: TextEditingController(text: value ?? ''),
        decoration: InputDecoration(
            labelText: label,
            hintText: 'Choose location',
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.map_outlined)),
      );
}
