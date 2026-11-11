import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'profile_page.dart';
import 'add_transaction_page.dart';

import 'goals_page.dart';
import 'goals_info_page.dart';

import 'budget_page.dart';
import 'label_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String username = "";
  double budget = 0;
  double spent = 0;

  List<Map<String, dynamic>> activities = [];

  final pesoFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final data = userDoc.data();

      if (data != null) {
        setState(() {
          username = data['firstName'] ?? "User";
          budget = (data['budget'] ?? 0).toDouble();
          spent = (data['spent'] ?? 0).toDouble();
        });
      }

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('transactions')
          .get();

      setState(() {
        activities = transactionsSnapshot.docs.map((doc) {
          final d = doc.data();
          return {
            "type": d['type'],
            "amount": (d['amount'] ?? 0).toDouble(),
            "icon": d['type'] == "Lunch"
                ? Icons.fastfood
                : Icons.shopping_cart,
          };
        }).toList();
      });
    } catch (e) {
      print("Error loading dashboard: $e");
    }
  }

  double get remaining => budget - spent;

  double get progress => budget == 0 ? 0 : spent / budget;

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
            onRefresh: loadDashboardData,
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
                          _buildBudgetCard(),
                          // const SizedBox(height: 20),
                          // _buildRecentActivity(),
                          const SizedBox(height: 20),
                          _buildRecentMeals()
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
          "Hey, $username!",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Let’s manage your food & budget today",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Budget",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4E6E58),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pesoFormat.format(budget),
            style: const TextStyle(
              fontFamily: 'sans-serif', // ✅ peso fix
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Spent: ${pesoFormat.format(spent)}",
                style: const TextStyle(
                  fontFamily: 'sans-serif', // ✅ peso fix
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E6E58),
                ),
              ),
              Text(
                "Remaining: ${pesoFormat.format(remaining)}",
                style: const TextStyle(
                  fontFamily: 'sans-serif', // ✅ peso fix
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E6E58),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activity",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B5E20),
                ),
              ),

              // ➕ ADD BUTTON
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTransactionPage(userId: widget.userId),
                    ),
                  );

                  if (result == true) {
                    loadDashboardData(); // 🔥 refresh UI
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No recent activity yet",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final item = activities[index];

                return ListTile(
                  leading: Icon(item["icon"], color: Colors.green),
                  title: Text(item["type"], style: TextStyle(color: Color(0xFF2E7D32), fontSize: 24, fontWeight: FontWeight.bold)),
                  trailing: Text(
                    pesoFormat.format(item["amount"]),
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontFamily: 'sans-serif', // ✅ peso fix
                      fontSize: 24,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

 // to be added
  Widget _buildRecentMeals(){
    return Container(
      // padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('Meal History', style: TextStyle(color: Colors.white)),
        SizedBox(height: 5),
        Row(
          children: [
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {},
              child: Text("All"),
            ),
          ),
          SizedBox(width: 5,),
          SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
                onPressed: () {},
                child: Text("Breakfast"),
              ),
            ),
          SizedBox(width: 5,),
          SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
                onPressed: () {},
                child: Text("Lunch"),
              ),
            ),       
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
                onPressed: () {},
                child: Text("Dinner"),
              ),
            ),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
                onPressed: () {},
                child: Text("Snack"),
              ),
            ),
        ],
        )
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
            _navItem(Icons.home_rounded, "home", true, () {
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