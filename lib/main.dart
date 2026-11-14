import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';
import 'package:ojay_and_mae_invitation/src/firebase_bootstrap.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  WebInterop.stopActiveAudio();

  // Initialize Firebase concurrently so first-frame cover rendering is not blocked.
  unawaited(FirebaseBootstrap.ensureInitialized());

  final recipientName = OjayMaeWeddingApp.resolveRecipientName();
  WebInterop.updateSplashProgress(90, 96);

  // Only precache above-the-fold cover assets before first frame.
  await preCacheAssetImages(InvitationAssets.coverCritical)
      .timeout(const Duration(milliseconds: 1200), onTimeout: () {});

  runApp(OjayMaeWeddingApp(recipientName: recipientName));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    WebInterop.completeSplash();
    unawaited(preCacheAssetImages(InvitationAssets.deferred));
  });
}

Future<void> preCacheAssetImages([List<String> assets = InvitationAssets.all]) {
  final views = PlatformDispatcher.instance.views;
  final devicePixelRatio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
  final config = ImageConfiguration(devicePixelRatio: devicePixelRatio);

  final futures = <Future<void>>[];
  for (final assetPath in assets) {
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

  return Future.wait(futures).then((_) {});
}
