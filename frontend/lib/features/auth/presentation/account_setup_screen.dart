import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final saving = auth.status == AuthStatus.verifying;
    final canContinue = _name.text.trim().isNotEmpty && auth.pendingCode != null;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 104),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Complete your account',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Tell us how to address you and how you want to use Dagadi.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  TextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 22),
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
                        child: Text(auth.errorMessage!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 16),
                  Text(
                      'You can change your role anytime without creating a new account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
      ))),
      bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder()),
                onPressed: saving || !canContinue ? null : _complete,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
              ))),
    );
  }

  Future<void> _complete() async {
    final auth = ref.read(authControllerProvider);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(auth.pendingCode!, name: _name.text.trim());
    if (ok && mounted) {
      context
          .go(auth.role == 'driver' ? '/driver/dashboard' : '/passenger/home');
    }
  }
}
