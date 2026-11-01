import 'package:flutter/material.dart';

class FulfillmentOrder {
  const FulfillmentOrder({
    required this.id,
    required this.orderCode,
    this.starterKitId,
    required this.kitName,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    required this.shippingCity,
    required this.status,
    required this.fulfillmentMode,
    this.assignedWarehouseId,
    this.senderAlias,
    this.distanceKm,
    this.driverName,
    this.driverPhone,
    this.trackingNumber,
    this.dispatchedAt,
    this.deliveredAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String orderCode;
  final String? starterKitId;
  final String kitName;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final String shippingCity;
  final String status;
  final String fulfillmentMode;
  final String? assignedWarehouseId;
  final String? senderAlias;
  final double? distanceKm;
  final String? driverName;
  final String? driverPhone;
  final String? trackingNumber;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final String? notes;
  final DateTime createdAt;

  factory FulfillmentOrder.fromMap(Map<String, dynamic> json) {
    return FulfillmentOrder(
      id: json['id'] as String,
      orderCode: (json['order_code'] as String?) ?? 'ORD-0000',
      starterKitId: json['starter_kit_id'] as String?,
      kitName: (json['kit_name'] as String?) ?? 'Paket Usaha Retail',
      recipientName: (json['recipient_name'] as String?) ?? '',
      recipientPhone: (json['recipient_phone'] as String?) ?? '',
      shippingAddress: (json['shipping_address'] as String?) ?? '',
      shippingCity: (json['shipping_city'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending_dispatch',
      fulfillmentMode: (json['fulfillment_mode'] as String?) ?? 'agent_direct',
      assignedWarehouseId: json['assigned_warehouse_id'] as String?,
      senderAlias: json['sender_alias'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      dispatchedAt: json['dispatched_at'] == null
          ? null
          : DateTime.tryParse(json['dispatched_at'] as String),
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.tryParse(json['delivered_at'] as String),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending_dispatch':
        return 'Menunggu Konfirmasi & Pembayaran';
      case 'packing':
        return 'Sedang Dikemas di Gudang';
      case 'in_transit':
        return 'Dalam Pengiriman Kurir';
      case 'delivered':
        return 'Paket Diterima & Aktif';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending_dispatch':
        return const Color(0xFFD97706); // Amber
      case 'packing':
        return const Color(0xFF0070FC); // Blue Syupeo
      case 'in_transit':
        return const Color(0xFF6366F1); // Indigo
      case 'delivered':
        return const Color(0xFF10B981); // Emerald
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'pending_dispatch':
        return const Color(0xFFFEF3C7);
      case 'packing':
        return const Color(0xFFEFF6FF);
      case 'in_transit':
        return const Color(0xFFEEF2FF);
      case 'delivered':
        return const Color(0xFFECFDF5);
      case 'cancelled':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  bool get isPending => status == 'pending_dispatch';
  bool get isPacking => status == 'packing';
  bool get isInTransit => status == 'in_transit';
  bool get isDelivered => status == 'delivered';
}

