import 'dart:convert';

/// Helper representasi tag TLV EMVCo (QRIS MPM Nasional).
class QrisTlv {
  final String tag;
  final String value;

  const QrisTlv({required this.tag, required this.value});

  String format() {
    final lenStr = value.length.toString().padLeft(2, '0');
    return '$tag$lenStr$value';
  }
}

/// Helper generator untuk QRIS Dinamis berbasis standar EMVCo (QRIS MPM Nasional).
/// Mengubah payload QRIS Statis toko (Point of Initiation Method: 11)
/// menjadi QRIS Dinamis (Point of Initiation Method: 12) dengan menyuntikkan Tag 54 (Transaction Amount)
/// dan menghitung ulang Tag 63 (CRC16/CCITT-FALSE Checksum).
class QrisDynamicGenerator {
  QrisDynamicGenerator._();

  /// Hitung CRC16/CCITT-FALSE (Polynomial: 0x1021, Initial: 0xFFFF)
  static String calculateCrc16(String input) {
    int crc = 0xFFFF;
    final bytes = ascii.encode(input);

    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Parse TLV EMVCo root-level secara berurutan.
  static List<QrisTlv> parseTlv(String raw) {
    final list = <QrisTlv>[];
    final trimmed = raw.trim();
    int idx = 0;

    while (idx + 4 <= trimmed.length) {
      final tag = trimmed.substring(idx, idx + 2);
      final len = int.tryParse(trimmed.substring(idx + 2, idx + 4)) ?? -1;
      if (len < 0 || idx + 4 + len > trimmed.length) break;
      final val = trimmed.substring(idx + 4, idx + 4 + len);
      list.add(QrisTlv(tag: tag, value: val));
      idx += 4 + len;
    }

    return list;
  }

  /// Validasi apakah string merupakan format payload QRIS EMVCo yang valid
  static bool isValidQrisPayload(String? payload) {
    if (payload == null) return false;
    final trimmed = payload.trim();
    if (!trimmed.startsWith('000201') || trimmed.length < 40) return false;
    final tags = parseTlv(trimmed);
    return tags.isNotEmpty && tags.first.tag == '00' && tags.length >= 3;
  }

  /// Ekstrak Nama Merchant (Tag 59) dari payload QRIS
  static String? extractMerchantName(String rawQris) {
    try {
      final tags = parseTlv(rawQris);
      for (final t in tags) {
        if (t.tag == '59' && t.value.trim().isNotEmpty) {
          return t.value.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ekstrak Kota Merchant (Tag 60) dari payload QRIS
  static String? extractMerchantCity(String rawQris) {
    try {
      final tags = parseTlv(rawQris);
      for (final t in tags) {
        if (t.tag == '60' && t.value.trim().isNotEmpty) {
          return t.value.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ubah string QRIS statis menjadi QRIS dinamis dengan nominal tagihan tertentu.
  /// Jika nominal <= 0 atau format payload invalid, akan mengembalikan payload asli.
  static String generateDynamicQris({
    required String rawQris,
    required double amount,
  }) {
    if (amount <= 0) return rawQris;

    final tags = parseTlv(rawQris);
    if (tags.isEmpty || tags.first.tag != '00') {
      return rawQris;
    }

    // 1. Hapus Tag 63 lama (Checksum) dan Tag 54 lama (Transaction Amount) jika ada
    tags.removeWhere((t) => t.tag == '63' || t.tag == '54');

    // 2. Ubah Tag 01 (Point of Initiation Method) dari '11' (Statis) menjadi '12' (Dinamis)
    final tag01Index = tags.indexWhere((t) => t.tag == '01');
    if (tag01Index != -1) {
      tags[tag01Index] = const QrisTlv(tag: '01', value: '12');
    } else {
      // Sisipkan setelah Tag 00 jika belum ada
      tags.insert(1, const QrisTlv(tag: '01', value: '12'));
    }

    // 3. Format tag amount (Tag 54) tanpa desimal untuk IDR
    final amountInt = amount.round();
    final newTag54 = QrisTlv(tag: '54', value: amountInt.toString());

    // 4. Standar EMVCo: Tag 54 disisipkan sebelum Tag 58 (Country Code 'ID')
    final tag58Index = tags.indexWhere((t) => t.tag == '58');
    if (tag58Index != -1) {
      tags.insert(tag58Index, newTag54);
    } else {
      // Jika Tag 58 tidak ditemukan, tempatkan sebelum Tag 59 (Merchant Name) atau di akhir
      final tag59Index = tags.indexWhere((t) => t.tag == '59');
      if (tag59Index != -1) {
        tags.insert(tag59Index, newTag54);
      } else {
        tags.add(newTag54);
      }
    }

    // 5. Rakit kembali seluruh tag
    final buffer = StringBuffer();
    for (final t in tags) {
      buffer.write(t.format());
    }

    // 6. Tambahkan Tag 63 header ('6304') dan hitung CRC16
    buffer.write('6304');
    final payloadForChecksum = buffer.toString();
    final checksum = calculateCrc16(payloadForChecksum);

    return '$payloadForChecksum$checksum';
  }
}
