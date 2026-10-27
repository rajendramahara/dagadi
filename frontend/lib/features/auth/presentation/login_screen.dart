import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _canSend => RegExp(r'^\d{10}$').hasMatch(_phone.text.trim());

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.status == AuthStatus.sendingOtp;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.route_outlined,
                        size: 40, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome to Dagadi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Join a journey. Send a parcel. Be “दगड़ी”.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 42),
                  TextField(
                    controller: _phone,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10)
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '0000000000',
                        prefixIconConstraints: BoxConstraints(minWidth: 84),
                        prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('🇮🇳'),
                              SizedBox(width: 6),
                              Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                            ]))),
                  ),
                  if (auth.errorMessage != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text('Could not send OTP. Please try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.error))),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 18),
        child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(shape: const RoundedRectangleBorder()),
              onPressed: loading || !_canSend ? null : _send,
              icon: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sms_outlined),
              label: Text(loading ? 'Sending OTP…' : 'Send OTP'),
            )),
      ),
    );
  }

  Future<void> _send() async {
    await ref
        .read(authControllerProvider.notifier)
        .sendOtp('+91${_phone.text.trim()}', name: '');
    if (mounted &&
        ref.read(authControllerProvider).status != AuthStatus.error) {
      context.push('/otp');
    }
  }
}
