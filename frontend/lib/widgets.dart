// DESTINATION: lib/widgets.dart
import 'package:flutter/material.dart';
 
import 'config.dart';
 
/// A short message at the bottom of the screen. Red when [error] is true.
void showMessage(BuildContext context, String text, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(color: error ? scheme.onError : null),
        ),
        backgroundColor: error ? scheme.error : null,
        duration: Duration(seconds: error ? 6 : 4),
      ),
    );
}
 
/// Centres a form and stops it stretching across a wide browser window.
class CenteredForm extends StatelessWidget {
  final Widget child;
  final double maxWidth;
 
  const CenteredForm({super.key, required this.child, this.maxWidth = 440});
 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
 
/// A small coloured label for a job status.
class StatusChip extends StatelessWidget {
  final String status;
 
  const StatusChip(this.status, {super.key});
 
  static const Map<String, MaterialColor> _colors = {
    'requested': Colors.orange,
    'accepted': Colors.blue,
    'checked_in': Colors.teal,
    'checked_out': Colors.indigo,
    'completed': Colors.green,
    'rejected': Colors.grey,
    'cancelled': Colors.grey,
    'sos_triggered': Colors.red,
  };
 
  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        kJobStatus[status] ?? status,
        style: TextStyle(color: color.shade900, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
 
/// "2026-10-24T18:30:12+01:00" -> "2026-10-24 18:30"
String shortTime(dynamic iso) {
  final text = (iso ?? '').toString();
  return text.length >= 16 ? text.substring(0, 16).replaceFirst('T', ' ') : text;
}
 
/// A person's verified face photo, or their first letter when there is no photo.
class PersonAvatar extends StatelessWidget {
  final dynamic photo;
  final String name;
  final double radius;
  const PersonAvatar({super.key, required this.photo, required this.name, this.radius = 20});
 
  @override
  Widget build(BuildContext context) {
    final letter = CircleAvatar(
      radius: radius,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
    );
    final url = (photo ?? '').toString();
    if (url.isEmpty) return letter;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => letter,
      ),
    );
  }
}