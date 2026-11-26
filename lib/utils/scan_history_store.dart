import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ScanEntry = Map<String, dynamic>;

/// Only metadata is kept in memory. Each scan owns a private copy of its photo.
class ScanHistoryStore extends ValueNotifier<List<ScanEntry>> {
  ScanHistoryStore(
    this.userId, {
    this.directory = getApplicationSupportDirectory,
  }) : super(const []);

  final String userId;
  final Future<Directory> Function() directory;
  static Future<void> _pending = Future.value();
  late Directory _account;
  bool _loaded = false;
  bool _disposed = false;

  Directory get _active => Directory('${_account.path}/scans');
  String _key(String id) => base64Url.encode(utf8.encode(id));
  Directory _scan(String id) => Directory('${_active.path}/${_key(id)}');
  File _metadata(Directory dir) => File('${dir.path}/result.json');
  File _photo(Directory dir) => File('${dir.path}/photo');

  Future<void> _run(Future<void> Function() action) {
    final next = _pending.then((_) async {
      if (!_loaded) await _load();
      await action();
    });
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> load() => _run(() async {});

  Future<void> _load() async {
    final base = await directory();
    _account = Directory('${base.path}/valuefood_history/${_key(userId)}');
    await _active.create(recursive: true);
    // Recover interrupted writes/deletions before opening the committed scans.
    await for (final entry in _account.list()) {
      if (entry is Directory &&
          entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('temp-')) {
        await _discard(entry);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyKey = 'scanHistory.$userId';
    final legacy = prefs.getStringList(legacyKey);
    if (legacy != null) {
      for (final raw in legacy) {
        final data = jsonDecode(raw) as ScanEntry;
        final id = data['id'] as String;
        if (!await _scan(id).exists()) {
          final preview = data.remove('preview');
          await _writeNew(data, (dest) async {
            if (preview is String && preview.isNotEmpty) {
              await dest.writeAsBytes(base64Decode(preview), flush: true);
            }
          });
        }
      }
      if (!await prefs.remove(legacyKey)) {
        throw StateError('Could not finish migration');
      }
    }
    final entries = <ScanEntry>[];
    await for (final dir in _active.list()) {
      if (dir is! Directory) continue;
      final data = jsonDecode(await _metadata(dir).readAsString()) as ScanEntry;
      entries.add(_withPhoto(data, dir));
    }
    entries.sort((a, b) {
      final order = ((b['scannedAt'] as int?) ?? 0).compareTo(
        (a['scannedAt'] as int?) ?? 0,
      );
      return order != 0
          ? order
          : (b['id'] as String).compareTo(a['id'] as String);
    });
    _loaded = true;
    _publish(entries);
  }

  ScanEntry _withPhoto(ScanEntry data, Directory dir) => {
    ...data,
    if (data['hasPhoto'] == true) 'photoPath': _photo(dir).path,
  };

  Future<ScanEntry> _writeNew(
    ScanEntry data,
    Future<void> Function(File) copyPhoto,
  ) async {
    final target = _scan(data['id'] as String);
    final temp = await _account.createTemp('temp-');
    try {
      await copyPhoto(_photo(temp));
      final saved = {...data, 'hasPhoto': await _photo(temp).exists()};
      await _metadata(temp).writeAsString(jsonEncode(saved), flush: true);
      await temp.rename(target.path);
      return _withPhoto(saved, target);
    } finally {
      await _discard(temp);
    }
  }

  Future<void> add(ScanEntry data, File photo) => _run(() async {
    final entry = await _writeNew(data, (dest) async {
      await photo.copy(dest.path);
    });
    _publish([entry, ...value]);
  });

  /// Enrichment arriving after a deletion must never recreate the scan.
  Future<void> update(String id, ScanEntry changes) => _run(() async {
    final dir = _scan(id);
    final file = _metadata(dir);
    if (!await file.exists()) return;
    final previous = jsonDecode(await file.readAsString()) as ScanEntry;
    final data = {...previous, ...changes};
    final temp = File('${dir.path}/result.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
    _publish([
      for (final e in value)
        if (e['id'] == id) _withPhoto(data, dir) else e,
    ]);
  });

  Future<void> remove(String id) => _run(() async {
    await _detach(_scan(id));
    _publish([
      for (final e in value)
        if (e['id'] != id) e,
    ]);
  });

  Future<void> clear() => _run(() async {
    await _detach(_active);
    _publish([]);
    await _active.create(recursive: true);
  });

  Future<void> _detach(Directory dir) async {
    if (!await dir.exists()) return;
    // Renaming removes the photo and its metadata from history together.
    final trash = await dir.rename(
      '${_account.path}/temp-trash-${DateTime.now().microsecondsSinceEpoch}',
    );
    await _discard(trash);
  }

  Future<void> _discard(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // The next load retries cleanup of detached folders.
    }
  }

  void _publish(List<ScanEntry> entries) {
    if (!_disposed) value = List.unmodifiable(entries);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
