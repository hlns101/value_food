import 'package:flutter/material.dart';

/// Shared typography, colors, and navigation styling for main page headers.
class PageHeader extends StatelessWidget {
  static const nameColor = Color(0xFF7DB848);
  static const titleColor = Color(0xFF176084);
  static const green = Color(0xFF287D35);

  final String title;
  final String subtitle;
  final String? name;
  final String? prefix;
  final VoidCallback? onBack;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.name,
    this.prefix,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name?.trim() ?? '';
    final firstName = trimmedName.isEmpty
        ? 'User'
        : trimmedName.split(RegExp(r'\s+')).first;
    final titlePrefix = name != null ? '$firstName’s ' : (prefix ?? '');

    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE6F4E7),
              foregroundColor: green,
              minimumSize: const Size(48, 48),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  if (titlePrefix.isNotEmpty)
                    TextSpan(text: titlePrefix,
                        style: const TextStyle(color: nameColor)),
                  TextSpan(text: title,
                      style: const TextStyle(color: titleColor)),
                ]),
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
