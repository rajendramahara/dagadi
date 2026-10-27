import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'driver_providers.dart';
import 'driver_navigation.dart';
import 'fleet_setup_screen.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});
  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  static final _registrationFormat =
      RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$');
  final _reg = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  Uint8List? _frontPhoto;
  bool _adding = false;
  String? _error;
  int _section = 0;

  bool get _isRegistrationValid =>
      _registrationFormat.hasMatch(_reg.text.trim().toUpperCase());
  bool get _canSave => _isRegistrationValid;

  @override
  void dispose() {
    _reg.dispose();
    _model.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 700, imageQuality: 65);
      return image?.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final fleets = ref.watch(fleetsProvider);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Vehicle management'),
          automaticallyImplyLeading: false,
          actions: driverAppBarActions(context, vehiclesActive: true)),
      bottomNavigationBar: const DriverNavigation(),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Fleet')),
              ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.directions_car_outlined),
                  label: Text('Vehicles')),
            ],
            selected: {_section},
            onSelectionChanged: (value) =>
                setState(() => _section = value.first),
          ),
        ),
        Expanded(
            child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vehiclesProvider);
            ref.invalidate(fleetsProvider);
          },
          child:
              _section == 0 ? _fleetSection(fleets) : _vehicleSection(vehicles),
        )),
      ]),
    );
  }

  Widget _fleetSection(AsyncValue<List<dynamic>> fleets) => fleets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _emptySection(Icons.groups_outlined,
          'Could not load fleets', 'Create fleet', _openFleetSheet),
      data: (list) => list.isEmpty
          ? _emptySection(Icons.groups_outlined, 'Create your first fleet',
              'Create fleet', _openFleetSheet,
              subtitle: 'Assign a Dagadi driver after creating it.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                          onPressed: _openFleetSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Create fleet')));
                }
                final fleet = list[index - 1] as Map<String, dynamic>;
                return Card(
                    child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.groups_outlined)),
                  title: Text(fleet['name']?.toString() ?? 'Fleet'),
                  subtitle: Text(fleet['assigned_driver_name'] == null
                      ? 'No driver assigned'
                      : '${fleet['assigned_driver_name']} · ${fleet['assigned_driver_phone']}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _openFleetSheet(fleet),
                ));
              }));

  Widget _vehicleSection(AsyncValue<List<dynamic>> vehicles) => vehicles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _emptySection(
          Icons.directions_car_outlined,
          'Could not load vehicles',
          'Add vehicle',
          () => _showAddSheet(context)),
      data: (list) => list.isEmpty
          ? _emptySection(
              Icons.directions_car_outlined,
              'Add your first vehicle',
              'Add vehicle',
              () => _showAddSheet(context),
              subtitle: 'A vehicle is required before you can create a route.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                          onPressed: () => _showAddSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add vehicle')));
                }
                final vehicle = list[index - 1] as Map<String, dynamic>;
                return _VehicleCard(
                    vehicle: vehicle,
                    onEdit: () => _showAddSheet(context, vehicle: vehicle));
              }));

  Widget _emptySection(
          IconData icon, String title, String action, VoidCallback onPressed,
          {String? subtitle}) =>
      ListView(children: [
        const SizedBox(height: 140),
        Icon(icon, size: 56),
        const SizedBox(height: 12),
        Center(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (subtitle != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
              child: Text(subtitle, textAlign: TextAlign.center)),
        const SizedBox(height: 20),
        Center(
            child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: Text(action))),
      ]);

  Future<void> _openFleetSheet([Map<String, dynamic>? fleet]) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .78,
            child: FleetSetupScreen(fleet: fleet, embedded: true)));
    ref.invalidate(fleetsProvider);
  }

  void _showAddSheet(BuildContext context, {Map<String, dynamic>? vehicle}) {
    final editing = vehicle != null;
    _reg.text = vehicle?['registration_no']?.toString() ?? '';
    _model.text = vehicle?['model']?.toString() ?? '';
    _color.text = vehicle?['color']?.toString() ?? '';
    _frontPhoto = null;
    String? sheetError;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) => SafeArea(
                    child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 20),
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(editing ? 'Edit vehicle' : 'Add vehicle',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        Center(
                            child: Stack(clipBehavior: Clip.none, children: [
                          GestureDetector(
                              onTap: _frontPhoto == null
                                  ? null
                                  : () => _showVehicleImage(
                                      sheetContext, _frontPhoto!),
                              child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  backgroundImage: _frontPhoto == null
                                      ? null
                                      : MemoryImage(_frontPhoto!),
                                  child: _frontPhoto == null
                                      ? const Icon(
                                          Icons.directions_car_outlined,
                                          size: 42)
                                      : null)),
                          Positioned(
                              right: -2,
                              bottom: -2,
                              child: IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                      minimumSize: const Size(34, 34),
                                      padding: const EdgeInsets.all(5)),
                                  onPressed: () async {
                                    final photo = await _pickPhoto();
                                    setSheetState(() {
                                      if (photo == null) {
                                        sheetError =
                                            'Could not select an image. Please choose a photo from your device.';
                                      } else {
                                        _frontPhoto = photo;
                                        sheetError = null;
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.camera_alt_outlined,
                                      size: 18),
                                  tooltip: 'Choose front vehicle photo')),
                          if (_frontPhoto != null)
                            Positioned(
                                left: -2,
                                bottom: -2,
                                child: IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                        minimumSize: const Size(28, 28),
                                        padding: const EdgeInsets.all(3)),
                                    onPressed: () =>
                                        setSheetState(() => _frontPhoto = null),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 15),
                                    tooltip: 'Remove photo'))
                        ])),
                        const SizedBox(height: 8),
                        const Center(
                            child: Text(
                                'Upload a clear front photo showing the vehicle and registration plate.',
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _reg,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [_IndianRegistrationFormatter()],
                            onChanged: (_) => setSheetState(() {
                                  sheetError = null;
                                }),
                            decoration: InputDecoration(
                                labelText: 'Registration number',
                                hintText: 'UK04TB1343',
                                errorText: _reg.text.isNotEmpty &&
                                        !_isRegistrationValid
                                    ? 'Use format UK04TB1343'
                                    : null)),
                        const SizedBox(height: 10),
                        TextField(
                            controller: _model,
                            decoration: const InputDecoration(
                                labelText: 'Vehicle model')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: _color,
                            decoration:
                                const InputDecoration(labelText: 'Colour')),
                        if ((sheetError ?? _error) != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(sheetError ?? _error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 16),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: _adding || !_canSave
                                    ? null
                                    : () =>
                                        _submit(sheetContext, vehicle: vehicle),
                                child: _adding
                                    ? const CircularProgressIndicator()
                                    : Text(editing
                                        ? 'Save changes'
                                        : 'Save vehicle'))),
                      ])),
                ))));
  }

  Future<void> _submit(BuildContext sheetContext,
      {Map<String, dynamic>? vehicle}) async {
    if (!_canSave) {
      setState(() => _error = 'Use registration format UK04TB1343.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final savedVehicle = vehicle == null
          ? await ref.read(driverRepositoryProvider).createVehicle(
              registrationNo: _reg.text.trim().toUpperCase(),
              model: _model.text.trim(),
              color: _color.text.trim())
          : await ref.read(driverRepositoryProvider).updateVehicle(
              id: vehicle['id'] as String,
              registrationNo: _reg.text.trim().toUpperCase(),
              model: _model.text.trim(),
              color: _color.text.trim());
      var photoStored = true;
      if (_frontPhoto != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('vehicle_photo_${savedVehicle['id']}',
              base64Encode(_frontPhoto!));
        } catch (_) {
          photoStored = false;
        }
      }
      _reg.clear();
      _model.clear();
      _color.clear();
      _frontPhoto = null;
      ref.invalidate(vehiclesProvider);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted && !photoStored) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Vehicle saved, but its photo could not be stored on this device.'),
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onEdit});
  final Map<String, dynamic> vehicle;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (_, snapshot) {
                  final encoded = snapshot.data
                      ?.getString('vehicle_photo_${vehicle['id']}');
                  final avatar = CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: encoded == null
                          ? null
                          : MemoryImage(base64Decode(encoded)),
                      child: encoded == null
                          ? const Icon(Icons.directions_car_outlined, size: 32)
                          : null);
                  return encoded == null
                      ? avatar
                      : GestureDetector(
                          onTap: () =>
                              _showVehicleImage(context, base64Decode(encoded)),
                          child: avatar);
                }),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text((vehicle['model'] ?? 'Vehicle').toString(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text((vehicle['registration_no'] ?? '').toString(),
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text('${vehicle['color'] ?? 'Colour not set'}',
                      style: Theme.of(context).textTheme.bodySmall)
                ])),
            IconButton(
                tooltip: 'Edit vehicle',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined)),
          ])));
}

void _showVehicleImage(BuildContext context, Uint8List bytes) =>
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
                child: Stack(children: [
              InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain)),
              Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)))
            ])));

class _IndianRegistrationFormatter extends TextInputFormatter {
  static final _positions = <bool>[
    true,
    true,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    false
  ];

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final source = newValue.text.toUpperCase();
    final result = StringBuffer();
    for (final char in source.characters) {
      if (result.length == _positions.length) break;
      final expectsLetter = _positions[result.length];
      final valid = expectsLetter
          ? RegExp(r'[A-Z]').hasMatch(char)
          : RegExp(r'[0-9]').hasMatch(char);
      if (valid) result.write(char);
    }
    final text = result.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
