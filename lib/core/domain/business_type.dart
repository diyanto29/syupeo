import 'package:flutter/material.dart';

enum BusinessType {
  cafe(
    label: 'Cafe / Resto',
    description: 'Manajemen meja, antrian dapur, & menu kompleks.',
    icon: Icons.restaurant_rounded,
  ),
  retail(
    label: 'Retail / Toko',
    description: 'Stok barang jadi & transaksi cepat.',
    icon: Icons.shopping_bag_rounded,
  ),
  laundry(
    label: 'Laundry',
    description: 'Lacak status cucian & jasa layanan.',
    icon: Icons.local_laundry_service_rounded,
  ),
  showroom(
    label: 'Showroom Motor',
    description: 'Unit kendaraan & manajemen leads.',
    icon: Icons.motorcycle_rounded,
  ),
  kuliner(
    label: 'Pedagang Kuliner',
    description: 'UMKM Makanan & minuman simpel.',
    icon: Icons.fastfood_rounded,
  );

  final String label;
  final String description;
  final IconData icon;

  const BusinessType({
    required this.label,
    required this.description,
    required this.icon,
  });

  /// Daftar fitur default yang diaktifkan untuk setiap tipe bisnis.
  /// Ini hanya template awal, user bisa mengubahnya nanti.
  List<String> get defaultFeatures {
    return switch (this) {
      BusinessType.cafe => [
        'transaction',
        'order_mgmt',
        'table_mgmt',
        'kitchen_kds',
        'inventory',
        'menu_mgmt',
        'qr_order',
        'reports',
      ],
      BusinessType.retail => [
        'transaction',
        'order_mgmt',
        'inventory',
        'menu_mgmt',
        'reports',
      ],
      BusinessType.laundry => [
        'transaction',
        'order_mgmt',
        'inventory',
        'menu_mgmt',
        'reports',
      ],
      BusinessType.showroom => [
        'transaction',
        'order_mgmt',
        'inventory',
        'menu_mgmt',
        'reports',
      ],
      BusinessType.kuliner => [
        'transaction',
        'order_mgmt',
        'kitchen_kds',
        'menu_mgmt',
        'reports',
      ],
    };
  }

  static BusinessType? fromValue(String? value) {
    if (value == null) return null;
    try {
      return BusinessType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}
