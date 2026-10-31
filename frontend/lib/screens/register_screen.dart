// DESTINATION: lib/screens/register_screen.dart
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../widgets.dart';
import 'verification_screen.dart';
 
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
 
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
 
class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _town = TextEditingController(text: 'Nsukka');
  final _ecName = TextEditingController();
  final _ecPhone = TextEditingController();
  final _ecEmail = TextEditingController();
 
  String _role = 'artisan'; // 'artisan' or 'client'
  String? _category;
  String _artisanType = 'onsite';
  bool _busy = false;
  bool _hide = true;
 
  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password, _town, _ecName, _ecPhone, _ecEmail]) {
      c.dispose();
    }
    super.dispose();
  }
 
  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Enter $what' : null;
 
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'email': _email.text.trim(),
        'phone_number': _phone.text.trim(),
        'password': _password.text,
        'user_type': _role,
        if (_ecEmail.text.trim().isNotEmpty) ...{
          'emergency_contact_name': _ecName.text.trim(),
          'emergency_contact_phone': _ecPhone.text.trim(),
          'emergency_contact_email': _ecEmail.text.trim(),
        },
        if (_role == 'artisan') ...{
          'category': _category,
          'artisan_type': _artisanType,
          'town': _town.text.trim().isEmpty ? 'Nsukka' : _town.text.trim(),
        },
      };
      await Api.instance.register(body);
      await Api.instance.login(_email.text, _password.text);
      if (!mounted) return;
      // New accounts go straight into verification (the email code was just sent)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VerificationScreen(firstTime: true)),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final isArtisan = _role == 'artisan';
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: CenteredForm(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'artisan', label: Text('I am an artisan'), icon: Icon(Icons.handyman)),
                  ButtonSegment(
                      value: 'client', label: Text('I need an artisan'), icon: Icon(Icons.person)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'First name'),
                      validator: (v) => _required(v, 'your first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (v) => _required(v, 'your last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '08012345678',
                ),
                validator: (v) =>
                    (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10)
                        ? 'Enter a valid phone number'
                        : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Password (at least 6 characters)',
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
              ),
              if (isArtisan) ...[
                const SizedBox(height: 22),
                Text('Your work', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final e in kCategories.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Choose what you do' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _artisanType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'How do you work?'),
                  items: [
                    for (final e in kArtisanTypes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _artisanType = v ?? 'onsite'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _town,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Town'),
                ),
              ],
              const SizedBox(height: 22),
              Text('Emergency contact (optional now)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'If you press SOS on a job, we email this person with your location. You can add it later.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ecName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Contact name'),
                validator: (v) => (_ecEmail.text.trim().isNotEmpty && (v ?? '').trim().isEmpty)
                    ? 'Enter the contact\'s name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ecPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact phone'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ecEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Contact email'),
                validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@'))
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}