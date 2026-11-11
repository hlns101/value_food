import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'main.dart' show AuthGate;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // 🔥 VERY IMPORTANT FIX
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

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
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: IntrinsicHeight(
                // child: Padding(
                // padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.08),

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

                    SizedBox(height: 30),

                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(122, 184, 77, 100),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(40.0),
                          topLeft: Radius.circular(40.0),
                        ),
                      ),
                      height: MediaQuery.of(context).size.height / 1.5,
                      width: double.infinity,
                      child: Column(
                        children: [
                          SizedBox(height: 50),
                          RichText(
                            text: TextSpan(
                              text: 'Welcome Back!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          RichText(
                            text: TextSpan(
                              text: 'Log in to your nutrition tracker',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          SizedBox(
                            width: (MediaQuery.of(context).size.width / 1.3)
                                .clamp(0.0, 360.0),
                            child: CustomTextField(
                              label: "Email",
                              hint: "your@email.com",
                              icon: Icons.email,
                              controller: emailController,
                            ),
                          ),

                          const SizedBox(height: 15),

                          SizedBox(
                            width: (MediaQuery.of(context).size.width / 1.3)
                                .clamp(0.0, 360.0),
                            child: CustomTextField(
                              label: "Password",
                              hint: "••••••••",
                              icon: Icons.lock,
                              isPassword: true,
                              controller: passwordController,
                            ),
                          ),

                          const SizedBox(height: 50),

                          SizedBox(
                            width: (MediaQuery.of(context).size.width / 1.3)
                                .clamp(0.0, 360.0),
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                elevation: 6,
                              ),
                              onPressed: loginUser,
                              child: const Text(
                                "Log In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(color: Colors.white),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
                // ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
