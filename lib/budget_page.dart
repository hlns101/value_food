import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'profile_page.dart';

import 'dashboard_page.dart';

import 'goals_page.dart';
import 'savings_page.dart';
import 'goals_info_page.dart';
import 'label_page.dart';

class BudgetPage extends StatefulWidget {
  final String userId;
  const BudgetPage({super.key, required this.userId});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int calories = 0;
  double budget = 0;
  var weeklyBudget;
  var monthlyBudget;

  double height = 0;
  double weight = 0;
  int age = 0;

  // women formula and moderately active for Miffin-St Jeor equation 
  var BMR;
  var dailyCalorieNeeds;

  @override
  void initState() {
    super.initState();
    loadBudgetData();
  }

  Future<void> loadBudgetData() async {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

    final data = userDoc.data();
    if (data != null) {
      setState(() {
        budget = (data['budget'] ?? 0).toDouble();
        height = (data['height'] ?? 0).toDouble();
        weight = (data['weight'] ?? 0).toDouble();
        age = (data['age'] ?? 0);
        weeklyBudget = budget / 4;

        // BMR 
        if (data['sex'] == 'Female'){
          BMR = ((10 * data['weight']) + (6.25 * data['height']) - (5 * data['age']) - 161).toDouble();
        } else if (data['sex'] == 'Male'){
           BMR = ((10 * data['weight']) + (6.25 * data['height']) - (5 * data['age']) + 5 ).toDouble();
        }

        // estimated daily caloric needs
        if (data['activityLevel'] == 'Sedentary'){
          dailyCalorieNeeds = ((BMR * 1.2).toDouble().toStringAsFixed(2));
        } else if (data['activityLevel'] == 'Lightly Active'){
          dailyCalorieNeeds = ((BMR * 1.375).toDouble().toStringAsFixed(2));
        } else if (data['activityLevel'] == 'Moderately Active'){
          dailyCalorieNeeds = ((BMR * 1.55).toDouble().toStringAsFixed(2));
        } else if (data['activityLevel'] == 'Active'){
           dailyCalorieNeeds = ((BMR * 1.725).toDouble().toStringAsFixed(2));
        } else if (data['activityLevel'] == 'Very Active'){
          dailyCalorieNeeds = ((BMR * 1.9).toDouble().toStringAsFixed(2));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(
            side: BorderSide(width: 3, color: const Color(0xFF2E7D32)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LabelPage(userId: widget.userId),
              ),
            );
          },
          child: Image.asset(
            'assets/icons/scan_icon.png',
            color: const Color(0xFF2E7D32),
            height: 32,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(color: Color.fromRGBO(122, 184, 77, 100)),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadBudgetData,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 1),
                        _buildButtons(),
                        const SizedBox(height: 20),
                        _buildPlanBox(),
                        const SizedBox(height: 20),
                        _buildMeals(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Budget",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "To help manage your spendings",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return SizedBox(
      child: Row(
        children: [
          const SizedBox(width: 15),
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.5,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BudgetPage(userId: widget.userId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 6,
              ),
              child: const Text(
                "Meal Plan",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.5,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SavingsPage(userId: widget.userId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 6,
              ),
              child: const Text(
                "Savings",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBox() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Weight Loss Meal Plan",
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromRGBO(0, 0, 0, 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          Column(
            children: [
              const Text(
                "Personalized based on your personal info and budget",
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(0, 0, 0, 1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(
                  top: 50,
                  bottom: 50,
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(196, 35, 35, 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.red,
                      size: 30,
                    ),

                    Text(
                      'Estimated Daily\nCaloric Needs',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        // fontFamily: 'Poppins-Bold',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '$dailyCalorieNeeds',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                         Text(
                      '  kcal',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        // fontFamily: 'Poppins-Bold',
                      ),
                    ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10, width: 30),
              Container(
                padding: const EdgeInsets.only(
                  top: 50,
                  bottom: 50,
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(136, 185, 103, 0.21),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '₱',
                          style: TextStyle(
                            color: Color.fromRGBO(46, 125, 50, 100),
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // button to edit weekly budget, not working yet 
                        const SizedBox(width: 60),
                        GestureDetector(
                          onTap: () async {},
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Text(
                      'Weekly Budget',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                        // letterSpacing: 2,
                        // fontFamily: 'Poppins-Bold',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '₱$weeklyBudget',
                      style: TextStyle(
                        color: Color.fromRGBO(46, 125, 50, 100),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        // letterSpacing: 2,
                        // fontFamily: 'Poppins-Bold',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
                const SizedBox(height: 10),
                        Text(
                      '*Daily Caloric Needs is based on the Miffin-St \nJeor equation',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        // fontWeight: FontWeight.bold,
                        // fontFamily: 'Poppins-Bold',
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildMeals() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Meal Suggestions",
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromRGBO(0, 0, 0, 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text('Generated based on your scanned grocery products'),
          const SizedBox(height: 20),
          Text('☀️ Breakfast', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          _buildBreakfast()
        ],
      ),
    );
  }

  Widget _buildBreakfast() {
     return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color.fromRGBO(136, 185, 103, 0.21),
        // borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Text(
                "Oatmeal with Sliced Banana",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,

                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 10),
              Text(
                "₱30",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Scrambled Eggs on Rice",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,

                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 10),
              Text(
                "₱27",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Boiled Kamote with eggs",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,

                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 10),
              Text(
                "₱22",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
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
            _navItem(Icons.savings_rounded, "budget", true, () {
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
            _navItem(Icons.person_rounded, "profile", false, () {
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
