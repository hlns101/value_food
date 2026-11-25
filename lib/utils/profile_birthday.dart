import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

int ageOn(DateTime birthday, DateTime today) {
  final beforeBirthday =
      today.month < birthday.month ||
      (today.month == birthday.month && today.day < birthday.day);
  return today.year - birthday.year - (beforeBirthday ? 1 : 0);
}

DateTime? profileBirthday(Map<String, dynamic> data) {
  final raw = data['birthdate'];
  DateTime? date = raw is Timestamp
      ? raw.toDate()
      : raw is DateTime
      ? raw
      : null;
  if (raw is String) {
    date = DateTime.tryParse(raw);
    if (date == null) {
      try {
        date = DateFormat('MM-dd-yyyy').parseStrict(raw);
      } on FormatException {
        return null;
      }
    }
  }
  if (date == null || date.year < 1900 || date.isAfter(DateTime.now()))
    return null;
  // Older edit screens sometimes saved today's date over an adult's birthday.
  final stored = int.tryParse('${data['age']}');
  if (ageOn(date, DateTime.now()) == 0 && (stored ?? 0) > 0) return null;
  return date;
}

class ProfileBirthdayButton extends StatelessWidget {
  const ProfileBirthdayButton({
    super.key,
    required this.date,
    required this.onChanged,
  });
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xff2e7d32);
    const paper = Color(0xfff8fbf5);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(0, 48),
          foregroundColor: const Color(0xff184929),
          backgroundColor: paper,
          side: const BorderSide(color: Color(0xffc9ddc5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            helpText: 'Select your date of birth',
            confirmText: 'Use birthday',
            initialDatePickerMode: date == null
                ? DatePickerMode.year
                : DatePickerMode.day,
            initialDate: date ?? DateTime(now.year - 18, now.month, now.day),
            firstDate: DateTime(1900),
            lastDate: now,
            builder: (context, dialog) {
              final theme = Theme.of(context);
              final colors =
                  ColorScheme.fromSeed(
                    seedColor: green,
                    brightness: Brightness.light,
                  ).copyWith(
                    primary: green,
                    onPrimary: Colors.white,
                    surface: paper,
                    secondary: const Color(0xff176084),
                  );
              return Theme(
                data: theme.copyWith(
                  colorScheme: colors,
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: paper,
                    surfaceTintColor: Colors.transparent,
                    headerBackgroundColor: green,
                    headerForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                child: dialog!,
              );
            },
          );
          if (picked != null && context.mounted) onChanged(picked);
        },
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date == null
                    ? 'Select your birthday'
                    : DateFormat.yMMMMd().format(date!),
              ),
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }
}
