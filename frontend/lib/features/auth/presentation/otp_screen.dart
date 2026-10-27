import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _secondsUntilResend = 20;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    final devOtp = ref.read(authControllerProvider).devOtp;
    if (devOtp != null) {
      for (var i = 0; i < devOtp.length && i < _codeControllers.length; i++) {
        _codeControllers[i].text = devOtp[i];
      }
    }
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsUntilResend = 20);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsUntilResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend--);
    });
  }

  String get _code =>
      _codeControllers.map((controller) => controller.text).join();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.verifying;
    final scheme = Theme.of(context).colorScheme;

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
                  Text(l10n.otpTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.otpSubtitle(authState.phone)} Enter the 6-digit OTP sent by SMS.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _otpBox),
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(authState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed:
                          isLoading || _resending || _secondsUntilResend > 0
                              ? null
                              : _resendOtp,
                      icon: _resending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_outlined),
                      label: Text(_resending
                          ? 'Sending OTP…'
                          : _secondsUntilResend > 0
                              ? 'Resend OTP in ${_secondsUntilResend}s'
                              : 'Resend OTP'),
                    ),
                  ),
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
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: isLoading || _code.length != 6 ? null : _verify,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.verify),
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 46,
      height: 58,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: const InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
        maxLength: 1,
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty && index < _focusNodes.length - 1) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Future<void> _resendOtp() async {
    setState(() => _resending = true);
    await ref.read(authControllerProvider.notifier).sendOtp(
          ref.read(authControllerProvider).phone,
          name: ref.read(authControllerProvider).userName ?? '',
        );
    if (!mounted) return;
    setState(() => _resending = false);
    final state = ref.read(authControllerProvider);
    if (state.status != AuthStatus.error) _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.status == AuthStatus.error
          ? 'Could not resend OTP. Please try again.'
          : 'A new OTP has been sent.'),
    ));
  }

  Future<void> _verify() async {
    final existing =
        await ref.read(authControllerProvider.notifier).checkOtp(_code);
    if (!mounted || existing == null) return;
    if (!existing) {
      context.push('/account-setup');
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).verifyOtp(_code);
    if (ok && mounted) {
      final role = ref.read(authControllerProvider).role;
      context.go(role == 'driver' ? '/driver/dashboard' : '/passenger/home');
    }
  }
}
