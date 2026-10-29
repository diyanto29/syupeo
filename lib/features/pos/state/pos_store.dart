import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dpos/features/pos/domain/pos_models.dart';

final posStoreProvider = NotifierProvider<PosStore, PosState>(PosStore.new);

class PosStore extends Notifier<PosState> {
  @override
  PosState build() {
    final now = DateTime.now();
    final menuItems = [
      const MenuItemData(
        id: 'm1',
        name: 'Nasi Goreng Signature',
        category: MenuCategory.food,
        price: 32000,
        description: 'Nasi goreng smoky dengan telur dan acar.',
        stockAvailable: true,
        ingredients: ['Beras', 'Telur', 'Bumbu', 'Ayam'],
      ),
      const MenuItemData(
        id: 'm2',
        name: 'Mie Ayam Truffle',
        category: MenuCategory.food,
        price: 29000,
        description: 'Mie kenyal dengan ayam gurih dan minyak truffle.',
        stockAvailable: true,
        ingredients: ['Mie', 'Ayam', 'Jamur'],
      ),
      const MenuItemData(
        id: 'm3',
        name: 'Es Kopi Susu Gula Aren',
        category: MenuCategory.drink,
        price: 22000,
        description: 'Kopi susu dingin dengan balance pahit dan manis.',
        stockAvailable: true,
        ingredients: ['Espresso', 'Susu', 'Gula aren'],
      ),
      const MenuItemData(
        id: 'm4',
        name: 'Lychee Sparkling',
        category: MenuCategory.drink,
        price: 26000,
        description: 'Minuman segar dengan soda dan leci.',
        stockAvailable: false,
        ingredients: ['Leci', 'Soda', 'Mint'],
      ),
      const MenuItemData(
        id: 'm5',
        name: 'Cheesecake Lotus',
        category: MenuCategory.dessert,
        price: 28000,
        description: 'Dessert creamy dengan crumb lotus.',
        stockAvailable: true,
        ingredients: ['Cream cheese', 'Biskuit lotus', 'Butter'],
      ),
    ];

    final order1 = OrderTicket(
      id: 'o1',
      tableNumber: 3,
      createdAt: now.subtract(const Duration(minutes: 24)),
      status: OrderStatus.cooking,
      isValidated: true,
      source: 'QR Customer',
      items: const [
        OrderItem(
          menuItemId: 'm1',
          name: 'Nasi Goreng Signature',
          quantity: 2,
          price: 32000,
          note: 'Pedas level 3',
        ),
        OrderItem(
          menuItemId: 'm3',
          name: 'Es Kopi Susu Gula Aren',
          quantity: 1,
          price: 22000,
          note: 'Less sugar',
        ),
      ],
    );

    final order2 = OrderTicket(
      id: 'o2',
      tableNumber: 5,
      createdAt: now.subtract(const Duration(minutes: 8)),
      status: OrderStatus.pending,
      isValidated: false,
      source: 'QR Customer',
      items: const [
        OrderItem(
          menuItemId: 'm2',
          name: 'Mie Ayam Truffle',
          quantity: 1,
          price: 29000,
          note: 'Tanpa daun bawang',
        ),
      ],
    );

    final order3 = OrderTicket(
      id: 'o3',
      tableNumber: 8,
      createdAt: now.subtract(const Duration(minutes: 14)),
      status: OrderStatus.ready,
      isValidated: true,
      source: 'Manual Waiter',
      items: const [
        OrderItem(
          menuItemId: 'm1',
          name: 'Nasi Goreng Signature',
          quantity: 1,
          price: 32000,
          note: 'Alergi kacang',
        ),
        OrderItem(
          menuItemId: 'm5',
          name: 'Cheesecake Lotus',
          quantity: 1,
          price: 28000,
          note: '',
        ),
      ],
    );

    return PosState(
      selectedRole: UserRole.waiter,
      selectedCustomerTable: 3,
      selectedCategory: null,
      searchQuery: '',
      menuItems: menuItems,
      sessions: [
        TableSession(
          id: 's1',
          tableNumber: 3,
          status: TableStatus.occupied,
          qrCode: 'QR-TABLE-3-S1',
          isActive: true,
          orders: [order1],
        ),
        TableSession(
          id: 's2',
          tableNumber: 5,
          status: TableStatus.awaitingValidation,
          qrCode: 'QR-TABLE-5-S2',
          isActive: true,
          orders: [order2],
        ),
        TableSession(
          id: 's3',
          tableNumber: 8,
          status: TableStatus.occupied,
          qrCode: 'QR-TABLE-8-S3',
          isActive: true,
          orders: [order3],
        ),
      ],
      notifications: [
        AppNotification(
          id: 'n1',
          message: 'Meja 8: pesanan siap diantar dari dapur.',
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        AppNotification(
          id: 'n2',
          message: 'Meja 3 menekan tombol Call Waiter.',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
      users: const [
        UserAccount(name: 'Rina', role: UserRole.waiter, active: true),
        UserAccount(name: 'Bagas', role: UserRole.kitchen, active: true),
        UserAccount(name: 'Nadia', role: UserRole.admin, active: true),
        UserAccount(name: 'Tio', role: UserRole.waiter, active: false),
      ],
      analytics: const AnalyticsSnapshot(
        revenueToday: 4860000,
        netProfitEstimate: 1925000,
        topSeller: 'Nasi Goreng Signature',
        bestWaiter: 'Rina',
      ),
    );
  }

  List<TableSession> get activeSessions =>
      state.sessions.where((session) => session.isActive).toList();

  List<OrderTicket> get allOrders => [
    for (final session in state.sessions) ...session.orders,
  ];

  void switchRole(UserRole role) {
    state = state.copyWith(selectedRole: role);
  }

  void selectCustomerTable(int? tableNumber) {
    state = state.copyWith(selectedCustomerTable: tableNumber);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setCategory(MenuCategory? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearSelectedCategory: category == null,
    );
  }

  void openTable(int tableNumber) {
    final existing = state.sessions
        .where(
          (session) => session.tableNumber == tableNumber && session.isActive,
        )
        .isNotEmpty;
    if (existing) {
      pushNotification('Meja $tableNumber sudah aktif, QR tidak dibuat ulang.');
      return;
    }

    final sessionId = 'S${DateTime.now().millisecondsSinceEpoch}';
    final session = TableSession(
      id: sessionId,
      tableNumber: tableNumber,
      status: TableStatus.occupied,
      qrCode: 'QR-TABLE-$tableNumber-$sessionId',
      isActive: true,
      orders: const [],
    );

    state = state.copyWith(
      sessions: [...state.sessions, session]
        ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber)),
    );
    pushNotification('Meja $tableNumber dibuka. Session $sessionId aktif.');
  }

  void transferTable(String sessionId, int newTableNumber) {
    state = state.copyWith(
      sessions:
          state.sessions
              .map(
                (session) => session.id == sessionId
                    ? session.copyWith(tableNumber: newTableNumber)
                    : session,
              )
              .toList()
            ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber)),
    );
    pushNotification('Session $sessionId dipindahkan ke meja $newTableNumber.');
  }

  void validateOrder(String orderId, bool approved) {
    state = state.copyWith(
      sessions: state.sessions
          .map(
            (session) => session.copyWith(
              status: session.orders.any((order) => order.id == orderId)
                  ? (approved
                        ? TableStatus.occupied
                        : TableStatus.awaitingValidation)
                  : session.status,
              orders: session.orders
                  .map(
                    (order) => order.id == orderId
                        ? order.copyWith(
                            isValidated: approved,
                            status: approved
                                ? OrderStatus.cooking
                                : OrderStatus.rejected,
                          )
                        : order,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );

    pushNotification(
      approved
          ? 'Order $orderId divalidasi dan dikirim ke dapur.'
          : 'Order $orderId ditolak oleh waiter.',
    );
  }

  void addCustomerOrder({
    required int tableNumber,
    required MenuItemData menuItem,
    required String note,
  }) {
    final newOrder = OrderTicket(
      id: 'O${DateTime.now().millisecondsSinceEpoch}',
      tableNumber: tableNumber,
      createdAt: DateTime.now(),
      status: OrderStatus.pending,
      isValidated: false,
      source: 'QR Customer',
      items: [
        OrderItem(
          menuItemId: menuItem.id,
          name: menuItem.name,
          quantity: 1,
          price: menuItem.price,
          note: note,
        ),
      ],
    );

    bool sessionFound = false;
    final sessions = state.sessions.map((session) {
      if (session.tableNumber != tableNumber || !session.isActive) {
        return session;
      }
      sessionFound = true;
      return session.copyWith(
        status: TableStatus.awaitingValidation,
        orders: [...session.orders, newOrder],
      );
    }).toList();

    if (!sessionFound) {
      return;
    }

    state = state.copyWith(sessions: sessions);
    pushNotification('Pesanan baru dari meja $tableNumber menunggu validasi.');
  }

  void addManualOrder({
    required int tableNumber,
    required MenuItemData menuItem,
  }) {
    final newOrder = OrderTicket(
      id: 'O${DateTime.now().millisecondsSinceEpoch}',
      tableNumber: tableNumber,
      createdAt: DateTime.now(),
      status: OrderStatus.cooking,
      isValidated: true,
      source: 'Manual Waiter',
      items: [
        OrderItem(
          menuItemId: menuItem.id,
          name: menuItem.name,
          quantity: 1,
          price: menuItem.price,
          note: 'Dicatat waiter',
        ),
      ],
    );

    state = state.copyWith(
      sessions: state.sessions.map((session) {
        if (session.tableNumber != tableNumber || !session.isActive) {
          return session;
        }
        return session.copyWith(
          status: TableStatus.occupied,
          orders: [...session.orders, newOrder],
        );
      }).toList(),
    );
    pushNotification('Manual order ditambahkan ke meja $tableNumber.');
  }

  void callWaiter(int tableNumber) {
    pushNotification('Meja $tableNumber menekan tombol Call Waiter.');
  }

  void updateOrderStatus(String orderId, OrderStatus nextStatus) {
    state = state.copyWith(
      sessions: state.sessions
          .map(
            (session) => session.copyWith(
              orders: session.orders
                  .map(
                    (order) => order.id == orderId
                        ? order.copyWith(status: nextStatus)
                        : order,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );

    if (nextStatus == OrderStatus.ready) {
      final order = allOrders.firstWhere((item) => item.id == orderId);
      pushNotification(
        'Kitchen update: meja ${order.tableNumber} siap diantar.',
      );
    }
  }

  void toggleStock(String menuId) {
    state = state.copyWith(
      menuItems: state.menuItems
          .map(
            (item) => item.id == menuId
                ? item.copyWith(stockAvailable: !item.stockAvailable)
                : item,
          )
          .toList(),
    );
  }

  void checkoutSession(String sessionId, PaymentMethod method) {
    state = state.copyWith(
      sessions: state.sessions
          .map(
            (session) => session.id == sessionId
                ? session.copyWith(
                    isActive: false,
                    status: TableStatus.available,
                    orders: session.orders
                        .map(
                          (order) => order.copyWith(status: OrderStatus.paid),
                        )
                        .toList(),
                  )
                : session,
          )
          .toList(),
    );
    pushNotification(
      'Session $sessionId ditutup via ${method.label}. QR meja dinonaktifkan.',
    );
  }

  void pushNotification(String message) {
    state = state.copyWith(
      notifications: [
        AppNotification(
          id: 'N${DateTime.now().millisecondsSinceEpoch}',
          message: message,
          createdAt: DateTime.now(),
        ),
        ...state.notifications,
      ],
    );
  }
}
