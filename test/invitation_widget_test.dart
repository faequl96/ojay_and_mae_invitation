import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';
import 'package:ojay_and_mae_invitation/src/music_player.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';

Future<void> _pumpFrames(WidgetTester tester, {int steps = 16, int stepMs = 100}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(Duration(milliseconds: stepMs));
  }
}

Future<void> _centerOnScreen(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await _pumpFrames(tester, steps: 15, stepMs: 100);
}

void main() {
  testWidgets('Cover gate opens invitation and renders hero on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const OjayMaeWeddingApp(recipientName: 'Budi'));
    await tester.pump();

    expect(find.text('Buka Undangan'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);

    await tester.tap(find.text('Buka Undangan'));
    await _pumpFrames(tester, steps: 15, stepMs: 100);

    expect(find.text('Buka Undangan'), findsNothing);
    expect(find.text('Sabtu, 19 Desember 2026'), findsOneWidget);
  });

  testWidgets('Desktop nav chips scroll to offscreen lazy sliver sections', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const OjayMaeWeddingApp(recipientName: 'Siti'));
    await tester.pump();

    await tester.tap(find.text('Buka Undangan'));
    await _pumpFrames(tester, steps: 15, stepMs: 100);

    expect(find.text('Pembuka'), findsOneWidget);
    expect(find.text('Penutup'), findsOneWidget);

    await tester.tap(find.text('RSVP'));
    await _pumpFrames(tester, steps: 20, stepMs: 100);

    expect(find.text('RSVP & Ucapan Doa'), findsOneWidget);
    expect(find.text('Kirim Konfirmasi'), findsOneWidget);

    await tester.tap(find.text('Penutup'));
    await _pumpFrames(tester, steps: 20, stepMs: 100);

    expect(find.text('Terima Kasih'), findsOneWidget);
  });

  testWidgets('RSVP form validation, submission, and pagination work without Firebase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const OjayMaeWeddingApp(recipientName: 'Rina'));
    await tester.pump();

    await tester.tap(find.text('Buka Undangan'));
    await _pumpFrames(tester, steps: 15, stepMs: 100);

    await tester.tap(find.text('RSVP'));
    await _pumpFrames(tester, steps: 20, stepMs: 100);

    // Pagination moves to page 2 and back to page 1
    expect(find.text('Hal 1 / 2'), findsOneWidget);
    await _centerOnScreen(tester, find.text('Selanjutnya'));
    await tester.tap(find.text('Selanjutnya'));
    await tester.pump();
    expect(find.text('Hal 2 / 2'), findsOneWidget);

    await _centerOnScreen(tester, find.text('Sebelumnya'));
    await tester.tap(find.text('Sebelumnya'));
    await tester.pump();
    expect(find.text('Hal 1 / 2'), findsOneWidget);

    // Submit with empty message shows validation snackbar
    await _centerOnScreen(tester, find.text('Kirim Konfirmasi'));
    await tester.tap(find.text('Kirim Konfirmasi'));
    await tester.pump();
    expect(find.text('Mohon isi nama dan ucapan doa terlebih dahulu.'), findsOneWidget);

    // Select attendance chip, enter message, and submit
    final uncertainChip = find.text('Masih Ragu').first;
    await _centerOnScreen(tester, uncertainChip);
    await tester.tap(uncertainChip);
    await tester.pump();

    final messageField = find.byType(EditableText).last;
    await tester.enterText(messageField, 'Semoga sakinah mawaddah warahmah!');
    await tester.pump();

    await _centerOnScreen(tester, find.text('Kirim Konfirmasi'));
    await tester.tap(find.text('Kirim Konfirmasi'));
    await _pumpFrames(tester, steps: 10, stepMs: 60);

    expect(find.text('Semoga sakinah mawaddah warahmah!'), findsOneWidget);
    expect(find.text('Hal 1 / 2'), findsOneWidget);
  });

  testWidgets(
    'Cover morphs smoothly into bottom-right rotating DVD player with pause, play, and replay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const OjayMaeWeddingApp(recipientName: 'Siti'));
      await tester.pump();

      expect(find.text('Buka Undangan'), findsOneWidget);
      await tester.tap(find.text('Buka Undangan'));

      // Pump intermediate morph frames to verify smooth progression without layout errors.
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // Morph completes: cover button gone, DVD controls docked at bottom-right.
      expect(find.text('Buka Undangan'), findsNothing);
      final pauseFinder = find.byIcon(Icons.pause_rounded);
      final replayFinder = find.byIcon(Icons.replay_rounded);
      expect(pauseFinder, findsOneWidget);
      expect(replayFinder, findsOneWidget);

      final pausePos = tester.getCenter(pauseFinder);
      final replayPos = tester.getCenter(replayFinder);
      expect(pausePos.dx, greaterThan(390 * 0.5));
      expect(pausePos.dy, greaterThan(844 * 0.85));
      expect(replayPos.dx, lessThan(pausePos.dx));

      // Verify DVD disc is actively rotating while music plays.
      double currentDiscAngle() {
        final discTransforms = tester.widgetList<Transform>(
          find.byWidgetPredicate(
            (w) => w is Transform && w.alignment == Alignment.center && w.child is Stack,
          ),
        );
        final matrix = discTransforms.last.transform;
        return math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
      }

      final angleStart = currentDiscAngle();
      await tester.pump(const Duration(milliseconds: 400));
      final anglePlaying = currentDiscAngle();
      expect((anglePlaying - angleStart).abs(), greaterThan(0.05));

      // Pause music: icon switches to play and rotation freezes at current angle.
      await tester.tap(pauseFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      final anglePaused1 = currentDiscAngle();
      await tester.pump(const Duration(milliseconds: 400));
      final anglePaused2 = currentDiscAngle();
      expect((anglePaused2 - anglePaused1).abs(), lessThan(0.0001));

      // Play music: icon switches back to pause and rotation resumes smoothly.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      final angleResumed1 = currentDiscAngle();
      await tester.pump(const Duration(milliseconds: 400));
      final angleResumed2 = currentDiscAngle();
      expect((angleResumed2 - angleResumed1).abs(), greaterThan(0.05));

      // Pause again, then tap Replay: music restarts and switches back to playing state.
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(replayFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    },
  );

  test('Audio stops cleanly on track completion without auto-looping and replays cleanly', () {
    var endedCalled = false;
    final engine = WebAudioEngine(
      assetPath: InvitationMusicController.defaultMusicAsset,
      onEnded: () => endedCalled = true,
    );

    engine.play();
    expect(engine.isPlaying, isTrue);

    // Track finishes naturally: should NOT auto-loop.
    engine.debugCompleteTrack();
    expect(endedCalled, isTrue);
    expect(engine.isPlaying, isFalse);
    expect(engine.progress, 1.0);

    // Pressing play after ended restarts from 0.
    engine.play();
    expect(engine.isPlaying, isTrue);
    expect(engine.progress, 0.0);

    // Replay resets to 0 and keeps playing.
    engine.debugCompleteTrack();
    expect(engine.isPlaying, isFalse);
    engine.replay();
    expect(engine.isPlaying, isTrue);
    expect(engine.progress, 0.0);

    engine.dispose();
  });
}
