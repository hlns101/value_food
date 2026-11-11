import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'signup_page.dart';
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

  runApp(const ValueFoodApp());
}

class ValueFoodApp extends StatelessWidget {
  const ValueFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ValueFood',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // ⏳ Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ✅ Logged in
          if (snapshot.hasData) {
            return DashboardPage(userId: snapshot.data!.uid);
          }

          // ❌ Not logged in
          return const LandingPage();
        },
      ),
    );
  }
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

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: SingleChildScrollView(
            // padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: size.height * 0.03),

                // LOGO
                Image.asset(
                  'assets/new_logo.png',
                  height: MediaQuery.of(context).size.height / 5,
                  width: MediaQuery.of(context).size.width / 2,
                  fit: BoxFit.cover,
                ),

                SizedBox(height: 20),

                // TITLE
                RichText(
                  text: TextSpan(
                    text: 'Value',
                    style: TextStyle(
                      color: Color.fromRGBO(32, 101, 137, 100),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Poppins-Bold',
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Food',
                        style: TextStyle(
                          color: Color.fromRGBO(122, 184, 77, 100),
                        ),
                      ),
                    ],
                  ),
                ),

                // under title text
                Text(
                  'Smart Choice. Safe Nutrition. Maximum Value.',
                  style: TextStyle(color: Color.fromRGBO(46, 125, 50, 100)),
                ),

                SizedBox(height: 50),

                // green card start
                Container(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(122, 184, 77, 100),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(40.0),
                      topLeft: Radius.circular(40.0),
                    ),
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 50, bottom: 30),
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                      Text(
                        'Your Smart Nutrition and \n \t \t \t Budget Companion',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      FeatureCard(
                        icon: Icons.camera_alt,
                        title: "Scan Nutrition Labels",
                        subtitle:
                            "Instantly capture and gives the nutritional facts",
                      ),
                      SizedBox(height: 20),

                      FeatureCard(
                        icon: Icons.track_changes,
                        title: "Diet Recommendations",
                        subtitle:
                            "Personalized meal plans based on your scanned items",
                      ),

                      SizedBox(height: 20),

                      FeatureCard(
                        icon: Icons.shield,
                        title: "Allergen Warnings",
                        subtitle: "Takes note of your allergies",
                      ),

                      SizedBox(height: 50),
                      SizedBox(
                        width: MediaQuery.of(context).size.width / 1.3,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 6,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SignupPage()),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Get Started',
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: '→',
                                  style: TextStyle(fontSize: 25),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: MediaQuery.of(context).size.width / 1.3,
                        height: 60,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                            );
                          },
                          
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account?',
                              style: TextStyle(
                                 color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: ' Log In',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: Colors.white,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // child: Text(
                          //   "Already have an account? Log In",
                          //   style: TextStyle(
                          //     color: Colors.white,
                          //     fontWeight: FontWeight.w600,
                          //     fontSize: 16,
                          //   ),
                          // ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
