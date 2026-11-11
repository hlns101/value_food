import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class AppHaptics {
  static bool enabled = true;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  static int _generation = 0;
  static void start() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      final generation = ++_generation;
      enabled = false;
      await _profile?.cancel();
      if (generation != _generation) return;
      if (user != null) {
        _profile = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
              if (generation == _generation)
                enabled = doc.data()?['hapticsEnabled'] != false;
            }, onError: (Object _) {});
      }
    });
  }

  static void selection() {
    if (enabled)
      unawaited(HapticFeedback.heavyImpact().catchError((Object _) {}));
  }
}
