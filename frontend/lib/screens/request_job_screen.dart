// DESTINATION: lib/screens/request_job_screen.dart
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../services/location.dart';
import '../widgets.dart';
import 'job_detail_screen.dart';
 
/// A client describes the job and sends it to one artisan.
class RequestJobScreen extends StatefulWidget {
  /// One item from the artisan list (needs 'id', 'display_name' or 'business_name', 'category').
  final Map<String, dynamic> artisan;
 
  const RequestJobScreen({super.key, required this.artisan});
 
  @override
  State<RequestJobScreen> createState() => _RequestJobScreenState();
}
 
class _RequestJobScreenState extends State<RequestJobScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _lga = TextEditingController(text: 'Nsukka');
  final _description = TextEditingController();
 
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _busy = false;
 
  @override
  void dispose() {
    _address.dispose();
    _lga.dispose();
    _description.dispose();
    super.dispose();
  }
 
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
 
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final job = await Api.instance.requestJob({
        'artisan_profile': widget.artisan['id'],
        'job_address_text': _address.text.trim(),
        'job_address_lga': _lga.text.trim().isEmpty ? 'Nsukka' : _lga.text.trim(),
        'description': _description.text.trim(),
        if (_lat != null && _lng != null) ...{'client_lat': _lat, 'client_lng': _lng},
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: (job['id'] as num).toInt())),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.artisan;
    final name = (a['display_name'] ?? a['business_name'] ?? '').toString();
    final category = kCategories[a['category']] ?? a['category'].toString();
 
    return Scaffold(
      appBar: AppBar(title: const Text('Request an artisan')),
      body: CenteredForm(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: PersonAvatar(photo: a['photo'], name: name),
                  title: Text(name),
                  subtitle: Text('$category  ·  ${a['price']}'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'What do you need done?',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Describe the job in a few words' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Where is the job? (address)',
                  helperText: 'The artisan only sees this after accepting the job.',
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Enter the address of the job' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lga,
                decoration: const InputDecoration(labelText: 'Area / LGA'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: (_locating || _busy) ? null : _useLocation,
                icon: _locating
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_lat == null ? Icons.my_location : Icons.check_circle,
                        color: _lat == null ? null : Colors.green),
                label: Text(_lat == null
                    ? 'Add my GPS location (optional)'
                    : 'Location added. Tap to refresh'),
              ),
              const SizedBox(height: 6),
              Text(
                'GPS lets the system check later that the artisan really arrives at the job site.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}