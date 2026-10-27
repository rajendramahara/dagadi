import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import 'passenger_controller.dart';

class RideRequestScreen extends ConsumerStatefulWidget {
  const RideRequestScreen({required this.match, required this.form, super.key});
  final JourneyMatch match;
  final SearchFormState form;

  @override
  ConsumerState<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends ConsumerState<RideRequestScreen> {
  final _noteController = TextEditingController();
  final _weightController = TextEditingController();
  final _sizeController = TextEditingController();
  int _passengerCount = 1;
  Uint8List? _parcelImage;
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final form = widget.form;
    final match = widget.match;
    final isParcel = form.bookingType == 'parcel';

    return Scaffold(
      appBar: AppBar(title: Text(isParcel ? 'Send parcel' : 'Confirm ride')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your journey', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      _RouteRow(
                          icon: Icons.trip_origin,
                          label: l10n.pickup,
                          value: form.fromName),
                      const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(Icons.more_vert, size: 16))),
                      _RouteRow(
                          icon: Icons.location_on,
                          label: l10n.drop,
                          value: form.toName),
                    ]))),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            if (isParcel) ...[
              Text('Parcel details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Approximate weight (kg)',
                      hintText: 'For example, 2.5')),
              const SizedBox(height: 8),
              TextField(
                  controller: _sizeController,
                  decoration: const InputDecoration(
                      labelText: 'Parcel size',
                      hintText: 'Small bag, medium box, etc.')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: _pickParcelImage,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(_parcelImage == null
                      ? 'Upload parcel image'
                      : 'Parcel image added')),
              if (_parcelImage != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_parcelImage!,
                              height: 100, width: 140, fit: BoxFit.cover)),
                      IconButton(
                          onPressed: () => setState(() => _parcelImage = null),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove parcel photo')
                    ])),
            ] else ...[
              Text('Passengers',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4+'))
                  ],
                  selected: {
                    _passengerCount
                  },
                  onSelectionChanged: (value) =>
                      setState(() => _passengerCount = value.first)),
            ],
            const SizedBox(height: 20),
            Card(
                child: ListTile(
                    leading: CircleAvatar(
                        child: Text(match.driverName.isEmpty
                            ? '?'
                            : match.driverName[0])),
                    title: Text(match.driverName),
                    subtitle:
                        Text('${match.vehicleModel} · ${match.vehicleRegNo}'),
                    trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${match.distanceKm.toStringAsFixed(1)} km'),
                          const Icon(Icons.star, size: 14, color: Colors.amber)
                        ]))),
            const SizedBox(height: 20),
            TextField(
              controller: _noteController,
              decoration:
                  InputDecoration(labelText: l10n.note, hintText: l10n.addNote),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton(
            style:
                FilledButton.styleFrom(shape: const RoundedRectangleBorder()),
            onPressed: _sending ? null : () => _submit(context, form, match),
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.sendRequest),
          )),
    );
  }

  Future<void> _submit(
      BuildContext context, SearchFormState form, JourneyMatch match) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final repo = ref.read(passengerRepositoryProvider);
      await repo.createRequest(
        journeyId: match.journeyId,
        bookingType: form.bookingType,
        pickupName: form.fromName,
        pickup: form.pickup!,
        pickupSequence: match.pickupSequence,
        dropName: form.toName,
        drop: form.drop!,
        dropSequence: match.dropSequence,
        note: _noteController.text,
        passengerCount: _passengerCount,
        parcelWeightKg: double.tryParse(_weightController.text.trim()),
        parcelSize: _sizeController.text.trim(),
        parcelImageData:
            _parcelImage == null ? '' : base64Encode(_parcelImage!),
      );
      if (context.mounted) context.go('/passenger/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickParcelImage() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _parcelImage = bytes);
    }
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value.isEmpty ? '-' : value,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
