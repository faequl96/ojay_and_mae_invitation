import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ojay_and_mae_invitation/src/invitation_theme.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';
import 'package:ojay_and_mae_invitation/src/whatsapp_dashboard_models.dart';

abstract final class _DashboardPalette._() {
  static const Color bg = GothicTheme.bgBlack;
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color surfaceInput = Color(0xFF0B0B0B);
  static const Color border = Color(0x2EFFFFFF);
  static const Color borderStrong = Color(0x52FFFFFF);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF0C2617);
  static const Color whatsappBubble = Color(0xFF0F2D1D);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDark = Color(0xFF2B1E08);
  static const Color sky = Color(0xFF38BDF8);
  static const Color skyDark = Color(0xFF0C2330);
  static const Color rose = Color(0xFFF87171);
  static const Color roseDark = Color(0xFF2C1012);
}

enum _MobileDashboardTab(final String label) {
  guests('Daftar Tamu'),
  settings('Template Pesan'),
}

/// Dashboard pengiriman link undangan Ojay & Mae via WhatsApp.
class const InvitationDashboardScreen({
  super.key,
  final GuestDashboardStore? store,
  final ContactPickerCallback? onPickContact,
  final ContactPickerCallback? onPickContactFile,
}) extends StatefulWidget {
  @override
  State<InvitationDashboardScreen> createState() => _InvitationDashboardScreenState();
}

class _InvitationDashboardScreenState() extends State<InvitationDashboardScreen> {
  late final GuestDashboardStore _store;
  late final bool _ownsStore;
  final ValueNotifier<_MobileDashboardTab> _mobileTab = ValueNotifier<_MobileDashboardTab>(.guests);
  final ValueNotifier<bool> _mobileActionsExpanded = ValueNotifier<bool>(false);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? GuestDashboardStore();
    unawaited(_store.refreshFirestoreRsvps());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _mobileTab.dispose();
    _mobileActionsExpanded.dispose();
    if (_ownsStore) {
      _store.dispose();
    }
    super.dispose();
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(text, style: GothicTheme.snackbarBold),
        ),
      );
  }

  static bool _isMobileViewport(BuildContext context) => MediaQuery.sizeOf(context).width < 1020;

  static Future<T?> _showAdaptivePopup<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (_isMobileViewport(context)) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: barrierDismissible,
        enableDrag: barrierDismissible,
        backgroundColor: _DashboardPalette.surface,
        clipBehavior: .antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: .vertical(top: .circular(20))),
        builder: builder,
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  void _sendGuestViaWhatsApp(GuestInvitation guest) {
    final message = _store.buildMessageForGuest(guest);
    final waUri = _store.buildWhatsAppUriForGuest(guest, customMessage: message);
    // Buka URL secara sinkron di dalam event tap agar tidak diblokir popup blocker browser.
    WebInterop.openExternalUrl(waUri.toString());
    _store.markAsSent(guest.id, sentMessage: message);
    _showSnackBar(
      guest.hasPhone
          ? 'Membuka WhatsApp untuk ${guest.name}...'
          : 'Membuka WhatsApp — pilih kontak untuk ${guest.name}.',
    );
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    _showSnackBar(label);
  }

  Future<void> _openAddGuestDialog() {
    return _showAdaptivePopup<void>(
      context: context,
      builder: (ctx) => _GuestFormDialog(
        title: 'Tambah Tamu Baru',
        submitLabel: 'Tambah Daftar',
        onPickContact: widget.onPickContact,
        onPickContactFile: widget.onPickContactFile,
        onSave: ({required name, required phone, required category}) {
          final created = _store.addGuest(name: name, phone: phone, category: category);
          Navigator.of(ctx).pop();
          _showSnackBar('${created.name} ditambahkan ke daftar tamu.');
        },
      ),
    );
  }

  Future<void> _openEditGuestDialog(GuestInvitation guest) {
    return _showAdaptivePopup<void>(
      context: context,
      builder: (ctx) => _GuestFormDialog(
        title: 'Edit Data Tamu',
        submitLabel: 'Simpan Perubahan',
        initialName: guest.name,
        initialPhone: guest.phone,
        initialCategory: guest.category,
        onPickContact: widget.onPickContact,
        onPickContactFile: widget.onPickContactFile,
        onSave: ({required name, required phone, required category}) {
          _store.updateGuest(id: guest.id, name: name, phone: phone, category: category);
          Navigator.of(ctx).pop();
          _showSnackBar('Data tamu "$name" diperbarui.');
        },
      ),
    );
  }

  Future<void> _openGuestMessagePopup(GuestInvitation guest) {
    return _showAdaptivePopup<void>(
      context: context,
      builder: (ctx) => _GuestMessageDialog(
        guest: guest,
        store: _store,
        onShowMessage: _showSnackBar,
        onCopyMessage: (msg) => _copyText(msg, 'Pesan WA ${guest.name} disalin!'),
        onSendMessage: (msg) {
          final waUri = _store.buildWhatsAppUriForGuest(guest, customMessage: msg);
          WebInterop.openExternalUrl(waUri.toString());
          _store.markAsSent(guest.id, sentMessage: msg);
          _showSnackBar(
            guest.hasPhone
                ? 'Membuka WhatsApp untuk ${guest.name}...'
                : 'Membuka WhatsApp — pilih kontak untuk ${guest.name}.',
          );
        },
      ),
    );
  }

  Future<void> _openBulkImportDialog() {
    return _showAdaptivePopup<void>(
      context: context,
      builder: (ctx) => _BulkImportDialog(
        onImportDrafts: (drafts, {required skipDuplicates}) {
          final result = _store.importDrafts(drafts, skipDuplicateNames: skipDuplicates);
          Navigator.of(ctx).pop();
          _showSnackBar(
            'Berhasil mengimpor ${result.added} tamu'
            '${result.skipped > 0 ? ' (${result.skipped} dilewati)' : ''}.',
          );
        },
        onImportJsonBackup: (rawJson) {
          final ok = _store.importJsonBackup(rawJson);
          if (ok) {
            Navigator.of(ctx).pop();
            _showSnackBar('Backup JSON berhasil diimpor.');
          } else {
            _showSnackBar('Format JSON backup tidak valid.');
          }
        },
      ),
    );
  }

  Future<void> _openBackupExportDialog() {
    return _showAdaptivePopup<void>(
      context: context,
      builder: (ctx) => _BackupExportDialog(store: _store, onShowMessage: _showSnackBar),
    );
  }

  Future<void> _openGuidedQueueDialog() async {
    final queue = _store.queueCandidates();
    if (queue.isEmpty) {
      _showSnackBar('Tidak ada tamu yang belum dikirim atau dipilih.');
      return;
    }

    await _showAdaptivePopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GuidedQueueDialog(
        initialQueue: queue,
        store: _store,
        onSendViaWhatsApp: (guest, customMessage) {
          final waUri = _store.buildWhatsAppUriForGuest(guest, customMessage: customMessage);
          WebInterop.openExternalUrl(waUri.toString());
          _store.markAsSent(guest.id, sentMessage: customMessage);
        },
        onMarkSentOnly: (guest, customMessage) =>
            _store.markAsSent(guest.id, sentMessage: customMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1020;

    return Scaffold(
      backgroundColor: _DashboardPalette.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                _DashboardHeader(
                  isDesktop: isDesktop,
                  mobileActionsExpanded: _mobileActionsExpanded,
                  pendingCount: _store.pendingCount,
                  selectedCount: _store.selectedIds.length,
                  onOpenBulkImport: _openBulkImportDialog,
                  onOpenBackup: _openBackupExportDialog,
                  onStartQueue: _openGuidedQueueDialog,
                ),
                Expanded(
                  child: isDesktop
                      ? _DesktopDashboardBody(
                          store: _store,
                          leftScrollController: _leftScrollController,
                          rightScrollController: _rightScrollController,
                          searchController: _searchController,
                          onShowMessage: _showSnackBar,
                          onOpenAddGuest: _openAddGuestDialog,
                          onSendGuest: _sendGuestViaWhatsApp,
                          onCopyLink: (g) => _copyText(
                            _store.buildLinkForGuest(g),
                            'Link undangan ${g.name} disalin!',
                          ),
                          onCopyMessage: (g) => _copyText(
                            _store.buildMessageForGuest(g),
                            'Pesan WA ${g.name} disalin!',
                          ),
                          onViewMessage: _openGuestMessagePopup,
                          onEditGuest: _openEditGuestDialog,
                          onOpenBulkImport: _openBulkImportDialog,
                          onStartQueue: _openGuidedQueueDialog,
                        )
                      : _MobileDashboardBody(
                          store: _store,
                          mobileTab: _mobileTab,
                          scrollController: _rightScrollController,
                          searchController: _searchController,
                          onShowMessage: _showSnackBar,
                          onOpenAddGuest: _openAddGuestDialog,
                          onSendGuest: _sendGuestViaWhatsApp,
                          onCopyLink: (g) => _copyText(
                            _store.buildLinkForGuest(g),
                            'Link undangan ${g.name} disalin!',
                          ),
                          onCopyMessage: (g) => _copyText(
                            _store.buildMessageForGuest(g),
                            'Pesan WA ${g.name} disalin!',
                          ),
                          onViewMessage: _openGuestMessagePopup,
                          onEditGuest: _openEditGuestDialog,
                          onOpenBulkImport: _openBulkImportDialog,
                          onStartQueue: _openGuidedQueueDialog,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================
class const _DashboardHeader({
  required final bool isDesktop,
  required final ValueNotifier<bool> mobileActionsExpanded,
  required final int pendingCount,
  required final int selectedCount,
  required final VoidCallback onOpenBulkImport,
  required final VoidCallback onOpenBackup,
  required final VoidCallback onStartQueue,
}) extends StatelessWidget {
  static const BoxDecoration _headerDecoration = BoxDecoration(
    color: _DashboardPalette.surface,
    border: Border(bottom: BorderSide(color: _DashboardPalette.border)),
  );
  static final ButtonStyle _outlineStyle = OutlinedButton.styleFrom(
    foregroundColor: GothicTheme.white,
    side: const BorderSide(color: _DashboardPalette.borderStrong),
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
    padding: const .symmetric(horizontal: 12, vertical: 10),
  );
  static final ButtonStyle _mobileToggleStyle = OutlinedButton.styleFrom(
    foregroundColor: GothicTheme.white,
    side: const BorderSide(color: _DashboardPalette.borderStrong),
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
    padding: const .symmetric(horizontal: 10, vertical: 8),
    minimumSize: const Size(0, 34),
  );
  static final ButtonStyle _queueButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: _DashboardPalette.whatsappGreen,
    foregroundColor: GothicTheme.bgBlack,
    disabledBackgroundColor: Colors.white12,
    disabledForegroundColor: Colors.white38,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
    padding: const .symmetric(horizontal: 14, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    final queueCount = selectedCount > 0 ? selectedCount : pendingCount;
    final queueLabel = selectedCount > 0
        ? 'Kirim Terpilih ($selectedCount)'
        : 'Antrean Kirim ($pendingCount)';

    final actionButtons = [
      OutlinedButton.icon(
        onPressed: onOpenBulkImport,
        style: _outlineStyle,
        icon: const Icon(Icons.playlist_add_rounded, size: 16),
        label: Text('Impor Massal', style: GothicTheme.sans(size: 12, weight: .w600)),
      ),
      OutlinedButton.icon(
        onPressed: onOpenBackup,
        style: _outlineStyle,
        icon: const Icon(Icons.download_rounded, size: 16),
        label: Text('Backup / CSV', style: GothicTheme.sans(size: 12, weight: .w600)),
      ),
      ElevatedButton.icon(
        onPressed: queueCount > 0 ? onStartQueue : null,
        style: _queueButtonStyle,
        icon: const Icon(Icons.send_rounded, size: 15),
        label: Text(
          queueLabel,
          style: GothicTheme.sans(
            size: 12,
            color: queueCount > 0 ? GothicTheme.bgBlack : Colors.white38,
            weight: .bold,
          ),
        ),
      ),
    ];

    return DecoratedBox(
      decoration: _headerDecoration,
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 4),
        child: isDesktop
            ? Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: .spaceBetween,
                crossAxisAlignment: .center,
                children: [
                  const Row(
                    mainAxisSize: .min,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: InvitationAssetImage(assetPath: InvitationAssets.coverInitialFF),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: _HeaderBrandTitle()),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: .center,
                    children: actionButtons,
                  ),
                ],
              )
            : ValueListenableBuilder<bool>(
                valueListenable: mobileActionsExpanded,
                builder: (context, expanded, _) {
                  return Column(
                    crossAxisAlignment: .stretch,
                    mainAxisSize: .min,
                    children: [
                      Row(
                        crossAxisAlignment: .center,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: InvitationAssetImage(assetPath: InvitationAssets.coverInitialFF),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: _HeaderBrandTitle()),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: expanded
                                ? 'Sembunyikan tombol impor, ekspor & antrean'
                                : 'Tampilkan tombol impor, ekspor & antrean',
                            child: OutlinedButton.icon(
                              onPressed: () => mobileActionsExpanded.value = !expanded,
                              style: _mobileToggleStyle,
                              icon: Icon(
                                expanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 17,
                              ),
                              label: Text(
                                expanded ? 'Tutup' : 'Menu',
                                style: GothicTheme.sans(size: 11.5, weight: .w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: .topCenter,
                        child: expanded
                            ? Padding(
                                padding: const .only(top: 10, bottom: 6),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: .center,
                                  children: actionButtons,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class const _HeaderBrandTitle() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Text('Dashboard Undangan WA', style: GothicTheme.sans(size: 16, weight: .bold)),
        Text(
          'Ojay & Mae • Sabtu, 19 Desember 2026',
          style: GothicTheme.sans(size: 11.5, color: Colors.white60),
        ),
      ],
    );
  }
}

// ============================================================================
// LAYOUT DESKTOP & MOBILE
// ============================================================================
class const _DesktopDashboardBody({
  required final GuestDashboardStore store,
  required final ScrollController leftScrollController,
  required final ScrollController rightScrollController,
  required final TextEditingController searchController,
  required final ValueChanged<String> onShowMessage,
  required final VoidCallback onOpenAddGuest,
  required final ValueChanged<GuestInvitation> onSendGuest,
  required final ValueChanged<GuestInvitation> onCopyLink,
  required final ValueChanged<GuestInvitation> onCopyMessage,
  required final ValueChanged<GuestInvitation> onViewMessage,
  required final ValueChanged<GuestInvitation> onEditGuest,
  required final VoidCallback onOpenBulkImport,
  required final VoidCallback onStartQueue,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .stretch,
      children: [
        SizedBox(
          width: 420,
          child: CustomScrollView(
            controller: leftScrollController,
            scrollCacheExtent: const .pixels(400),
            slivers: [
              SliverPadding(
                padding: const .all(16),
                sliver: SliverToBoxAdapter(child: _TemplateEditorCard(store: store)),
              ),
            ],
          ),
        ),
        const ColoredBox(
          color: _DashboardPalette.border,
          child: SizedBox(width: 1, height: .infinity),
        ),
        Expanded(
          child: _GuestWorkspaceSliverScroll(
            store: store,
            scrollController: rightScrollController,
            searchController: searchController,
            includeTopPadding: true,
            onOpenAddGuest: onOpenAddGuest,
            onSendGuest: onSendGuest,
            onCopyLink: onCopyLink,
            onCopyMessage: onCopyMessage,
            onViewMessage: onViewMessage,
            onEditGuest: onEditGuest,
            onOpenBulkImport: onOpenBulkImport,
            onStartQueue: onStartQueue,
            onShowMessage: onShowMessage,
          ),
        ),
      ],
    );
  }
}

class const _MobileDashboardBody({
  required final GuestDashboardStore store,
  required final ValueNotifier<_MobileDashboardTab> mobileTab,
  required final ScrollController scrollController,
  required final TextEditingController searchController,
  required final ValueChanged<String> onShowMessage,
  required final VoidCallback onOpenAddGuest,
  required final ValueChanged<GuestInvitation> onSendGuest,
  required final ValueChanged<GuestInvitation> onCopyLink,
  required final ValueChanged<GuestInvitation> onCopyMessage,
  required final ValueChanged<GuestInvitation> onViewMessage,
  required final ValueChanged<GuestInvitation> onEditGuest,
  required final VoidCallback onOpenBulkImport,
  required final VoidCallback onStartQueue,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_MobileDashboardTab>(
      valueListenable: mobileTab,
      builder: (context, activeTab, _) {
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _MobileTabChip(
                      label: 'Daftar Tamu (${store.totalGuests})',
                      selected: activeTab == .guests,
                      onTap: () => mobileTab.value = .guests,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MobileTabChip(
                      label: 'Template Pesan',
                      selected: activeTab == .settings,
                      onTap: () => mobileTab.value = .settings,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: activeTab == .guests
                  ? _GuestWorkspaceSliverScroll(
                      store: store,
                      scrollController: scrollController,
                      searchController: searchController,
                      includeTopPadding: false,
                      onOpenAddGuest: onOpenAddGuest,
                      onSendGuest: onSendGuest,
                      onCopyLink: onCopyLink,
                      onCopyMessage: onCopyMessage,
                      onViewMessage: onViewMessage,
                      onEditGuest: onEditGuest,
                      onOpenBulkImport: onOpenBulkImport,
                      onStartQueue: onStartQueue,
                      onShowMessage: onShowMessage,
                    )
                  : CustomScrollView(
                      scrollCacheExtent: const .pixels(400),
                      slivers: [
                        SliverPadding(
                          padding: const .fromLTRB(14, 4, 14, 24),
                          sliver: SliverToBoxAdapter(child: _TemplateEditorCard(store: store)),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class const _MobileTabChip({
  required final String label,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const BorderRadius _radius = .all(.circular(10));
  static const BoxDecoration _selectedDec = BoxDecoration(
    color: GothicTheme.white,
    borderRadius: _radius,
  );
  static const BoxDecoration _unselectedDec = BoxDecoration(
    color: _DashboardPalette.surfaceElevated,
    borderRadius: _radius,
    border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: selected ? _selectedDec : _unselectedDec,
        child: Padding(
          padding: const .symmetric(vertical: 10, horizontal: 10),
          child: Text(
            label,
            textAlign: .center,
            style: GothicTheme.sans(
              size: 12,
              color: selected ? GothicTheme.bgBlack : GothicTheme.textGrey,
              weight: .bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RIGHT / MAIN WORKSPACE: STATS + SEARCH + FILTER + LAZY SLIVER LIST
// ============================================================================
class const _GuestWorkspaceSliverScroll({
  required final GuestDashboardStore store,
  required final ScrollController scrollController,
  required final TextEditingController searchController,
  required final bool includeTopPadding,
  required final VoidCallback onOpenAddGuest,
  required final ValueChanged<GuestInvitation> onSendGuest,
  required final ValueChanged<GuestInvitation> onCopyLink,
  required final ValueChanged<GuestInvitation> onCopyMessage,
  required final ValueChanged<GuestInvitation> onViewMessage,
  required final ValueChanged<GuestInvitation> onEditGuest,
  required final VoidCallback onOpenBulkImport,
  required final VoidCallback onStartQueue,
  required final ValueChanged<String> onShowMessage,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final filtered = store.filteredGuests;
    final horizontalPad = includeTopPadding ? 20.0 : 14.0;
    final topPad = includeTopPadding ? 16.0 : 4.0;

    return CustomScrollView(
      controller: scrollController,
      scrollCacheExtent: const .pixels(480),
      slivers: [
        SliverPadding(
          padding: .fromLTRB(horizontalPad, topPad, horizontalPad, 6),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                _StatsSummaryRow(store: store),
                const SizedBox(height: 14),
                _GuestFilterToolbar(store: store, searchController: searchController),
              ],
            ),
          ),
        ),
        PinnedHeaderSliver(
          child: _GuestListControlBar(
            store: store,
            horizontalPadding: horizontalPad,
            filteredCount: filtered.length,
            onOpenAddGuest: onOpenAddGuest,
            onStartQueue: onStartQueue,
            onShowMessage: onShowMessage,
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: .symmetric(horizontal: horizontalPad, vertical: 16),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyGuestsState(
                hasAnyGuests: store.totalGuests > 0,
                onClearFilter: () {
                  searchController.clear();
                  store
                    ..setSearchQuery('')
                    ..setFilterMode(.all)
                    ..setCategoryFilter('Semua');
                },
                onOpenBulkImport: onOpenBulkImport,
                onLoadSampleGuests: () {
                  store.loadSampleGuests();
                  onShowMessage('3 contoh tamu ditambahkan.');
                },
              ),
            ),
          )
        else
          SliverPadding(
            padding: .fromLTRB(horizontalPad, 10, horizontalPad, 28),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final guest = filtered[index];
                final rsvp = store.rsvpSummary.byNormalizedRecipient[guest.normalizedName];
                final invitationLink = store.buildLinkForGuest(guest);
                return Padding(
                  key: ValueKey(guest.id),
                  padding: const .only(bottom: 10),
                  child: _GuestCard(
                    guest: guest,
                    invitationLink: invitationLink,
                    rsvpSnapshot: rsvp,
                    isSelected: store.selectedIds.contains(guest.id),
                    onToggleSelect: () => store.toggleSelection(guest.id),
                    onSendWhatsApp: () => onSendGuest(guest),
                    onCopyLink: () => onCopyLink(guest),
                    onCopyMessage: () => onCopyMessage(guest),
                    onViewMessage: () => onViewMessage(guest),
                    onEdit: () => onEditGuest(guest),
                    onToggleStatus: () {
                      if (guest.sendStatus == .sent) {
                        store.markAsPending(guest.id);
                      } else {
                        store.markAsSent(guest.id);
                      }
                    },
                    onDelete: () {
                      store.deleteGuest(guest.id);
                      onShowMessage('${guest.name} dihapus dari daftar.');
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class const _StatsSummaryRow({required final GuestDashboardStore store}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rsvp = store.rsvpSummary;
    final withPhoneCount = store.guests.where((g) => g.hasPhone).length;
    final cards = [
      _StatCard(
        label: 'Total Tamu',
        value: '${store.totalGuests}',
        subtitle: '$withPhoneCount pakai no. WA',
        accent: GothicTheme.white,
        isActiveFilter: store.filterMode == .all,
        onTap: () => store.setFilterMode(.all),
      ),
      _StatCard(
        label: 'Belum Dikirim',
        value: '${store.pendingCount}',
        subtitle: 'Siap dikirim gratis',
        accent: _DashboardPalette.amber,
        isActiveFilter: store.filterMode == .pending,
        onTap: () => store.setFilterMode(store.filterMode == .pending ? .all : .pending),
      ),
      _StatCard(
        label: 'Sudah Terkirim',
        value: '${store.sentCount}',
        subtitle: 'Via WhatsApp',
        accent: _DashboardPalette.whatsappGreen,
        isActiveFilter: store.filterMode == .sent,
        onTap: () => store.setFilterMode(store.filterMode == .sent ? .all : .sent),
      ),
      _StatCard(
        label: 'RSVP Masuk',
        value: rsvp.isLoading ? '...' : '${rsvp.totalCount}',
        subtitle: rsvp.isConnected
            ? 'Hadir ${rsvp.attendingCount} • Ragu ${rsvp.uncertainCount}'
            : (rsvp.errorMessage ?? 'Sinkron Firestore'),
        accent: _DashboardPalette.sky,
        isActiveFilter: store.filterMode == .rsvpSubmitted,
        onTap: () =>
            store.setFilterMode(store.filterMode == .rsvpSubmitted ? .all : .rsvpSubmitted),
        trailingAction: SizedBox(
          width: 24,
          height: 24,
          child: InkWell(
            onTap: () => unawaited(store.refreshFirestoreRsvps(force: true)),
            borderRadius: const .all(.circular(12)),
            child: Center(
              child: Icon(
                Icons.refresh_rounded,
                size: 15,
                color: rsvp.isLoading ? Colors.white24 : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        if (constraints.maxWidth >= 760) {
          return _EqualHeightStatRow(spacing: spacing, children: cards);
        }
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            _EqualHeightStatRow(spacing: spacing, children: [cards[0], cards[1]]),
            const SizedBox(height: spacing),
            _EqualHeightStatRow(spacing: spacing, children: [cards[2], cards[3]]),
          ],
        );
      },
    );
  }
}

class const _EqualHeightStatRow({
  required final List<Widget> children,
  required final double spacing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class const _StatCard({
  required final String label,
  required final String value,
  required final String subtitle,
  required final Color accent,
  required final bool isActiveFilter,
  required final VoidCallback onTap,
  final Widget? trailingAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const .all(.circular(14)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _DashboardPalette.surface,
          borderRadius: const .all(.circular(14)),
          border: Border.fromBorderSide(
            BorderSide(
              color: isActiveFilter ? accent.withValues(alpha: 0.85) : _DashboardPalette.border,
              width: isActiveFilter ? 1.3 : 1.0,
            ),
          ),
        ),
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                mainAxisAlignment: .spaceBetween,
                crossAxisAlignment: .center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: GothicTheme.sans(size: 11, color: Colors.white60, weight: .w600),
                    ),
                  ),
                  // Samakan tinggi baris judul semua kartu agar kartu RSVP tidak lebih tinggi.
                  trailingAction ?? const SizedBox(height: 24),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: .ellipsis,
                style: GothicTheme.sans(size: 22, color: accent, weight: .bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: .ellipsis,
                style: GothicTheme.sans(size: 10.5, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _GuestFilterToolbar({
  required final GuestDashboardStore store,
  required final TextEditingController searchController,
}) extends StatelessWidget {
  static const BoxDecoration _surfaceDecoration = BoxDecoration(
    color: _DashboardPalette.surface,
    borderRadius: .all(.circular(14)),
    border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
  );
  static const OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: .all(.circular(10)),
    borderSide: BorderSide(color: _DashboardPalette.border),
  );
  static const OutlineInputBorder _focusedBorder = OutlineInputBorder(
    borderRadius: .all(.circular(10)),
    borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _surfaceDecoration,
      child: Padding(
        padding: const .all(12),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            TextField(
              controller: searchController,
              onChanged: store.setSearchQuery,
              style: GothicTheme.sans(size: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari nama tamu, nomor WA, atau kategori...',
                hintStyle: GothicTheme.sans(size: 12, color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                suffixIcon: store.searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                          store.setSearchQuery('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                      )
                    : null,
                filled: true,
                fillColor: _DashboardPalette.surfaceInput,
                contentPadding: const .symmetric(horizontal: 12, vertical: 10),
                enabledBorder: _border,
                focusedBorder: _focusedBorder,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: .center,
              children: [
                for (final cat in store.availableCategories)
                  _CategoryFilterPill(
                    label: cat == 'Semua' ? 'Semua Kategori' : cat,
                    selected: store.categoryFilter == cat,
                    onTap: () => store.setCategoryFilter(cat),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class const _GuestListControlBar({
  required final GuestDashboardStore store,
  required final double horizontalPadding,
  required final int filteredCount,
  required final VoidCallback onOpenAddGuest,
  required final VoidCallback onStartQueue,
  required final ValueChanged<String> onShowMessage,
}) extends StatelessWidget {
  static const BoxDecoration _pinnedBorder = BoxDecoration(
    border: Border(bottom: BorderSide(color: _DashboardPalette.border)),
  );
  static final ButtonStyle _quickAddStyle = ElevatedButton.styleFrom(
    backgroundColor: GothicTheme.white,
    foregroundColor: GothicTheme.bgBlack,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
    padding: const .symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    final selectedCount = store.selectedIds.length;
    final filtered = store.filteredGuests;
    final allFilteredSelected =
        filtered.isNotEmpty && filtered.every((g) => store.selectedIds.contains(g.id));

    // Gunakan latar Material solid agar kartu yang discroll di bawah bar pinned tertutup bersih.
    return Material(
      color: _DashboardPalette.bg,
      child: DecoratedBox(
        decoration: _pinnedBorder,
        child: Padding(
          padding: .fromLTRB(horizontalPadding, 6, horizontalPadding, 8),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                crossAxisAlignment: .center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: .centerLeft,
                      child: InkWell(
                        onTap: filteredCount > 0 ? store.toggleSelectAllFiltered : null,
                        borderRadius: const .all(.circular(6)),
                        child: Padding(
                          // Left 14px aligns the checkbox icon vertically with _GuestCard's checkbox.
                          padding: const .fromLTRB(14, 6, 8, 6),
                          child: Row(
                            mainAxisSize: .min,
                            children: [
                              Icon(
                                allFilteredSelected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 19,
                                color: filteredCount == 0
                                    ? Colors.white24
                                    : (allFilteredSelected
                                          ? _DashboardPalette.whatsappGreen
                                          : Colors.white60),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  selectedCount > 0
                                      ? '$selectedCount dipilih'
                                      : 'Pilih semua ($filteredCount)',
                                  overflow: .ellipsis,
                                  style: GothicTheme.sans(
                                    size: 12,
                                    color: filteredCount == 0
                                        ? Colors.white38
                                        : GothicTheme.textGrey,
                                    weight: .w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onOpenAddGuest,
                    style: _quickAddStyle,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: Text(
                      'Tambah Tamu Baru',
                      style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
                    ),
                  ),
                ],
              ),
              if (selectedCount > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const .only(left: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: .center,
                    children: [
                      TextButton(
                        onPressed: store.clearSelection,
                        style: TextButton.styleFrom(
                          padding: const .symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: .shrinkWrap,
                        ),
                        child: Text(
                          'Batal pilih',
                          style: GothicTheme.sans(size: 11.5, color: Colors.white60),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final count = selectedCount;
                          store.deleteSelectedGuests();
                          onShowMessage('$count tamu terpilih dihapus.');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _DashboardPalette.rose,
                          side: const BorderSide(color: _DashboardPalette.rose, width: 0.7),
                          padding: const .symmetric(horizontal: 10, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                        label: Text(
                          'Hapus ($selectedCount)',
                          style: GothicTheme.sans(
                            size: 11,
                            color: _DashboardPalette.rose,
                            weight: .bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: onStartQueue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _DashboardPalette.whatsappGreen,
                          foregroundColor: GothicTheme.bgBlack,
                          elevation: 0,
                          padding: const .symmetric(horizontal: 10, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: Text(
                          'Kirim Terpilih ($selectedCount)',
                          style: GothicTheme.sans(
                            size: 11,
                            color: GothicTheme.bgBlack,
                            weight: .bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class const _FilterPill({
  required final String label,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const .all(.circular(16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? GothicTheme.white : _DashboardPalette.surfaceElevated,
          borderRadius: const .all(.circular(16)),
          border: Border.fromBorderSide(
            BorderSide(color: selected ? GothicTheme.white : _DashboardPalette.border),
          ),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: GothicTheme.sans(
              size: 11,
              color: selected ? GothicTheme.bgBlack : GothicTheme.textGrey,
              weight: selected ? .bold : .w500,
            ),
          ),
        ),
      ),
    );
  }
}

class const _CategoryFilterPill({
  required final String label,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const .all(.circular(16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? _DashboardPalette.whatsappDark : Colors.transparent,
          borderRadius: const .all(.circular(16)),
          border: Border.fromBorderSide(
            BorderSide(color: selected ? _DashboardPalette.whatsappGreen : Colors.white12),
          ),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 9, vertical: 4),
          child: Text(
            label,
            style: GothicTheme.sans(
              size: 10.5,
              color: selected ? _DashboardPalette.whatsappGreen : Colors.white60,
              weight: selected ? .bold : .normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GUEST CARD
// ============================================================================
class const _GuestCard({
  required final GuestInvitation guest,
  required final String invitationLink,
  required final GuestRsvpSnapshot? rsvpSnapshot,
  required final bool isSelected,
  required final VoidCallback onToggleSelect,
  required final VoidCallback onSendWhatsApp,
  required final VoidCallback onCopyLink,
  required final VoidCallback onCopyMessage,
  required final VoidCallback onViewMessage,
  required final VoidCallback onEdit,
  required final VoidCallback onToggleStatus,
  required final VoidCallback onDelete,
}) extends StatelessWidget {
  static final ButtonStyle _waButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: _DashboardPalette.whatsappGreen,
    foregroundColor: GothicTheme.bgBlack,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(9))),
    padding: const .symmetric(horizontal: 12, vertical: 8),
  );
  static final ButtonStyle _subtleButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: GothicTheme.white,
    side: const BorderSide(color: _DashboardPalette.borderStrong),
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(9))),
    padding: const .symmetric(horizontal: 10, vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    final isSent = guest.sendStatus == .sent;
    final phoneDisplay = guest.hasPhone
        ? WhatsAppInvitationHelper.formatPhoneDisplay(guest.phone)
        : 'Tanpa No. WA (Pilih Kontak Manual di WA)';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _DashboardPalette.surface,
        borderRadius: const .all(.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(
            color: isSelected
                ? _DashboardPalette.whatsappGreen.withValues(alpha: 0.7)
                : _DashboardPalette.border,
          ),
        ),
      ),
      child: Padding(
        padding: const .all(14),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                InkWell(
                  onTap: onToggleSelect,
                  borderRadius: const .all(.circular(6)),
                  child: Padding(
                    padding: const .only(top: 2, right: 10, bottom: 2),
                    child: Icon(
                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 19,
                      color: isSelected ? _DashboardPalette.whatsappGreen : Colors.white38,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: .center,
                        children: [
                          Text(guest.name, style: GothicTheme.sans(size: 14, weight: .bold)),
                          _MiniTag(
                            label: guest.category,
                            fg: GothicTheme.textGrey,
                            bg: _DashboardPalette.surfaceElevated,
                            border: _DashboardPalette.border,
                          ),
                          _MiniTag(
                            label: isSent
                                ? (guest.sentCount > 1
                                      ? 'Terkirim (${guest.sentCount}x)'
                                      : 'Terkirim')
                                : 'Belum Dikirim',
                            fg: isSent ? _DashboardPalette.whatsappGreen : _DashboardPalette.amber,
                            bg: isSent
                                ? _DashboardPalette.whatsappDark
                                : _DashboardPalette.amberDark,
                            border: isSent
                                ? _DashboardPalette.whatsappGreen
                                : _DashboardPalette.amber,
                          ),
                          if (guest.hasCustomMessage)
                            const _MiniTag(
                              label: 'Pesan Khusus',
                              fg: _DashboardPalette.sky,
                              bg: _DashboardPalette.skyDark,
                              border: _DashboardPalette.sky,
                            ),
                          if (rsvpSnapshot != null) _RsvpStatusBadge(snapshot: rsvpSnapshot!),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            guest.hasPhone
                                ? Icons.phone_android_rounded
                                : Icons.person_search_rounded,
                            size: 13,
                            color: guest.hasPhone ? Colors.white60 : _DashboardPalette.amber,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              phoneDisplay,
                              style: GothicTheme.sans(
                                size: 11.5,
                                color: guest.hasPhone ? Colors.white70 : _DashboardPalette.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (guest.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(guest.note, style: GothicTheme.sans(size: 11, color: Colors.white54)),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: _DashboardPalette.surfaceElevated,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white60),
                  onSelected: (value) {
                    switch (value) {
                      case 'message':
                        onViewMessage();
                      case 'edit':
                        onEdit();
                      case 'toggle_status':
                        onToggleStatus();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'message',
                      child: Text('Lihat Isi Pesan', style: GothicTheme.sans(size: 12)),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit Data Tamu', style: GothicTheme.sans(size: 12)),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_status',
                      child: Text(
                        isSent ? 'Tandai Belum Dikirim' : 'Tandai Sudah Terkirim',
                        style: GothicTheme.sans(size: 12),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Hapus Tamu',
                        style: GothicTheme.sans(size: 12, color: _DashboardPalette.rose),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: _DashboardPalette.surfaceInput,
                borderRadius: .all(.circular(8)),
                border: Border.fromBorderSide(BorderSide(color: Colors.white10)),
              ),
              child: Padding(
                padding: const .symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SelectableText(
                        invitationLink,
                        maxLines: 1,
                        style: GothicTheme.sans(size: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: onSendWhatsApp,
                  style: _waButtonStyle,
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                    guest.hasPhone ? 'Kirim WhatsApp' : 'Pilih Kontak WA',
                    style: GothicTheme.sans(size: 11.5, color: GothicTheme.bgBlack, weight: .bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyLink,
                  style: _subtleButtonStyle,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text('Salin Link', style: GothicTheme.sans(size: 11.5, weight: .w600)),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyMessage,
                  style: _subtleButtonStyle,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: Text('Salin Pesan', style: GothicTheme.sans(size: 11.5, weight: .w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class const _MiniTag({
  required final String label,
  required final Color fg,
  required final Color bg,
  required final Color border,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const .all(.circular(10)),
        border: Border.fromBorderSide(
          BorderSide(color: border.withValues(alpha: 0.65), width: 0.8),
        ),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: GothicTheme.sans(size: 10, color: fg, weight: .bold),
        ),
      ),
    );
  }
}

class const _RsvpStatusBadge({required final GuestRsvpSnapshot snapshot}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (snapshot.attendanceLabel) {
      'Hadir' => (_DashboardPalette.sky, _DashboardPalette.skyDark),
      'Tidak Hadir' => (_DashboardPalette.rose, _DashboardPalette.roseDark),
      _ => (_DashboardPalette.amber, _DashboardPalette.amberDark),
    };
    return _MiniTag(label: 'RSVP: ${snapshot.attendanceLabel}', fg: fg, bg: bg, border: fg);
  }
}

class const _EmptyGuestsState({
  required final bool hasAnyGuests,
  required final VoidCallback onClearFilter,
  required final VoidCallback onOpenBulkImport,
  required final VoidCallback onLoadSampleGuests,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _DashboardPalette.surface,
            borderRadius: .all(.circular(16)),
            border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
          ),
          child: Padding(
            padding: const .all(24),
            child: Column(
              mainAxisSize: .min,
              children: [
                const Icon(
                  Icons.mark_chat_unread_outlined,
                  size: 38,
                  color: _DashboardPalette.whatsappGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  hasAnyGuests
                      ? 'Tidak ada tamu yang cocok dengan filter.'
                      : 'Belum ada daftar tamu undangan.',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 14, weight: .bold),
                ),
                const SizedBox(height: 6),
                Text(
                  hasAnyGuests
                      ? 'Coba ubah kata kunci pencarian atau reset filter kategori.'
                      : 'Tambahkan tamu lewat tombol Tambah Tamu Baru di atas atau impor file '
                            'CSV / JSON, lalu kirim undangan langsung lewat WhatsApp.',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 12, color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: .center,
                  children: [
                    if (hasAnyGuests)
                      ElevatedButton(
                        onPressed: onClearFilter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GothicTheme.white,
                          foregroundColor: GothicTheme.bgBlack,
                        ),
                        child: Text(
                          'Reset Filter',
                          style: GothicTheme.sans(
                            size: 12,
                            color: GothicTheme.bgBlack,
                            weight: .bold,
                          ),
                        ),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: onOpenBulkImport,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GothicTheme.white,
                          side: const BorderSide(color: _DashboardPalette.borderStrong),
                        ),
                        icon: const Icon(Icons.playlist_add_rounded, size: 16),
                        label: Text('Impor CSV / JSON', style: GothicTheme.sans(size: 12)),
                      ),
                      TextButton(
                        onPressed: onLoadSampleGuests,
                        child: Text(
                          'Muat 3 Contoh Tamu',
                          style: GothicTheme.sans(
                            size: 12,
                            color: _DashboardPalette.whatsappGreen,
                            weight: .bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LEFT PANE: TEMPLATE PESAN & PREVIEW BUBBLE
// ============================================================================
typedef _GuestSaveCallback = void Function({
  required String name,
  required String phone,
  required String category,
});

class const _TemplateEditorCard({required final GuestDashboardStore store}) extends StatefulWidget {
  @override
  State<_TemplateEditorCard> createState() => _TemplateEditorCardState();
}

class _TemplateEditorCardState() extends State<_TemplateEditorCard> {
  static const BoxDecoration _decoration = BoxDecoration(
    color: _DashboardPalette.surface,
    borderRadius: .all(.circular(14)),
    border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
  );

  late final TextEditingController _templateController;

  @override
  void initState() {
    super.initState();
    _templateController = TextEditingController(text: widget.store.templateText);
  }

  @override
  void didUpdateWidget(covariant _TemplateEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_templateController.text != widget.store.templateText) {
      _templateController.text = widget.store.templateText;
    }
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sampleGuest = widget.store.guests.isNotEmpty
        ? widget.store.guests.first
        : GuestInvitation(
            id: 'preview',
            name: 'Budi Santoso',
            phone: '6281234567890',
            category: 'Teman',
            note: '',
            sendStatus: .pending,
            sentCount: 0,
            createdAt: DateTime(2026, 11, 15),
          );
    final previewText = widget.store.renderActiveTemplateForGuest(sampleGuest);
    final templatePresets = widget.store.availableTemplatePresets;
    final trimmedTemplate = widget.store.templateText.trim();

    return DecoratedBox(
      decoration: _decoration,
      child: Padding(
        padding: const .all(14),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 19, color: GothicTheme.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Template Pesan WhatsApp',
                    style: GothicTheme.sans(size: 13.5, weight: .bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in templatePresets)
                  _FilterPill(
                    label: preset.name,
                    selected:
                        widget.store.activePresetId == preset.id ||
                        trimmedTemplate == preset.body.trim(),
                    onTap: () {
                      widget.store.selectPreset(preset);
                      _templateController.text = preset.body;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _templateController,
              maxLines: 8,
              minLines: 4,
              onChanged: widget.store.updateTemplate,
              style: GothicTheme.sans(size: 12, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: _DashboardPalette.surfaceInput,
                hintText: 'Tulis template pesan undangan...',
                hintStyle: GothicTheme.sans(size: 12, color: Colors.white38),
                contentPadding: const .only(left: 12, top: 12, bottom: 12),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: .all(.circular(10)),
                  borderSide: BorderSide(color: _DashboardPalette.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: .all(.circular(10)),
                  borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pratinjau Bubble Chat (${sampleGuest.name})',
              style: GothicTheme.sans(size: 11, color: Colors.white60, weight: .w600),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: _DashboardPalette.whatsappBubble,
                borderRadius: .all(.circular(12)),
                border: Border.fromBorderSide(
                  BorderSide(color: _DashboardPalette.whatsappGreen, width: 0.6),
                ),
              ),
              child: Padding(
                padding: const .all(12),
                child: SelectableText(
                  previewText,
                  style: GothicTheme.sans(size: 11.5, color: GothicTheme.white, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _DashboardTextField({
  required final TextEditingController controller,
  required final String label,
  required final String hint,
  final TextInputType keyboardType = .text,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GothicTheme.sans(size: 12.5),
      decoration: InputDecoration(
        // isDense: true,
        labelText: label,
        hintText: hint,
        labelStyle: GothicTheme.sans(size: 11.5, color: GothicTheme.textGrey),
        hintStyle: GothicTheme.sans(size: 11.5, color: Colors.white38),
        filled: true,
        fillColor: _DashboardPalette.surfaceInput,
        contentPadding: const .symmetric(horizontal: 12, vertical: 10),
        enabledBorder: const OutlineInputBorder(
          borderRadius: .all(.circular(10)),
          borderSide: BorderSide(color: _DashboardPalette.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: .all(.circular(10)),
          borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOGS / BOTTOMSHEETS: TAMBAH/EDIT TAMU, ISI PESAN, IMPOR/EKSPOR, ANTREAN WA
// ============================================================================
class const _AdaptivePopupScaffold({
  required final Widget title,
  required final Widget content,
  required final List<Widget> actions,
  final double desktopWidth = 420,
  final double? fixedContentHeight,
  final bool scrollableContent = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = _InvitationDashboardScreenState._isMobileViewport(context);
    if (!isMobile) {
      return AlertDialog(
        backgroundColor: _DashboardPalette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(16)),
          side: BorderSide(color: _DashboardPalette.borderStrong),
        ),
        title: title,
        content: SizedBox(
          width: desktopWidth,
          height: fixedContentHeight,
          child: scrollableContent ? SingleChildScrollView(child: content) : content,
        ),
        actions: actions,
      );
    }

    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;

    return Padding(
      padding: .only(bottom: viewInsetsBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _DashboardPalette.surface,
            borderRadius: .vertical(top: .circular(20)),
            border: Border(top: BorderSide(color: _DashboardPalette.borderStrong)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const .fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: .all(.circular(2)),
                      ),
                      child: SizedBox(width: 36, height: 4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  title,
                  const SizedBox(height: 14),
                  if (scrollableContent)
                    Flexible(child: SingleChildScrollView(child: content))
                  else
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: fixedContentHeight ?? 360),
                        child: content,
                      ),
                    ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: .end,
                      crossAxisAlignment: .center,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _GuestMessageDialog({
  required final GuestInvitation guest,
  required final GuestDashboardStore store,
  required final ValueChanged<String> onShowMessage,
  required final ValueChanged<String> onCopyMessage,
  required final ValueChanged<String> onSendMessage,
}) extends StatefulWidget {
  @override
  State<_GuestMessageDialog> createState() => _GuestMessageDialogState();
}

class _GuestMessageDialogState() extends State<_GuestMessageDialog> {
  late final TextEditingController _messageController;
  late final ValueNotifier<bool> _isCustomSaved;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.store.buildMessageForGuest(widget.guest),
    );
    _isCustomSaved = ValueNotifier<bool>(widget.guest.hasCustomMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _isCustomSaved.dispose();
    super.dispose();
  }

  void _resetToTemplate() {
    widget.store.clearGuestCustomMessage(widget.guest.id);
    _messageController.text = widget.store.renderActiveTemplateForGuest(widget.guest);
    _isCustomSaved.value = false;
    widget.onShowMessage('Pesan ${widget.guest.name} dikembalikan ke template aktif.');
  }

  void _saveMessage() {
    final trimmed = _messageController.text.trim();
    if (trimmed.isEmpty) {
      widget.onShowMessage('Isi pesan tidak boleh kosong.');
      return;
    }
    widget.store.updateGuestMessage(widget.guest.id, trimmed);
    Navigator.of(context).pop();
    widget.onShowMessage('Isi pesan untuk ${widget.guest.name} disimpan.');
  }

  void _sendMessage() {
    final trimmed = _messageController.text.trim();
    if (trimmed.isEmpty) {
      widget.onShowMessage('Isi pesan tidak boleh kosong.');
      return;
    }
    widget.onSendMessage(_messageController.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    final link = widget.store.buildLinkForGuest(guest);

    return _AdaptivePopupScaffold(
      desktopWidth: 500,
      title: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: _DashboardPalette.whatsappGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Isi Pesan Undangan', style: GothicTheme.sans(size: 15, weight: .bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _DashboardPalette.surfaceElevated,
              borderRadius: .all(.circular(12)),
              border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
            ),
            child: Padding(
              padding: const .all(12),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: .center,
                    children: [
                      Text(guest.name, style: GothicTheme.sans(size: 14, weight: .bold)),
                      _MiniTag(
                        label: guest.category,
                        fg: GothicTheme.textGrey,
                        bg: _DashboardPalette.surfaceInput,
                        border: _DashboardPalette.border,
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isCustomSaved,
                        builder: (context, isCustom, _) {
                          if (!isCustom) return const SizedBox.shrink();
                          return const _MiniTag(
                            label: 'Pesan Khusus',
                            fg: _DashboardPalette.sky,
                            bg: _DashboardPalette.skyDark,
                            border: _DashboardPalette.sky,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guest.hasPhone
                        ? WhatsAppInvitationHelper.formatPhoneDisplay(guest.phone)
                        : 'Tanpa No. WA (Pilih Kontak Manual di WA)',
                    style: GothicTheme.sans(
                      size: 11.5,
                      color: guest.hasPhone ? Colors.white70 : _DashboardPalette.amber,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(link, style: GothicTheme.sans(size: 11, color: Colors.white54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Isi Pesan WhatsApp (bisa dilihat atau diedit khusus untuk tamu ini):',
            style: GothicTheme.sans(size: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 10,
            minLines: 6,
            style: GothicTheme.sans(size: 12, height: 1.4),
            decoration: const InputDecoration(
              filled: true,
              fillColor: _DashboardPalette.surfaceInput,
              contentPadding: .all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: .all(.circular(10)),
                borderSide: BorderSide(color: _DashboardPalette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: .all(.circular(10)),
                borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesan yang berbeda dari 3 template bawaan akan otomatis muncul di pilihan Template Pesan.',
            style: GothicTheme.sans(size: 10.5, color: Colors.white54),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: .end,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isCustomSaved,
                builder: (context, isCustom, _) {
                  if (!isCustom) return const SizedBox.shrink();
                  return Row(
                    children: [
                      TextButton(
                        onPressed: _resetToTemplate,
                        child: Text(
                          'Reset Template',
                          style: GothicTheme.sans(
                            size: 12,
                            color: _DashboardPalette.amber,
                            weight: .w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                },
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onCopyMessage(_messageController.text),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GothicTheme.white,
                  side: const BorderSide(color: _DashboardPalette.borderStrong),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text('Salin', style: GothicTheme.sans(size: 12, weight: .w600)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _saveMessage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: GothicTheme.white,
                  side: const BorderSide(color: _DashboardPalette.borderStrong),
                ),
                child: Text('Simpan Pesan', style: GothicTheme.sans(size: 12, weight: .bold)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const .only(bottom: 20),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup', style: GothicTheme.sans(size: 12, color: Colors.white60)),
          ),
        ),
        Padding(
          padding: const .only(bottom: 20),
          child: ElevatedButton.icon(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: _DashboardPalette.whatsappGreen,
              foregroundColor: GothicTheme.bgBlack,
            ),
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text(
              'Kirim WA',
              style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
            ),
          ),
        ),
      ],
    );
  }
}

class const _GuestFormDialog({
  required final String title,
  required final String submitLabel,
  required final _GuestSaveCallback onSave,
  final ContactPickerCallback? onPickContact,
  final ContactPickerCallback? onPickContactFile,
  final String initialName = '',
  final String initialPhone = '',
  final String initialCategory = 'Teman',
}) extends StatefulWidget {
  @override
  State<_GuestFormDialog> createState() => _GuestFormDialogState();
}

class _GuestFormDialogState() extends State<_GuestFormDialog> {
  static final ButtonStyle _contactPickButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: _DashboardPalette.whatsappGreen,
    side: const BorderSide(color: _DashboardPalette.whatsappGreen, width: 0.8),
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
    padding: const .symmetric(horizontal: 12, vertical: 10),
  );

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final ValueNotifier<String> _category;
  final ValueNotifier<String?> _errorText = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _isPickingContact = ValueNotifier<bool>(false);
  String? _lastPickedContactName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _category = ValueNotifier<String>(widget.initialCategory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _category.dispose();
    _errorText.dispose();
    _isPickingContact.dispose();
    super.dispose();
  }

  Future<void> _handlePickContact() {
    final pickFn = widget.onPickContact ?? WhatsAppInvitationHelper.pickDeviceContact;
    return _runContactPicker(pickFn, allowFallbackDialog: true);
  }

  Future<void> _handlePickContactFromVcf() {
    final pickFileFn = widget.onPickContactFile ?? _pickContactsFromVcfFile;
    return _runContactPicker(pickFileFn, allowFallbackDialog: false);
  }

  Future<void> _runContactPicker(
    Future<ContactPickResult> Function() picker, {
    required bool allowFallbackDialog,
  }) async {
    if (_isPickingContact.value) return;
    _errorText.value = null;
    _isPickingContact.value = true;
    ContactPickResult result;
    try {
      result = await picker();
    } finally {
      if (mounted) _isPickingContact.value = false;
    }
    if (!mounted) return;
    await _applyContactPickResult(result, allowFallbackDialog: allowFallbackDialog);
  }

  static Future<ContactPickResult> _pickContactsFromVcfFile() async {
    final picked = await WebInterop.pickTextFile(accept: '.vcf,text/vcard');
    if (picked == null) return const ContactPickResult(status: .cancelled);
    final contacts = WhatsAppInvitationHelper.parseVCardContacts(picked.content);
    if (contacts.isEmpty) return const ContactPickResult(status: .failed);
    return ContactPickResult(status: .picked, contacts: contacts);
  }

  Future<void> _applyContactPickResult(
    ContactPickResult result, {
    required bool allowFallbackDialog,
  }) async {
    switch (result.status) {
      case .cancelled:
        return;
      case .unsupported:
        if (!allowFallbackDialog) {
          _errorText.value = 'Pemilih kontak tidak didukung di browser ini. Anda bisa input manual atau kosongkan untuk pilih dari WhatsApp nanti.';
          return;
        }
        final wantsVcf = await _InvitationDashboardScreenState._showAdaptivePopup<bool>(
          context: context,
          builder: (ctx) => const _ContactPickerFallbackDialog(),
        );
        if (!mounted || wantsVcf != true) return;
        await _handlePickContactFromVcf();
      case .failed:
        if (!allowFallbackDialog) {
          _errorText.value =
              'File kontak (.vcf) tidak berisi data kontak atau nomor telepon yang valid.';
          return;
        }
        final wantsVcf = await _InvitationDashboardScreenState._showAdaptivePopup<bool>(
          context: context,
          builder: (ctx) => const _ContactPickerFallbackDialog(failedToOpen: true),
        );
        if (!mounted) return;
        if (wantsVcf == true) {
          await _handlePickContactFromVcf();
          return;
        }
        _errorText.value = 'Gagal membuka kontak perangkat di browser ini. Coba browser Chrome Android, impor file .vcf, atau ketik manual.';
      case .picked:
        if (result.contacts.isEmpty) return;
        if (result.contacts.length == 1) {
          await _applySingleContact(result.contacts.first);
          return;
        }
        final chosen = await _InvitationDashboardScreenState._showAdaptivePopup<ContactCandidate>(
          context: context,
          builder: (ctx) => _SelectContactDialog(contacts: result.contacts),
        );
        if (!mounted || chosen == null) return;
        await _applySingleContact(chosen);
    }
  }

  void _applyPickedContactName(String rawContactName) {
    final pickedName = rawContactName.trim();
    if (pickedName.isEmpty) return;
    final currentName = _nameController.text.trim();
    final isReplacedFromPreviousPick =
        _lastPickedContactName != null && currentName == _lastPickedContactName;
    if (currentName.isEmpty || isReplacedFromPreviousPick) {
      _nameController.text = pickedName;
      _lastPickedContactName = pickedName;
    }
  }

  Future<void> _applySingleContact(ContactCandidate contact) async {
    if (contact.phones.isEmpty) {
      _applyPickedContactName(contact.name);
      _errorText.value = contact.name.isNotEmpty
          ? 'Kontak "${contact.name}" tidak memiliki nomor telepon yang valid. Kosongkan saja agar bisa pilih di WhatsApp nanti.'
          : 'Kontak yang dipilih tidak memiliki nomor telepon yang valid.';
      return;
    }
    if (contact.phones.length == 1) {
      _applyPickedContactName(contact.name);
      _fillContactPhone(contact.phones.first);
      return;
    }
    final selectedPhone = await _InvitationDashboardScreenState._showAdaptivePopup<String>(
      context: context,
      builder: (ctx) => _SelectContactPhoneDialog(contact: contact),
    );
    if (!mounted || selectedPhone == null || selectedPhone.isEmpty) return;
    _applyPickedContactName(contact.name);
    _fillContactPhone(selectedPhone);
  }

  void _fillContactPhone(String normalizedPhone) {
    _phoneController.text = WhatsAppInvitationHelper.formatPhoneDisplay(normalizedPhone);
    _errorText.value = null;
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      _errorText.value = 'Nama tamu wajib diisi.';
      return;
    }
    if (!WhatsAppInvitationHelper.isValidOptionalPhone(phone)) {
      _errorText.value = 'Format nomor WhatsApp tidak valid. Contoh: 08123456789';
      return;
    }
    widget.onSave(name: name, phone: phone, category: _category.value);
  }

  @override
  Widget build(BuildContext context) {
    return _AdaptivePopupScaffold(
      desktopWidth: 420,
      title: Text(widget.title, style: GothicTheme.sans(size: 15, weight: .bold)),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          _DashboardTextField(
            controller: _nameController,
            label: 'Nama Tamu *',
            hint: 'Misal: Budi Santoso',
          ),
          const SizedBox(height: 10),
          _DashboardTextField(
            controller: _phoneController,
            label: 'Nomor WhatsApp (Opsional)',
            hint: '08123456789',
            keyboardType: .phone,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _isPickingContact,
            builder: (context, isPicking, _) => Align(
              alignment: .centerLeft,
              child: OutlinedButton.icon(
                onPressed: isPicking ? null : _handlePickContact,
                style: _contactPickButtonStyle,
                icon: const Icon(Icons.contacts_rounded, size: 16),
                label: Text(
                  isPicking ? 'Membuka Kontak...' : 'Pilih dari Kontak',
                  style: GothicTheme.sans(
                    size: 12,
                    color: _DashboardPalette.whatsappGreen,
                    weight: .bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _OptionalPhoneInfoBox(),
          const SizedBox(height: 10),
          Text('Kategori', style: GothicTheme.sans(size: 11, color: Colors.white60)),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: _category,
            builder: (context, selected, _) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in WhatsAppInvitationHelper.defaultCategories)
                  _FilterPill(
                    label: cat,
                    selected: selected == cat,
                    onTap: () => _category.value = cat,
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _errorText,
            builder: (context, err, _) {
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const .only(top: 8),
                child: Text(
                  err,
                  style: GothicTheme.sans(size: 11.5, color: _DashboardPalette.rose),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],
      ),
      actions: [
        Padding(
          padding: const .only(bottom: 20),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: GothicTheme.sans(size: 12, color: Colors.white60)),
          ),
        ),
        Padding(
          padding: const .only(bottom: 20),
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: GothicTheme.white,
              foregroundColor: GothicTheme.bgBlack,
            ),
            child: Text(
              widget.submitLabel,
              style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
            ),
          ),
        ),
      ],
    );
  }
}

class const _OptionalPhoneInfoBox() extends StatelessWidget {
  static const BoxDecoration _decoration = BoxDecoration(
    color: _DashboardPalette.skyDark,
    borderRadius: .all(.circular(10)),
    border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.sky, width: 0.5)),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration,
      child: Padding(
        padding: const .symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            const Padding(
              padding: .only(top: 1),
              child: Icon(Icons.info_outline_rounded, size: 15, color: _DashboardPalette.sky),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nomor WA tidak wajib diisi. Jika dikosongkan, nanti Anda bisa langsung memilih kontak dari WhatsApp saat mengirim.',
                style: GothicTheme.sans(size: 11, color: Colors.white70, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _ContactPickerFallbackDialog({final bool failedToOpen = false})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _AdaptivePopupScaffold(
      desktopWidth: 400,
      title: Text('Pilih Kontak', style: GothicTheme.sans(size: 15, weight: .bold)),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            failedToOpen
                ? 'Browser ini belum berhasil membuka pemilih kontak perangkat secara langsung '
                      '(umumnya terjadi di Opera, browser desktop/iOS, atau saat izin kontak ditolak). '
                      'Untuk akses kontak langsung, gunakan Chrome atau Samsung Internet di HP Android.'
                : 'Akses daftar kontak langsung hanya didukung di browser HP Android '
                      '(Chrome atau Samsung Internet).',
            style: GothicTheme.sans(size: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            'Sebagai alternatif, Anda bisa memilih file kontak (.vcf / vCard) dari perangkat '
            'atau mengosongkan kolom nomor WA — karena nomor tidak wajib diisi dan kontak bisa '
            'dipilih langsung dari WhatsApp saat mengirim nanti.',
            style: GothicTheme.sans(size: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Tutup', style: GothicTheme.sans(size: 12, color: Colors.white60)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _DashboardPalette.whatsappGreen,
            foregroundColor: GothicTheme.bgBlack,
          ),
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text(
            'Pilih File Kontak (.vcf)',
            style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
          ),
        ),
      ],
    );
  }
}

class const _SelectContactPhoneDialog({required final ContactCandidate contact})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = contact.name.isNotEmpty
        ? 'Pilih Nomor untuk ${contact.name}'
        : 'Pilih Nomor WhatsApp';
    return _AdaptivePopupScaffold(
      desktopWidth: 380,
      title: Text(title, style: GothicTheme.sans(size: 15, weight: .bold)),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          for (var i = 0; i < contact.phones.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(contact.phones[i]),
              style: OutlinedButton.styleFrom(
                foregroundColor: GothicTheme.white,
                side: const BorderSide(color: _DashboardPalette.borderStrong),
                alignment: .centerLeft,
                padding: const .symmetric(horizontal: 12, vertical: 12),
              ),
              icon: const Icon(
                Icons.phone_android_rounded,
                size: 16,
                color: _DashboardPalette.whatsappGreen,
              ),
              label: Text(
                WhatsAppInvitationHelper.formatPhoneDisplay(contact.phones[i]),
                style: GothicTheme.sans(size: 12.5, weight: .w600),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal', style: GothicTheme.sans(size: 12, color: Colors.white60)),
        ),
      ],
    );
  }
}

class const _SelectContactDialog({required final List<ContactCandidate> contacts})
    extends StatefulWidget {
  @override
  State<_SelectContactDialog> createState() => _SelectContactDialogState();
}

class _SelectContactDialogState() extends State<_SelectContactDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AdaptivePopupScaffold(
      desktopWidth: 400,
      fixedContentHeight: 360,
      scrollableContent: false,
      title: Text(
        'Pilih Kontak (${widget.contacts.length})',
        style: GothicTheme.sans(size: 15, weight: .bold),
      ),
      content: Column(
        crossAxisAlignment: .stretch,
        children: [
          _DashboardTextField(
            controller: _searchController,
            label: 'Cari Kontak',
            hint: 'Ketik nama atau nomor...',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListenableBuilder(
              listenable: _searchController,
              builder: (context, _) {
                final q = _searchController.text.trim().toLowerCase();
                final filtered = [
                  for (final c in widget.contacts)
                    if (q.isEmpty ||
                        c.name.toLowerCase().contains(q) ||
                        c.phones.any((p) => p.contains(q)))
                      c,
                ];
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada kontak yang cocok.',
                      style: GothicTheme.sans(size: 12, color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemExtent: 64,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final subtitle = contact.phones.isNotEmpty
                        ? contact.phones.map(WhatsAppInvitationHelper.formatPhoneDisplay).join(', ')
                        : 'Tanpa nomor telepon';
                    return Padding(
                      padding: const .only(bottom: 6),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(contact),
                        borderRadius: const .all(.circular(10)),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: _DashboardPalette.surfaceElevated,
                            borderRadius: .all(.circular(10)),
                            border: Border.fromBorderSide(
                              BorderSide(color: _DashboardPalette.border),
                            ),
                          ),
                          child: Padding(
                            padding: const .symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              mainAxisAlignment: .center,
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  contact.name.isNotEmpty ? contact.name : 'Tanpa Nama',
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: GothicTheme.sans(size: 12.5, weight: .bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: GothicTheme.sans(
                                    size: 11.5,
                                    color: contact.phones.isNotEmpty
                                        ? Colors.white70
                                        : _DashboardPalette.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal', style: GothicTheme.sans(size: 12, color: Colors.white60)),
        ),
      ],
    );
  }
}

class const _BulkImportDialog({
  required final void Function(List<ParsedGuestDraft> drafts, {required bool skipDuplicates})
  onImportDrafts,
  required final ValueChanged<String> onImportJsonBackup,
}) extends StatefulWidget {
  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState() extends State<_BulkImportDialog> {
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<String> _defaultCategory = ValueNotifier<String>('Teman');
  final ValueNotifier<bool> _skipDuplicates = ValueNotifier<bool>(true);
  final ValueNotifier<List<ParsedGuestDraft>> _previewDrafts =
      ValueNotifier<List<ParsedGuestDraft>>(const []);
  final ValueNotifier<bool> _looksLikeJson = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorText = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _textController.dispose();
    _defaultCategory.dispose();
    _skipDuplicates.dispose();
    _previewDrafts.dispose();
    _looksLikeJson.dispose();
    _errorText.dispose();
    super.dispose();
  }

  void _reparse() {
    final text = _textController.text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _looksLikeJson.value = false;
      _errorText.value = null;
      _previewDrafts.value = const [];
      return;
    }

    final isJson = trimmed.startsWith('{') || trimmed.startsWith('[');
    _looksLikeJson.value = isJson;
    if (isJson) {
      final backup = WhatsAppInvitationHelper.parseBackupJson(trimmed);
      if (backup == null) {
        _errorText.value = 'Format JSON tidak valid. Gunakan file JSON ekspor atau format CSV.';
        _previewDrafts.value = const [];
      } else {
        _errorText.value = null;
        _previewDrafts.value = [
          for (final g in backup.guests)
            ParsedGuestDraft(
              name: g.name,
              phone: g.phone,
              category: g.category,
              note: g.note,
              isPhoneValid: true,
            ),
        ];
      }
      return;
    }

    if ((trimmed.contains('\t') || trimmed.contains('|')) &&
        !trimmed.contains(',') &&
        !trimmed.contains(';')) {
      _errorText.value =
          'Format tidak didukung. Impor hanya mendukung format CSV (, / ;) dan JSON.';
      _previewDrafts.value = const [];
      return;
    }

    _errorText.value = null;
    _previewDrafts.value = WhatsAppInvitationHelper.parseBulkGuestText(
      text,
      defaultCategory: _defaultCategory.value,
    );
  }

  Future<void> _pickFile() async {
    final picked = await WebInterop.pickTextFile(accept: '.csv,.json');
    if (!mounted || picked == null) return;
    if (picked.name.isNotEmpty &&
        !WhatsAppInvitationHelper.isSupportedImportFilename(picked.name)) {
      _errorText.value = 'Format file "${picked.name}" tidak didukung. Pilih file .csv atau .json.';
      _previewDrafts.value = const [];
      return;
    }
    if (picked.content.isEmpty) return;
    _textController.text = picked.content;
    _reparse();
  }

  @override
  Widget build(BuildContext context) {
    return _AdaptivePopupScaffold(
      desktopWidth: 520,
      title: Text(
        'Impor Daftar Tamu (CSV / JSON)',
        style: GothicTheme.sans(size: 15, weight: .bold),
      ),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            'Tempel data berformat CSV atau JSON, atau pilih file .csv / .json.\n'
            'Format CSV per baris: Nama Tamu, Nomor WA (opsional), Kategori — '
            'jika nomor kosong, nanti bisa pilih kontak dari WhatsApp.',
            style: GothicTheme.sans(size: 11.5, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          if (kIsWeb) ...[
            Align(
              alignment: .centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: GothicTheme.white,
                  side: const BorderSide(color: _DashboardPalette.borderStrong),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  'Pilih File (.csv / .json)',
                  style: GothicTheme.sans(size: 12, weight: .w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _textController,
            maxLines: 8,
            minLines: 5,
            onChanged: (_) => _reparse(),
            style: GothicTheme.sans(size: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: _DashboardPalette.surfaceInput,
              hintText:
                  'Contoh CSV:\n'
                  'Budi Santoso, 081234567890, Teman\n'
                  'Keluarga Bapak Ahmad, 085698765432, Keluarga\n'
                  'Rina & Partner',
              hintStyle: GothicTheme.sans(size: 11.5, color: Colors.white38),
              contentPadding: const .all(12),
              enabledBorder: const OutlineInputBorder(
                borderRadius: .all(.circular(10)),
                borderSide: BorderSide(color: _DashboardPalette.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: .all(.circular(10)),
                borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kategori Default (jika kolom kategori CSV kosong)',
            style: GothicTheme.sans(size: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: _defaultCategory,
            builder: (context, selected, _) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in WhatsAppInvitationHelper.defaultCategories)
                  _FilterPill(
                    label: cat,
                    selected: selected == cat,
                    onTap: () {
                      _defaultCategory.value = cat;
                      _reparse();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _skipDuplicates,
            builder: (context, skip, _) => InkWell(
              onTap: () => _skipDuplicates.value = !skip,
              child: Padding(
                padding: const .symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      skip ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: skip ? _DashboardPalette.whatsappGreen : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lewati tamu dengan nama yang sudah ada di daftar',
                        style: GothicTheme.sans(size: 11.5, color: GothicTheme.textGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _errorText,
            builder: (context, err, _) {
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const .only(top: 6),
                child: Text(
                  err,
                  style: GothicTheme.sans(size: 11.5, color: _DashboardPalette.rose),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<ParsedGuestDraft>>(
            valueListenable: _previewDrafts,
            builder: (context, drafts, _) {
              if (drafts.isEmpty) return const SizedBox.shrink();
              final withPhone = drafts.where((d) => d.phone.isNotEmpty).length;
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: _DashboardPalette.whatsappDark,
                  borderRadius: .all(.circular(10)),
                  border: Border.fromBorderSide(
                    BorderSide(color: _DashboardPalette.whatsappGreen, width: 0.7),
                  ),
                ),
                child: Padding(
                  padding: const .all(10),
                  child: Text(
                    'Siap diimpor: ${drafts.length} tamu ($withPhone dengan nomor WA, '
                    '${drafts.length - withPhone} tanpa nomor).',
                    style: GothicTheme.sans(
                      size: 11.5,
                      color: _DashboardPalette.whatsappGreen,
                      weight: .bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const .only(bottom: 20),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: GothicTheme.sans(size: 12, color: Colors.white60)),
          ),
        ),
        Padding(
          padding: const .only(bottom: 20),
          child: ValueListenableBuilder<List<ParsedGuestDraft>>(
            valueListenable: _previewDrafts,
            builder: (context, drafts, _) => ElevatedButton(
              onPressed: drafts.isEmpty
                  ? null
                  : () {
                      if (_looksLikeJson.value) {
                        widget.onImportJsonBackup(_textController.text);
                      } else {
                        widget.onImportDrafts(drafts, skipDuplicates: _skipDuplicates.value);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardPalette.whatsappGreen,
                foregroundColor: GothicTheme.bgBlack,
                disabledBackgroundColor: Colors.white12,
              ),
              child: Text(
                'Impor ${drafts.length} Tamu',
                style: GothicTheme.sans(
                  size: 12,
                  color: drafts.isEmpty ? Colors.white38 : GothicTheme.bgBlack,
                  weight: .bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class const _BackupExportDialog({
  required final GuestDashboardStore store,
  required final ValueChanged<String> onShowMessage,
}) extends StatelessWidget {
  Future<void> _copy(BuildContext context, String data, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: data));
    onShowMessage(successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final csvData = WhatsAppInvitationHelper.exportGuestsToCsv(
      guests: store.guests,
      baseUrl: store.baseUrl,
      rsvpByRecipient: store.rsvpSummary.byNormalizedRecipient,
    );
    final jsonData = WhatsAppInvitationHelper.exportBackupJson(
      guests: store.guests,
      baseUrl: store.baseUrl,
      template: store.templateText,
      activePresetId: store.activePresetId,
    );

    return _AdaptivePopupScaffold(
      desktopWidth: 440,
      title: Text('Ekspor & Backup Data Tamu', style: GothicTheme.sans(size: 15, weight: .bold)),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            'Data tamu disimpan aman secara lokal di browser Anda. '
            'Unduh dalam format CSV atau JSON untuk cadangan data.',
            style: GothicTheme.sans(size: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              if (kIsWeb &&
                  WebInterop.downloadTextFile(
                    filename: 'daftar_tamu_ojay_mae.csv',
                    content: csvData,
                    mimeType: 'text/csv;charset=utf-8',
                  )) {
                onShowMessage('File CSV daftar tamu diunduh.');
              } else {
                unawaited(_copy(context, csvData, 'Data CSV disalin ke clipboard!'));
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: GothicTheme.white,
              side: const BorderSide(color: _DashboardPalette.borderStrong),
              padding: const .symmetric(vertical: 12, horizontal: 14),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 17),
            label: Text(
              kIsWeb ? 'Unduh CSV (.csv)' : 'Salin Data CSV',
              style: GothicTheme.sans(size: 12, weight: .bold),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              if (kIsWeb &&
                  WebInterop.downloadTextFile(
                    filename: 'backup_undangan_ojay_mae.json',
                    content: jsonData,
                    mimeType: 'application/json;charset=utf-8',
                  )) {
                onShowMessage('File JSON backup diunduh.');
              } else {
                unawaited(_copy(context, jsonData, 'Backup JSON disalin ke clipboard!'));
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: GothicTheme.white,
              side: const BorderSide(color: _DashboardPalette.borderStrong),
              padding: const .symmetric(vertical: 12, horizontal: 14),
            ),
            icon: const Icon(Icons.data_object_rounded, size: 17),
            label: Text(
              kIsWeb ? 'Unduh Backup Lengkap (.json)' : 'Salin Backup JSON',
              style: GothicTheme.sans(size: 12, weight: .bold),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const .only(bottom: 20),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup', style: GothicTheme.sans(size: 12, color: Colors.white60)),
          ),
        ),
      ],
    );
  }
}

/// Dialog "Antrean Kirim Cepat" untuk mengirim ke banyak tamu secara berurutan,
/// 100% gratis lewat link `wa.me` resmi tanpa bot atau API berbayar.
class const _GuidedQueueDialog({
  required final List<GuestInvitation> initialQueue,
  required final GuestDashboardStore store,
  required final void Function(GuestInvitation guest, String customMessage) onSendViaWhatsApp,
  required final void Function(GuestInvitation guest, String customMessage) onMarkSentOnly,
}) extends StatefulWidget {
  @override
  State<_GuidedQueueDialog> createState() => _GuidedQueueDialogState();
}

class _GuidedQueueDialogState() extends State<_GuidedQueueDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);
  int _processedInSession = 0;

  @override
  void initState() {
    super.initState();
    _syncMessageForIndex(0);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  void _syncMessageForIndex(int idx) {
    if (idx < 0 || idx >= widget.initialQueue.length) return;
    final guest = widget.initialQueue[idx];
    _messageController.text = widget.store.buildMessageForGuest(guest);
  }

  void _goToIndex(int nextIndex) {
    final clamped = math.max(0, math.min(nextIndex, widget.initialQueue.length));
    _currentIndex.value = clamped;
    _syncMessageForIndex(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.initialQueue.length;

    return _AdaptivePopupScaffold(
      desktopWidth: 500,
      title: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: _DashboardPalette.whatsappGreen, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Antrean Kirim Cepat (Gratis)',
              style: GothicTheme.sans(size: 15, weight: .bold),
            ),
          ),
        ],
      ),
      content: ValueListenableBuilder<int>(
        valueListenable: _currentIndex,
        builder: (context, idx, _) {
          if (idx >= total) {
            return Column(
              mainAxisSize: .min,
              children: [
                const SizedBox(height: 10),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 52,
                  color: _DashboardPalette.whatsappGreen,
                ),
                const SizedBox(height: 12),
                Text('Antrean Selesai!', style: GothicTheme.sans(size: 17, weight: .bold)),
                const SizedBox(height: 6),
                Text(
                  '$_processedInSession undangan telah dikirim/ditandai dari $total tamu dalam antrean.',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 12.5, color: Colors.white70),
                ),
              ],
            );
          }

          final guest = widget.initialQueue[idx];
          final link = widget.store.buildLinkForGuest(guest);
          final progress = (idx + 1) / total;

          return Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: .spaceBetween,
                crossAxisAlignment: .center,
                children: [
                  Text(
                    'Tamu ${idx + 1} dari $total',
                    style: GothicTheme.sans(
                      size: 12,
                      color: _DashboardPalette.whatsappGreen,
                      weight: .bold,
                    ),
                  ),
                  Text(
                    '$_processedInSession terkirim sesi ini',
                    style: GothicTheme.sans(size: 11, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: const .all(.circular(4)),
                color: _DashboardPalette.whatsappGreen,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: _DashboardPalette.surfaceElevated,
                  borderRadius: .all(.circular(12)),
                  border: Border.fromBorderSide(BorderSide(color: _DashboardPalette.border)),
                ),
                child: Padding(
                  padding: const .all(12),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              guest.name,
                              style: GothicTheme.sans(size: 15, weight: .bold),
                            ),
                          ),
                          _MiniTag(
                            label: guest.category,
                            fg: GothicTheme.textGrey,
                            bg: _DashboardPalette.surfaceInput,
                            border: _DashboardPalette.border,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        guest.hasPhone
                            ? WhatsAppInvitationHelper.formatPhoneDisplay(guest.phone)
                            : 'Tanpa Nomor — Pilih kontak manual di WhatsApp',
                        style: GothicTheme.sans(
                          size: 12,
                          color: guest.hasPhone ? Colors.white70 : _DashboardPalette.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(link, style: GothicTheme.sans(size: 11, color: Colors.white54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pesan WhatsApp (bisa diedit khusus untuk tamu ini):',
                style: GothicTheme.sans(size: 11, color: Colors.white60),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                maxLines: 7,
                minLines: 5,
                style: GothicTheme.sans(size: 12, height: 1.4),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: _DashboardPalette.surfaceInput,
                  contentPadding: .all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: .all(.circular(10)),
                    borderSide: BorderSide(color: _DashboardPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: .all(.circular(10)),
                    borderSide: BorderSide(color: GothicTheme.white, width: 1.2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: _currentIndex,
          builder: (context, idx, _) {
            if (idx >= total) {
              return ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DashboardPalette.whatsappGreen,
                  foregroundColor: GothicTheme.bgBlack,
                ),
                child: Text(
                  'Selesai',
                  style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
                ),
              );
            }

            final guest = widget.initialQueue[idx];
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: .end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Tutup', style: GothicTheme.sans(size: 12, color: Colors.white54)),
                ),
                if (idx > 0)
                  OutlinedButton(
                    onPressed: () => _goToIndex(idx - 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GothicTheme.white,
                      side: const BorderSide(color: _DashboardPalette.border),
                    ),
                    child: Text('Sebelumnya', style: GothicTheme.sans(size: 12)),
                  ),
                OutlinedButton(
                  onPressed: () => _goToIndex(idx + 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GothicTheme.white,
                    side: const BorderSide(color: _DashboardPalette.border),
                  ),
                  child: Text('Lewati', style: GothicTheme.sans(size: 12)),
                ),
                OutlinedButton(
                  onPressed: () {
                    widget.onMarkSentOnly(guest, _messageController.text);
                    _processedInSession++;
                    _goToIndex(idx + 1);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _DashboardPalette.whatsappGreen,
                    side: const BorderSide(color: _DashboardPalette.whatsappGreen, width: 0.8),
                  ),
                  child: Text(
                    'Tandai Terkirim',
                    style: GothicTheme.sans(
                      size: 12,
                      color: _DashboardPalette.whatsappGreen,
                      weight: .bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onSendViaWhatsApp(guest, _messageController.text);
                    _processedInSession++;
                    _goToIndex(idx + 1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashboardPalette.whatsappGreen,
                    foregroundColor: GothicTheme.bgBlack,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: Text(
                    'Buka WhatsApp & Lanjut',
                    style: GothicTheme.sans(size: 12, color: GothicTheme.bgBlack, weight: .bold),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
