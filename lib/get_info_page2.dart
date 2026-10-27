import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class GetInfoPage2 extends StatefulWidget {
  final String userId;

  const GetInfoPage2({
    super.key,
    required this.userId,
  });

  @override
  State<GetInfoPage2> createState() => _GetInfoPageState2();
}

class _GetInfoPageState2 extends State<GetInfoPage2> {

  String selectedLevel = 'Sedentary';

  var activityItems = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Active',
    'Very Active',
  ];

// NCDs for now is just a dropdown but will be updated since its possible to have multiple and there will be other changes
  String selectedNCD = 'None';

  var ncdTypes = [
    'None',
    'Type 1 Diabetes',
    'Type 2 Diabetes',
    'Hypertension'
  ];

  Future<void> saveUserData() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
            'activityLevel': selectedLevel,
            'ncds': selectedNCD
          });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardPage(userId: widget.userId)),
      );
    } catch (e) {
      print("Error saving user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: SingleChildScrollView(
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
                const SizedBox(height: 20),

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

                Container(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(122, 184, 77, 100),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(40.0),
                      topLeft: Radius.circular(40.0),
                    ),
                  ),
                  height: MediaQuery.of(context).size.height / 0.8,
                  width: double.infinity,
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                       RichText(
                        text: TextSpan(
                          text: 'Create Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Info can be updated at any time.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 25),
                      Expanded(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width / 1.3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly Activity Level',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField(
                                  // value: selectedSex
                                  initialValue: selectedLevel,
                                  items: const [
                                    DropdownMenuItem(
                                      value: "Sedentary",
                                      child: Text("Little or No Exercise"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Lightly Active",
                                      child: Text("Lightly Active"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Moderately Active",
                                      child: Text("Moderately Active"),
                                    ),

                                    DropdownMenuItem(
                                      value: "Active",
                                      child: Text("Active"),
                                    ),

                                    DropdownMenuItem(
                                      value: "Very Active",
                                      child: Text("Very Active"),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedLevel = value!;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // NCD dropdown
                                 Text(
                                  'Non-Communicable Disease(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField(
                                  // value: selectedSex
                                  initialValue: selectedNCD,
                                  items: const [
                                    DropdownMenuItem(
                                      value: "None",
                                      child: Text("None"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Type 1 Diabetes",
                                      child: Text("Type 1 Diabetes"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Type 2 Diabetes",
                                      child: Text("Type 2 Diabetes"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Hypertension",
                                      child: Text("Hypertension"),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedNCD = value!;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width / 1.3,
                                  child: ElevatedButton(
                                    onPressed: saveUserData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 6,
                                    ),
                                    child: const Text(
                                      // changed from create account to next
                                      "Create Account",
                                      style: TextStyle(color: Colors.white),
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
