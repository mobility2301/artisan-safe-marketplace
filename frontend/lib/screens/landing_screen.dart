// DESTINATION: lib/screens/landing_screen.dart
import 'package:flutter/material.dart';
 
import '../config.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
 
bool _isWide(BuildContext context) => MediaQuery.of(context).size.width >= 880;
 
/// The first page a visitor sees, before logging in.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
 
  void _login(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
 
  void _register(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.paper,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(onLogin: () => _login(context), onRegister: () => _register(context)),
            const _HowItWorks(),
            const _SafetyFeatures(),
            const _Trades(),
            const _Audiences(),
            _FinalCta(onLogin: () => _login(context), onRegister: () => _register(context)),
          ],
        ),
      ),
    );
  }
}
 
/// Centres content and stops it growing wider than a comfortable reading width.
class _Page extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
 
  const _Page({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
    );
  }
}
 
// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
 
  const _Hero({required this.onLogin, required this.onRegister});
 
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
 
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Know who is coming to your door.',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 52 : 36,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const Text(
            'Artisan Safe checks every artisan and client against the photo on their ID '
            'before a job starts, and keeps a record of where the job took place.',
            style: TextStyle(color: Color(0xFFD5DAF0), fontSize: 17, height: 1.5),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Brand.gold,
                foregroundColor: Brand.ink,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: onRegister,
              child: const Text('Create account'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x66FFFFFF)),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: onLogin,
              child: const Text('Log in'),
            ),
          ],
        ),
      ],
    );
 
    return Container(
      width: double.infinity,
      color: Brand.indigo,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _RingsPainter())),
          _Page(
            padding: EdgeInsets.fromLTRB(24, 20, 24, wide ? 80 : 48),
            child: Column(
              children: [
                _NavBar(onLogin: onLogin, onRegister: onRegister),
                SizedBox(height: wide ? 64 : 40),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: copy),
                      const SizedBox(width: 56),
                      const Expanded(flex: 5, child: _CheckInCard()),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [copy, const SizedBox(height: 40), const _CheckInCard()],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _NavBar extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
 
  const _NavBar({required this.onLogin, required this.onRegister});
 
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Brand.gold, shape: BoxShape.circle),
          child: const Icon(Icons.verified_user, color: Brand.ink, size: 22),
        ),
        const SizedBox(width: 12),
        const Text(
          'Artisan Safe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: onLogin,
          child: const Text('Log in'),
        ),
        if (wide) ...[
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Brand.indigo,
            ),
            onPressed: onRegister,
            child: const Text('Create account'),
          ),
        ],
      ],
    );
  }
}
 
/// Soft rings in the corners, a nod to the circular Uli patterns of Nsukka art.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color.fromRGBO(255, 255, 255, 0.07);
    final top = Offset(size.width * 0.9, size.height * 0.12);
    final bottom = Offset(size.width * 0.02, size.height * 0.98);
    for (var i = 1; i <= 10; i++) {
      canvas.drawCircle(top, i * 46.0, paint);
    }
    for (var i = 1; i <= 7; i++) {
      canvas.drawCircle(bottom, i * 40.0, paint);
    }
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 
/// An example of what a client sees when the artisan checks in. It plays once on load.
class _CheckInCard extends StatelessWidget {
  const _CheckInCard();
 
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: still ? Duration.zero : const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final score = 93.4 * t;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 48, offset: Offset(0, 24)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Brand.gold, width: 3),
                      color: Brand.paper,
                    ),
                    child: const Icon(Icons.person, size: 34, color: Brand.indigo),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Check-in at your door',
                            style: TextStyle(color: Brand.muted, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Artisan has arrived',
                            style: TextStyle(
                                color: Brand.ink, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: t > 0.96 ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F4EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: Brand.lagoon),
                          SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  color: Brand.lagoon,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Face match', style: TextStyle(color: Brand.muted)),
                  Text('${score.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Brand.ink, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.934 * t,
                  minHeight: 8,
                  backgroundColor: Brand.paper,
                  color: Brand.lagoon,
                ),
              ),
              const SizedBox(height: 18),
              const _CardLine('Distance from the address', '38 m of 500 m allowed'),
              const _CardLine('Compared with', 'The photo on the ID'),
              const _CardLine('Saved', 'Time and location'),
              const SizedBox(height: 10),
              const Text('Example values, for illustration.',
                  style: TextStyle(color: Brand.muted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
 
class _CardLine extends StatelessWidget {
  final String label;
  final String value;
 
  const _CardLine(this.label, this.value);
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(color: Brand.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
 
// ---------------------------------------------------------------------------
// How a safe job works (a real sequence, so the steps are numbered)
// ---------------------------------------------------------------------------
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
 
  static const List<List<String>> _steps = [
    ['Verify who you are', 'Confirm your email and NIN, then match your face to the photo on your ID.'],
    ['Book or accept a job', 'Clients request an artisan. The address stays hidden until the artisan accepts.'],
    ['Check in at the door', 'The artisan takes a live selfie. It must match, and the phone must be at the address.'],
    ['Finish and confirm', 'The artisan checks out, the client confirms, and the client can rate the work.'],
  ];
 
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final items = [
      for (var i = 0; i < _steps.length; i++) _Step(number: i + 1, title: _steps[i][0], body: _steps[i][1]),
    ];
    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How a safe job works',
              style: TextStyle(
                  color: Brand.ink, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 32),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 28),
                  Expanded(child: items[i]),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 24),
                  items[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}
 
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
 
  const _Step({required this.number, required this.title, required this.body});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Brand.indigo, shape: BoxShape.circle),
          child: Text('$number',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Brand.ink, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(color: Brand.muted, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
 
// ---------------------------------------------------------------------------
// Safety features
// ---------------------------------------------------------------------------
class _SafetyFeatures extends StatelessWidget {
  const _SafetyFeatures();
 
  static const List<_Feature> _features = [
    _Feature(Icons.face_retouching_natural, 'Face matched to the ID photo',
        'At sign-up a live selfie is compared with the photo on the ID. A photo of a photo is rejected.'),
    _Feature(Icons.pin_drop_outlined, 'Check-in at the address',
        'The artisan\'s selfie must match, and the phone must be within 500 metres of the job address.'),
    _Feature(Icons.history, 'A record of every job',
        'The address, the arrival time and the checkout time are saved, so there is always a trail.'),
    _Feature(Icons.sos, 'SOS to someone you trust',
        'One tap emails your emergency contact the job address, your location and both names.'),
    _Feature(Icons.lock_outline, 'Private until accepted',
        'An artisan sees the job address and the client\'s phone number only after accepting.'),
    _Feature(Icons.star_outline, 'Ratings from real jobs',
        'Clients rate an artisan after confirming the job is finished.'),
  ];
 
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return _Page(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, box) {
          final itemWidth = wide ? (box.maxWidth - 40) / 2 : box.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Safety is built into every step',
                  style: TextStyle(
                      color: Brand.ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 40,
                runSpacing: 28,
                children: [
                  for (final f in _features) SizedBox(width: itemWidth, child: f),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
 
class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
 
  const _Feature(this.icon, this.title, this.body);
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECF8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Brand.indigo),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Brand.ink, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: Brand.muted, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
 
// ---------------------------------------------------------------------------
// Trades
// ---------------------------------------------------------------------------
class _Trades extends StatelessWidget {
  const _Trades();
 
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trades you can find in Nsukka',
              style: TextStyle(
                  color: Brand.ink, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final name in kCategories.values)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Brand.line),
                  ),
                  child: Text(name,
                      style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
 
// ---------------------------------------------------------------------------
// Clients and artisans
// ---------------------------------------------------------------------------
class _Audiences extends StatelessWidget {
  const _Audiences();
 
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    const clients = _Audience(
      title: 'For clients',
      dark: false,
      points: [
        'See a verified photo before you book',
        'Get a warning at once if a check-in fails',
        'Press SOS if you feel unsafe',
        'Rate the work when it is done',
      ],
    );
    const artisans = _Audience(
      title: 'For artisans',
      dark: true,
      points: [
        'Show your verified photo and describe your work',
        'Prove that you arrived, and when you left',
        'Press SOS if a job turns unsafe',
        'Build a rating from real jobs',
      ],
    );
    return _Page(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 64),
      child: wide
          ? const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: clients),
                  SizedBox(width: 24),
                  Expanded(child: artisans),
                ],
              ),
            )
          : const Column(
              children: [clients, SizedBox(height: 20), artisans],
            ),
    );
  }
}
 
class _Audience extends StatelessWidget {
  final String title;
  final bool dark;
  final List<String> points;
 
  const _Audience({required this.title, required this.dark, required this.points});
 
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : Brand.ink;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dark ? Brand.indigo : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: Brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: fg, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 18),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 20, color: dark ? Brand.gold : Brand.lagoon),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p, style: TextStyle(color: fg, fontSize: 16, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
 
// ---------------------------------------------------------------------------
// Final call to action and footer
// ---------------------------------------------------------------------------
class _FinalCta extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
 
  const _FinalCta({required this.onLogin, required this.onRegister});
 
  @override
  Widget build(BuildContext context) {
    return _Page(
      color: Brand.ink,
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 36),
      child: Column(
        children: [
          const Text(
            'Start your next job with someone you can recognise.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.gold,
                  foregroundColor: Brand.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                ),
                onPressed: onRegister,
                child: const Text('Create account'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                ),
                onPressed: onLogin,
                child: const Text('Log in'),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'A final year project at the University of Nigeria, Nsukka. This is a working prototype, not a public service.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9BA3C7), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}