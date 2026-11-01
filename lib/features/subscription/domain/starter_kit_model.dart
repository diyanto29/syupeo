import 'package:flutter/foundation.dart';

@immutable
class StarterKit {
  const StarterKit({
    required this.id,
    required this.name,
    required this.slug,
    this.badge,
    required this.price,
    this.originalPrice,
    this.description,
    this.suitableFor,
    this.itemsIncluded = const [],
    this.isPopular = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? badge;
  final int price;
  final int? originalPrice;
  final String? description;
  final String? suitableFor;
  final List<String> itemsIncluded;
  final bool isPopular;
  final bool isActive;
  final int sortOrder;

  factory StarterKit.fromMap(Map<String, dynamic> map) {
    List<String> items = [];
    if (map['items_included'] is List) {
      items = (map['items_included'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return StarterKit(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      badge: map['badge']?.toString(),
      price: (map['price'] as num?)?.toInt() ?? 200000,
      originalPrice: (map['original_price'] as num?)?.toInt(),
      description: map['description']?.toString(),
      suitableFor: map['suitable_for']?.toString(),
      itemsIncluded: items,
      isPopular: map['is_popular'] == true,
      isActive: map['is_active'] != false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// 4 Paket Usaha Resmi Syupeo (@ Rp 200.000)
  static const List<StarterKit> defaultKits = [
    StarterKit(
      id: 'paket-01-toko-pemula',
      slug: 'paket-01-toko-pemula',
      name: 'Paket 01 — Toko Pemula',
      badge: 'FAVORIT KELUARGA 🌾',
      price: 200000,
      originalPrice: 240000,
      description:
          'Stok sembako & kebutuhan harian rutin yang paling cepat berputar di perumahan.',
      suitableFor: 'Tetangga, Usaha Rumahan, Kos-kosan, Toko Kelontong',
      itemsIncluded: [
        'Beras Premium 2 kg (Bahan Pokok)',
        'Minyak Goreng 1 Liter & Gula Pasir 1 kg',
        'Tepung Terigu 1 kg & Mi Instan Pilihan (5 pcs)',
        'Kopi Sachet Nikmat (10 pcs) & Teh Pilihan',
        'Sabun Mandi (2 pcs) & Sabun Cuci Piring',
        'Deterjen Pakaian & Pasta Gigi Keluarga',
        'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
        'Web Toko Online Siap Pakai & Dukungan QRIS Kasir',
      ],
      isPopular: true,
      isActive: true,
      sortOrder: 1,
    ),
    StarterKit(
      id: 'paket-02-gen-z-box',
      slug: 'paket-02-gen-z-box',
      name: 'Paket 02 — Gen Z Box',
      badge: 'TREN VIRAL 🔥',
      price: 200000,
      originalPrice: 260000,
      description:
          'Aksesori kekinian & fashion items margin tinggi yang sangat diminati anak muda.',
      suitableFor: 'Mahasiswa, Pelajar, Reseller Kampus, TikTok & IG Shop',
      itemsIncluded: [
        'Phone Charm Kekinian (5 pcs)',
        'Pop Socket Karakter Trendi (3 pcs)',
        'Pelindung Kabel Handphone (5 pcs)',
        'Scrunchie Rambut (5 pcs) & Jepit Rambut Korea (4 pcs)',
        'Gantungan Kunci Estetik (5 pcs) & Stiker Pack (10 pcs)',
        'Kaos Kaki Korea Stylish (3 pasang)',
        'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      ],
      isPopular: false,
      isActive: true,
      sortOrder: 2,
    ),
    StarterKit(
      id: 'paket-03-beauty-box',
      slug: 'paket-03-beauty-box',
      name: 'Paket 03 — Beauty Box Makarizo',
      badge: 'STOK RESELLER 💄',
      price: 200000,
      originalPrice: 250000,
      description:
          'Stok produk perawatan & kecantikan resmi Makarizo untuk dijual dengan margin menarik.',
      suitableFor: 'Reseller Kecantikan, Salon Rumahan, Beauty Creator',
      itemsIncluded: [
        'Produk Perawatan Rambut & Tubuh Makarizo Resmi',
        'Produk Kecantikan Pelengkap Terlaris',
        'Kemasan Reseller Eksklusif (Pouch & Label Toko)',
        'Materi Promosi Foto Produk Asli & Konten Video',
        'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      ],
      isPopular: false,
      isActive: true,
      sortOrder: 3,
    ),
    StarterKit(
      id: 'paket-04-air-mineral',
      slug: 'paket-04-air-mineral',
      name: 'Paket 04 — Air Mineral & Minuman',
      badge: 'PUTARAN HARIAN 🥤',
      price: 200000,
      originalPrice: 230000,
      description:
          'Stok air galon, botol, dan minuman dingin kemasan untuk kebutuhan harian warga.',
      suitableFor: 'Depot Air, Warung Makan, Toko Kelontong, Kantin',
      itemsIncluded: [
        'Air Mineral Galon & Botol Kemasan Pilihan',
        'Minuman Teh & Kopi Kemasan Siap Minum',
        'Minuman Isotonik & Penyegar Tubuh',
        'Dukungan Pasokan Rutin dari Hub Syupeo',
        'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      ],
      isPopular: false,
      isActive: true,
      sortOrder: 4,
    ),
  ];
}

