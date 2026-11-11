import 'package:flutter/material.dart';

/// Dashboard-style header shared by the dashboard, budget, goals, and profile.
class DashboardHeader extends StatelessWidget {
  final String name;
  final String? pageTitle;
  final String subtitle;

  const DashboardHeader({
    super.key,
    required this.name,
    required this.subtitle,
    this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'User' : name.trim();
    final firstName = displayName.split(RegExp(r'\s+')).first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: pageTitle == null ? 'Hey, ' : '$firstName’s ',
                    style: const TextStyle(color: Color(0xFF7DB848)),
                  ),
                  TextSpan(
                    text: pageTitle ?? '$displayName!',
                    style: const TextStyle(color: Color(0xFF176084)),
                  ),
                ]),
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7DB848))),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Image.asset('assets/logo_plain.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }
}
