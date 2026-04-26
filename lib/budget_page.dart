import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'profile_page.dart';

import 'dashboard_page.dart';
import 'scanner_page.dart';

import 'goals_page.dart';
import 'savings_page.dart';
import 'goals_info_page.dart';

class BudgetPage extends StatefulWidget {
  final String userId;
  const BudgetPage({super.key, required this.userId});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int calories = 0;
  double budget = 0;

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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF81C784), Color(0xFFE8F5E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadBudgetData,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
                          // const SizedBox(height: 20),
                          // _buildRecommended(),
                        ],
                      ),
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
            style: TextStyle(fontSize: 16, color: Color(0xFF33691E)),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      //color: Colors.white,
      //padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const SizedBox(width: 20),
          TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(23),
            ),
            onPressed: null,
            child: const Text(
              'Meal Plan',
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(0, 0, 0, 1),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                
              ),
            ),
          ),
          const SizedBox(width: 40),
          TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(23),
            ),
            onPressed: () async {
              HapticFeedback.vibrate();
                   await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SavingsPage(userId: widget.userId),
                    ),
                  );
            },
            child: const Text(
              'Savings',
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(0, 0, 0, 1),
                fontWeight: FontWeight.bold,
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
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Weight Loss Meal Plan",
                style: TextStyle(
                  fontSize: 16,
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
                  fontSize: 10,
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
                padding: const EdgeInsets.only(top: 50, bottom: 50),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(196, 35, 35, 0.1),
                  // borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🔥 \n Daily Calories \n 1920', //test
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(232, 85, 40, 1),
                    //color: Color.fromRGBO(0, 0, 0, 1)
                  ),
                ),
              ),

              const SizedBox(height: 10, width: 30),
              Container(
                padding: const EdgeInsets.only(top: 50, bottom: 50),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(136, 185, 103, 0.21),
                  // borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₱ \n Weekly Budget \n ₱1000', //test
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
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
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
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
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,

      onTap: (index) {
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(userId: widget.userId),
            ),
          );
        }

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BudgetPage(userId: widget.userId),
            ),
          );
        }

        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScannerPage(userId: widget.userId),
            ),
          );
        }

         if (index==3){
          // HapticFeedback.heavyImpact();
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => GoalsInfoPage(userId: widget.userId),
            ),
          );
        }

        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: widget.userId),
            ),
          );
        }
      },

      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.savings), label: ""),
     BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner, size: 40), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.flag), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
      ],
    );
  }
}
