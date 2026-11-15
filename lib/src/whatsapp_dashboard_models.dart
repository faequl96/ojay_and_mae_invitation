import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ojay_and_mae_invitation/src/firebase_bootstrap.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';

/// Status pengiriman undangan WhatsApp per tamu.
enum GuestSendStatus(final String label) {
  pending('Belum Dikirim'),
  sent('Terkirim');

  static GuestSendStatus fromWire(String? raw) => switch (raw?.trim()) {
    'sent' || 'Terkirim' => .sent,
    _ => .pending,
  };
}

/// Filter tampilan daftar tamu pada dashboard.
enum GuestFilterMode(final String label) {
  all('Semua'),
  pending('Belum Dikirim'),
  sent('Terkirim'),
  rsvpSubmitted('Sudah RSVP');
}

/// Entitas tamu undangan untuk pengiriman link via WhatsApp gratis.
final class const GuestInvitation({
  required final String id,
  required final String name,
  required final String phone,
  required final String category,
  required final String note,
  required final GuestSendStatus sendStatus,
  required final int sentCount,
  required final DateTime createdAt,
  final DateTime? sentAt,
  final String customMessage = '',
}) {
  bool get hasPhone => phone.isNotEmpty;
  bool get hasCustomMessage => customMessage.trim().isNotEmpty;
  String get normalizedName => name.trim().toLowerCase();

  GuestInvitation copyWith({
    String? id,
    String? name,
    String? phone,
    String? category,
    String? note,
    GuestSendStatus? sendStatus,
    int? sentCount,
    DateTime? createdAt,
    DateTime? sentAt,
    bool clearSentAt = false,
    String? customMessage,
    bool clearCustomMessage = false,
  }) {
    return GuestInvitation(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      note: note ?? this.note,
      sendStatus: sendStatus ?? this.sendStatus,
      sentCount: sentCount ?? this.sentCount,
      createdAt: createdAt ?? this.createdAt,
      sentAt: clearSentAt ? null : (sentAt ?? this.sentAt),
      customMessage: clearCustomMessage ? '' : (customMessage ?? this.customMessage),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'category': category,
    'note': note,
    'sendStatus': sendStatus.name,
    'sentCount': sentCount,
    'createdAt': createdAt.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    if (customMessage.isNotEmpty) 'customMessage': customMessage,
  };

  static GuestInvitation? fromJsonObject(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final name = (raw['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    final rawId = (raw['id'] as String?)?.trim() ?? '';
    final rawPhone = (raw['phone'] as String?)?.trim() ?? '';
    final normalizedPhone = WhatsAppInvitationHelper.normalizePhone(rawPhone);
    final category = (raw['category'] as String?)?.trim();
    final note = (raw['note'] as String?)?.trim() ?? '';
    final rawCustomMessage =
        (raw['customMessage'] as String?) ?? (raw['message'] as String?) ?? '';
    final customMessage = rawCustomMessage.trim();
    final status = GuestSendStatus.fromWire(raw['sendStatus'] as String?);
    final rawCount = raw['sentCount'];
    final sentCount = switch (rawCount) {
      int v => math.max(0, v),
      num v => math.max(0, v.toInt()),
      _ => status == .sent ? 1 : 0,
    };
    final createdAt = _parseIsoDate(raw['createdAt']) ?? DateTime.now();
    final sentAt = _parseIsoDate(raw['sentAt']);

    return GuestInvitation(
      id: rawId.isNotEmpty ? rawId : WhatsAppInvitationHelper.generateId(),
      name: name,
      phone: normalizedPhone,
      category: (category != null && category.isNotEmpty) ? category : 'Teman',
      note: note,
      sendStatus: status,
      sentCount: sentCount,
      createdAt: createdAt,
      sentAt: sentAt,
      customMessage: customMessage,
    );
  }

  static DateTime? _parseIsoDate(Object? raw) => switch (raw) {
    String s => DateTime.tryParse(s),
    int ms => DateTime.fromMillisecondsSinceEpoch(ms),
    _ => null,
  };
}

/// Preset template pesan WhatsApp siap pakai.
final class const WhatsAppTemplatePreset({
  required final String id,
  required final String name,
  required final String body,
});

/// Snapshot RSVP tamu dari Firestore (read-only).
final class const GuestRsvpSnapshot({
  required final String attendanceLabel,
  required final String senderName,
  required final String message,
  final DateTime? createdAt,
}) {
  Map<String, Object?> toCacheJson() => {
    'attendance': attendanceLabel,
    'senderName': senderName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  static GuestRsvpSnapshot? fromCacheObject(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final attendance = (raw['attendance'] as String?)?.trim();
    if (attendance == null || attendance.isEmpty) return null;
    final senderName = (raw['senderName'] as String?)?.trim() ?? '';
    final createdAtRaw = raw['createdAt'];
    final createdAt = switch (createdAtRaw) {
      String s => DateTime.tryParse(s),
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    };
    return GuestRsvpSnapshot(
      attendanceLabel: attendance,
      senderName: senderName,
      message: '',
      createdAt: createdAt,
    );
  }
}

/// Rencana sinkronisasi RSVP hemat kuota Firestore (Spark free tier).
enum RsvpSyncAction() {
  skipCooldown,
  noChanges,
  fetchDelta,
  fetchFull,
}

/// Ringkasan statistik RSVP langsung dari Firestore.
final class const RsvpSummarySnapshot({
  required final int totalCount,
  required final int attendingCount,
  required final int notAttendingCount,
  required final int uncertainCount,
  required final Map<String, GuestRsvpSnapshot> byNormalizedRecipient,
  required final bool isLoading,
  required final bool isConnected,
  final String? errorMessage,
  final DateTime? lastSyncedAt,
}) {
  static const RsvpSummarySnapshot initial = RsvpSummarySnapshot(
    totalCount: 0,
    attendingCount: 0,
    notAttendingCount: 0,
    uncertainCount: 0,
    byNormalizedRecipient: {},
    isLoading: false,
    isConnected: false,
  );
}

/// Draft hasil parsing impor CSV / JSON.
final class const ParsedGuestDraft({
  required final String name,
  required final String phone,
  required final String category,
  required final String note,
  required final bool isPhoneValid,
});

/// Status hasil pemilihan kontak dari perangkat atau file kontak (.vcf).
enum ContactPickStatus() {
  picked,
  cancelled,
  unsupported,
  failed,
}

/// Satu kandidat kontak hasil pembacaan Contact Picker / vCard (.vcf).
final class const ContactCandidate({
  required final String name,
  required final List<String> phones,
});

/// Hasil pemanggilan pemilih kontak perangkat atau file kontak (.vcf).
final class const ContactPickResult({
  required final ContactPickStatus status,
  final List<ContactCandidate> contacts = const [],
});

typedef ContactPickerCallback = Future<ContactPickResult> Function();

/// Utilitas murni: normalisasi nomor WhatsApp, pembentuk URL personalisasi,
/// engine template pesan, dan parser/exporter CSV & JSON.
abstract final class WhatsAppInvitationHelper._() {
  static const List<String> defaultCategories = [
    'Teman',
    'Keluarga',
    'Rekan Kerja',
    'Tetangga',
    'VIP',
  ];

  static const List<WhatsAppTemplatePreset> presets = [
    WhatsAppTemplatePreset(
      id: 'resmi_islami',
      name: 'Resmi & Islami',
      body:
          "Assalamu'alaikum Warahmatullahi Wabarakaatuh\n\n"
          'Kepada Yth.\n'
          'Bapak/Ibu/Saudara/i *{nama}*\n\n'
          'Tanpa mengurangi rasa hormat, perkenankan kami mengundang Bapak/Ibu/Saudara/i '
          'untuk menghadiri acara pernikahan kami:\n\n'
          '*Achmad Fauzi (Ojay) & Fitri Anggraini (Mae)*\n'
          'Sabtu, 19 Desember 2026\n'
          'Pukul 09.00 WIB s/d Selesai\n\n'
          'Berikut tautan undangan digital kami untuk informasi lokasi & konfirmasi kehadiran:\n'
          '{link}\n\n'
          'Merupakan suatu kehormatan dan kebahagiaan bagi kami apabila Bapak/Ibu/Saudara/i '
          'berkenan hadir serta memberikan doa restu.\n\n'
          "Wassalamu'alaikum Warahmatullahi Wabarakaatuh\n"
          'Kami yang berbahagia,\n'
          '*Ojay & Mae*',
    ),
    WhatsAppTemplatePreset(
      id: 'santai_teman',
      name: 'Santai & Sahabat',
      body:
          'Halo *{nama}*!\n\n'
          'Kami mau berbagi kabar bahagia nih. InsyaAllah kami akan menikah pada:\n'
          'Hari/Tgl: *Sabtu, 19 Desember 2026*\n'
          'Waktu: *09.00 WIB s/d Selesai*\n\n'
          'Yuk buka undangan online kami di link berikut:\n'
          '{link}\n\n'
          'Jangan lupa isi konfirmasi kehadiran (RSVP) dan kirim doa restu di undangannya ya. '
          'Ditunggu kehadirannya!\n\n'
          'Salam hangat,\n'
          '*Ojay & Mae*',
    ),
    WhatsAppTemplatePreset(
      id: 'ringkas_cepat',
      name: 'Singkat & Praktis',
      body:
          'Yth. *{nama}*,\n\n'
          'Dengan penuh rasa syukur, kami mengundang Anda untuk hadir di hari bahagia pernikahan kami:\n'
          '*Ojay & Mae* — Sabtu, 19 Desember 2026.\n\n'
          'Buka undangan & konfirmasi kehadiran di sini:\n'
          '{link}\n\n'
          'Terima kasih atas perhatian & doa restunya.',
    ),
  ];

  static final RegExp _nonDigitRegex = RegExp(r'[^0-9]');
  static final RegExp _hasLetterRegex = RegExp(r'[a-zA-Z]');
  static int _idSequence = 0;

  static String generateId() {
    _idSequence = (_idSequence + 1) & 0xFFFF;
    final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final seq = _idSequence.toRadixString(36);
    return 'g_${ms}_$seq';
  }

  /// Menormalisasi nomor HP ke format internasional WhatsApp tanpa tanda `+`
  /// (misal `0812-3456-789` -> `628123456789`).
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final hadPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(_nonDigitRegex, '');
    if (digits.isEmpty) return '';

    if (!hadPlus && digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    }
    if (digits.startsWith('8') && digits.length >= 8 && digits.length <= 13) {
      return '62$digits';
    }
    return digits;
  }

  static bool isValidOptionalPhone(String raw) {
    final normalized = normalizePhone(raw);
    if (normalized.isEmpty) return true;
    return normalized.length >= 8 && normalized.length <= 16;
  }

  static String formatPhoneDisplay(String normalized) {
    if (normalized.isEmpty) return '';
    if (normalized.startsWith('62') && normalized.length >= 10) {
      final local = normalized.substring(2);
      final p1 = local.substring(0, 3);
      final rest = local.substring(3);
      final buf = StringBuffer('+62 $p1');
      for (var i = 0; i < rest.length; i += 4) {
        final end = math.min(i + 4, rest.length);
        buf
          ..write('-')
          ..write(rest.substring(i, end));
      }
      return buf.toString();
    }
    return '+$normalized';
  }

  static List<String> normalizeUniquePhones(Iterable<String> rawPhones) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawPhones) {
      final normalized = normalizePhone(raw);
      if (normalized.length < 8 || normalized.length > 16) continue;
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return List<String>.unmodifiable(result);
  }

  /// Membuka pemilih kontak perangkat (Web Contact Picker API) bila didukung browser.
  static Future<ContactPickResult> pickDeviceContact() async {
    final res = await WebInterop.pickPhoneContact();
    return switch (res.status) {
      'unsupported' => const ContactPickResult(status: .unsupported),
      'cancelled' => const ContactPickResult(status: .cancelled),
      'picked' => ContactPickResult(
        status: .picked,
        contacts: [
          ContactCandidate(
            name: res.name.trim(),
            phones: normalizeUniquePhones(res.phones),
          ),
        ],
      ),
      _ => const ContactPickResult(status: .failed),
    };
  }

  /// Mem-parsing daftar kontak dari konten file vCard (.vcf) v2.1 / v3.0 / v4.0.
  static List<ContactCandidate> parseVCardContacts(String rawText) {
    if (rawText.trim().isEmpty) return const [];
    final cleaned = rawText.startsWith('\uFEFF') ? rawText.substring(1) : rawText;
    final lines = _unfoldVCardLines(cleaned);
    final contacts = <ContactCandidate>[];

    var inCard = false;
    var fnName = '';
    var nName = '';
    final rawPhones = <String>[];

    void flushCard() {
      if (!inCard) return;
      final resolvedName = fnName.isNotEmpty ? fnName : nName;
      final phones = normalizeUniquePhones(rawPhones);
      if (resolvedName.isNotEmpty || phones.isNotEmpty) {
        contacts.add(ContactCandidate(name: resolvedName, phones: phones));
      }
      inCard = false;
      fnName = '';
      nName = '';
      rawPhones.clear();
    }

    for (final line in lines) {
      final trimmedUpper = line.trim().toUpperCase();
      if (trimmedUpper == 'BEGIN:VCARD') {
        flushCard();
        inCard = true;
        continue;
      }
      if (trimmedUpper == 'END:VCARD') {
        flushCard();
        continue;
      }
      if (!inCard) continue;

      final colonIdx = line.indexOf(':');
      if (colonIdx <= 0) continue;

      final header = line.substring(0, colonIdx);
      final rawValue = line.substring(colonIdx + 1);
      final segments = header.split(';');
      final rawProp = segments.first.trim();
      final dotIdx = rawProp.indexOf('.');
      final prop = (dotIdx != -1 ? rawProp.substring(dotIdx + 1) : rawProp).trim().toUpperCase();

      final params = segments.skip(1).toList(growable: false);
      final isQuotedPrintable = params.any((p) => p.toUpperCase().contains('QUOTED-PRINTABLE'));
      final decodedValue = isQuotedPrintable ? _decodeQuotedPrintable(rawValue) : rawValue;

      switch (prop) {
        case 'FN':
          final candidate = _unescapeVCardText(decodedValue).trim();
          if (fnName.isEmpty && candidate.isNotEmpty) {
            fnName = candidate;
          }
        case 'N':
          if (nName.isEmpty) {
            final parts = _splitVCardComponents(decodedValue);
            final ordered = <String>[
              if (parts.length > 3) parts[3],
              if (parts.length > 1) parts[1],
              if (parts.length > 2) parts[2],
              if (parts.isNotEmpty) parts[0],
              if (parts.length > 4) parts[4],
            ];
            final joined = [
              for (final part in ordered)
                if (part.trim().isNotEmpty) part.trim(),
            ].join(' ');
            if (joined.isNotEmpty) {
              nName = joined;
            }
          }
        case 'TEL':
          var telValue = decodedValue.trim();
          if (telValue.toLowerCase().startsWith('tel:')) {
            telValue = telValue.substring(4).trim();
          }
          if (telValue.isEmpty) {
            for (final param in params) {
              final lowerParam = param.trim().toLowerCase();
              if (lowerParam.startsWith('waid=')) {
                telValue = param.trim().substring(5).trim();
                break;
              }
            }
          }
          if (telValue.isNotEmpty) {
            rawPhones.add(telValue);
          }
      }
    }

    flushCard();
    return List<ContactCandidate>.unmodifiable(contacts);
  }

  static List<String> _unfoldVCardLines(String rawText) {
    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final unfolded = <String>[];
    for (final line in rawLines) {
      if (unfolded.isNotEmpty) {
        final isFolded = line.startsWith(' ') || line.startsWith('\t');
        final isQpContinuation =
            unfolded.last.endsWith('=') && _isQuotedPrintableHeader(unfolded.last);
        if (isFolded || isQpContinuation) {
          final prev = unfolded.last;
          final prefix = isQpContinuation ? prev.substring(0, prev.length - 1) : prev;
          final suffix = isFolded ? line.substring(1) : line;
          unfolded.last = '$prefix$suffix';
          continue;
        }
      }
      unfolded.add(line);
    }
    return unfolded;
  }

  static bool _isQuotedPrintableHeader(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx <= 0) return false;
    return line.substring(0, colonIdx).toUpperCase().contains('QUOTED-PRINTABLE');
  }

  static String _decodeQuotedPrintable(String input) {
    final bytes = <int>[];
    for (var i = 0; i < input.length; i++) {
      if (input[i] == '=' && i + 2 < input.length) {
        final hex = int.tryParse(input.substring(i + 1, i + 3), radix: 16);
        if (hex != null) {
          bytes.add(hex);
          i += 2;
          continue;
        }
      }
      bytes.addAll(utf8.encode(input[i]));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static List<String> _splitVCardComponents(String input) {
    final result = <String>[];
    final buf = StringBuffer();
    var escaped = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        buf.write(_unescapeVCardChar(ch));
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else if (ch == ';') {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  static String _unescapeVCardText(String input) {
    final buf = StringBuffer();
    var escaped = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        buf.write(_unescapeVCardChar(ch));
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String _unescapeVCardChar(String ch) => switch (ch) {
    'n' || 'N' => ' ',
    ',' || ';' || '\\' => ch,
    _ => ch,
  };

  static const List<String> _dashboardPathSuffixes = ['/dashboard', '/index.html'];

  static String defaultBaseUrl() {
    final href = WebInterop.getCurrentHref();
    if (href != null && (href.startsWith('http://') || href.startsWith('https://'))) {
      return normalizeBaseUrl(href);
    }
    final origin = WebInterop.getCurrentOrigin();
    if (origin != null && (origin.startsWith('http://') || origin.startsWith('https://'))) {
      return normalizeBaseUrl(origin);
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return normalizeBaseUrl(base.toString());
    }
    return 'https://ojay-and-mae.vercel.app';
  }

  static String normalizeBaseUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://ojay-and-mae.vercel.app';

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final isLocal =
          trimmed.startsWith('localhost') ||
          trimmed.startsWith('127.0.0.1') ||
          trimmed.startsWith('0.0.0.0');
      trimmed = '${isLocal ? 'http' : 'https'}://$trimmed';
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      return 'https://ojay-and-mae.vercel.app';
    }

    var cleanPath = parsed.path;
    while (cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }
    final lowerPath = cleanPath.toLowerCase();
    for (final suffix in _dashboardPathSuffixes) {
      if (lowerPath == suffix) {
        cleanPath = '';
        break;
      }
      if (lowerPath.endsWith(suffix)) {
        cleanPath = cleanPath.substring(0, cleanPath.length - suffix.length);
        break;
      }
    }
    while (cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }

    return Uri(
      scheme: parsed.scheme,
      userInfo: parsed.userInfo,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: cleanPath,
    ).toString();
  }

  static bool isSupportedImportFilename(String filename) {
    final lower = filename.trim().toLowerCase();
    return lower.endsWith('.csv') || lower.endsWith('.json');
  }

  /// Membentuk tautan undangan personalisasi yang aman diklik di dalam chat WhatsApp.
  static String buildInvitationLink({required String baseUrl, required String guestName}) {
    final cleanBase = normalizeBaseUrl(baseUrl);
    final cleanName = guestName.trim();
    if (cleanName.isEmpty) return '$cleanBase/';

    // Encode spasi sebagai %20 & tanda kurung/seru agar WhatsApp tidak memotong URL.
    final encodedName = Uri.encodeComponent(cleanName)
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('!', '%21')
        .replaceAll("'", '%27')
        .replaceAll('*', '%2A');
    return '$cleanBase/?to=$encodedName';
  }

  static String renderMessage({
    required String template,
    required String guestName,
    required String invitationLink,
    String category = '',
  }) {
    return template
        .replaceAll('{nama}', guestName.trim())
        .replaceAll('{link}', invitationLink)
        .replaceAll('{kategori}', category.trim());
  }

  static final List<RegExp> _protectedTemplateSpans = [
    RegExp(r'Achmad Fauzi \(Ojay\) & Fitri Anggraini \(Mae\)'),
    RegExp(r'Achmad Fauzi \(Ojay\)'),
    RegExp(r'Fitri Anggraini \(Mae\)'),
    RegExp(r'Ojay & Mae'),
    RegExp(r'Bapak/Ibu/Saudara/i'),
  ];

  static String _normalizeMessageText(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  static String _stableTemplateHash(String input) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(36);
  }

  static List<({int start, int end})> _findProtectedRanges(String text) {
    final ranges = <({int start, int end})>[];
    for (final pattern in _protectedTemplateSpans) {
      for (final match in pattern.allMatches(text)) {
        ranges.add((start: match.start, end: match.end));
      }
    }
    return ranges;
  }

  static bool _overlapsRanges(int start, int end, List<({int start, int end})> ranges) {
    for (final r in ranges) {
      if (start < r.end && end > r.start) return true;
    }
    return false;
  }

  static String _replaceGuestNameWithPlaceholder(String text, String guestName) {
    final cleanName = guestName.trim();
    if (cleanName.isEmpty || text.contains('{nama}')) return text;

    final protected = _findProtectedRanges(text);
    final escaped = RegExp.escape(cleanName);
    final boldPattern = RegExp(r'\*' + escaped + r'\*');
    var replaced = _replaceMatchesOutsideRanges(text, boldPattern, '*{nama}*', protected);
    if (replaced != text) return replaced;

    final exactPattern = RegExp(r'(?<![\p{L}\p{N}])' + escaped + r'(?![\p{L}\p{N}])', unicode: true);
    replaced = _replaceMatchesOutsideRanges(text, exactPattern, '{nama}', protected);
    if (replaced != text) return replaced;

    final insensitivePattern = RegExp(
      r'(?<![\p{L}\p{N}])' + escaped + r'(?![\p{L}\p{N}])',
      unicode: true,
      caseSensitive: false,
    );
    return _replaceMatchesOutsideRanges(text, insensitivePattern, '{nama}', protected);
  }

  static String _replaceMatchesOutsideRanges(
    String text,
    RegExp pattern,
    String replacement,
    List<({int start, int end})> protected,
  ) {
    final buf = StringBuffer();
    var cursor = 0;
    var changed = false;
    for (final match in pattern.allMatches(text)) {
      if (_overlapsRanges(match.start, match.end, protected)) continue;
      buf
        ..write(text.substring(cursor, match.start))
        ..write(replacement);
      cursor = match.end;
      changed = true;
    }
    if (!changed) return text;
    buf.write(text.substring(cursor));
    return buf.toString();
  }

  /// Mengubah isi pesan tamu menjadi template yang dapat dipakai ulang (`{nama}`, `{link}`).
  static String extractTemplateFromGuestMessage({
    required String message,
    required GuestInvitation guest,
    required String baseUrl,
  }) {
    var result = _normalizeMessageText(message);
    if (result.isEmpty) return '';

    final expectedLink = buildInvitationLink(baseUrl: baseUrl, guestName: guest.name);
    if (!result.contains('{link}') && expectedLink.isNotEmpty) {
      result = result.replaceAll(expectedLink, '{link}');
      if (!result.contains('{link}')) {
        final query = Uri.tryParse(expectedLink)?.query ?? '';
        if (query.isNotEmpty) {
          final anyOriginLink = RegExp(r'https?://[^\s]+\?' + RegExp.escape(query));
          result = result.replaceAll(anyOriginLink, '{link}');
        }
      }
    }

    return _replaceGuestNameWithPlaceholder(result, guest.name);
  }

  /// Mengecek apakah pesan tamu sama dengan salah satu dari 3 preset bawaan.
  static bool isSameAsBuiltInPreset({
    required String message,
    required GuestInvitation guest,
    required String baseUrl,
  }) {
    final normalized = _normalizeMessageText(message);
    if (normalized.isEmpty) return true;

    final link = buildInvitationLink(baseUrl: baseUrl, guestName: guest.name);
    final extracted = extractTemplateFromGuestMessage(
      message: normalized,
      guest: guest,
      baseUrl: baseUrl,
    );

    for (final preset in presets) {
      final presetNorm = _normalizeMessageText(preset.body);
      if (normalized == presetNorm || extracted == presetNorm) {
        return true;
      }
      final rendered = _normalizeMessageText(
        renderMessage(
          template: preset.body,
          guestName: guest.name,
          invitationLink: link,
          category: guest.category,
        ),
      );
      if (normalized == rendered) {
        return true;
      }
    }
    return false;
  }

  /// Menghasilkan item template tambahan dari isi pesan tamu yang berbeda dari 3 preset bawaan.
  static List<WhatsAppTemplatePreset> buildGuestDerivedTemplates({
    required List<GuestInvitation> guests,
    required String baseUrl,
  }) {
    final seenBodies = <String>{
      for (final preset in presets) _normalizeMessageText(preset.body),
    };
    final derived = <WhatsAppTemplatePreset>[];

    for (final guest in guests) {
      if (!guest.hasCustomMessage) continue;
      if (isSameAsBuiltInPreset(message: guest.customMessage, guest: guest, baseUrl: baseUrl)) {
        continue;
      }
      final templateBody = extractTemplateFromGuestMessage(
        message: guest.customMessage,
        guest: guest,
        baseUrl: baseUrl,
      );
      if (templateBody.isEmpty || !seenBodies.add(templateBody)) continue;

      final cleanName = guest.name.trim();
      final shortName = cleanName.length > 18 ? '${cleanName.substring(0, 17)}…' : cleanName;
      derived.add(
        WhatsAppTemplatePreset(
          id: 'guest_tpl_${_stableTemplateHash(templateBody)}',
          name: shortName.isNotEmpty ? 'Pesan: $shortName' : 'Pesan Tamu',
          body: templateBody,
        ),
      );
    }

    return List<WhatsAppTemplatePreset>.unmodifiable(derived);
  }

  /// Membentuk URL resmi `https://wa.me/...` yang 100% gratis tanpa API berbayar.
  static Uri buildWhatsAppUri({required String normalizedPhone, required String message}) {
    final cleanDigits = normalizePhone(normalizedPhone);
    final encodedMessage = Uri.encodeComponent(message);
    if (cleanDigits.isEmpty) {
      return Uri.parse('https://wa.me/?text=$encodedMessage');
    }
    return Uri.parse('https://wa.me/$cleanDigits?text=$encodedMessage');
  }

  /// Mem-parsing data berformat CSV (pemisah koma `,` atau titik koma `;`, atau 1 kolom nama).
  static List<ParsedGuestDraft> parseBulkGuestText(
    String rawText, {
    String defaultCategory = 'Teman',
  }) {
    final cleanedText = rawText.startsWith('\uFEFF') ? rawText.substring(1) : rawText;
    final lines = const LineSplitter().convert(cleanedText);
    final drafts = <ParsedGuestDraft>[];

    var nameCol = 0;
    var phoneCol = 1;
    var categoryCol = 2;
    var hasHeaderMapping = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line);
      if (cols.isEmpty) continue;

      if (!hasHeaderMapping && drafts.isEmpty && _looksLikeHeaderRow(cols)) {
        final mapping = _detectCsvColumns(cols);
        nameCol = mapping.nameCol;
        phoneCol = mapping.phoneCol;
        categoryCol = mapping.categoryCol;
        hasHeaderMapping = true;
        continue;
      }

      var rawName = nameCol < cols.length ? cols[nameCol].trim() : '';
      var rawPhone = (phoneCol >= 0 && phoneCol < cols.length) ? cols[phoneCol].trim() : '';
      final rawCategory =
          (categoryCol >= 0 && categoryCol < cols.length) ? cols[categoryCol].trim() : '';

      // Jika user menempel CSV `08123456789, Budi Santoso`, tukar otomatis.
      if (!hasHeaderMapping &&
          cols.length >= 2 &&
          _looksLikePhoneCell(rawName) &&
          !_looksLikePhoneCell(rawPhone)) {
        final temp = rawName;
        rawName = rawPhone;
        rawPhone = temp;
      }

      if (rawName.isEmpty) continue;
      final normalizedPhone = normalizePhone(rawPhone);
      final isPhoneValid = isValidOptionalPhone(rawPhone);

      drafts.add(
        ParsedGuestDraft(
          name: rawName,
          phone: normalizedPhone,
          category: rawCategory.isNotEmpty ? rawCategory : defaultCategory,
          note: '',
          isPhoneValid: isPhoneValid,
        ),
      );
    }

    return drafts;
  }

  static List<String> _splitCsvLine(String line) {
    if (line.contains(';')) {
      return _splitDelimitedLine(line, ';');
    }
    if (line.contains(',')) {
      return _splitDelimitedLine(line, ',');
    }
    return [line.trim()];
  }

  static ({int nameCol, int phoneCol, int categoryCol}) _detectCsvColumns(List<String> headers) {
    var nameCol = -1;
    var phoneCol = -1;
    var categoryCol = -1;
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      if (nameCol == -1 &&
          (h == 'nama' ||
              h == 'name' ||
              h.contains('nama tamu') ||
              h == 'tamu' ||
              h == 'guest' ||
              h == 'penerima')) {
        nameCol = i;
      } else if (phoneCol == -1 &&
          (h.contains('wa') ||
              h.contains('whatsapp') ||
              h.contains('telepon') ||
              h.contains('phone') ||
              h.contains('hp') ||
              h == 'no' ||
              h == 'nomor')) {
        phoneCol = i;
      } else if (categoryCol == -1 && (h.contains('kategori') || h.contains('category'))) {
        categoryCol = i;
      }
    }
    return (nameCol: nameCol == -1 ? 0 : nameCol, phoneCol: phoneCol, categoryCol: categoryCol);
  }

  static List<String> _splitDelimitedLine(String line, String delimiter) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static bool _looksLikeHeaderRow(List<String> cols) {
    if (cols.isEmpty) return false;
    const nameHeaders = {'nama', 'name', 'nama tamu', 'tamu', 'guest', 'penerima'};
    const phoneHeaders = {'no', 'nomor', 'no wa', 'wa', 'whatsapp', 'hp', 'no hp', 'telepon', 'phone'};
    if (cols.any((c) => nameHeaders.contains(c.trim().toLowerCase()))) return true;
    final first = cols[0].toLowerCase();
    final second = cols.length > 1 ? cols[1].toLowerCase() : '';
    if (cols.length >= 2 && first.contains('nama') && phoneHeaders.any(second.contains)) {
      return true;
    }
    return false;
  }

  static bool _looksLikePhoneCell(String cell) {
    if (_hasLetterRegex.hasMatch(cell)) return false;
    final digits = cell.replaceAll(_nonDigitRegex, '');
    return digits.length >= 8;
  }

  static String exportGuestsToCsv({
    required List<GuestInvitation> guests,
    required String baseUrl,
    required Map<String, GuestRsvpSnapshot> rsvpByRecipient,
  }) {
    final buf = StringBuffer('\uFEFF')
      ..writeln('Nama Tamu,Nomor WhatsApp,Kategori,Status Kirim,Waktu Kirim,Link Undangan,Status RSVP');

    for (final guest in guests) {
      final link = buildInvitationLink(baseUrl: baseUrl, guestName: guest.name);
      final rsvp = rsvpByRecipient[guest.normalizedName];
      final sentAtStr = guest.sentAt != null ? guest.sentAt!.toLocal().toIso8601String() : '';
      final phoneStr = guest.hasPhone ? formatPhoneDisplay(guest.phone) : '';
      buf.writeln(
        [
          _escapeCsv(guest.name),
          _escapeCsv(phoneStr),
          _escapeCsv(guest.category),
          _escapeCsv(guest.sendStatus.label),
          _escapeCsv(sentAtStr),
          _escapeCsv(link),
          _escapeCsv(rsvp?.attendanceLabel ?? 'Belum RSVP'),
        ].join(','),
      );
    }
    return buf.toString();
  }

  static String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String exportBackupJson({
    required List<GuestInvitation> guests,
    required String baseUrl,
    required String template,
    required String activePresetId,
  }) {
    final payload = <String, Object?>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'baseUrl': normalizeBaseUrl(baseUrl),
      'activePresetId': activePresetId,
      'template': template,
      'guests': [for (final g in guests) g.toJson()],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static ({
    List<GuestInvitation> guests,
    String? baseUrl,
    String? template,
    String? activePresetId,
  })?
  parseBackupJson(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;

    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is List<Object?>) {
        final guests = <GuestInvitation>[
          for (final item in decoded) ?GuestInvitation.fromJsonObject(item),
        ];
        return (guests: guests, baseUrl: null, template: null, activePresetId: null);
      }
      if (decoded is Map<Object?, Object?>) {
        final rawGuests = decoded['guests'];
        final guests = <GuestInvitation>[
          if (rawGuests is List<Object?>)
            for (final item in rawGuests) ?GuestInvitation.fromJsonObject(item),
        ];
        final baseUrl = (decoded['baseUrl'] as String?)?.trim();
        final template = decoded['template'] as String?;
        final presetId = (decoded['activePresetId'] as String?)?.trim();
        return (
          guests: guests,
          baseUrl: (baseUrl != null && baseUrl.isNotEmpty) ? normalizeBaseUrl(baseUrl) : null,
          template: (template != null && template.trim().isNotEmpty) ? template : null,
          activePresetId: (presetId != null && presetId.isNotEmpty) ? presetId : null,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static const int maxColdStartRsvpDocs = 100;
  static const int maxDeltaRsvpDocs = 40;

  /// Menentukan strategi pembacaan Firestore paling hemat berdasarkan cache lokal & `count()`.
  static ({RsvpSyncAction action, int fetchLimit}) planRsvpSync({
    required bool hasCache,
    required int cachedTotalCount,
    required int remoteTotalCount,
  }) {
    if (remoteTotalCount <= 0) {
      return (action: .noChanges, fetchLimit: 0);
    }
    if (hasCache && remoteTotalCount == cachedTotalCount) {
      return (action: .noChanges, fetchLimit: 0);
    }
    final delta = remoteTotalCount - cachedTotalCount;
    if (hasCache && delta > 0 && delta <= maxDeltaRsvpDocs) {
      return (action: .fetchDelta, fetchLimit: math.min(delta + 2, maxDeltaRsvpDocs + 2));
    }
    return (
      action: .fetchFull,
      fetchLimit: math.min(remoteTotalCount, maxColdStartRsvpDocs),
    );
  }

  static String serializeRsvpCache(RsvpSummarySnapshot summary, DateTime checkedAt) {
    final encodedRecipients = <String, Object?>{
      for (final entry in summary.byNormalizedRecipient.entries)
        entry.key: entry.value.toCacheJson(),
    };
    return jsonEncode(<String, Object?>{
      'version': 1,
      'totalCount': summary.totalCount,
      'attendingCount': summary.attendingCount,
      'notAttendingCount': summary.notAttendingCount,
      'uncertainCount': summary.uncertainCount,
      'lastCheckedAt': checkedAt.toIso8601String(),
      'byRecipient': encodedRecipients,
    });
  }

  static ({RsvpSummarySnapshot summary, DateTime? checkedAt})? parseRsvpCache(String raw) {
    if (raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<Object?, Object?>) return null;

      final total = (decoded['totalCount'] as num?)?.toInt() ?? 0;
      final attending = (decoded['attendingCount'] as num?)?.toInt() ?? 0;
      final notAttending = (decoded['notAttendingCount'] as num?)?.toInt() ?? 0;
      final uncertain = (decoded['uncertainCount'] as num?)?.toInt() ?? 0;
      final checkedAtStr = decoded['lastCheckedAt'] as String?;
      final checkedAt = checkedAtStr != null ? DateTime.tryParse(checkedAtStr) : null;

      final rawMap = decoded['byRecipient'];
      final byRecipient = <String, GuestRsvpSnapshot>{};
      if (rawMap is Map<Object?, Object?>) {
        for (final entry in rawMap.entries) {
          final key = entry.key;
          if (key is! String || key.isEmpty) continue;
          final parsedSnapshot = GuestRsvpSnapshot.fromCacheObject(entry.value);
          if (parsedSnapshot != null) {
            byRecipient[key] = parsedSnapshot;
          }
        }
      }

      return (
        summary: RsvpSummarySnapshot(
          totalCount: total,
          attendingCount: attending,
          notAttendingCount: notAttending,
          uncertainCount: uncertain,
          byNormalizedRecipient: Map<String, GuestRsvpSnapshot>.unmodifiable(byRecipient),
          isLoading: false,
          isConnected: true,
          lastSyncedAt: checkedAt,
        ),
        checkedAt: checkedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Store reaktif untuk seluruh status & daftar tamu Dashboard Pengiriman WhatsApp.
final class GuestDashboardStore({String? baseUrl}) extends ChangeNotifier {
  this {
    _restoreFromStorage();
    _restoreRsvpCache();
  }

  static const String storageKey = 'ojay_mae_wa_dashboard_v1';
  static const String rsvpCacheStorageKey = 'ojay_mae_rsvp_cache_v1';
  static const Duration rsvpAutoSyncCooldown = Duration(seconds: 60);
  static const Duration rsvpManualCooldown = Duration(seconds: 4);

  List<GuestInvitation> _guests = const [];
  String? _baseUrlOverride = (baseUrl != null && baseUrl.trim().isNotEmpty)
      ? WhatsAppInvitationHelper.normalizeBaseUrl(baseUrl)
      : null;
  String _templateText = WhatsAppInvitationHelper.presets.first.body;
  String _activePresetId = WhatsAppInvitationHelper.presets.first.id;
  String _searchQuery = '';
  GuestFilterMode _filterMode = .all;
  String _categoryFilter = 'Semua';
  Set<String> _selectedIds = {};
  RsvpSummarySnapshot _rsvpSummary = RsvpSummarySnapshot.initial;
  bool _hasRsvpCache = false;
  DateTime? _lastRsvpCheckAt;
  bool _disposed = false;

  List<GuestInvitation> get guests => _guests;
  String get baseUrl => _baseUrlOverride ?? WhatsAppInvitationHelper.defaultBaseUrl();
  String get templateText => _templateText;
  String get activePresetId => _activePresetId;
  String get searchQuery => _searchQuery;
  GuestFilterMode get filterMode => _filterMode;
  String get categoryFilter => _categoryFilter;
  Set<String> get selectedIds => Set<String>.unmodifiable(_selectedIds);
  RsvpSummarySnapshot get rsvpSummary => _rsvpSummary;

  int get totalGuests => _guests.length;
  int get pendingCount => _guests.where((g) => g.sendStatus == .pending).length;
  int get sentCount => _guests.where((g) => g.sendStatus == .sent).length;

  List<String> get availableCategories {
    final set = <String>{'Semua', ...WhatsAppInvitationHelper.defaultCategories};
    for (final guest in _guests) {
      if (guest.category.isNotEmpty) set.add(guest.category);
    }
    return List<String>.unmodifiable(set);
  }

  List<GuestInvitation> get filteredGuests {
    final query = _searchQuery.trim().toLowerCase();
    return [
      for (final guest in _guests)
        if (_matchesFilters(guest, query)) guest,
    ];
  }

  bool _matchesFilters(GuestInvitation guest, String query) {
    if (_categoryFilter != 'Semua' && guest.category != _categoryFilter) {
      return false;
    }
    switch (_filterMode) {
      case .all:
        break;
      case .pending:
        if (guest.sendStatus != .pending) return false;
      case .sent:
        if (guest.sendStatus != .sent) return false;
      case .rsvpSubmitted:
        if (!_rsvpSummary.byNormalizedRecipient.containsKey(guest.normalizedName)) {
          return false;
        }
    }
    if (query.isEmpty) return true;
    return guest.name.toLowerCase().contains(query) ||
        guest.phone.contains(query) ||
        guest.category.toLowerCase().contains(query) ||
        guest.note.toLowerCase().contains(query);
  }

  void _restoreFromStorage() {
    final raw = WebInterop.getStorageItem(storageKey);
    if (raw == null || raw.isEmpty) return;

    final parsed = WhatsAppInvitationHelper.parseBackupJson(raw);
    if (parsed == null) return;
    _guests = List<GuestInvitation>.unmodifiable(parsed.guests);
    if (parsed.template != null) _templateText = parsed.template!;
    if (parsed.activePresetId != null) _activePresetId = parsed.activePresetId!;
  }

  void _saveToStorage() {
    final serialized = WhatsAppInvitationHelper.exportBackupJson(
      guests: _guests,
      baseUrl: baseUrl,
      template: _templateText,
      activePresetId: _activePresetId,
    );
    WebInterop.setStorageItem(storageKey, serialized);
  }

  void _commitAndNotify() {
    if (_disposed) return;
    _saveToStorage();
    notifyListeners();
  }

  List<WhatsAppTemplatePreset> get availableTemplatePresets => List<WhatsAppTemplatePreset>.unmodifiable([
    ...WhatsAppInvitationHelper.presets,
    ...WhatsAppInvitationHelper.buildGuestDerivedTemplates(guests: _guests, baseUrl: baseUrl),
  ]);

  String buildLinkForGuest(GuestInvitation guest) =>
      WhatsAppInvitationHelper.buildInvitationLink(baseUrl: baseUrl, guestName: guest.name);

  String renderActiveTemplateForGuest(GuestInvitation guest) {
    final link = buildLinkForGuest(guest);
    return WhatsAppInvitationHelper.renderMessage(
      template: _templateText,
      guestName: guest.name,
      invitationLink: link,
      category: guest.category,
    );
  }

  String buildMessageForGuest(GuestInvitation guest) {
    if (guest.hasCustomMessage) {
      final link = buildLinkForGuest(guest);
      return WhatsAppInvitationHelper.renderMessage(
        template: guest.customMessage,
        guestName: guest.name,
        invitationLink: link,
        category: guest.category,
      );
    }
    return renderActiveTemplateForGuest(guest);
  }

  Uri buildWhatsAppUriForGuest(GuestInvitation guest, {String? customMessage}) {
    final text = customMessage ?? buildMessageForGuest(guest);
    return WhatsAppInvitationHelper.buildWhatsAppUri(
      normalizedPhone: guest.phone,
      message: text,
    );
  }

  GuestInvitation addGuest({
    required String name,
    String phone = '',
    String category = 'Teman',
    String note = '',
  }) {
    final cleanName = name.trim();
    final cleanPhone = WhatsAppInvitationHelper.normalizePhone(phone);
    final cleanCat = category.trim().isNotEmpty ? category.trim() : 'Teman';
    final entry = GuestInvitation(
      id: WhatsAppInvitationHelper.generateId(),
      name: cleanName,
      phone: cleanPhone,
      category: cleanCat,
      note: note.trim(),
      sendStatus: .pending,
      sentCount: 0,
      createdAt: DateTime.now(),
    );
    _guests = List<GuestInvitation>.unmodifiable([entry, ..._guests]);
    _commitAndNotify();
    return entry;
  }

  void updateGuest({
    required String id,
    required String name,
    String phone = '',
    String category = 'Teman',
    String? note,
  }) {
    final cleanName = name.trim();
    final cleanPhone = WhatsAppInvitationHelper.normalizePhone(phone);
    final cleanCat = category.trim().isNotEmpty ? category.trim() : 'Teman';
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id == id)
          g.copyWith(
            name: cleanName,
            phone: cleanPhone,
            category: cleanCat,
            note: note != null ? note.trim() : g.note,
          )
        else
          g,
    ]);
    _commitAndNotify();
  }

  void deleteGuest(String id) {
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id != id) g,
    ]);
    _selectedIds = Set<String>.from(_selectedIds)..remove(id);
    _commitAndNotify();
  }

  void deleteSelectedGuests() {
    if (_selectedIds.isEmpty) return;
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (!_selectedIds.contains(g.id)) g,
    ]);
    _selectedIds = {};
    _commitAndNotify();
  }

  ({int added, int skipped}) importDrafts(
    List<ParsedGuestDraft> drafts, {
    bool skipDuplicateNames = true,
  }) {
    final existingNames = <String>{for (final g in _guests) g.normalizedName};
    final addedList = <GuestInvitation>[];
    var skipped = 0;

    for (final draft in drafts) {
      final normalized = draft.name.trim().toLowerCase();
      if (normalized.isEmpty) {
        skipped++;
        continue;
      }
      if (skipDuplicateNames && existingNames.contains(normalized)) {
        skipped++;
        continue;
      }
      existingNames.add(normalized);
      addedList.add(
        GuestInvitation(
          id: WhatsAppInvitationHelper.generateId(),
          name: draft.name.trim(),
          phone: draft.phone,
          category: draft.category,
          note: draft.note,
          sendStatus: .pending,
          sentCount: 0,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (addedList.isNotEmpty) {
      _guests = List<GuestInvitation>.unmodifiable([...addedList, ..._guests]);
      _commitAndNotify();
    }
    return (added: addedList.length, skipped: skipped);
  }

  bool importJsonBackup(String rawJson, {bool replaceExisting = false}) {
    final parsed = WhatsAppInvitationHelper.parseBackupJson(rawJson);
    if (parsed == null) return false;

    if (replaceExisting) {
      _guests = List<GuestInvitation>.unmodifiable(parsed.guests);
      _selectedIds = {};
    } else {
      final existingIds = <String>{for (final g in _guests) g.id};
      final existingNames = <String>{for (final g in _guests) g.normalizedName};
      final incoming = <GuestInvitation>[
        for (final g in parsed.guests)
          if (!existingIds.contains(g.id) && !existingNames.contains(g.normalizedName)) g,
      ];
      _guests = List<GuestInvitation>.unmodifiable([...incoming, ..._guests]);
    }
    if (parsed.template != null) _templateText = parsed.template!;
    if (parsed.activePresetId != null) _activePresetId = parsed.activePresetId!;

    _commitAndNotify();
    return true;
  }

  void loadSampleGuests() {
    importDrafts(const [
      ParsedGuestDraft(
        name: 'Budi Santoso',
        phone: '6281234567890',
        category: 'Teman',
        note: '',
        isPhoneValid: true,
      ),
      ParsedGuestDraft(
        name: 'Keluarga Bapak Ahmad',
        phone: '6285698765432',
        category: 'Keluarga',
        note: '',
        isPhoneValid: true,
      ),
      ParsedGuestDraft(
        name: 'Rina & Partner',
        phone: '',
        category: 'Rekan Kerja',
        note: '',
        isPhoneValid: true,
      ),
    ]);
  }

  void updateGuestMessage(String id, String message) {
    final trimmed = message.trim();
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id == id)
          _applyMessageUpdate(g, trimmed)
        else
          g,
    ]);
    _commitAndNotify();
  }

  GuestInvitation _applyMessageUpdate(GuestInvitation guest, String trimmedMessage) {
    if (trimmedMessage.isEmpty) {
      return guest.copyWith(clearCustomMessage: true);
    }
    final activeRendered = renderActiveTemplateForGuest(guest).trim();
    final isSameAsBuiltIn = WhatsAppInvitationHelper.isSameAsBuiltInPreset(
      message: trimmedMessage,
      guest: guest,
      baseUrl: baseUrl,
    );
    if (trimmedMessage == activeRendered && isSameAsBuiltIn) {
      return guest.copyWith(clearCustomMessage: true);
    }
    return guest.copyWith(customMessage: trimmedMessage);
  }

  void clearGuestCustomMessage(String id) {
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id == id) g.copyWith(clearCustomMessage: true) else g,
    ]);
    _commitAndNotify();
  }

  void markAsSent(String id, {String? sentMessage}) {
    final now = DateTime.now();
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id == id)
          _markGuestSent(g, now, sentMessage)
        else
          g,
    ]);
    _commitAndNotify();
  }

  GuestInvitation _markGuestSent(GuestInvitation guest, DateTime now, String? sentMessage) {
    if (sentMessage == null) {
      return guest.copyWith(sendStatus: .sent, sentCount: guest.sentCount + 1, sentAt: now);
    }
    final trimmed = sentMessage.trim();
    if (trimmed.isEmpty) {
      return guest.copyWith(sendStatus: .sent, sentCount: guest.sentCount + 1, sentAt: now);
    }
    final isSameAsBuiltIn = WhatsAppInvitationHelper.isSameAsBuiltInPreset(
      message: trimmed,
      guest: guest,
      baseUrl: baseUrl,
    );
    if (!isSameAsBuiltIn) {
      return guest.copyWith(
        sendStatus: .sent,
        sentCount: guest.sentCount + 1,
        sentAt: now,
        customMessage: trimmed,
      );
    }
    if (guest.hasCustomMessage && trimmed != guest.customMessage.trim()) {
      return guest.copyWith(
        sendStatus: .sent,
        sentCount: guest.sentCount + 1,
        sentAt: now,
        clearCustomMessage: true,
      );
    }
    return guest.copyWith(sendStatus: .sent, sentCount: guest.sentCount + 1, sentAt: now);
  }

  void markAsPending(String id) {
    _guests = List<GuestInvitation>.unmodifiable([
      for (final g in _guests)
        if (g.id == id) g.copyWith(sendStatus: .pending, clearSentAt: true) else g,
    ]);
    _commitAndNotify();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterMode(GuestFilterMode mode) {
    if (_filterMode == mode) return;
    _filterMode = mode;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
  }

  void toggleSelection(String id) {
    final next = Set<String>.from(_selectedIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    _selectedIds = next;
    notifyListeners();
  }

  void toggleSelectAllFiltered() {
    final visible = filteredGuests;
    if (visible.isEmpty) return;
    final allVisibleSelected = visible.every((g) => _selectedIds.contains(g.id));
    final next = Set<String>.from(_selectedIds);
    if (allVisibleSelected) {
      for (final g in visible) {
        next.remove(g.id);
      }
    } else {
      for (final g in visible) {
        next.add(g.id);
      }
    }
    _selectedIds = next;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds = {};
    notifyListeners();
  }

  void updateBaseUrl(String nextUrl) {
    final normalized = WhatsAppInvitationHelper.normalizeBaseUrl(nextUrl);
    if (_baseUrlOverride == normalized) return;
    _baseUrlOverride = normalized;
    _commitAndNotify();
  }

  void resetBaseUrlToCurrentOrigin() {
    if (_baseUrlOverride == null) return;
    _baseUrlOverride = null;
    _commitAndNotify();
  }

  void updateTemplate(String nextTemplate, {String? presetId}) {
    _templateText = nextTemplate;
    if (presetId != null) {
      _activePresetId = presetId;
    } else {
      final normalized = nextTemplate.trim();
      var matchedId = 'custom';
      for (final preset in availableTemplatePresets) {
        if (preset.body.trim() == normalized) {
          matchedId = preset.id;
          break;
        }
      }
      _activePresetId = matchedId;
    }
    _commitAndNotify();
  }

  void selectPreset(WhatsAppTemplatePreset preset) {
    _templateText = preset.body;
    _activePresetId = preset.id;
    _commitAndNotify();
  }

  List<GuestInvitation> queueCandidates() {
    if (_selectedIds.isNotEmpty) {
      return [
        for (final g in _guests)
          if (_selectedIds.contains(g.id)) g,
      ];
    }
    return [
      for (final g in _guests)
        if (g.sendStatus == .pending) g,
    ];
  }

  void _restoreRsvpCache() {
    final raw = WebInterop.getStorageItem(rsvpCacheStorageKey);
    if (raw == null || raw.isEmpty) return;

    final parsed = WhatsAppInvitationHelper.parseRsvpCache(raw);
    if (parsed == null) return;
    _rsvpSummary = parsed.summary;
    _hasRsvpCache = true;
    _lastRsvpCheckAt = parsed.checkedAt;
  }

  void _saveRsvpCache(RsvpSummarySnapshot summary, DateTime checkedAt) {
    _hasRsvpCache = true;
    _lastRsvpCheckAt = checkedAt;
    WebInterop.setStorageItem(
      rsvpCacheStorageKey,
      WhatsAppInvitationHelper.serializeRsvpCache(summary, checkedAt),
    );
  }

  /// Sinkronkan ringkasan RSVP dari Firestore secara read-only dan super hemat kuota:
  /// 1) Daftar tamu & status kirim WA disimpan 100% di localStorage (0 read / 0 write Firestore).
  /// 2) Cooldown 60 dtk saat buka dashboard ulang -> 0 read bila masih segar.
  /// 3) Cek `count()` (1 read per 1.000 dokumen) sebelum mengunduh dokumen apa pun.
  /// 4) Jika jumlah berubah, ambil hanya dokumen delta terbaru + agregasi `.count()`.
  Future<void> refreshFirestoreRsvps({bool force = false}) async {
    if (_disposed || _rsvpSummary.isLoading) return;

    final now = DateTime.now();
    final lastCheck = _lastRsvpCheckAt;
    if (lastCheck != null) {
      final elapsed = now.difference(lastCheck);
      if (!force && _hasRsvpCache && elapsed < rsvpAutoSyncCooldown) {
        return;
      }
      if (force && elapsed < rsvpManualCooldown) {
        return;
      }
    }

    _rsvpSummary = RsvpSummarySnapshot(
      totalCount: _rsvpSummary.totalCount,
      attendingCount: _rsvpSummary.attendingCount,
      notAttendingCount: _rsvpSummary.notAttendingCount,
      uncertainCount: _rsvpSummary.uncertainCount,
      byNormalizedRecipient: _rsvpSummary.byNormalizedRecipient,
      isLoading: true,
      isConnected: _rsvpSummary.isConnected,
      lastSyncedAt: _rsvpSummary.lastSyncedAt,
    );
    notifyListeners();

    try {
      final ready = FirebaseBootstrap.isReady || await FirebaseBootstrap.ensureInitialized();
      if (_disposed) return;
      if (!ready) {
        _rsvpSummary = RsvpSummarySnapshot(
          totalCount: _rsvpSummary.totalCount,
          attendingCount: _rsvpSummary.attendingCount,
          notAttendingCount: _rsvpSummary.notAttendingCount,
          uncertainCount: _rsvpSummary.uncertainCount,
          byNormalizedRecipient: _rsvpSummary.byNormalizedRecipient,
          isLoading: false,
          isConnected: false,
          errorMessage: 'Mode lokal (Firestore belum terhubung).',
          lastSyncedAt: _rsvpSummary.lastSyncedAt,
        );
        notifyListeners();
        return;
      }

      final col = FirebaseFirestore.instance.collection('rsvps');
      // 1 read untuk mengecek total dokumen (gratis hingga 50.000 read/hari).
      final totalSnap = await col.count().get();
      if (_disposed) return;

      final remoteTotal = totalSnap.count ?? 0;
      final checkedAt = DateTime.now();

      if (remoteTotal == 0) {
        final emptySummary = RsvpSummarySnapshot(
          totalCount: 0,
          attendingCount: 0,
          notAttendingCount: 0,
          uncertainCount: 0,
          byNormalizedRecipient: const {},
          isLoading: false,
          isConnected: true,
          lastSyncedAt: checkedAt,
        );
        _rsvpSummary = emptySummary;
        _saveRsvpCache(emptySummary, checkedAt);
        notifyListeners();
        return;
      }

      final plan = WhatsAppInvitationHelper.planRsvpSync(
        hasCache: _hasRsvpCache,
        cachedTotalCount: _rsvpSummary.totalCount,
        remoteTotalCount: remoteTotal,
      );

      if (plan.action == .noChanges) {
        final unchangedSummary = RsvpSummarySnapshot(
          totalCount: _rsvpSummary.totalCount,
          attendingCount: _rsvpSummary.attendingCount,
          notAttendingCount: _rsvpSummary.notAttendingCount,
          uncertainCount: _rsvpSummary.uncertainCount,
          byNormalizedRecipient: _rsvpSummary.byNormalizedRecipient,
          isLoading: false,
          isConnected: true,
          lastSyncedAt: checkedAt,
        );
        _rsvpSummary = unchangedSummary;
        _saveRsvpCache(unchangedSummary, checkedAt);
        notifyListeners();
        return;
      }

      final snap = await col
          .orderBy('createdAt', descending: true)
          .limit(plan.fetchLimit)
          .get();
      if (_disposed) return;

      final byRecipient = plan.action == .fetchDelta
          ? Map<String, GuestRsvpSnapshot>.from(_rsvpSummary.byNormalizedRecipient)
          : <String, GuestRsvpSnapshot>{};

      var localAttending = 0;
      var localNotAttending = 0;
      var localUncertain = 0;

      // Iterasi dari terlama ke terbaru di dalam batch agar entri terbaru selalu menimpa status lama.
      for (final doc in snap.docs.reversed) {
        final data = doc.data();
        final attendance = (data['attendance'] as String?)?.trim() ?? 'Hadir';
        switch (attendance) {
          case 'Tidak Hadir':
            localNotAttending++;
          case 'Masih Ragu':
            localUncertain++;
          default:
            localAttending++;
        }

        final recipientName = (data['recipientName'] as String?)?.trim() ?? '';
        final senderName = (data['name'] as String?)?.trim() ?? '';
        final message = (data['message'] as String?)?.trim() ?? '';
        final createdAt = _parseCreatedAt(data['createdAt']);

        final snapshot = GuestRsvpSnapshot(
          attendanceLabel: attendance,
          senderName: senderName,
          message: message,
          createdAt: createdAt,
        );

        final normRecipient = recipientName.toLowerCase();
        if (normRecipient.isNotEmpty) {
          byRecipient[normRecipient] = snapshot;
        }
        final normSender = senderName.toLowerCase();
        if (normSender.isNotEmpty) {
          byRecipient[normSender] = snapshot;
        }
      }

      var attending = localAttending;
      var notAttending = localNotAttending;
      var uncertain = localUncertain;

      // Jika seluruh dokumen belum terambil penuh dalam batch ini (atau mode delta),
      // pakai 3 query agregasi .count() (total hanya 3 read) agar statistik tetap akurat 100%.
      final needsExactAggregateCounts =
          plan.action == .fetchDelta || snap.docs.length < remoteTotal;
      if (needsExactAggregateCounts) {
        final counts = await Future.wait([
          col.where('attendance', isEqualTo: 'Hadir').count().get(),
          col.where('attendance', isEqualTo: 'Tidak Hadir').count().get(),
          col.where('attendance', isEqualTo: 'Masih Ragu').count().get(),
        ]);
        if (_disposed) return;
        attending = counts[0].count ?? attending;
        notAttending = counts[1].count ?? notAttending;
        uncertain = counts[2].count ?? uncertain;
      }

      final syncedAt = DateTime.now();
      final nextSummary = RsvpSummarySnapshot(
        totalCount: remoteTotal,
        attendingCount: attending,
        notAttendingCount: notAttending,
        uncertainCount: uncertain,
        byNormalizedRecipient: Map<String, GuestRsvpSnapshot>.unmodifiable(byRecipient),
        isLoading: false,
        isConnected: true,
        lastSyncedAt: syncedAt,
      );
      _rsvpSummary = nextSummary;
      _saveRsvpCache(nextSummary, syncedAt);
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _rsvpSummary = RsvpSummarySnapshot(
        totalCount: _rsvpSummary.totalCount,
        attendingCount: _rsvpSummary.attendingCount,
        notAttendingCount: _rsvpSummary.notAttendingCount,
        uncertainCount: _rsvpSummary.uncertainCount,
        byNormalizedRecipient: _rsvpSummary.byNormalizedRecipient,
        isLoading: false,
        isConnected: _hasRsvpCache,
        errorMessage: 'Tidak dapat memuat statistik RSVP.',
        lastSyncedAt: _rsvpSummary.lastSyncedAt,
      );
      notifyListeners();
    }
  }

  static DateTime? _parseCreatedAt(Object? raw) => switch (raw) {
    Timestamp ts => ts.toDate().toLocal(),
    DateTime dt => dt.toLocal(),
    String iso => DateTime.tryParse(iso)?.toLocal(),
    int ms => DateTime.fromMillisecondsSinceEpoch(ms).toLocal(),
    _ => null,
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
