// DESTINATION: lib/screens/job_detail_screen.dart
import 'dart:typed_data';
 
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../services/location.dart';
import '../widgets.dart';
import 'camera_screen.dart';
 
/// One job: what it is, who it is with, and the buttons that are allowed right now.
/// The server decides which buttons are allowed (allowed_actions), so the app
/// never offers a step the job cannot take.
class JobDetailScreen extends StatefulWidget {
  final int jobId;
 
  const JobDetailScreen({super.key, required this.jobId});
 
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}
 
class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? _job;
  String? _error;
  bool _busy = false;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    try {
      final job = await Api.instance.job(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }
 
  Future<String?> _askText(String title, String label,
      {TextInputType? keyboard, String confirm = 'OK'}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboard,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }
 
  Future<void> _act(String action) async {
    final Map<String, dynamic> body;
    final String done;
 
    if (action == 'accept') {
      final amount = await _askText(
        'Accept this job',
        'Estimated price in naira (optional)',
        keyboard: TextInputType.number,
        confirm: 'Accept',
      );
      if (amount == null) return;
      if (amount.isNotEmpty && double.tryParse(amount) == null) {
        if (mounted) showMessage(context, 'Enter the price as a number, for example 5000.', error: true);
        return;
      }
      body = {if (amount.isNotEmpty) 'estimated_amount': amount};
      done = 'Job accepted.';
    } else {
      final reason = await _askText(
        action == 'reject' ? 'Decline this job' : 'Cancel this job',
        'Reason (optional)',
        confirm: action == 'reject' ? 'Decline' : 'Cancel job',
      );
      if (reason == null) return;
      body = {'reason': reason};
      done = action == 'reject' ? 'Job declined.' : 'Job cancelled.';
    }
 
    setState(() => _busy = true);
    try {
      if (action == 'accept') {
        // Accepting records where the artisan was, as part of the safety trail
        final pos = await getCurrentPosition();
        body['lat'] = pos.latitude;
        body['lng'] = pos.longitude;
      }
      final updated = await Api.instance.jobAction(widget.jobId, action, body: body);
      if (!mounted) return;
      setState(() => _job = updated);
      showMessage(context, done);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<void> _dialog(String title, String text, {bool good = true}) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(good ? Icons.verified_user : Icons.gpp_bad,
              color: good ? Colors.green : Colors.red, size: 40),
          title: Text(title),
          content: Text(text),
          actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
 
  Future<bool> _confirm(String title, String text, String yes) async =>
      (await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(yes)),
          ],
        ),
      )) ==
      true;
 
  Future<void> _checkIn() async {
    final selfie = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraScreen(title: 'Check-in selfie', front: true)),
    );
    if (selfie == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final pos = await getCurrentPosition();
      final r = await Api.instance.checkIn(widget.jobId, selfie, pos.latitude, pos.longitude);
      if (!mounted) return;
      final score = r['match_score'] == null ? '' : '\nFace match: ${r['match_score']}%';
      if (r['verified'] == true) {
        final m = r['distance_m'];
        final where = (r['location_checked'] == true && m != null)
            ? '\nYou are about $m m from the client\'s address.'
            : '';
        if (r['job'] is Map) _job = Map<String, dynamic>.from(r['job'] as Map);
        await _dialog('Checked in', 'Your identity was confirmed. The client has been told you arrived.$score$where');
      } else {
        await _dialog('Check-in failed', '${r['error'] ?? 'Verification failed.'}$score\nThe client has been warned.',
            good: false);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<void> _review() async {
    int stars = 5;
    final ctrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Rate this artisan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setD(() => stars = i),
                      icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                    ),
                ],
              ),
              TextField(
                controller: ctrl,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (send != true) return;
    setState(() => _busy = true);
    try {
      final updated = await Api.instance.reviewJob(widget.jobId, stars, ctrl.text.trim());
      if (!mounted) return;
      setState(() => _job = updated);
      showMessage(context, 'Thank you. Your review has been saved.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<void> _simple(String action) async {
    setState(() => _busy = true);
    try {
      final Map<String, dynamic> updated;
      String done;
      if (action == 'checkout') {
        final pos = await getCurrentPosition();
        updated = await Api.instance.checkOut(widget.jobId, pos.latitude, pos.longitude);
        done = 'Checked out. The client will confirm the job is finished.';
      } else if (action == 'confirm_checkout') {
        updated = await Api.instance.confirmCheckout(widget.jobId);
        done = 'Job completed.';
      } else {
        updated = await Api.instance.resolveSos(widget.jobId);
        done = 'SOS resolved. The job has been closed.';
      }
      if (!mounted) return;
      setState(() => _job = updated);
      showMessage(context, done);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<void> _sos() async {
    final ok = await _confirm(
      'Send SOS?',
      'Your emergency contact will be emailed your name, the job address and your live location, and the other person will be alerted.',
      'Send SOS',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final pos = await getCurrentPosition();
      final r = await Api.instance.sos(widget.jobId, pos.latitude, pos.longitude);
      if (!mounted) return;
      if (r['job'] is Map) _job = Map<String, dynamic>.from(r['job'] as Map);
      await _dialog('SOS sent', (r['message'] ?? 'Alert raised.').toString(), good: r['notified'] == true);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Widget _safetyCard(Map<String, dynamic> j) {
    final theme = Theme.of(context);
    final last = j['last_checkin'];
    final out = j['checkout'];
    final failed = (j['failed_checkins'] as num?)?.toInt() ?? 0;
    final lines = <Widget>[];
    if (last is Map) {
      final ok = last['is_verified'] == true;
      lines.add(_row('Check-in', ok ? 'Verified, face match ${last['match_score']}%' : 'FAILED: ${last['reason'] ?? 'not verified'}'));
      if (last['distance_m'] != null) lines.add(_row('Distance', '${last['distance_m']} m from the address'));
      lines.add(_row('Time', shortTime(last['time'])));
      if (failed > 0) lines.add(_row('Failed tries', '$failed'));
    }
    if (out is Map) {
      lines.add(_row('Checked out', shortTime(out['time'])));
      lines.add(_row('Client confirmed', out['client_confirmed'] == true ? 'Yes' : 'Not yet'));
    }
    final rev = j['review'];
    if (rev is Map) {
      lines.add(_row('Review', '${rev['rating']} out of 5${(rev['comment'] ?? '').toString().isEmpty ? '' : ': ${rev['comment']}'}'));
    }
    if (j['sos_open'] == true) {
      lines.add(Text('An SOS alert is open on this job.',
          style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)));
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Safety record', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              ...lines,
            ],
          ),
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${widget.jobId}'),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ],
                ),
              ),
            )
          : _job == null
              ? const Center(child: CircularProgressIndicator())
              : _content(_job!),
    );
  }
 
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
 
  Widget _content(Map<String, dynamic> j) {
    final theme = Theme.of(context);
    final asClient = j['my_role'] == 'client';
    final other = (asClient ? j['artisan_display_name'] : j['client_name']).toString();
    final category = kCategories[j['category']] ?? j['category'].toString();
    final status = j['status'].toString();
    final address = j['job_address_text'];
    final phone = j['other_party_phone'];
    final amount = j['estimated_amount'];
    final actions = List<String>.from((j['allowed_actions'] as List?) ?? const []);
 
    return CenteredForm(
      maxWidth: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(category, style: theme.textTheme.titleLarge)),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          if ((j['other_party_photo'] ?? '').toString().isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    PersonAvatar(photo: j['other_party_photo'], name: other, radius: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asClient ? 'The artisan coming to you' : 'The client you will meet',
                              style: theme.textTheme.bodySmall),
                          Text(other, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Verified photo. Make sure it is the person you meet.',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('You are the', asClient ? 'client' : 'artisan'),
                  _row(asClient ? 'Artisan' : 'Client', other),
                  _row('Description', j['description'].toString()),
                  _row('Area', j['job_address_lga'].toString()),
                  if (address != null) _row('Address', address.toString()),
                  if (phone != null)
                    _row('Phone', phone.toString())
                  else
                    _row('Phone', 'Shared once the artisan accepts the job.'),
                  if (amount is num && amount > 0) _row('Estimate', '₦${amount.toStringAsFixed(0)}'),
                  _row('Requested', shortTime(j['created_at'])),
                ],
              ),
            ),
          ),
          if (!asClient && status == 'requested')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The client\'s address and phone number stay hidden until you accept.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          _safetyCard(j),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && actions.contains('checkin')) ...[
            FilledButton.icon(
              onPressed: _checkIn,
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Check in (selfie + location)'),
            ),
            const SizedBox(height: 10),
          ],
          if (!_busy && actions.contains('checkout')) ...[
            FilledButton.icon(
              onPressed: () => _simple('checkout'),
              icon: const Icon(Icons.logout),
              label: const Text('Check out (job finished)'),
            ),
            const SizedBox(height: 10),
          ],
          if (!_busy && actions.contains('confirm_checkout')) ...[
            FilledButton.icon(
              onPressed: () => _simple('confirm_checkout'),
              icon: const Icon(Icons.task_alt),
              label: const Text('Confirm job is finished'),
            ),
            const SizedBox(height: 10),
          ],
          if (!_busy && actions.contains('review')) ...[
            FilledButton.icon(
              onPressed: _review,
              icon: const Icon(Icons.star),
              label: const Text('Rate this artisan'),
            ),
            const SizedBox(height: 10),
          ],
          if (!_busy && actions.contains('resolve_sos')) ...[
            FilledButton.icon(
              onPressed: () => _simple('resolve_sos'),
              icon: const Icon(Icons.health_and_safety),
              label: const Text('I am safe - resolve SOS'),
            ),
            const SizedBox(height: 10),
          ],
          if (!_busy && actions.contains('accept'))
            FilledButton.icon(
              onPressed: () => _act('accept'),
              icon: const Icon(Icons.check),
              label: const Text('Accept job'),
            ),
          if (!_busy && actions.contains('reject')) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _act('reject'),
              icon: const Icon(Icons.close),
              label: const Text('Decline'),
            ),
          ],
          if (!_busy && actions.contains('cancel')) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _act('cancel'),
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel job'),
            ),
          ],
          if (!_busy && actions.contains('sos')) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _sos,
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              icon: const Icon(Icons.sos),
              label: const Text('SOS - I need help'),
            ),
          ],
        ],
      ),
    );
  }
}