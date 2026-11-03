import 'dart:async';
import 'dart:js_interop';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

@JS('updateSplashProgress')
external JSPromise _jsUpdateSplashProgress(
  double initialPercent,
  double targetPercent,
  double minMs,
  double maxMs,
);

void main() async {
  usePathUrlStrategy();

  RsvpController rsvpController;
  try {
    await Firebase.initializeApp();
    rsvpController = RsvpController();
    unawaited(rsvpController.loadInitialMessages());
  } catch (_) {
    rsvpController = RsvpController(firestore: null);
  }

  await _jsUpdateSplashProgress(80, 95, 50, 350).toDart;

  // await Future.delayed(const Duration(seconds: 1));

  await _jsUpdateSplashProgress(95, 100, 150, 250).toDart;

  runApp(OjayMaeOutlawWeddingApp(rsvpController: rsvpController));
}
