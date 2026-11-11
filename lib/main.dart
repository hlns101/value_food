import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'widgets/welcome_brand.dart';
import 'signup_page.dart';
import 'utils/app_haptics.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

class Food {
  final String name;
  final String budget;

  Food({required this.name, required this.budget});
}

List<Food> foodList = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  // Wait for the persisted session before deciding which screen to show.
  await FirebaseAuth.instance.authStateChanges().first;

  debugPrint('========== FIREBASE INITIALIZED ==========');

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  debugPrint('========== APP CHECK ACTIVATED ==========');

  try {
    final token = await FirebaseAppCheck.instance.getToken(true);

    debugPrint('APP CHECK TEST: ${token == null ? "FAILED" : "SUCCESS"}');
  } catch (e) {
    debugPrint('APP CHECK TEST FAILED: $e');
  }

  AppHaptics.start();
  runApp(const ValueFoodApp());
}

class ValueFoodApp extends StatelessWidget {
  const ValueFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ValueFood',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF7FAF7),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _session = FirebaseAuth.instance.authStateChanges();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _session,
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: WelcomeBrand()),
        );
      }
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Unable to restore your session. Please reopen the app.',
            ),
          ),
        );
      }
      final user = snapshot.data;
      if (user == null) return const LandingPage();
      return _ProfileGate(key: ValueKey(user.uid), userId: user.uid);
    },
  );
}

class _ProfileGate extends StatefulWidget {
  final String userId;
  const _ProfileGate({super.key, required this.userId});
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profile =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed:
                      () => setState(() {
                        _profile =
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .snapshots();
                      }),
                  child: const Text(
                    'Unable to load your profile. Check your connection.',
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: WelcomeBrand()),
            );
          }
          final data = snapshot.data!.data();
          if (data == null || data['onboardingComplete'] == false) {
            return SignupPage(
              existingUserId: widget.userId,
              initialData: data ?? const {},
            );
          }
          return DashboardPage(userId: widget.userId);
        },
      );
}

// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;

//     // 🔥 CHECK IF LOGGED IN
//     if (user != null) {
//       return DashboardPage(userId: user.uid);
//     } else {
//       return const LoginPage();
//     }
//   }
// }

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precacheImage(const AssetImage('assets/new_logo.png'), context).then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _controller.value = 1;
        } else {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final headerHeight = (height * .34).clamp(160.0, 265.0);
            final brandHeight = headerHeight - 24;
            final centeredTop = (height - brandHeight) / 2;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = Curves.easeInOutCubic.transform(
                  _controller.value,
                );
                return Stack(
                  children: [
                    Positioned(
                      top: height + (headerHeight - height) * progress,
                      left: 0,
                      right: 0,
                      height: height - headerHeight,
                      child: IgnorePointer(
                        ignoring: _controller.value < 1,
                        child: _welcomePanel(context),
                      ),
                    ),
                    Positioned(
                      top: centeredTop + (12 - centeredTop) * progress,
                      left: 0,
                      right: 0,
                      height: brandHeight,
                      child: const WelcomeBrand(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _welcomePanel(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF7AB84D),
      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
    ),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        30,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        children: [
          const Text(
            'Your Smart Nutrition and\nBudget Companion',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const FeatureCard(
            icon: Icons.camera_alt,
            title: 'Scan Nutrition Labels',
            subtitle: 'Instantly capture nutrition facts',
          ),
          const SizedBox(height: 12),
          const FeatureCard(
            icon: Icons.track_changes,
            title: 'Diet Recommendations',
            subtitle: 'Personalized recommendations based on scanned items',
          ),
          const SizedBox(height: 12),
          const FeatureCard(
            icon: Icons.shield,
            title: 'Allergen Warnings',
            subtitle: 'Takes note of your allergies',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignupPage()),
                  ),
              child: const Text('Get Started →'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  ),
              child: const Text('Already have an account? Log In'),
            ),
          ),
        ],
      ),
    ),
  );
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width / 1.3,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(icon, color: Color.fromRGBO(138, 207, 124, 100)),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    // color: Color(0xFF1B5E20),
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
