import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'profile_page.dart';

import 'dashboard_page.dart';

import 'goals_page.dart';
import 'budget_page.dart';
import 'label_page.dart';

class GoalsInfoPage extends StatefulWidget {
  final String userId;
  const GoalsInfoPage({super.key, required this.userId});

  @override
  State<GoalsInfoPage> createState() => _GoalsInfoPageState();
}

class _GoalsInfoPageState extends State<GoalsInfoPage> {
  double weight = 0;
  double targetWeight = 0;
  String targetDate = "";
  @override
  void initState() {
    super.initState();
    loadGoalsData();
  }

  Future<void> loadGoalsData() async {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

    final data = userDoc.data();
    if (data != null) {
      setState(() {
        weight = (data['weight'] ?? 0).toDouble();
        targetWeight = (data['targetWeight'] ?? 0).toDouble();
        targetDate = (data['targetDate']);
      });
    }
  }

  double get progress => weight == 0 ? 0 : targetWeight / weight;
  double get progressPercent => (progress * 100).roundToDouble();
  double get toLose => weight - targetWeight;

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
        decoration: BoxDecoration(color: Color.fromRGBO(122, 184, 77, 100)),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadGoalsData,
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
                          const SizedBox(height: 20),
                          _buildGoalCard(),
                          const SizedBox(height: 20),
                          _buildTimeline(),
                          const SizedBox(height: 20),
                          _buildRecommended(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Weight Goal",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Track your progress towards your target",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildGoalCard() {
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
              Image.asset('assets/icons/target_check.png'),
              const Text(
                " Your Goal",
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromRGBO(0, 0, 0, 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 80),

              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalsPage(userId: widget.userId),
                    ),
                  );

                  if (result == true) {
                    loadGoalsData();
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(232, 245, 233, 100),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: RichText(
                  text: TextSpan(
                    text: 'Current Weight',
                    style: TextStyle(
                      // color: Color.fromRGBO( 	125,	125,	125, 100),
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins-Bold',
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: '\n \n $weight kg',
                        style: TextStyle(
                          // these are too bright, need darker text so its easier to read
                          // color: Color.fromRGBO(122, 184, 77, 100),
                          // color: Color.fromRGBO(121, 190, 75, 1),
                          color: Color(0xFF1B5E20),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 50, width: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(232, 245, 233, 100),
                  borderRadius: BorderRadius.circular(20),
                ),
                // 'Target Weight \n $targetWeight kg', //test
                child: RichText(
                  text: TextSpan(
                    text: 'Target Weight',
                    style: TextStyle(
                      // color: Color.fromRGBO( 	125,	125,	125, 100),
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins-Bold',
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: '\n \n $targetWeight kg',
                        style: TextStyle(
                          // color: Color.fromRGBO(122, 184, 77, 100),
                          color: Color(0xFF1B5E20),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
          Row(
            children: [
              Text("Progress", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 170),
              Text(
                '$progressPercent %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 20,
                backgroundColor: Colors.grey.shade300,
                color: Colors.green,
              ),
            ),
          ),

          const SizedBox(height: 10),
          Column(
            children: [
              Text(
                '$toLose kgs to lose', //test
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
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

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Color.fromRGBO(121, 190, 75, 100),
              ),
              Text(
                " Timeline",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // i put a date manually for now 
              Text(
                "Target Date",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,

                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 80),
              Text(
                "05/20/2026",
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
                "Days Remaining",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,

                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 80),
              Text(
                "60 days",
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

  Widget _buildRecommended() {
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.recommend_outlined,
                color: Color.fromRGBO(121, 190, 75, 1),
              ),
              Text(
                " Recommended Plan",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
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
                "Weekly Target",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(232, 245, 233, 100),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Column(
                  children: [
                    Text(
                      '0.5 kg  to lose / week ', //test
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),

                    Text(
                      'This is healthy and sustainable ', //test
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
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
            _navItem(Icons.savings_rounded, "budget", false, () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetPage(userId: widget.userId),
                ),
              );
            }),
            const SizedBox(width: 48),
            _navItem(Icons.flag_rounded, "goals", true, () {
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
