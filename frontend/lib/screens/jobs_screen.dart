// ===== SAVE AS:  C:\dev\artisan_app\lib\screens\jobs_screen.dart   (NEW file) =====
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../services/api.dart';
import '../widgets.dart';
import 'job_detail_screen.dart';
 
/// Every job the logged-in person takes part in, as client or as artisan.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
 
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}
 
class _JobsScreenState extends State<JobsScreen> {
  List<dynamic> _jobs = [];
  bool _loading = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    setState(() {
      _loading = _jobs.isEmpty;
      _error = null;
    });
    try {
      final jobs = await Api.instance.jobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
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
 
  Future<void> _open(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: id)),
    );
    if (mounted) _load();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My jobs'),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _body(),
        ),
      ),
    );
  }
 
  Widget _body() {
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
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_jobs.isEmpty) return const Center(child: Text('No jobs yet.'));
 
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _jobs.length,
        itemBuilder: (context, i) {
          final j = Map<String, dynamic>.from(_jobs[i] as Map);
          final asClient = j['my_role'] == 'client';
          final other = (asClient ? j['artisan_display_name'] : j['client_name']).toString();
          final category = kCategories[j['category']] ?? j['category'].toString();
          return Card(
            child: ListTile(
              title: Text(other),
              subtitle: Text(
                '${asClient ? 'You requested' : 'Requested from you'}  ·  $category\n'
                '${shortTime(j['created_at'])}',
              ),
              isThreeLine: true,
              trailing: StatusChip(j['status'].toString()),
              onTap: () => _open((j['id'] as num).toInt()),
            ),
          );
        },
      ),
    );
  }
}