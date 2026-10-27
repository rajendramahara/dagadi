import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final saving = auth.status == AuthStatus.verifying;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose how to continue')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'Welcome back${auth.userName?.isNotEmpty == true ? ', ${auth.userName}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(auth.phone),
                  const SizedBox(height: 28),
                  Text('Continue as',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'passenger',
                            icon: Icon(Icons.person_outline),
                            label: Text('Passenger')),
                        ButtonSegment(
                            value: 'driver',
                            icon: Icon(Icons.drive_eta_outlined),
                            label: Text('Driver'))
                      ],
                      selected: {
                        auth.role
                      },
                      onSelectionChanged: saving
                          ? null
                          : (value) => ref
                              .read(authControllerProvider.notifier)
                              .setRole(value.first)),
                  if (auth.errorMessage != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text('Could not switch role. Please try again.',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                ])),
      ))),
      bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder()),
                onPressed: saving ? null : () => _continue(context, ref),
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
              ))),
    );
  }

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final role = ref.read(authControllerProvider).role;
    final ok = await ref.read(authControllerProvider.notifier).switchRole(role);
    if (ok && context.mounted) {
      context.go(role == 'driver' ? '/driver/dashboard' : '/passenger/home');
    }
  }
}
