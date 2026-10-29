import 'package:flutter/material.dart';

enum UserRole { waiter, customer, kitchen, admin }

enum TableStatus { available, awaitingValidation, occupied }

enum OrderStatus { pending, cooking, ready, served, rejected, paid }

enum PaymentMethod { cash, debit, qris }

enum MenuCategory { food, drink, dessert }

enum Capability {
  openTable,
  inputOrder,
  validateOrder,
  updateCookingStatus,
  editMenuPrice,
  closeSession,
  financeReport,
}

class MenuItemData {
  const MenuItemData({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.stockAvailable,
    required this.ingredients,
  });

  final String id;
  final String name;
  final MenuCategory category;
  final double price;
  final String description;
  final bool stockAvailable;
  final List<String> ingredients;

  MenuItemData copyWith({
    String? id,
    String? name,
    MenuCategory? category,
    double? price,
    String? description,
    bool? stockAvailable,
    List<String>? ingredients,
  }) {
    return MenuItemData(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.note,
  });

  final String menuItemId;
  final String name;
  final int quantity;
  final double price;
  final String note;

  double get subtotal => price * quantity;
}

class OrderTicket {
  const OrderTicket({
    required this.id,
    required this.tableNumber,
    required this.createdAt,
    required this.status,
    required this.isValidated,
    required this.source,
    required this.items,
  });

  final String id;
  final int tableNumber;
  final DateTime createdAt;
  final OrderStatus status;
  final bool isValidated;
  final String source;
  final List<OrderItem> items;

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  OrderTicket copyWith({
    String? id,
    int? tableNumber,
    DateTime? createdAt,
    OrderStatus? status,
    bool? isValidated,
    String? source,
    List<OrderItem>? items,
  }) {
    return OrderTicket(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isValidated: isValidated ?? this.isValidated,
      source: source ?? this.source,
      items: items ?? this.items,
    );
  }
}

class TableSession {
  const TableSession({
    required this.id,
    required this.tableNumber,
    required this.status,
    required this.qrCode,
    required this.isActive,
    required this.orders,
  });

  final String id;
  final int tableNumber;
  final TableStatus status;
  final String qrCode;
  final bool isActive;
  final List<OrderTicket> orders;

  double get runningBill => orders.fold(0, (sum, order) => sum + order.total);

  TableSession copyWith({
    String? id,
    int? tableNumber,
    TableStatus? status,
    String? qrCode,
    bool? isActive,
    List<OrderTicket>? orders,
  }) {
    return TableSession(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      isActive: isActive ?? this.isActive,
      orders: orders ?? this.orders,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;
}

class UserAccount {
  const UserAccount({
    required this.name,
    required this.role,
    required this.active,
  });

  final String name;
  final UserRole role;
  final bool active;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.revenueToday,
    required this.netProfitEstimate,
    required this.topSeller,
    required this.bestWaiter,
  });

  final double revenueToday;
  final double netProfitEstimate;
  final String topSeller;
  final String bestWaiter;
}

class PosState {
  const PosState({
    required this.selectedRole,
    required this.selectedCustomerTable,
    required this.selectedCategory,
    required this.menuItems,
    required this.sessions,
    required this.notifications,
    required this.users,
    required this.analytics,
    required this.searchQuery,
  });

  final UserRole selectedRole;
  final int? selectedCustomerTable;
  final MenuCategory? selectedCategory;
  final List<MenuItemData> menuItems;
  final List<TableSession> sessions;
  final List<AppNotification> notifications;
  final List<UserAccount> users;
  final AnalyticsSnapshot analytics;
  final String searchQuery;

  PosState copyWith({
    UserRole? selectedRole,
    int? selectedCustomerTable,
    bool clearSelectedCustomerTable = false,
    MenuCategory? selectedCategory,
    bool clearSelectedCategory = false,
    List<MenuItemData>? menuItems,
    List<TableSession>? sessions,
    List<AppNotification>? notifications,
    List<UserAccount>? users,
    AnalyticsSnapshot? analytics,
    String? searchQuery,
  }) {
    return PosState(
      selectedRole: selectedRole ?? this.selectedRole,
      selectedCustomerTable: clearSelectedCustomerTable
          ? null
          : selectedCustomerTable ?? this.selectedCustomerTable,
      selectedCategory: clearSelectedCategory
          ? null
          : selectedCategory ?? this.selectedCategory,
      menuItems: menuItems ?? this.menuItems,
      sessions: sessions ?? this.sessions,
      notifications: notifications ?? this.notifications,
      users: users ?? this.users,
      analytics: analytics ?? this.analytics,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.waiter => 'Waiter',
    UserRole.customer => 'Customer',
    UserRole.kitchen => 'Kitchen',
    UserRole.admin => 'Admin / Kasir',
  };

  IconData get icon => switch (this) {
    UserRole.waiter => Icons.room_service_rounded,
    UserRole.customer => Icons.qr_code_scanner_rounded,
    UserRole.kitchen => Icons.soup_kitchen_rounded,
    UserRole.admin => Icons.point_of_sale_rounded,
  };

  Color get accent => switch (this) {
    UserRole.waiter => const Color(0xFF006B5B),
    UserRole.customer => const Color(0xFF0057B8),
    UserRole.kitchen => const Color(0xFFB54708),
    UserRole.admin => const Color(0xFF7A1F3D),
  };
}

extension TableStatusX on TableStatus {
  String get label => switch (this) {
    TableStatus.available => 'Kosong',
    TableStatus.awaitingValidation => 'Menunggu Validasi',
    TableStatus.occupied => 'Aktif',
  };

  Color get color => switch (this) {
    TableStatus.available => const Color(0xFF2E7D32),
    TableStatus.awaitingValidation => const Color(0xFFF9A825),
    TableStatus.occupied => const Color(0xFFC62828),
  };
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.cooking => 'Cooking',
    OrderStatus.ready => 'Ready',
    OrderStatus.served => 'Served',
    OrderStatus.rejected => 'Rejected',
    OrderStatus.paid => 'Paid',
  };

  Color get color => switch (this) {
    OrderStatus.pending => const Color(0xFFD97706),
    OrderStatus.cooking => const Color(0xFF2563EB),
    OrderStatus.ready => const Color(0xFF0F766E),
    OrderStatus.served => const Color(0xFF4F46E5),
    OrderStatus.rejected => const Color(0xFFB91C1C),
    OrderStatus.paid => const Color(0xFF15803D),
  };
}

extension MenuCategoryX on MenuCategory {
  String get label => switch (this) {
    MenuCategory.food => 'Makanan',
    MenuCategory.drink => 'Minuman',
    MenuCategory.dessert => 'Dessert',
  };
}

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Tunai',
    PaymentMethod.debit => 'Debit',
    PaymentMethod.qris => 'QRIS',
  };
}
