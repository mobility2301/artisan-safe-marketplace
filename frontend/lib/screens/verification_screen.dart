// ===== SAVE AS:  C:\dev\artisan_app\lib\screens\verification_screen.dart   (REPLACE whole file) =====
import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../widgets.dart';
import 'camera_screen.dart';
import 'home_screen.dart';
 
/// The 4 safety steps, in order:
/// 1 email code, 2 NIN, 3 profile photo vs ID, 4 live selfie vs ID.
/// Each step unlocks only after the one before it passes (the server enforces
/// this too; the screen just mirrors it).
class VerificationScreen extends StatefulWidget {
  /// true right after sign-up: shows "Skip for now" and finishes by opening Home.
  final bool firstTime;
 
  const VerificationScreen({super.key, this.firstTime = false});
 
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}
 
class _VerificationScreenState extends State<VerificationScreen> {
  Map<String, dynamic>? _status;
  String? _loadError;
 
  @override
  void initState() {
    super.initState();
    _reload();
  }
 
  Future<void> _reload() async {
    try {
      final s = await Api.instance.status();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }
 
  void _finish() {
    if (widget.firstTime) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pop();
    }
  }
 
  _StepState _stateOf(int step, int level) =>
      step <= level ? _StepState.done : (step == level + 1 ? _StepState.current : _StepState.locked);
 
  String _percent(dynamic v) => v is num ? v.toStringAsFixed(1) : '0.0';
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your identity'),
        actions: [
          if (widget.firstTime) TextButton(onPressed: _finish, child: const Text('Skip for now')),
        ],
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Try again')),
                  ],
                ),
              ),
            )
          : _status == null
              ? const Center(child: CircularProgressIndicator())
              : _content(_status!),
    );
  }
 
  Widget _content(Map<String, dynamic> s) {
    final level = (s['verification_level'] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);
 
    return CenteredForm(
      maxWidth: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trust score: ${s['trust_score']} / 100', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: level / 4,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text('$level of 4 steps complete'),
          const SizedBox(height: 16),
          _StepCard(
            number: 1,
            title: 'Email',
            subtitle: level >= 1 ? 'Email confirmed' : 'Enter the 6-digit code sent to your email',
            state: _stateOf(1, level),
            body: _OtpStep(channel: 'email', onDone: _reload),
          ),
          _StepCard(
            number: 2,
            title: 'National Identification Number (NIN)',
            subtitle: level >= 2
                ? 'NIN ending ${s['nin_last4']} (check type: ${s['nin_check_method']})'
                : 'Your 11-digit NIN',
            state: _stateOf(2, level),
            body: _NinStep(onDone: _reload),
          ),
          _StepCard(
            number: 3,
            title: 'Photo and ID',
            subtitle: level >= 3
                ? 'Your photo matches your ID (${_percent(s['photo_match_score'])}%)'
                : 'A clear photo of your face and a photo of your ID card',
            state: _stateOf(3, level),
            body: _PhotoStep(onDone: _reload),
          ),
          _StepCard(
            number: 4,
            title: 'Live selfie',
            subtitle: level >= 4
                ? 'Live selfie matches your ID (${_percent(s['live_match_score'])}%)'
                : 'A selfie taken right now, to prove it is really you',
            state: _stateOf(4, level),
            body: _LiveStep(onDone: _reload),
          ),
          if (level >= 4) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.verified, size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('You are fully verified', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _finish, child: const Text('Continue')),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
// ======================================================================
// One card per step
// ======================================================================
 
enum _StepState { done, current, locked }
 
class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  final Widget body;
 
  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.body,
  });
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget leading;
    switch (state) {
      case _StepState.done:
        leading = const Icon(Icons.check_circle, color: Colors.green, size: 28);
      case _StepState.current:
        leading = CircleAvatar(radius: 14, child: Text('$number'));
      case _StepState.locked:
        leading = Icon(Icons.lock_outline, color: theme.disabledColor, size: 28);
    }
 
    return Opacity(
      opacity: state == _StepState.locked ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        Text(subtitle, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (state == _StepState.current) ...[
                const SizedBox(height: 14),
                body,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
 
class _ResultBox extends StatelessWidget {
  final bool ok;
  final String text;
 
  const _ResultBox({required this.ok, required this.text});
 
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: ok ? Colors.green.shade900 : scheme.onErrorContainer),
      ),
    );
  }
}
 
Widget _spinner() => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
 
// ======================================================================
// Step 1: email code
// ======================================================================
 
class _OtpStep extends StatefulWidget {
  final String channel; // 'email' or 'phone'
  final VoidCallback onDone;
 
  const _OtpStep({required this.channel, required this.onDone});
 
  @override
  State<_OtpStep> createState() => _OtpStepState();
}
 
class _OtpStepState extends State<_OtpStep> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _info; // the server's message; in development it contains the code
 
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }
 
  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final msg = await Api.instance.sendOtp(widget.channel);
      if (mounted) setState(() => _info = msg);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      showMessage(context, 'The code has 6 digits.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await Api.instance.verifyOtp(widget.channel, _code.text);
      if (!mounted) return;
      showMessage(context, msg);
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
          onSubmitted: (_) => _busy ? null : _verify(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy ? _spinner() : const Text('Confirm'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _busy ? null : _send,
              child: const Text('Send new code'),
            ),
          ],
        ),
        if (_info != null) _ResultBox(ok: true, text: _info!),
      ],
    );
  }
}
 
// ======================================================================
// Step 2: NIN
// ======================================================================
 
class _NinStep extends StatefulWidget {
  final VoidCallback onDone;
 
  const _NinStep({required this.onDone});
 
  @override
  State<_NinStep> createState() => _NinStepState();
}
 
class _NinStepState extends State<_NinStep> {
  final _nin = TextEditingController();
  bool _busy = false;
 
  @override
  void dispose() {
    _nin.dispose();
    super.dispose();
  }
 
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final msg = await Api.instance.submitNin(_nin.text);
      if (!mounted) return;
      showMessage(context, msg);
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nin,
          keyboardType: TextInputType.number,
          maxLength: 11,
          decoration: const InputDecoration(labelText: 'NIN (11 digits)', counterText: ''),
          onSubmitted: (_) => _busy ? null : _submit(),
        ),
        const SizedBox(height: 6),
        Text(
          'Demo mode: the NIN format is checked, but it is not yet looked up in the NIMC '
          'database. Your full NIN is never stored, only its last 4 digits.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? _spinner() : const Text('Submit NIN'),
        ),
      ],
    );
  }
}
 
// ======================================================================
// Photo picking (used by steps 3 and 4)
// ======================================================================
 
class _PhotoPicker extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final bool cameraFront;
  final ValueChanged<Uint8List> onPicked;
 
  const _PhotoPicker({
    required this.label,
    required this.bytes,
    required this.cameraFront,
    required this.onPicked,
  });
 
  Future<void> _fromFile() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;
    onPicked(await picked.readAsBytes());
  }
 
  Future<void> _fromCamera(BuildContext context) async {
    final taken = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CameraScreen(title: label, front: cameraFront)),
    );
    if (taken != null) onPicked(taken);
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: bytes == null
              ? Icon(Icons.image_outlined, color: theme.colorScheme.outline)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(bytes!, fit: BoxFit.cover),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _fromFile,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Choose file'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _fromCamera(context),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
 
// ======================================================================
// Step 3: profile photo vs ID
// ======================================================================
 
class _PhotoStep extends StatefulWidget {
  final VoidCallback onDone;
 
  const _PhotoStep({required this.onDone});
 
  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}
 
class _PhotoStepState extends State<_PhotoStep> {
  Uint8List? _profile;
  Uint8List? _id;
  String _idType = 'national_id';
  bool _busy = false;
  bool _ok = false;
  String? _result;
 
  Future<void> _submit() async {
    if (_profile == null || _id == null) {
      showMessage(context, 'Add both photos first.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final res = await Api.instance.uploadPhotos(profile: _profile, idPhoto: _id, idType: _idType);
      final photo = (res['auto_verification'] as Map?)?['photo'] as Map?;
      final ok = photo?['ok'] == true;
      final score = photo?['score'];
      final msg = (photo?['msg'] ?? 'Photos uploaded.').toString();
      if (!mounted) return;
      setState(() {
        _ok = ok;
        _result = (score is num && score > 0) ? '$msg (${score.toStringAsFixed(1)}% match)' : msg;
      });
      if (ok) widget.onDone();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _result = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoPicker(
          label: 'Your photo',
          bytes: _profile,
          cameraFront: true,
          onPicked: (b) => setState(() => _profile = b),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _idType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'ID type'),
          items: [
            for (final e in kIdTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _idType = v ?? 'national_id'),
        ),
        const SizedBox(height: 14),
        _PhotoPicker(
          label: 'Photo of your ID',
          bytes: _id,
          cameraFront: false,
          onPicked: (b) => setState(() => _id = b),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? _spinner() : const Text('Upload and verify'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Checking the faces. This can take a little while the first time.'),
          ),
        if (_result != null) _ResultBox(ok: _ok, text: _result!),
      ],
    );
  }
}
 
// ======================================================================
// Step 4: live selfie vs ID
// ======================================================================
 
class _LiveStep extends StatefulWidget {
  final VoidCallback onDone;
 
  const _LiveStep({required this.onDone});
 
  @override
  State<_LiveStep> createState() => _LiveStepState();
}
 
class _LiveStepState extends State<_LiveStep> {
  Uint8List? _selfie;
  bool _busy = false;
  bool _ok = false;
  String? _result;
 
  Future<void> _capture() async {
    final taken = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(title: 'Live selfie', front: true),
      ),
    );
    if (taken != null && mounted) {
      setState(() {
        _selfie = taken;
        _result = null;
      });
    }
  }
 
  Future<void> _submit() async {
    if (_selfie == null) {
      showMessage(context, 'Take your selfie first.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final res = await Api.instance.uploadPhotos(live: _selfie);
      final live = (res['auto_verification'] as Map?)?['live'] as Map?;
      final ok = live?['ok'] == true;
      final score = live?['score'];
      final msg = (live?['msg'] ?? 'Selfie uploaded.').toString();
      if (!mounted) return;
      setState(() {
        _ok = ok;
        _result = (score is num && score > 0) ? '$msg (${score.toStringAsFixed(1)}% match)' : msg;
      });
      if (ok) widget.onDone();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _result = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Look straight at the camera in good light. A photo of a photo, or of a screen, '
          'will be rejected.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_selfie != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_selfie!, height: 220, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _capture,
          icon: const Icon(Icons.camera_alt),
          label: Text(_selfie == null ? 'Open camera' : 'Retake selfie'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? _spinner() : const Text('Submit selfie'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Checking that this is a live face and that it matches your ID...'),
          ),
        if (_result != null) _ResultBox(ok: _ok, text: _result!),
      ],
    );
  }
}