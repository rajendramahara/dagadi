import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'driver_providers.dart';
import 'driver_navigation.dart';

class FleetSetupScreen extends ConsumerStatefulWidget {
  const FleetSetupScreen({super.key, this.fleet, this.embedded = false});
  final Map<String, dynamic>? fleet;
  final bool embedded;

  @override
  ConsumerState<FleetSetupScreen> createState() => _FleetSetupScreenState();
}

class _FleetSetupScreenState extends ConsumerState<FleetSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _message;

  bool get _editing => widget.fleet != null;
  bool get _hasValidPhone => RegExp(r'^\d{10}$').hasMatch(_phone.text.trim());

  @override
  void initState() {
    super.initState();
    _name.text = widget.fleet?['name']?.toString() ?? '';
    _phone.text = (widget.fleet?['assigned_driver_phone']?.toString() ?? '')
        .replaceFirst(RegExp(r'^\+91'), '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(_editing ? 'Edit fleet' : 'Create fleet'),
              automaticallyImplyLeading: false,
              actions: driverAppBarActions(context)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_editing ? 'Edit fleet information' : 'Fleet information',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Set up the fleet and assign its Dagadi driver in one place.'),
          const SizedBox(height: 20),
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Fleet name',
                  hintText: 'For example, Kumaon Travels')),
          const SizedBox(height: 28),
          Text('Assign a driver',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
              'The driver manages and adds vehicles from their own Dagadi account.'),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
                labelText: 'Driver mobile number',
                hintText: '9876543210',
                prefixIconConstraints: const BoxConstraints(minWidth: 84),
                prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('🇮🇳'),
                      SizedBox(width: 6),
                      Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                    ])),
                errorText: _phone.text.isNotEmpty && !_hasValidPhone
                    ? 'Enter a 10-digit mobile number'
                    : null,
                helperText:
                    'Use the mobile number on the driver’s Dagadi account.'),
            onChanged: (_) => setState(() => _message = null),
          ),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_editing ? 'Save changes' : 'Create fleet'),
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded ? null : const DriverNavigation(),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _message = 'Enter a fleet name.');
      return;
    }
    if (_phone.text.isNotEmpty && !_hasValidPhone) {
      setState(() => _message = 'Enter a valid 10-digit driver mobile number.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final fleet = _editing
          ? widget.fleet!
          : await ref
              .read(driverRepositoryProvider)
              .createFleet(_name.text.trim());
      if (_editing)
        await ref
            .read(driverRepositoryProvider)
            .updateFleet(id: fleet['id'] as String, name: _name.text.trim());
      if (_phone.text.trim().isNotEmpty) {
        await ref.read(driverRepositoryProvider).assignDriverToFleet(
            fleetId: fleet['id'] as String, phone: '+91${_phone.text.trim()}');
      }
      ref.invalidate(fleetsProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _message =
            'Could not create this fleet. Confirm the driver has a Dagadi driver account and the phone number is correct.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
