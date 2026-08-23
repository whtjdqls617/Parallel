import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/parallel_app.dart';
import 'audio/ambient_music.dart';
import 'firebase_options.dart';
import 'notify/push_service.dart';
import 'subscription/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (_) {
    // Reads still work; writes require auth.
  }
  // RevenueCat + Firebase uid — features stay unlocked until we gate later.
  await SubscriptionService.instance.start(
    firebaseUid: FirebaseAuth.instance.currentUser?.uid,
  );
  // Reply push — needs permission; best-effort.
  unawaited(PushService.instance.start());
  // Don't pause Spotify / other apps when our nature bed starts.
  await AmbientMusic.ensureMixWithOthers();
  runApp(const ParallelApp());
}
