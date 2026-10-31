// DESTINATION: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../widgets.dart';
import 'jobs_screen.dart';
import 'landing_screen.dart';
import 'notifications_screen.dart';
import 'request_job_screen.dart';
import 'verification_screen.dart';
 
/// Browse artisans. Shows a reminder until the logged-in person is fully verified.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
 
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
 
class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _me;
  List<dynamic> _artisans = [];
  String _category = ''; // '' means all
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _loadAll();
  }
 
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
 
  Future<void> _editMyWork() async {
    Map<String, dynamic> p;
    try {
      p = await Api.instance.myArtisanProfile();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    final desc = TextEditingController(text: (p['description'] ?? '').toString());
    final price = TextEditingController(text: (p['price'] ?? '').toString());
    var available = p['is_available'] == true;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('About my work'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: desc,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Describe your work',
                    hintText: 'What you do, your experience, the jobs you take',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Price (for example ₦3000)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for jobs'),
                  value: available,
                  onChanged: (v) => setD(() => available = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await Api.instance.updateMyArtisanProfile(desc.text, price.text, available);
      if (!mounted) return;
      showMessage(context, 'Your work details are saved.');
      _loadAll();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }
 
  Future<void> _editEmergencyContact() async {
    final me = _me ?? {};
    final name = TextEditingController(text: (me['emergency_contact_name'] ?? '').toString());
    final phone = TextEditingController(text: (me['emergency_contact_phone'] ?? '').toString());
    final email = TextEditingController(text: (me['emergency_contact_email'] ?? '').toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('If you press SOS on a job, this person is emailed your location.'),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true) return;
    try {
      await Api.instance.updateEmergencyContact(name.text, phone.text, email.text);
      if (!mounted) return;
      showMessage(context, 'Emergency contact saved.');
      _loadAll();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }
 
  Future<void> _goToLogin() async {
    await Api.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }
 
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await Api.instance.me();
      final list = await Api.instance.artisans(category: _category, query: _search.text);
      if (!mounted) return;
      setState(() {
        _me = me;
        _artisans = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _goToLogin(); // saved login has expired
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }
 
  Future<void> _loadArtisans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.instance.artisans(category: _category, query: _search.text);
      if (!mounted) return;
      setState(() {
        _artisans = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }
 
  Future<void> _openVerification() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
    );
    if (mounted) _loadAll();
  }
 
  void _showDetails(Map<String, dynamic> a) {
    final theme = Theme.of(context);
    final description = (a['description'] ?? '').toString();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(
                  photo: a['photo'],
                  name: (a['display_name'] ?? a['business_name'] ?? '').toString(),
                  radius: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (a['display_name'] ?? a['business_name'] ?? '').toString(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(kCategories[a['category']] ?? a['category'].toString())),
                Chip(label: Text(kArtisanTypes[a['artisan_type']]?.split(' (').first ?? '')),
                Chip(label: Text(a['price'].toString())),
                Chip(label: Text(a['is_available'] == true ? 'Available' : 'Busy')),
              ],
            ),
            const SizedBox(height: 8),
            Text(description.isEmpty ? 'No description yet.' : description),
            if (_me?['user_type'] == 'client' && a['is_available'] == true) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Request this artisan'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RequestJobScreen(artisan: a)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = _me;
    final verified = me?['is_fully_verified'] == true;
    final level = (me?['verification_level'] as num?)?.toInt() ?? 0;
    final name = me == null ? '' : (me['first_name'] ?? '').toString();
 
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Artisans' : 'Hi, $name'),
        actions: [
          IconButton(
            tooltip: 'My jobs',
            icon: const Icon(Icons.work_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const JobsScreen())),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          if (me?['user_type'] == 'artisan')
            IconButton(
              tooltip: 'About my work',
              icon: const Icon(Icons.edit_note),
              onPressed: _editMyWork,
            ),
          IconButton(
            tooltip: 'Emergency contact',
            icon: const Icon(Icons.contact_emergency_outlined),
            onPressed: _editEmergencyContact,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _goToLogin,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (me != null && !verified)
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text('Verification: $level of 4 steps'),
                    subtitle: const Text('Finish it to be listed or to book an artisan.'),
                    trailing: FilledButton(
                      onPressed: _openVerification,
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search artisans',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _loadArtisans,
                    ),
                  ),
                  onSubmitted: (_) => _loadArtisans(),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    for (final entry in {'': 'All', ...kCategories}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _category == entry.key,
                          onSelected: (_) {
                            setState(() => _category = entry.key);
                            _loadArtisans();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _list()),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadAll, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_artisans.isEmpty) {
      return const Center(child: Text('No artisans found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: _artisans.length,
      itemBuilder: (context, i) {
        final a = Map<String, dynamic>.from(_artisans[i] as Map);
        final name = (a['display_name'] ?? a['business_name'] ?? '?').toString();
        final rating = double.tryParse(a['average_rating'].toString()) ?? 0;
        final category = kCategories[a['category']] ?? a['category'].toString();
        return Card(
          child: ListTile(
            leading: PersonAvatar(photo: a['photo'], name: name),
            title: Row(
              children: [
                Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
                if (a['is_verified'] == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 18, color: Colors.green),
                ],
              ],
            ),
            subtitle: Text('$category  ·  ${a['price']}  ·  ★ ${rating.toStringAsFixed(1)}'),
            trailing: Icon(
              a['is_available'] == true ? Icons.circle : Icons.circle_outlined,
              size: 14,
              color: a['is_available'] == true ? Colors.green : Colors.grey,
            ),
            onTap: () => _showDetails(a),
          ),
        );
      },
    );
  }
}