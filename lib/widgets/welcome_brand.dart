import 'package:flutter/material.dart';

/// The same visible brand is used while loading and during the welcome motion.
class WelcomeBrand extends StatelessWidget {
  const WelcomeBrand({super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: 310,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/new_logo.png', height: 145, width: 145,
            fit: BoxFit.contain, filterQuality: FilterQuality.high),
        const SizedBox(height: 10),
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Value', style: TextStyle(color: Color(0xFF206589))),
          TextSpan(text: 'Food', style: TextStyle(color: Color(0xFF7AB84D))),
        ]), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold,
            letterSpacing: 2)),
        const Text('Smart Choice. Safe Nutrition. Maximum Value.',
          style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
      ]),
    ),
  );
}
