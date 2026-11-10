import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'get_info_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUpUser() async {
    // 🛑 VALIDATION
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      if (!mounted) return;

      String userId = userCredential.user!.uid;

      // ✅ SUCCESS → GO TO GET INFO PAGE
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => GetInfoPage(
                userId: userId,
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: IntrinsicHeight(
                // padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.05),

                    // logo
                    Image.asset(
                      'assets/new_logo.png',
                      height: MediaQuery.of(context).size.height / 5,
                      width: MediaQuery.of(context).size.width / 2,
                      fit: BoxFit.cover,
                    ),

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

                    // green card
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(122, 184, 77, 100),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(40.0),
                          topLeft: Radius.circular(40.0),
                        ),
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 50),
                          RichText(
                            text: TextSpan(
                              text: 'Create Account',
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
                              text: 'Start your nutrition tracking journey',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),

                          CustomTextField(
                            label: "First Name",
                            hint: "John",
                            icon: Icons.person,
                            controller: firstNameController,
                          ),

                          const SizedBox(height: 15),

                          CustomTextField(
                            label: "Last Name",
                            hint: "Doe",
                            icon: Icons.person,
                            controller: lastNameController,
                          ),

                          const SizedBox(height: 15),

                          CustomTextField(
                            label: "Email",
                            hint: "your@email.com",
                            icon: Icons.email,
                            controller: emailController,
                          ),

                          const SizedBox(height: 15),

                          CustomTextField(
                            label: "Password",
                            hint: "••••••••",
                            icon: Icons.lock,
                            isPassword: true,
                            controller: passwordController,
                          ),

                          const SizedBox(height: 15),

                          CustomTextField(
                            label: "Confirm Password",
                            hint: "••••••••",
                            icon: Icons.lock,
                            isPassword: true,
                            controller: confirmPasswordController,
                          ),

                          const SizedBox(height: 30),
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
                              onPressed: signUpUser,
                              child: RichText(
                                text: TextSpan(
                                  text: 'Next',
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
                          const SizedBox(height: 40),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already have an account? ",
                                style: TextStyle(color: Colors.white),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Log In",
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 1.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
