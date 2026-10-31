// ===== SAVE AS:  C:\dev\artisan_app\lib\screens\notifications_screen.dart   (NEW file) =====
import 'package:flutter/material.dart';
 
import '../services/api.dart';
import '../widgets.dart';
import 'job_detail_screen.dart';
 
/// In-app notifications (new request, accepted, declined, cancelled...).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
 
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
 
class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await Api.instance.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
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
 
  Future<void> _open(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    final jobId = n['job'];
    if (n['is_read'] != true) {
      try {
        await Api.instance.markNotificationRead(id);
      } on ApiException {
        // not important enough to stop the user opening the job
      }
    }
    if (!mounted) return;
    if (jobId is num) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jobId.toInt())),
      );
    }
    if (mounted) _load();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
    if (_items.isEmpty) return const Center(child: Text('No notifications yet.'));
 
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final n = Map<String, dynamic>.from(_items[i] as Map);
          final unread = n['is_read'] != true;
          return Card(
            child: ListTile(
              leading: Icon(
                unread ? Icons.notifications_active : Icons.notifications_none,
                color: unread ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                n['title'].toString(),
                style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text('${n['body']}\n${shortTime(n['created_at'])}'),
              isThreeLine: true,
              onTap: () => _open(n),
            ),
          );
        },
      ),
    );
  }
}