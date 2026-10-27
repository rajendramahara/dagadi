import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_settings.dart';
import 'auth_controller.dart';
import '../../driver/presentation/driver_navigation.dart';
import '../../driver/presentation/driver_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.role});
  final String role;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _pincode;
  Uint8List? _photo;
  Uint8List? _savedPhoto;
  String _savedName = '';
  String _savedPincode = '';
  bool _editing = false;
  String? _nameError;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: ref.read(authControllerProvider).userName ?? '');
    _pincode = TextEditingController();
    _savedName = _name.text;
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider);
    final phone = ref.watch(authControllerProvider).phone;
    final driverProfile = widget.role == 'driver'
        ? ref.watch(driverProfileProvider)
        : const AsyncData<Map<String, dynamic>>({});
    final savedRoutes = widget.role == 'driver'
        ? ref.watch(savedRoutesProvider)
        : const AsyncData<List<dynamic>>([]);
    final hasActiveRoute =
        (savedRoutes.valueOrNull ?? const <dynamic>[]).any((route) {
      final data = route as Map<String, dynamic>;
      final scheduled =
          DateTime.tryParse(data['scheduled_at']?.toString() ?? '')?.toLocal();
      return scheduled != null && !scheduled.isAfter(DateTime.now());
    });
    return Scaffold(
        appBar: AppBar(
            title: const Text('Profile'),
            automaticallyImplyLeading: widget.role != 'driver',
            actions: widget.role == 'driver'
                ? driverAppBarActions(context, profileActive: true)
                : null),
        bottomNavigationBar:
            widget.role == 'driver' ? const DriverNavigation() : null,
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                  onTap: _photo == null
                      ? null
                      : () => _showImage(context, _photo!),
                  child: CircleAvatar(
                      radius: 52,
                      backgroundImage:
                          _photo == null ? null : MemoryImage(_photo!),
                      child: _photo == null
                          ? Text(
                              (_name.text.isEmpty ? '?' : _name.text[0])
                                  .toUpperCase(),
                              style: const TextStyle(fontSize: 30))
                          : null)),
              if (_editing)
                Positioned(
                    right: -4,
                    bottom: -4,
                    child: IconButton.filledTonal(
                        style: _imageButtonStyle,
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        tooltip: 'Change profile photo')),
              if (_editing && _photo != null)
                Positioned(
                    left: -4,
                    bottom: -4,
                    child: IconButton.filledTonal(
                        style: _imageButtonStyle,
                        onPressed: _removePhoto,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove profile photo')),
            ]),
            const SizedBox(width: 20),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextField(
                    controller: _name,
                    enabled: _editing,
                    onChanged: (_) => setState(() => _nameError = null),
                    decoration: InputDecoration(
                        labelText: 'Display name',
                        isDense: true,
                        errorText: _nameError),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pincode,
                    enabled: _editing,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6)
                    ],
                    decoration: const InputDecoration(
                        labelText: 'PIN code',
                        hintText: '262501',
                        isDense: true,
                        counterText: ''),
                  ),
                ])),
          ]),
          const SizedBox(height: 16),
          if (_editing)
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _cancelEditing, child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed:
                          _name.text.trim().isEmpty ? null : _saveProfile,
                      child: const Text('Save changes'))),
            ])
          else
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'))),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Mobile number'),
            subtitle:
                Text(phone.isEmpty ? 'Not available for this session' : phone),
          ),
          const SizedBox(height: 24),
          Text('App language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _twoChoices(
            context,
            first: 'English',
            second: 'हिन्दी',
            firstSelected: locale.languageCode == 'en',
            onFirst: () =>
                ref.read(appLocaleProvider.notifier).state = const Locale('en'),
            onSecond: () =>
                ref.read(appLocaleProvider.notifier).state = const Locale('hi'),
          ),
          const SizedBox(height: 24),
          Text('Switch Role', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _twoChoices(
            context,
            first: 'Passenger',
            second: 'Driver',
            firstSelected: widget.role == 'passenger',
            onFirst: widget.role == 'passenger' ? () {} : _switchRole,
            onSecond: widget.role == 'driver' ? () {} : _switchRole,
          ),
          if (widget.role == 'driver') ...[
            const SizedBox(height: 24),
            Text('Driver status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!hasActiveRoute)
              const Text('You can change status when route is active.')
            else
              driverProfile.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    const Text('Unable to load driver status. Please refresh.'),
                data: (data) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _statusChip(
                          'passenger_parcel',
                          data['availability']?.toString(),
                          Icons.check_circle_outline,
                          'Online'),
                      const SizedBox(width: 8),
                      _statusChip(
                          'parcel_only',
                          data['availability']?.toString(),
                          Icons.inventory_2_outlined,
                          'Parcel only'),
                      const SizedBox(width: 8),
                      _statusChip('offline', data['availability']?.toString(),
                          Icons.do_not_disturb_on_outlined, 'Offline'),
                    ])),
              ),
          ],
          const SizedBox(height: 24),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: () async {
                    await ref.read(authRepositoryProvider).logout();
                    if (context.mounted) context.go('/login');
                  })),
        ]));
  }

  ButtonStyle get _imageButtonStyle => IconButton.styleFrom(
      minimumSize: const Size(34, 34), padding: const EdgeInsets.all(5));

  Widget _twoChoices(BuildContext context,
          {required String first,
          required String second,
          required bool firstSelected,
          required VoidCallback? onFirst,
          required VoidCallback? onSecond}) =>
      Row(children: [
        Expanded(child: _choiceButton(context, first, firstSelected, onFirst)),
        const SizedBox(width: 10),
        Expanded(
            child: _choiceButton(context, second, !firstSelected, onSecond)),
      ]);

  Widget _choiceButton(BuildContext context, String label, bool selected,
      VoidCallback? onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor:
                selected ? scheme.primary : scheme.onSurfaceVariant,
            side: BorderSide(
                color: selected ? scheme.primary : scheme.outlineVariant),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(label));
  }

  Widget _statusChip(String value, String? current, IconData icon, String label,
      {bool enabled = true}) {
    final selected = current == value;
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: enabled ? () => _setAvailability(value) : null,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor:
              selected && enabled ? scheme.primary : scheme.onSurfaceVariant,
          side: BorderSide(
              color:
                  selected && enabled ? scheme.primary : scheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }

  Future<void> _setAvailability(String availability) async {
    try {
      await ref.read(driverRepositoryProvider).updateAvailability(availability);
      ref.invalidate(driverProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver status updated')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not update driver status. Please sign in again.')));
      }
    }
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 65);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('profile_photo');
    _pincode.text = prefs.getString('profile_pincode') ?? '';
    _savedPincode = _pincode.text;
    if (encoded != null && mounted) {
      setState(() {
        _photo = base64Decode(encoded);
        _savedPhoto = _photo;
      });
    }
  }

  Future<void> _removePhoto() async {
    if (mounted) {
      setState(() => _photo = null);
    }
  }

  void _cancelEditing() => setState(() {
        _name.text = _savedName;
        _pincode.text = _savedPincode;
        _photo = _savedPhoto;
        _editing = false;
        _nameError = null;
      });

  Future<void> _saveProfile() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Display name is required');
      return;
    }
    final saved = await ref
        .read(authControllerProvider.notifier)
        .updateDisplayName(_name.text.trim());
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not save your name. Please sign in again and retry.'),
        ));
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_pincode', _pincode.text.trim());
      if (_photo == null) {
        await prefs.remove('profile_photo');
      } else {
        await prefs.setString('profile_photo', base64Encode(_photo!));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Profile saved, but the photo could not be stored on this device.'),
        ));
      }
    }
    if (mounted) {
      setState(() {
        _savedName = _name.text.trim();
        _savedPincode = _pincode.text.trim();
        _savedPhoto = _photo;
        _editing = false;
        _nameError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _switchRole() async {
    final nextRole = widget.role == 'driver' ? 'passenger' : 'driver';
    final ok =
        await ref.read(authControllerProvider.notifier).switchRole(nextRole);
    if (!mounted || !ok) return;
    context.go(nextRole == 'driver' ? '/driver/dashboard' : '/passenger/home');
  }
}

void _showImage(BuildContext context, Uint8List bytes) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
            child: Stack(children: [
          InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)))
        ])));
