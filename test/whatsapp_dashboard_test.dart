import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ojay_and_mae_invitation/ojay_and_mae.dart';

void main() {
  group('WhatsAppInvitationHelper unit tests', () {
    test('normalizePhone handles Indonesian local, +62, missing 0, and international numbers', () {
      expect(WhatsAppInvitationHelper.normalizePhone('0812-3456-7890'), '6281234567890');
      expect(WhatsAppInvitationHelper.normalizePhone('+62 812 3456 7890'), '6281234567890');
      expect(WhatsAppInvitationHelper.normalizePhone('8123456789'), '628123456789');
      expect(WhatsAppInvitationHelper.normalizePhone('006581234567'), '6581234567');
      expect(WhatsAppInvitationHelper.normalizePhone('   '), '');
    });

    test('isValidOptionalPhone validates empty and valid/invalid lengths', () {
      expect(WhatsAppInvitationHelper.isValidOptionalPhone(''), isTrue);
      expect(WhatsAppInvitationHelper.isValidOptionalPhone('08123456789'), isTrue);
      expect(WhatsAppInvitationHelper.isValidOptionalPhone('12345'), isFalse);
    });

    test('formatPhoneDisplay formats Indonesian numbers cleanly', () {
      expect(WhatsAppInvitationHelper.formatPhoneDisplay('6281234567890'), '+62 812-3456-7890');
      expect(WhatsAppInvitationHelper.formatPhoneDisplay('6581234567'), '+6581234567');
    });

    test('normalizeBaseUrl strips /dashboard path and trailing slashes', () {
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('https://ojay-mae.vercel.app/dashboard/'),
        'https://ojay-mae.vercel.app',
      );
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('https://example.com/wedding/dashboard?a=1#frag'),
        'https://example.com/wedding',
      );
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('ojay-mae.vercel.app/'),
        'https://ojay-mae.vercel.app',
      );
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('http://localhost:8080/dashboard'),
        'http://localhost:8080',
      );
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('http://localhost:8080/index.html'),
        'http://localhost:8080',
      );
      expect(
        WhatsAppInvitationHelper.normalizeBaseUrl('http://localhost:8080/kirim'),
        'http://localhost:8080/kirim',
      );
      expect(WhatsAppInvitationHelper.isSupportedImportFilename('tamu.csv'), isTrue);
      expect(WhatsAppInvitationHelper.isSupportedImportFilename('backup.JSON'), isTrue);
      expect(WhatsAppInvitationHelper.isSupportedImportFilename('tamu.xlsx'), isFalse);
      expect(WhatsAppInvitationHelper.isSupportedImportFilename('tamu.txt'), isFalse);
    });

    test(
      'buildInvitationLink safely encodes special chars and round-trips with resolveRecipientName',
      () {
        final link = WhatsAppInvitationHelper.buildInvitationLink(
          baseUrl: 'https://ojay-mae.vercel.app/',
          guestName: 'Budi (Kantor) & Ibu!',
        );
        expect(link, 'https://ojay-mae.vercel.app/?to=Budi%20%28Kantor%29%20%26%20Ibu%21');
        expect(OjayMaeWeddingApp.resolveRecipientName(Uri.parse(link)), 'Budi (Kantor) & Ibu!');
      },
    );

    test('buildWhatsAppUri constructs free wa.me deep link with or without phone number', () {
      final withPhone = WhatsAppInvitationHelper.buildWhatsAppUri(
        normalizedPhone: '081234567890',
        message: 'Halo Budi!',
      );
      expect(withPhone.toString(), 'https://wa.me/6281234567890?text=Halo%20Budi!');

      final withoutPhone = WhatsAppInvitationHelper.buildWhatsAppUri(
        normalizedPhone: '',
        message: 'Halo Rina!',
      );
      expect(withoutPhone.toString(), 'https://wa.me/?text=Halo%20Rina!');
    });

    test(
      'parseBulkGuestText parses CSV only (comma, semicolon, quoted, BOM, headers, swapped cols)',
      () {
        const sample =
            '\uFEFF'
            '''
Nama Tamu,Nomor WhatsApp,Kategori,Status Kirim,Waktu Kirim,Link Undangan,Status RSVP
Budi Santoso, 081234567890, Teman, Terkirim, , https://ojay-mae.vercel.app/?to=Budi, Hadir
"Bapak Ahmad, S.T.", +62 856-9876-5432, Keluarga, Belum Dikirim, , https://ojay-mae.vercel.app/?to=Ahmad, Belum RSVP
Rina Wijaya; ; Tetangga
Hendra Kusuma
''';
        final drafts = WhatsAppInvitationHelper.parseBulkGuestText(sample);
        expect(drafts, hasLength(4));

        expect(drafts[0].name, 'Budi Santoso');
        expect(drafts[0].phone, '6281234567890');
        expect(drafts[0].category, 'Teman');
        expect(drafts[0].note, '');

        expect(drafts[1].name, 'Bapak Ahmad, S.T.');
        expect(drafts[1].phone, '6285698765432');
        expect(drafts[1].category, 'Keluarga');

        expect(drafts[2].name, 'Rina Wijaya');
        expect(drafts[2].phone, '');
        expect(drafts[2].category, 'Tetangga');

        expect(drafts[3].name, 'Hendra Kusuma');
        expect(drafts[3].phone, '');
        expect(drafts[3].category, 'Teman');

        final swapped = WhatsAppInvitationHelper.parseBulkGuestText(
          '081900001111, Andi Pratama, VIP',
        );
        expect(swapped, hasLength(1));
        expect(swapped.first.name, 'Andi Pratama');
        expect(swapped.first.phone, '6281900001111');
        expect(swapped.first.category, 'VIP');
      },
    );

    test('exportBackupJson and parseBackupJson round-trip cleanly', () {
      final guests = [
        GuestInvitation(
          id: 'g1',
          name: 'Faiq',
          phone: '628123456789',
          category: 'Teman',
          note: 'VIP',
          sendStatus: .sent,
          sentCount: 2,
          createdAt: DateTime(2026, 11, 15, 10),
          sentAt: DateTime(2026, 11, 15, 11),
        ),
      ];
      final json = WhatsAppInvitationHelper.exportBackupJson(
        guests: guests,
        baseUrl: 'https://ojay-mae.vercel.app',
        template: 'Halo {nama} {link}',
        activePresetId: 'custom',
      );
      final parsed = WhatsAppInvitationHelper.parseBackupJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.baseUrl, 'https://ojay-mae.vercel.app');
      expect(parsed.template, 'Halo {nama} {link}');
      expect(parsed.guests, hasLength(1));
      expect(parsed.guests.first.name, 'Faiq');
      expect(parsed.guests.first.sendStatus, GuestSendStatus.sent);
      expect(parsed.guests.first.sentCount, 2);

      final csv = WhatsAppInvitationHelper.exportGuestsToCsv(
        guests: guests,
        baseUrl: 'https://ojay-mae.vercel.app',
        rsvpByRecipient: const {
          'faiq': GuestRsvpSnapshot(
            attendanceLabel: 'Hadir',
            senderName: 'Faiq',
            message: 'Selamat!',
          ),
        },
      );
      expect(csv, contains('https://ojay-mae.vercel.app/?to=Faiq'));
      expect(csv, contains('Hadir'));

      final store = GuestDashboardStore(baseUrl: 'https://active-domain.example');
      addTearDown(store.dispose);
      expect(store.importJsonBackup(json), isTrue);
      // Domain link selalu mengikuti domain yang membuka dashboard, bukan domain lama di JSON.
      expect(store.baseUrl, 'https://active-domain.example');
    });

    test('planRsvpSync and RSVP cache codec minimize Firestore reads', () {
      // Unchanged totalCount -> 0 document reads needed (only 1 count() check)
      final unchanged = WhatsAppInvitationHelper.planRsvpSync(
        hasCache: true,
        cachedTotalCount: 42,
        remoteTotalCount: 42,
      );
      expect(unchanged.action, RsvpSyncAction.noChanges);
      expect(unchanged.fetchLimit, 0);

      // Small delta -> fetch only delta + 2 newest docs instead of full collection
      final deltaPlan = WhatsAppInvitationHelper.planRsvpSync(
        hasCache: true,
        cachedTotalCount: 42,
        remoteTotalCount: 44,
      );
      expect(deltaPlan.action, RsvpSyncAction.fetchDelta);
      expect(deltaPlan.fetchLimit, 4);

      // Cold start -> bounded by maxColdStartRsvpDocs (100)
      final coldLarge = WhatsAppInvitationHelper.planRsvpSync(
        hasCache: false,
        cachedTotalCount: 0,
        remoteTotalCount: 350,
      );
      expect(coldLarge.action, RsvpSyncAction.fetchFull);
      expect(coldLarge.fetchLimit, 100);

      // Cache round-trip preserves summary & recipient map
      final checkedAt = DateTime(2026, 11, 15, 21, 45);
      final encoded = WhatsAppInvitationHelper.serializeRsvpCache(
        const RsvpSummarySnapshot(
          totalCount: 15,
          attendingCount: 11,
          notAttendingCount: 2,
          uncertainCount: 2,
          byNormalizedRecipient: {
            'budi santoso': GuestRsvpSnapshot(
              attendanceLabel: 'Hadir',
              senderName: 'Budi Santoso',
              message: '',
            ),
          },
          isLoading: false,
          isConnected: true,
        ),
        checkedAt,
      );
      final restored = WhatsAppInvitationHelper.parseRsvpCache(encoded);
      expect(restored, isNotNull);
      expect(restored!.checkedAt, checkedAt);
      expect(restored.summary.totalCount, 15);
      expect(restored.summary.attendingCount, 11);
      expect(restored.summary.notAttendingCount, 2);
      expect(restored.summary.uncertainCount, 2);
      expect(restored.summary.byNormalizedRecipient['budi santoso']?.attendanceLabel, 'Hadir');
    });
  });

  group('InvitationDashboardScreen widget & routing tests', () {
    testWidgets('Route /dashboard opens cleaned WhatsApp dashboard directly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.defaultRouteNameTestValue = '/dashboard';
      addTearDown(() {
        tester.platformDispatcher.clearDefaultRouteNameTestValue();
        tester.view.reset();
      });

      await tester.pumpWidget(const OjayMaeWeddingApp());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(InvitationDashboardScreen), findsOneWidget);
      expect(find.text('Dashboard Undangan WA'), findsOneWidget);
      expect(find.text('100% Gratis • Direct WhatsApp'), findsNothing);
      expect(find.text('Domain Link Undangan'), findsNothing);
      expect(find.text('Lihat Undangan'), findsNothing);
      expect(find.text('Catatan (Opsional)'), findsNothing);
      expect(find.text('Simpan & Kirim'), findsNothing);
    });

    testWidgets('Only /dashboard opens dashboard; legacy routes and query params do not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.defaultRouteNameTestValue = '/?page=dashboard';
      addTearDown(() {
        tester.platformDispatcher.clearDefaultRouteNameTestValue();
        tester.view.reset();
      });

      await tester.pumpWidget(const OjayMaeWeddingApp());
      await tester.pump();

      expect(find.byType(InvitationDashboardScreen), findsNothing);
      expect(find.byType(InvitationScreen), findsOneWidget);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/dashboard')), isTrue);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/dashboard/')), isTrue);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/admin')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/kirim')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/kirim-undangan')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/?page=dashboard')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/?mode=dashboard')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/?dashboard=1')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/#/dashboard')), isFalse);
      expect(OjayMaeWeddingApp.isDashboardRoute(Uri.parse('/?to=Budi')), isFalse);
    });

    testWidgets(
      'Desktop layout aligns select-all & quick-add, opens add popup without notes/send, and cleans export & cards',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = GuestDashboardStore(baseUrl: 'https://ojay-mae.vercel.app');
        addTearDown(store.dispose);

        await tester.pumpWidget(MaterialApp(home: InvitationDashboardScreen(store: store)));
        await tester.pump();

        // No top-left Add Guest card and no status filter buttons
        expect(find.text('Tambah Tamu'), findsNothing);
        expect(find.text('Semua'), findsNothing);
        expect(find.text('Sudah RSVP'), findsNothing);

        final filterWrap = find
            .ancestor(of: find.text('Semua Kategori'), matching: find.byType(Wrap))
            .first;
        expect(find.descendant(of: filterWrap, matching: find.text('Semua')), findsNothing);
        expect(find.descendant(of: filterWrap, matching: find.text('Belum Dikirim')), findsNothing);
        expect(find.descendant(of: filterWrap, matching: find.text('Terkirim')), findsNothing);
        expect(
          find.descendant(of: filterWrap, matching: find.text('Sudah Terkirim')),
          findsNothing,
        );
        expect(find.descendant(of: filterWrap, matching: find.text('Sudah RSVP')), findsNothing);
        expect(find.descendant(of: filterWrap, matching: find.text('Keluarga')), findsOneWidget);

        // All 4 summary stat cards share identical height on desktop
        final desktopStatHeights = [
          for (final label in const ['Total Tamu', 'Belum Dikirim', 'Sudah Terkirim', 'RSVP Masuk'])
            tester
                .getSize(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first)
                .height,
        ];
        for (final h in desktopStatHeights) {
          expect(h, closeTo(desktopStatHeights.first, 0.01));
        }

        // Add first guest via quick-add popup form (no Catatan, no Simpan & Kirim)
        await tester.tap(find.text('Tambah Tamu Baru'));
        await tester.pumpAndSettle();

        final dialogFinder = find.byType(AlertDialog);
        await tester.enterText(
          find.descendant(
            of: dialogFinder,
            matching: find.widgetWithText(TextField, 'Nama Tamu *'),
          ),
          'Budi Santoso',
        );
        await tester.enterText(
          find.descendant(
            of: dialogFinder,
            matching: find.widgetWithText(TextField, 'Nomor WhatsApp (Opsional)'),
          ),
          '081234567890',
        );
        await tester.pump();

        await tester.tap(find.descendant(of: dialogFinder, matching: find.text('Tambah Daftar')));
        await tester.pumpAndSettle();

        expect(find.text('Budi Santoso'), findsOneWidget);
        expect(find.text('+62 812-3456-7890'), findsOneWidget);
        expect(find.text('https://ojay-mae.vercel.app/?to=Budi%20Santoso'), findsOneWidget);
        expect(find.text('Preview'), findsNothing);

        // Verify PopupMenu on card has Edit & Hapus but no Preview Undangan
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Preview Undangan'), findsNothing);
        expect(find.text('Edit Data Tamu'), findsOneWidget);
        await tester.tap(find.text('Edit Data Tamu'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Data Tamu'), findsOneWidget);
        expect(find.text('Catatan (Opsional)'), findsNothing);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        // Verify "Pilih semua" checkbox is outside the filter card, aligned horizontally with card checkbox,
        // and "Tambah Tamu Baru" button sits horizontally aligned at the right edge.
        final checkBoxes = find.byIcon(Icons.check_box_outline_blank_rounded);
        expect(checkBoxes, findsNWidgets(2));
        final selectAllDx = tester.getTopLeft(checkBoxes.first).dx;
        final itemCheckboxDx = tester.getTopLeft(checkBoxes.at(1)).dx;
        expect(selectAllDx, closeTo(itemCheckboxDx, 0.5));

        final selectAllCenterY = tester.getCenter(find.text('Pilih semua (1)')).dy;
        final quickAddFinder = find.text('Tambah Tamu Baru');
        expect(quickAddFinder, findsOneWidget);
        expect(tester.getCenter(quickAddFinder).dy, closeTo(selectAllCenterY, 2.0));

        // Tap quick add button -> opens popup Tambah Tamu Baru without notes or Simpan & Kirim WA
        await tester.tap(quickAddFinder);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Tambah Tamu Baru')),
          findsOneWidget,
        );
        expect(find.text('Catatan (Opsional)'), findsNothing);
        expect(find.text('Simpan & Kirim WA'), findsNothing);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextField, 'Nama Tamu *'),
          ),
          'Tamu Baru',
        );
        await tester.pump();
        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Tambah Daftar')),
        );
        await tester.pumpAndSettle();
        expect(store.totalGuests, 2);

        // Verify Export dialog removes Import button & Excel text
        await tester.tap(find.text('Backup / CSV'));
        await tester.pumpAndSettle();
        expect(find.text('Salin Data CSV'), findsOneWidget);
        expect(find.text('Salin Backup JSON'), findsOneWidget);
        expect(find.textContaining('Excel'), findsNothing);
        expect(find.text('Impor CSV / JSON Backup'), findsNothing);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        // Send first guest via WhatsApp marks guest as Terkirim
        await tester.tap(find.text('Kirim WhatsApp').first);
        await tester.pump();
        expect(store.sentCount, 1);

        // Add 2 more guests via Bulk Import modal (CSV)
        await tester.tap(find.text('Impor Massal'));
        await tester.pumpAndSettle();

        final bulkField = find.byType(TextField).last;
        await tester.enterText(bulkField, 'Siti Aminah, 085611112222\nRina Wijaya');
        await tester.pump();
        expect(find.text('Impor 2 Tamu'), findsOneWidget);

        await tester.tap(find.text('Impor 2 Tamu'));
        await tester.pumpAndSettle();

        expect(store.totalGuests, 4);
        expect(store.pendingCount, 3);

        // Launch Guided Queue for the 3 pending guests
        await tester.tap(find.text('Antrean Kirim (3)'));
        await tester.pumpAndSettle();

        expect(find.text('Antrean Kirim Cepat (Gratis)'), findsOneWidget);
        expect(find.text('Tamu 1 dari 3'), findsOneWidget);

        await tester.tap(find.text('Buka WhatsApp & Lanjut'));
        await tester.pump();
        await tester.tap(find.text('Buka WhatsApp & Lanjut'));
        await tester.pump();
        await tester.tap(find.text('Buka WhatsApp & Lanjut'));
        await tester.pump();
        expect(find.text('Antrean Selesai!'), findsOneWidget);

        await tester.tap(find.text('Selesai'));
        await tester.pumpAndSettle();

        expect(store.sentCount, 4);
        expect(store.pendingCount, 0);
      },
    );

    testWidgets('Mobile layout renders cleanly with tab switching and quick add modal', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = GuestDashboardStore(baseUrl: 'https://ojay-mae.vercel.app');
      addTearDown(store.dispose);

      await tester.pumpWidget(MaterialApp(home: InvitationDashboardScreen(store: store)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Daftar Tamu (0)'), findsOneWidget);
      expect(find.text('Template Pesan'), findsOneWidget);

      // Mobile header action buttons are hidden by default and can expand/collapse via Menu/Tutup.
      expect(find.text('Impor Massal'), findsNothing);
      expect(find.text('Backup / CSV'), findsNothing);
      expect(find.text('Antrean Kirim (0)'), findsNothing);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Impor Massal'), findsOneWidget);
      expect(find.text('Backup / CSV'), findsOneWidget);
      expect(find.text('Antrean Kirim (0)'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Impor Massal'), findsNothing);
      expect(find.text('Backup / CSV'), findsNothing);
      expect(find.text('Antrean Kirim (0)'), findsNothing);

      // All 4 summary stat cards also share identical height in mobile 2x2 grid
      final mobileStatHeights = [
        for (final label in const ['Total Tamu', 'Belum Dikirim', 'Sudah Terkirim', 'RSVP Masuk'])
          tester
              .getSize(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first)
              .height,
      ];
      for (final h in mobileStatHeights) {
        expect(h, closeTo(mobileStatHeights.first, 0.01));
      }

      // Switch to Template Pesan tab and verify preset chips (no Domain Link or Backup & Pindah Perangkat card)
      await tester.tap(find.text('Template Pesan'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Domain Link Undangan'), findsNothing);
      expect(find.text('Backup & Pindah Perangkat'), findsNothing);
      expect(find.text('Kelola'), findsNothing);
      expect(find.text('Template Pesan WhatsApp'), findsOneWidget);
      expect(find.text('Santai & Sahabat'), findsOneWidget);

      await tester.tap(find.text('Santai & Sahabat'));
      await tester.pump();
      expect(store.activePresetId, 'santai_teman');

      // Switch back to guests tab and tap Tambah Tamu Baru
      await tester.tap(find.text('Daftar Tamu (0)'));
      await tester.pump();
      await tester.tap(find.text('Tambah Tamu Baru'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Tambah Tamu Baru')),
        findsOneWidget,
      );
      expect(find.text('Catatan (Opsional)'), findsNothing);
      expect(find.text('Simpan & Kirim WA'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Nama Tamu *'), 'Dian Permata');
      await tester.pump();
      await tester.tap(find.text('Tambah Daftar'));
      await tester.pumpAndSettle();

      expect(store.totalGuests, 1);
      await tester.scrollUntilVisible(
        find.text('Dian Permata'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dian Permata'), findsOneWidget);
      expect(find.text('Pilih Kontak WA'), findsOneWidget);

      // Verify "Pilih semua -- Tambah Tamu Baru" row stays pinned at the top when scrolling down.
      store.importDrafts([
        for (var i = 1; i <= 12; i++)
          ParsedGuestDraft(
            name: 'Tamu Scroll $i',
            phone: '',
            category: 'Teman',
            note: '',
            isPhoneValid: true,
          ),
      ]);
      await tester.pump();

      final listScrollable = find.byType(Scrollable).first;
      final scrollableTop = tester.getTopLeft(listScrollable).dy;
      await tester.drag(listScrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Total Tamu'), findsNothing);
      final selectAllFinder = find.text('Pilih semua (13)');
      final quickAddPinnedFinder = find.text('Tambah Tamu Baru');
      expect(selectAllFinder, findsOneWidget);
      expect(quickAddPinnedFinder, findsOneWidget);

      final pinnedSelectY = tester.getTopLeft(selectAllFinder).dy;
      final pinnedAddY = tester.getTopLeft(quickAddPinnedFinder).dy;
      expect(pinnedSelectY, greaterThanOrEqualTo(scrollableTop));
      expect(pinnedSelectY, lessThanOrEqualTo(scrollableTop + 28));
      expect(pinnedAddY, greaterThanOrEqualTo(scrollableTop));
      expect(pinnedAddY, lessThanOrEqualTo(scrollableTop + 24));

      // Tapping pinned "Pilih semua (13)" while scrolled selects all visible guests cleanly.
      await tester.tap(selectAllFinder);
      await tester.pump();
      expect(store.selectedIds, hasLength(13));
      expect(find.text('Kirim Terpilih (13)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Route / still opens InvitationScreen cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const OjayMaeWeddingApp(recipientName: 'Budi'));
      await tester.pump();

      expect(find.byType(InvitationScreen), findsOneWidget);
      expect(find.text('Buka Undangan'), findsOneWidget);
    });
  });
}
