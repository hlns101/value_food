import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dashboard_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';

//import 'goals_page.dart';
import 'goals_info_page.dart';
import 'budget_page.dart';
import 'label_page.dart';
import 'dart:math';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String firstName = "";
  String lastName = "";
  int age = 0;
  double height = 0;
  double weight = 0;
  double budget = 0;
  List allergies = [];
  double bmi = 0;
  String sex = 'Male';



  final pesoFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

    final data = doc.data();

    if (data != null) {
      setState(() {
        String fullName = data['name'] ?? "";

        firstName =
            data['firstName'] ??
            (fullName.split(" ").isNotEmpty ? fullName.split(" ")[0] : "");
        lastName =
            data['lastName'] ??
            (fullName.split(" ").length > 1 ? fullName.split(" ")[1] : "");
        age = data['age'] ?? 0;
        height = (data['height'] ?? 0).toDouble();
        weight = (data['weight'] ?? 0).toDouble();
        budget = (data['budget'] ?? 0).toDouble();
        allergies = data['allergies'] ?? [];
        bmi = weight / pow(height/100, 2).toDouble();
        sex = (data['sex'] ?? '');
      });
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // double get bmi {
  //   if (height == 0) return 0;
  //   // double heightMeters = height * 0.0254;
  //   return weight / (height * height);
  // }

  String get bmiLabel {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
           backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(side: BorderSide(width: 3,color: const Color(0xFF2E7D32))),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LabelPage(userId: widget.userId),
              ),
            );
          },
          child: Image.asset('assets/icons/scan_icon.png', color:const Color(0xFF2E7D32), height: 32)
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
      body: Container(
        decoration: BoxDecoration(color: Color.fromRGBO(122, 184, 77, 100)),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildPersonalInfo(),
                        const SizedBox(height: 20),
                        _buildBMI(),
                        const SizedBox(height: 20),
                        _buildBudget(),
                        const SizedBox(height: 20),
                        _buildAllergies(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Profile Settings",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 5),
            Text(
              "Manage your personal information",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),

        // 🔥 LOGOUT BUTTON
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
          onPressed: () async {
            // Optional confirmation
            bool confirm =
                await showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text("Logout"),
                        content: const Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
                ) ??
                false;

            if (confirm) {
              logout();
            }
          },
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPersonalInfo() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFA5D6A7),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$firstName $lastName",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text("Your health profile"),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfilePage(userId: widget.userId),
                    ),
                  );

                  if (result == true) {
                    loadProfile(); // 🔥 refresh data
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Age\n$age years", style: TextStyle(fontWeight: FontWeight.w600)),
              Column(
                children: [
                  Text('Height', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text("${height.toDouble()} cm", style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Weight\n${weight.toDouble()} kg", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                "Budget\n${pesoFormat.format(budget)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBMI() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Body Mass Index (BMI)", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                bmi.toStringAsFixed(1),
                style: const TextStyle(fontSize: 32),
              ),
              Text(bmiLabel, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            ],
          ),
          const Text(
            "Underweight: < 18.5\nNormal: 18.5 - 24.9\nOverweight: 25 - 29.9\nObese: ≥ 30",
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBudget() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Grocery Budget", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                pesoFormat.format(budget),
                style: const TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text("Available per shopping trip"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllergies() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    WidgetSpan(child: Icon(Icons.warning, size: 18, color: Colors.red)),
                    TextSpan(
                      text: " Food Allergies",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                children:
                    allergies.map((a) {
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: Chip(
                          label: Text(a),
                          backgroundColor: Colors.red.shade100,
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 10,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, "home", false, () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardPage(userId: widget.userId),
                ),
              );
            }),
            _navItem(Icons.savings_rounded, "budget", false, () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetPage(userId: widget.userId),
                ),
              );
            }),
            const SizedBox(width: 48),
            _navItem(Icons.flag_rounded, "goals", false, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalsInfoPage(userId: widget.userId),
                ),
              );
            }),
            _navItem(Icons.person_rounded, "profile", true, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: widget.userId),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 26,
            color: isActive ? const Color(0xFF2E7D32) : const Color(0xFFB0BEC5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color:
                  isActive ? const Color(0xFF2E7D32) : const Color(0xFFB0BEC5),
            ),
          ),
        ],
      ),
    );
  }
}
