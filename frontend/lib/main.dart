// DESTINATION: lib/main.dart
import 'package:flutter/material.dart';
 
import 'screens/home_screen.dart';
import 'screens/landing_screen.dart';
import 'services/api.dart';
import 'theme.dart';
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.load(); // restore a saved login, if there is one
  runApp(const ArtisanApp());
}
 
class ArtisanApp extends StatelessWidget {
  const ArtisanApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artisan Safe',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Api.instance.isLoggedIn ? const HomeScreen() : const LandingScreen(),
    );
  }
}