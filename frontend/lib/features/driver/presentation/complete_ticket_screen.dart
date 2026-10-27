import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'driver_providers.dart';
import 'driver_navigation.dart';

class CompleteTicketScreen extends ConsumerStatefulWidget {
  const CompleteTicketScreen({required this.ticket, super.key});
  final Map<String, dynamic> ticket;

  @override
  ConsumerState<CompleteTicketScreen> createState() =>
      _CompleteTicketScreenState();
}

class _CompleteTicketScreenState extends ConsumerState<CompleteTicketScreen> {
  final _fareController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fareController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.completeTicket),
          automaticallyImplyLeading: false,
          actions: driverAppBarActions(context)),
      bottomNavigationBar: const DriverNavigation(currentIndex: 3),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Per spec: the driver is never forced to complete a ticket
            // immediately - this screen can be opened minutes, hours, or
            // a day after the ride was accepted. Nothing here blocks that.
            Card(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only completed tickets count toward earnings. Complete anytime.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _fareController,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.fare, prefixText: '₹ '),
            ),
            const SizedBox(height: 16),
            Text(l10n.paymentMethod,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'cash',
                    label: Text(l10n.cash),
                    icon: const Icon(Icons.money)),
                ButtonSegment(
                    value: 'upi',
                    label: Text(l10n.upi),
                    icon: const Icon(Icons.qr_code)),
                ButtonSegment(value: 'other', label: Text(l10n.other)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) =>
                  setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration:
                  InputDecoration(labelText: l10n.note, hintText: l10n.addNote),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.completeTicket),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final fareRupees = double.tryParse(_fareController.text.trim());
    if (fareRupees == null || fareRupees < 0) {
      setState(() => _error = 'Enter a valid fare amount');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(driverRepositoryProvider).completeTicket(
            ticketId: widget.ticket['id'] as String,
            farePaise: (fareRupees * 100).round(),
            paymentMethod: _paymentMethod,
            notes: _notesController.text,
          );
      ref.invalidate(pendingTicketsProvider);
      ref.invalidate(revenueDashboardProvider);
      if (mounted) context.go('/driver/dashboard');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
