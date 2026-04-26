import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'profile_page.dart';
import 'add_transaction_page.dart';

import 'scanner_page.dart';
import 'goals_page.dart';
import 'goals_info_page.dart';
import 'dashboard_page.dart';
import 'budget_page.dart';
//import 'package:table_calendar/table_calendar.dart';

class SavingsPage extends StatefulWidget {
  final String userId;

  const SavingsPage({super.key, required this.userId});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  double monthlyLimit = 0;
  double weeklyLimit = 0;
  double remaining = 0;

  double spent = 0;
  double spentToday = 300;

  double get progress => remaining == 0 ? 0 : remaining / spent;
  double get progressPercent => (progress * 100).roundToDouble();

  // for calendar
  DateTime selectedDate = DateTime.now();

  final firstDate = DateTime(2025, 1);
  final lastDate = DateTime(2027, 12);

  @override
  void initState() {
    super.initState();
    loadSavingsData();
  }

  Future<void> loadSavingsData() async {
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
            onRefresh: loadSavingsData,
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
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 1),
                          _buildButtons(),
                          const SizedBox(height: 10),
                          _buildSavingsCard(),
                          //Text('$selectedDate'.split(' ')[0]),
                          const SizedBox(height: 15),

                          // MaterialButton (
                          //   onPressed: HapticFeedback.heavyImpact,
                          //    child: Text("Click!"),

                          // ),

                          Divider(),
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.5),
                                  blurRadius: 5,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Spending Calendar ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                CalendarDatePicker(
                                  initialDate: selectedDate,
                                  firstDate: firstDate,
                                  lastDate: lastDate,

                                  onDateChanged: (newDate) {
                                    setState(() {
                                      selectedDate = newDate;
                                    });
                                  },
                                ),

                                Text(
                                  'Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year} \n\nSpendings: ₱200',
                                ),

                                Text(
                                  "Low Spendings",
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 71, 188, 79),
                                  ),
                                ),
                              ],
                              // child: CalendarDatePicker(

                              //   initialDate: selectedDate,
                              //   firstDate: firstDate,
                              //   lastDate: lastDate,
                              //   onDateChanged: (newDate) {},
                              // ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAddExpense(),
                          const SizedBox(height: 20),
                          //_buildExpenseInput()
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
            onPressed: () async {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetPage(userId: widget.userId),
                ),
              );
            },
            child: const Text(
              'Meal Plan',
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(0, 0, 0, 1),
                fontWeight: FontWeight.bold,
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
              await Navigator.pushReplacement(
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
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Budget Overview",
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromRGBO(0, 0, 0, 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 50),

              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SavingsPage(userId: widget.userId),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(height: 10),
              Container(
                //padding: const EdgeInsets.all(0.1),
                padding: const EdgeInsets.only(top: 30, bottom: 50, right: 10),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(136, 185, 103, 0.21),
                  // borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₱ \nMonthly Limit \n₱$monthlyLimit',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),

              const SizedBox(height: 10, width: 50),
              Container(
                //padding: const EdgeInsets.all(0.1),
                padding: const EdgeInsets.only(top: 30, bottom: 50, right: 10),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(136, 185, 103, 0.21),
                  // borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '💰\nRemaining\n ₱$remaining', //test
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

          const SizedBox(height: 20),
          Row(
            children: [
              Text("Spent"),
              const SizedBox(width: 170),
              Text('$progressPercent %'),
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
          Text(
            '', //test
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddExpense() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('Add Expense'),
          const SizedBox(width: 215),
          const Icon(Icons.add, color: Colors.black, size: 20),
        ],
      ),
    );
  }

  Widget _buildExpenseInput() {
    return TextFormField(
      decoration: InputDecoration(
        labelText:
            "Enter Spending for ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide(),
        ),
      ),

      keyboardType: TextInputType.numberWithOptions(),
      style: TextStyle(fontFamily: "Poppins"),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SavingsPage(userId: widget.userId),
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

        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GoalsInfoPage(userId: widget.userId),
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
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner, size: 40),
          label: "",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.flag), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
      ],
    );
  }
}
