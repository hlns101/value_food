import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;

  const EditProfilePage({super.key, required this.userId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final budgetController = TextEditingController();
  final allergyController = TextEditingController();

  List<String> allergies = [];

  String selectedSex = 'Male';
  String selectedLevel = 'Sedentary';
  String selectedNCD = 'None';

  var sexItems = ['Male', 'Female'];
  var activityItems = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Active',
    'Very Active',
  ];
  var ncdTypes = ['None', 'Type 1 Diabetes', 'Type 2 Diabetes', 'Hypertension'];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

    final data = doc.data();

    if (data != null) {
      firstNameController.text = data['firstName'] ?? "";
      lastNameController.text = data['lastName'] ?? "";
      ageController.text = data['age'].toString();
      heightController.text = data['height'].toString();
      weightController.text = data['weight'].toString();
      budgetController.text = data['budget'].toString();

      allergies = List<String>.from(data['allergies'] ?? []);
      setState(() {
        selectedSex = data['sex'];
        selectedLevel = data['activityLevel'];
        selectedNCD = data['ncds'];
      });
    }
  }

  Future<void> saveChanges() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'name':
          "${firstNameController.text.trim()} ${lastNameController.text.trim()}",
      'age': int.tryParse(ageController.text) ?? 0,
      'height': int.tryParse(heightController.text) ?? 0,
      'weight': int.tryParse(weightController.text) ?? 0,
      'budget': double.tryParse(budgetController.text) ?? 0,
      'allergies': allergies,
      'sex': selectedSex,
      'activityLevel': selectedLevel,
      'ncds': selectedNCD,
    });

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  void addAllergy() {
    if (allergyController.text.isNotEmpty) {
      setState(() {
        allergies.add(allergyController.text.trim());
        allergyController.clear();
      });
    }
  }

  void removeAllergy(String item) {
    setState(() {
      allergies.remove(item);
    });
  }

  Widget field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color.fromRGBO(122, 184, 77, 100),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: Color.fromRGBO(122, 184, 77, 100),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              CustomTextField(
                label: "First Name",
                hint: "",
                controller: firstNameController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: "Last Name",
                hint: "",
                controller: lastNameController,
              ),

              const SizedBox(height: 10),
              // sex dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sex',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField(
                    // value: selectedSex
                    initialValue: selectedSex,
                    items: const [
                      DropdownMenuItem(value: "Male", child: Text("Male")),
                      DropdownMenuItem(value: "Female", child: Text("Female")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSex = value!;
                      });
                    },
                    decoration: InputDecoration(
                      // labelText: "Sex",
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              CustomTextField(
                label: "Age",
                hint: "",
                controller: ageController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: "Height (cm)",
                hint: "",
                controller: heightController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: "Weight (kg)",
                hint: "",
                controller: weightController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: "Budget (PHP)",
                hint: "",
                controller: budgetController,
              ),
              const SizedBox(height: 10),

              // activity level
              Column(
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
                        child: Text("Sedentary"),
                      ),
                      DropdownMenuItem(
                        value: "Lightly Active",
                        child: Text("Lightly Active"),
                      ),
                      DropdownMenuItem(
                        value: "Moderately Active",
                        child: Text("Moderately Active"),
                      ),
                      DropdownMenuItem(value: "Active", child: Text("Active")),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              // NCD
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Non-Communicable Disease(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField(
                    initialValue: selectedNCD,
                    items: const [
                      DropdownMenuItem(value: "None", child: Text("None")),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // allergies
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Allergy',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 1.1,

                    child: Expanded(
                      child: TextField(
                        controller: allergyController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: '',
                          hintText: 'e.g Peanuts',
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.add_circle_outlined,
                              color: const Color(0xFF2E7D32),
                              size: 30,
                              shadows: <Shadow>[
                                Shadow(color: Colors.white, blurRadius: 15.0),
                              ],
                            ),
                            onPressed: addAllergy,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Wrap(
                children:
                    allergies.map((a) {
                      return Chip(
                        backgroundColor: Colors.red,
                        label: Text(a, style: TextStyle(color: Colors.white)),
                        onDeleted: () => removeAllergy(a),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: MediaQuery.of(context).size.width / 1.3,
                child: ElevatedButton(
                  onPressed: saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  // final IconData icon;
  // final bool isPassword;
  final TextEditingController controller;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    // required this.icon,
    required this.controller,
    // this.isPassword = false,
  });

  // custom box to make the fields
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 1.1,
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
            // obscureText: isPassword,
            decoration: InputDecoration(
              // prefixIcon: Icon(icon),
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
