import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanHistory {
  static Future<void> _pending = Future.value();
  static const limit = 20;

  static Future<List<Map<String, dynamic>>> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('scanHistory.$uid') ?? [];
    return values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> remove(String uid, String id) {
    final result = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final kept = (await read(uid)).where((item) => item['id'] != id).toList();
      if (!await prefs.setStringList(
        'scanHistory.$uid',
        kept.map(jsonEncode).toList(),
      ))
        throw StateError('Local deletion failed');
      return kept;
    });
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Future<List<Map<String, dynamic>>> save(
    String uid,
    Map<String, dynamic> entry,
  ) {
    final result = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final previous = await read(uid);
      final entries =
          [
            entry,
            ...previous.where((item) => item['id'] != entry['id']),
          ].take(limit).toList();
      final saved = await prefs.setStringList(
        'scanHistory.$uid',
        entries.map(jsonEncode).toList(),
      );
      if (!saved) throw StateError('Local storage did not accept the scan');
      return entries;
    });
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
