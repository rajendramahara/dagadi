import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';

class SessionGateScreen extends ConsumerStatefulWidget { const SessionGateScreen({super.key}); @override ConsumerState<SessionGateScreen> createState() => _SessionGateScreenState(); }
class _SessionGateScreenState extends ConsumerState<SessionGateScreen> {
  @override void initState() { super.initState(); _open(); }
  Future<void> _open() async { final role = await ref.read(authRepositoryProvider).restoreRole(); if (mounted) context.go(role == 'driver' ? '/driver/dashboard' : role == 'passenger' ? '/passenger/home' : '/login'); }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
