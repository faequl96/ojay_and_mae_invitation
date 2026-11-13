import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';

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
}
