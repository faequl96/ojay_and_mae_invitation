import 'dart:async';
import 'dart:js_interop';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';

@JS('updateSplashProgress')
external JSPromise? _jsUpdateSplashProgress(
  double initialPercent,
  double targetPercent,
  double minMs,
  double maxMs,
);

Future<void> _updateSplash(
  double initialPercent,
  double targetPercent,
  double minMs,
  double maxMs,
) async {
  try {
    final promise = _jsUpdateSplashProgress(
      initialPercent,
      targetPercent,
      minMs,
      maxMs,
    );
    if (promise != null) await promise.toDart;
  } catch (_) {}
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  final recipientName = OjayMaeWeddingApp.resolveRecipientName();

  await Future.wait([
    _initFirebase(),
    _updateSplash(80, 95, 50, 350),
    preCacheAssetImages(),
  ]);

  await _updateSplash(95, 100, 150, 250);

  runApp(OjayMaeWeddingApp(recipientName: recipientName));
}

Future<void> preCacheAssetImages() async {
  final views = PlatformDispatcher.instance.views;
  final devicePixelRatio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
  final config = ImageConfiguration(devicePixelRatio: devicePixelRatio);

  final futures = <Future<void>>[];
  for (final assetPath in InvitationAssets.all) {
    final completer = Completer<void>();
    final stream = AssetImage(assetPath).resolve(config);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    futures.add(completer.future);
  }

  await Future.wait(futures).timeout(
    const Duration(seconds: 3),
    onTimeout: () => const [],
  );
}
