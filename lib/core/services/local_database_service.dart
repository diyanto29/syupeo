import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<void> initialize() async {
    await database;
    debugPrint('[LocalDB] SQLite database initialized successfully');
  }

  Future<Database> _initDatabase() async {
    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final appSupportDir = await getApplicationSupportDirectory();
      path = p.join(appSupportDir.path, 'syupeo_local.db');
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'syupeo_local.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        final batch = db.batch();

        // 1. Menu Items Table
        batch.execute('''
          CREATE TABLE local_menu_items (
            id TEXT PRIMARY KEY,
            business_id TEXT NOT NULL,
            category_id TEXT,
            name TEXT NOT NULL,
            price REAL NOT NULL DEFAULT 0,
            cost_price REAL DEFAULT 0,
            stock_quantity INTEGER DEFAULT 0,
            track_stock_quantity INTEGER DEFAULT 0,
            stock_available INTEGER DEFAULT 1,
            image_url TEXT,
            barcode TEXT,
            sku TEXT,
            unit TEXT DEFAULT 'pcs',
            is_package INTEGER DEFAULT 0,
            raw_json TEXT NOT NULL,
            updated_at TEXT
          );
        ''');
        batch.execute('CREATE INDEX idx_menu_items_business ON local_menu_items(business_id);');
        batch.execute('CREATE INDEX idx_menu_items_category ON local_menu_items(category_id);');
        batch.execute('CREATE INDEX idx_menu_items_barcode ON local_menu_items(barcode);');

        // 2. Menu Categories Table
        batch.execute('''
          CREATE TABLE local_menu_categories (
            id TEXT PRIMARY KEY,
            business_id TEXT NOT NULL,
            name TEXT NOT NULL,
            visual_index INTEGER DEFAULT 0,
            raw_json TEXT NOT NULL
          );
        ''');
        batch.execute('CREATE INDEX idx_categories_business ON local_menu_categories(business_id);');

        // 3. Orders Table
        batch.execute('''
          CREATE TABLE local_orders (
            id TEXT PRIMARY KEY,
            outlet_id TEXT NOT NULL,
            business_id TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            customer_name TEXT,
            customer_phone TEXT,
            customer_email TEXT,
            table_number INTEGER,
            status TEXT NOT NULL,
            order_source TEXT NOT NULL DEFAULT 'pos',
            notes TEXT,
            subtotal REAL NOT NULL DEFAULT 0,
            discount_total REAL NOT NULL DEFAULT 0,
            tax_amount REAL NOT NULL DEFAULT 0,
            grand_total REAL NOT NULL DEFAULT 0,
            paid_amount REAL NOT NULL DEFAULT 0,
            change_amount REAL NOT NULL DEFAULT 0,
            cashier_id TEXT,
            cashier_name TEXT,
            waiter_id TEXT,
            waiter_name TEXT,
            created_at TEXT NOT NULL,
            paid_at TEXT,
            raw_json TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            sync_error TEXT,
            synced_at TEXT
          );
        ''');
        batch.execute('CREATE INDEX idx_orders_outlet ON local_orders(outlet_id);');
        batch.execute('CREATE INDEX idx_orders_sync ON local_orders(sync_status);');
        batch.execute('CREATE INDEX idx_orders_created ON local_orders(created_at);');

        // 4. Order Items Table
        batch.execute('''
          CREATE TABLE local_order_items (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            menu_item_id TEXT,
            variant_id TEXT,
            name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            cost_price REAL DEFAULT 0,
            notes TEXT,
            raw_json TEXT NOT NULL,
            FOREIGN KEY(order_id) REFERENCES local_orders(id) ON DELETE CASCADE
          );
        ''');
        batch.execute('CREATE INDEX idx_order_items_order ON local_order_items(order_id);');

        // 5. Order Discounts Table
        batch.execute('''
          CREATE TABLE local_order_discounts (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            discount_id TEXT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            applied_amount REAL NOT NULL,
            raw_json TEXT NOT NULL,
            FOREIGN KEY(order_id) REFERENCES local_orders(id) ON DELETE CASCADE
          );
        ''');
        batch.execute('CREATE INDEX idx_order_discounts_order ON local_order_discounts(order_id);');

        // 6. Order Payments Table
        batch.execute('''
          CREATE TABLE local_order_payments (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            payment_method_id TEXT,
            method_name TEXT NOT NULL,
            method_type TEXT NOT NULL,
            amount REAL NOT NULL,
            reference_number TEXT,
            raw_json TEXT NOT NULL,
            FOREIGN KEY(order_id) REFERENCES local_orders(id) ON DELETE CASCADE
          );
        ''');
        batch.execute('CREATE INDEX idx_order_payments_order ON local_order_payments(order_id);');

        // 7. Payment Methods Table
        batch.execute('''
          CREATE TABLE local_payment_methods (
            id TEXT PRIMARY KEY,
            outlet_id TEXT NOT NULL,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            raw_json TEXT NOT NULL
          );
        ''');
        batch.execute('CREATE INDEX idx_payment_methods_outlet ON local_payment_methods(outlet_id);');

        // 8. Key-Value Storage
        batch.execute('''
          CREATE TABLE app_key_value (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        ''');

        await batch.commit();
        debugPrint('[LocalDB] Database tables created.');
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // MENU ITEMS (PRODUCTS)
  // ════════════════════════════════════════════════════════════

  Future<void> saveMenuItems(List<MenuItem> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final item in items) {
      batch.insert(
        'local_menu_items',
        {
          'id': item.id,
          'business_id': item.businessId,
          'category_id': item.categoryId,
          'name': item.name,
          'price': item.price,
          'cost_price': item.recipeCost,
          'stock_quantity': item.stockQuantity,
          'track_stock_quantity': item.trackStockQuantity ? 1 : 0,
          'stock_available': item.stockAvailable ? 1 : 0,
          'image_url': item.imageUrl,
          'barcode': item.barcode,
          'sku': item.sku,
          'unit': item.displayUnit,
          'is_package': item.isPackage ? 1 : 0,
          'raw_json': jsonEncode(item.toJson()),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<MenuItem>> getMenuItems(String businessId) async {
    final db = await database;
    final rows = await db.query(
      'local_menu_items',
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );

    return rows.map((row) {
      final json = jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
      // Override with local stock quantity if present in table
      json['stock_quantity'] = row['stock_quantity'];
      json['stock_available'] = (row['stock_available'] as int? ?? 1) == 1;
      return MenuItem.fromJson(json);
    }).toList();
  }

  Future<void> updateLocalStock(String menuItemId, num newQuantity) async {
    final db = await database;
    await db.update(
      'local_menu_items',
      {
        'stock_quantity': newQuantity,
        'stock_available': newQuantity > 0 ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [menuItemId],
    );
  }

  /// Hitung total produk lokal yang tersimpan di SQLite
  Future<int> getMenuItemCount(String businessId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM local_menu_items WHERE business_id = ?',
      [businessId],
    ));
    return count ?? 0;
  }

  /// Cari produk berdasarkan Barcode persis (0ms response)
  Future<MenuItem?> getMenuItemByBarcode(String businessId, String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'local_menu_items',
      where: 'business_id = ? AND barcode = ?',
      whereArgs: [businessId, cleanBarcode],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['raw_json'] as String) as Map<String, dynamic>;
    json['stock_quantity'] = rows.first['stock_quantity'];
    json['stock_available'] = (rows.first['stock_available'] as int? ?? 1) == 1;
    return MenuItem.fromJson(json);
  }

  /// Pencarian cepat (offline) berdasarkan Nama / Barcode / SKU dengan limit
  Future<List<MenuItem>> searchMenuItems(
    String businessId,
    String query, {
    String? categoryId,
    int limit = 100,
  }) async {
    final db = await database;
    final clean = query.trim();

    String where = 'business_id = ?';
    List<dynamic> whereArgs = [businessId];

    if (categoryId != null && categoryId.isNotEmpty) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    if (clean.isNotEmpty) {
      where += ' AND (name LIKE ? OR barcode LIKE ? OR sku LIKE ?)';
      final pattern = '%$clean%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    final rows = await db.query(
      'local_menu_items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
      limit: limit,
    );

    return rows.map((row) {
      final json = jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
      json['stock_quantity'] = row['stock_quantity'];
      json['stock_available'] = (row['stock_available'] as int? ?? 1) == 1;
      return MenuItem.fromJson(json);
    }).toList();
  }

  /// Simpan nilai konfigurasi / metadata ke app_key_value
  Future<void> setKeyValue(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_key_value',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil nilai konfigurasi / metadata dari app_key_value
  Future<String?> getKeyValue(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_key_value',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ════════════════════════════════════════════════════════════
  // MENU CATEGORIES
  // ════════════════════════════════════════════════════════════

  Future<void> saveMenuCategories(String businessId, List<MenuCatalogCategory> categories) async {
    if (categories.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final cat in categories) {
      batch.insert(
        'local_menu_categories',
        {
          'id': cat.id,
          'business_id': businessId,
          'name': cat.name,
          'visual_index': cat.visualIndex,
          'raw_json': jsonEncode(cat.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<MenuCatalogCategory>> getMenuCategories(String businessId) async {
    final db = await database;
    final rows = await db.query(
      'local_menu_categories',
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );

    return rows.map((row) {
      final json = jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
      return MenuCatalogCategory.fromJson(json);
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  // PAYMENT METHODS
  // ════════════════════════════════════════════════════════════

  Future<void> savePaymentMethods(String outletId, List<PaymentMethodOption> methods) async {
    if (methods.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final m in methods) {
      batch.insert(
        'local_payment_methods',
        {
          'id': m.id,
          'outlet_id': outletId,
          'code': m.code,
          'name': m.name,
          'type': m.type,
          'raw_json': jsonEncode({
            'id': m.id,
            'code': m.code,
            'name': m.name,
            'type': m.type,
            'provider': m.provider,
            'account_label': m.accountLabel,
            'account_number': m.accountNumber,
            'instructions': m.instructions,
            'is_active': m.isActive,
            'sort_order': m.sortOrder,
            'requires_reference': m.requiresReference,
            'allows_change': m.allowsChange,
          }),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<PaymentMethodOption>> getPaymentMethods(String outletId) async {
    final db = await database;
    final rows = await db.query(
      'local_payment_methods',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
    );

    if (rows.isEmpty) {
      // Fallback default cash
      return [
        const PaymentMethodOption(
          id: 'cash-default',
          code: 'cash',
          name: 'Tunai (Cash)',
          type: 'cash',
          isActive: true,
          sortOrder: 0,
          requiresReference: false,
          allowsChange: true,
        ),
      ];
    }

    return rows.map((r) {
      final json = jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
      return PaymentMethodOption.fromJson(json);
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  // INVOICE NUMBER GENERATOR (OFFLINE-CAPABLE)
  // ════════════════════════════════════════════════════════════

  Future<String> getNextLocalInvoiceNumber(String outletId) async {
    final db = await database;
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final key = 'inv_seq_${outletId}_$todayStr';

    final existing = await db.query(
      'app_key_value',
      where: 'key = ?',
      whereArgs: [key],
    );

    int nextSeq = 1;
    if (existing.isNotEmpty) {
      nextSeq = (int.tryParse(existing.first['value'] as String) ?? 0) + 1;
    } else {
      // Periksa transaksi lokal hari ini yang sudah ada
      final rows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM local_orders
        WHERE outlet_id = ? AND invoice_number LIKE ?
      ''', [outletId, 'INV-$todayStr-%']);
      final cnt = Sqflite.firstIntValue(rows) ?? 0;
      nextSeq = cnt + 1;
    }

    await db.insert(
      'app_key_value',
      {'key': key, 'value': nextSeq.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final paddedSeq = nextSeq.toString().padLeft(4, '0');
    return 'INV-$todayStr-$paddedSeq';
  }

  // ════════════════════════════════════════════════════════════
  // TRANSACTIONS / ORDERS
  // ════════════════════════════════════════════════════════════

  Future<void> saveLocalOrder(
    TransactionOrder order, {
    required List<TransactionItem> items,
    required List<TransactionDiscount> discounts,
    List<TransactionPayment>? payments,
    String syncStatus = 'pending',
    String? syncError,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Insert order
      await txn.insert(
        'local_orders',
        {
          'id': order.id,
          'outlet_id': order.outletId,
          'business_id': order.businessId,
          'invoice_number': order.invoiceNumber,
          'customer_name': order.customerName,
          'customer_phone': order.customerPhone,
          'customer_email': order.customerEmail,
          'table_number': order.tableNumber,
          'status': order.status.dbValue,
          'order_source': order.orderSource.dbValue,
          'notes': order.notes,
          'subtotal': order.subtotal,
          'discount_total': order.discountTotal,
          'tax_amount': order.taxAmount,
          'grand_total': order.grandTotal,
          'paid_amount': order.paidAmount,
          'change_amount': order.changeAmount,
          'cashier_id': order.cashierId,
          'cashier_name': order.cashierName,
          'waiter_id': order.waiterId,
          'waiter_name': order.waiterName,
          'created_at': (order.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
          'paid_at': order.paidAt?.toIso8601String(),
          'raw_json': jsonEncode(order.toOrderJson()),
          'sync_status': syncStatus,
          'sync_error': syncError,
          'synced_at': syncStatus == 'synced' ? DateTime.now().toIso8601String() : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Clean items & re-insert
      await txn.delete('local_order_items', where: 'order_id = ?', whereArgs: [order.id]);
      for (final item in items) {
        await txn.insert(
          'local_order_items',
          {
            'id': item.id,
            'order_id': order.id,
            'menu_item_id': item.menuItemId,
            'variant_id': item.variantId,
            'name': item.name,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'cost_price': item.costPrice,
            'notes': item.notes,
            'raw_json': jsonEncode(item.toJson(order.id)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. Discounts
      await txn.delete('local_order_discounts', where: 'order_id = ?', whereArgs: [order.id]);
      for (final disc in discounts) {
        await txn.insert(
          'local_order_discounts',
          {
            'id': disc.id,
            'order_id': order.id,
            'discount_id': disc.discountId,
            'name': disc.name,
            'type': disc.type.dbValue,
            'applied_amount': disc.appliedAmount,
            'raw_json': jsonEncode(disc.toJson(order.id)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. Payments
      await txn.delete('local_order_payments', where: 'order_id = ?', whereArgs: [order.id]);
      if (payments != null) {
        for (final pay in payments) {
          await txn.insert(
            'local_order_payments',
            {
              'id': pay.id,
              'order_id': order.id,
              'payment_method_id': pay.paymentMethodId,
              'method_name': pay.methodName,
              'method_type': pay.methodType,
              'amount': pay.amount,
              'reference_number': pay.referenceNumber,
              'raw_json': jsonEncode(pay.toJson(order.id)),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    debugPrint('[LocalDB] Order ${order.invoiceNumber} saved locally (status: $syncStatus)');
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;
    final orderRows = await db.query(
      'local_orders',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );

    final result = <Map<String, dynamic>>[];
    for (final orderRow in orderRows) {
      final orderId = orderRow['id'] as String;

      final itemRows = await db.query(
        'local_order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final discountRows = await db.query(
        'local_order_discounts',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final paymentRows = await db.query(
        'local_order_payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final rawOrderMap = jsonDecode(orderRow['raw_json'] as String) as Map<String, dynamic>;
      if (!rawOrderMap.containsKey('created_at') || rawOrderMap['created_at'] == null) {
        rawOrderMap['created_at'] = orderRow['created_at'];
      }

      result.add({
        'order': rawOrderMap,
        'items': itemRows.map((r) => jsonDecode(r['raw_json'] as String)).toList(),
        'discounts': discountRows.map((r) => jsonDecode(r['raw_json'] as String)).toList(),
        'payments': paymentRows.map((r) => jsonDecode(r['raw_json'] as String)).toList(),
      });
    }

    return result;
  }

  /// Mengambil transaksi lokal SQLite dalam sesi shift (tersedia instan meski offline atau belum tersinkronisasi)
  Future<List<TransactionOrder>> getLocalOrdersForShift({
    required String outletId,
    required DateTime openedAt,
    DateTime? closedAt,
  }) async {
    final db = await database;
    final orderRows = await db.query(
      'local_orders',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
      orderBy: 'created_at DESC',
      limit: 300,
    );

    final safeOpenedAt = sanitizeShiftTime(openedAt);
    final safeClosedAt = closedAt != null ? sanitizeShiftTime(closedAt) : null;

    // Buffer 5 menit ke belakang untuk toleransi waktu pencatatan
    final fromUtc = safeOpenedAt.toUtc().subtract(const Duration(minutes: 5));
    final toUtc = (safeClosedAt ?? DateTime.now()).toUtc().add(const Duration(minutes: 5));

    final orders = <TransactionOrder>[];
    for (final orderRow in orderRows) {
      final orderId = orderRow['id'] as String;
      final rawOrder = jsonDecode(orderRow['raw_json'] as String) as Map<String, dynamic>;

      // Validasi rentang waktu secara independen dari zona waktu (UTC vs lokal)
      final createdAtRaw = rawOrder['created_at']?.toString() ?? orderRow['created_at']?.toString();
      if (createdAtRaw != null) {
        final dt = DateTime.tryParse(createdAtRaw);
        if (dt != null) {
          DateTime orderUtc = dt.toUtc();
          // Cek jika order tersimpan dengan clock lokal masa depan
          if (orderUtc.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) {
            orderUtc = orderUtc.subtract(DateTime.now().timeZoneOffset);
          }
          if (orderUtc.isBefore(fromUtc) || orderUtc.isAfter(toUtc)) {
            continue; // Di luar jendela waktu shift ini
          }
        }
      }

      final itemRows = await db.query('local_order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final discountRows = await db.query('local_order_discounts', where: 'order_id = ?', whereArgs: [orderId]);
      final paymentRows = await db.query('local_order_payments', where: 'order_id = ?', whereArgs: [orderId]);

      final fullJson = Map<String, dynamic>.from(rawOrder);
      if (!fullJson.containsKey('created_at') || fullJson['created_at'] == null) {
        fullJson['created_at'] = orderRow['created_at'];
      }
      fullJson['order_items'] = itemRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();
      fullJson['order_discounts'] = discountRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();
      fullJson['order_payments'] = paymentRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();

      try {
        orders.add(TransactionOrder.fromJson(fullJson));
      } catch (e) {
        debugPrint('[LocalDB] Error parsing order $orderId: $e');
      }
    }
    return orders;
  }

  /// Mengambil semua transaksi lokal SQLite untuk riwayat transaksi offline
  Future<List<TransactionOrder>> getAllLocalOrders({
    required String outletId,
    int limit = 50,
    int offset = 0,
    String? searchQuery,
    String? status,
  }) async {
    final db = await database;
    var whereClause = 'outlet_id = ?';
    final whereArgs = <dynamic>[outletId];

    if (status != null && status.isNotEmpty) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (invoice_number LIKE ? OR customer_name LIKE ?)';
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final orderRows = await db.query(
      'local_orders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final orders = <TransactionOrder>[];
    for (final orderRow in orderRows) {
      final orderId = orderRow['id'] as String;
      final rawOrder = jsonDecode(orderRow['raw_json'] as String) as Map<String, dynamic>;

      final itemRows = await db.query('local_order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final discountRows = await db.query('local_order_discounts', where: 'order_id = ?', whereArgs: [orderId]);
      final paymentRows = await db.query('local_order_payments', where: 'order_id = ?', whereArgs: [orderId]);

      final fullJson = Map<String, dynamic>.from(rawOrder);
      fullJson['order_items'] = itemRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();
      fullJson['order_discounts'] = discountRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();
      fullJson['order_payments'] = paymentRows.map((r) => jsonDecode(r['raw_json'] as String)).toList();

      try {
        orders.add(TransactionOrder.fromJson(fullJson));
      } catch (e) {
        debugPrint('[LocalDB] Error parsing local order: $e');
      }
    }
    return orders;
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM local_orders
      WHERE sync_status = 'pending' OR sync_status = 'failed'
    '''));
    return count ?? 0;
  }

  Future<void> markOrderSynced(String orderId) async {
    final db = await database;
    await db.update(
      'local_orders',
      {
        'sync_status': 'synced',
        'sync_error': null,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> markOrderSyncFailed(String orderId, String error) async {
    final db = await database;
    await db.update(
      'local_orders',
      {
        'sync_status': 'failed',
        'sync_error': error,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
