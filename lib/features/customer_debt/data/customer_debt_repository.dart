import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';

final customerDebtRepositoryProvider = Provider<CustomerDebtRepository>((ref) {
  return CustomerDebtRepository(SupabaseService.client);
});

class CustomerDebtRepository {
  final SupabaseClient _client;

  CustomerDebtRepository(this._client);

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

  // ── CUSTOMERS ─────────────────────────────────────────────────────────────

  /// Mengambil semua pelanggan untuk bisnis tertentu
  Future<List<Customer>> getCustomers(
    String businessId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('customers')
        .select('*')
        .eq('business_id', businessId);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or('name.ilike.%$q%,phone.ilike.%$q%');
    }

    final response = await query.order('current_debt', ascending: false).order('name', ascending: true);
    final list = response as List<dynamic>;
    return list.map((json) => Customer.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Membuat data pelanggan baru
  Future<Customer> createCustomer({
    required String businessId,
    required String name,
    required String phone,
    String? address,
    double creditLimit = 0,
    String? notes,
  }) async {
    // Standardize phone number: remove non-digits
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('62')) {
      cleanPhone = '0${cleanPhone.substring(2)}';
    }

    final data = {
      'business_id': businessId,
      'name': name.trim(),
      'phone': cleanPhone,
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'credit_limit': creditLimit,
      'current_debt': 0,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    };

    final response = await _client
        .from('customers')
        .insert(data)
        .select()
        .single();

    return Customer.fromJson(response);
  }

  /// Update data pelanggan
  Future<Customer> updateCustomer({
    required String customerId,
    required String name,
    required String phone,
    String? address,
    double creditLimit = 0,
    String? notes,
  }) async {
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('62')) {
      cleanPhone = '0${cleanPhone.substring(2)}';
    }

    final data = {
      'name': name.trim(),
      'phone': cleanPhone,
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'credit_limit': creditLimit,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('customers')
        .update(data)
        .eq('id', customerId)
        .select()
        .single();

    return Customer.fromJson(response);
  }

  /// Hapus data pelanggan
  Future<void> deleteCustomer(String customerId) async {
    // 1. Cek apakah ada kasbon aktif yang belum lunas
    final activeDebts = await _client
        .from('customer_debts')
        .select('id, remaining_amount')
        .eq('customer_id', customerId)
        .gt('remaining_amount', 0);

    if ((activeDebts as List).isNotEmpty) {
      throw Exception(
        'Pelanggan tidak dapat dihapus karena masih memiliki kasbon aktif yang belum lunas.',
      );
    }

    // 2. Bersihkan catatan kasbon lama yang sudah lunas jika ada
    await _client.from('customer_debts').delete().eq('customer_id', customerId);

    // 3. Hapus pelanggan
    await _client.from('customers').delete().eq('id', customerId);
  }

  // ── CUSTOMER DEBTS ────────────────────────────────────────────────────────

  /// Mengambil daftar piutang / kasbon
  Future<List<CustomerDebt>> getDebts(
    String businessId, {
    String? outletId,
    String? customerId,
    DebtStatus? status,
  }) async {
    var query = _client
        .from('customer_debts')
        .select('*, customers!inner(*)')
        .eq('business_id', businessId);

    if (outletId != null) {
      query = query.eq('outlet_id', outletId);
    }
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    if (status != null) {
      query = query.eq('status', status.toDbValue());
    }

    final response = await query.order('created_at', ascending: false);
    final list = response as List<dynamic>;
    return list.map((json) => CustomerDebt.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Catat Kasbon Baru (Bisa standalone atau dari order kasir)
  Future<CustomerDebt> createDebt({
    required String businessId,
    required String outletId,
    required String customerId,
    String? orderId,
    String? invoiceNumber,
    required double totalAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final data = {
      'business_id': businessId,
      'outlet_id': outletId,
      'customer_id': customerId,
      'order_id': orderId,
      'invoice_number': invoiceNumber ?? 'KASBON-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'total_amount': totalAmount,
      'remaining_amount': totalAmount,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'status': 'unpaid',
      'notes': notes,
      'created_by': userId,
    };

    final response = await _client
        .from('customer_debts')
        .insert(data)
        .select('*, customers(*)')
        .single();

    return CustomerDebt.fromJson(response);
  }

  // ── DEBT PAYMENTS ─────────────────────────────────────────────────────────

  /// Catat pembayaran cicilan / pelunasan kasbon
  Future<DebtPayment> payDebt({
    required String debtId,
    required String customerId,
    required String outletId,
    String? shiftId,
    required double amountPaid,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final data = {
      'debt_id': debtId,
      'customer_id': customerId,
      'outlet_id': outletId,
      'shift_id': shiftId,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'notes': notes,
      'received_by': userId,
    };

    final response = await _client
        .from('debt_payments')
        .insert(data)
        .select()
        .single();

    return DebtPayment.fromJson(response);
  }

  /// Mengambil riwayat cicilan untuk kasbon tertentu
  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    final response = await _client
        .from('debt_payments')
        .select()
        .eq('debt_id', debtId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => DebtPayment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil semua kasbon milik pelanggan tertentu
  Future<List<CustomerDebt>> getCustomerDebtsByCustomerId(String customerId) async {
    final response = await _client
        .from('customer_debts')
        .select('*, customers(*)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => CustomerDebt.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── WHATSAPP REMINDER ─────────────────────────────────────────────────────

  /// Format dan kirim pesan tagihan WhatsApp ke pelanggan
  Future<bool> sendWhatsAppReminder({
    required CustomerDebt debt,
    required String businessName,
    String? bankAccountDetails,
    String? customNote,
  }) async {
    final phone = debt.customerPhone ?? '';
    if (phone.isEmpty) return false;

    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }

    final customerName = debt.customerName ?? 'Pelanggan';
    final remaining = _currencyFormat.format(debt.remainingAmount);
    final total = _currencyFormat.format(debt.totalAmount);
    final invoice = debt.invoiceNumber ?? '-';
    final dueDateStr = debt.dueDate != null ? _dateFormat.format(debt.dueDate!) : '-';

    final buffer = StringBuffer();
    buffer.writeln('Halo kak *$customerName*, 🙏');
    buffer.writeln('Semoga sehat selalu.');
    buffer.writeln();
    buffer.writeln('Kami dari *$businessName* ingin menginformasikan rincian catatan kasbon belanja kakak:');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🧾 *No. Nota / Invoice:* $invoice');
    buffer.writeln('💰 *Total Belanja:* $total');
    buffer.writeln('⏳ *Sisa Tagihan:* *$remaining*');
    if (debt.dueDate != null) {
      buffer.writeln('📅 *Jatuh Tempo:* $dueDateStr');
    }
    if (debt.isOverdue) {
      final days = debt.overdueDays ?? 0;
      buffer.writeln('⚠️ _Status: Sudah melewati jatuh tempo ($days hari yang lalu)_');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (bankAccountDetails != null && bankAccountDetails.trim().isNotEmpty) {
      buffer.writeln('💳 *Pembayaran via Transfer Bank / QRIS:*');
      buffer.writeln(bankAccountDetails.trim());
      buffer.writeln();
    }

    if (customNote != null && customNote.trim().isNotEmpty) {
      buffer.writeln('💬 *Catatan:*');
      buffer.writeln(customNote.trim());
      buffer.writeln();
    }

    buffer.writeln('Jika sudah melakukan pembayaran, mohon konfirmasi kirim bukti transfer ya kak.');
    buffer.writeln('Terima kasih banyak atas kerjasamanya! 🙏😊');

    final message = buffer.toString();
    await Clipboard.setData(ClipboardData(text: message));

    // Log reminder ke debt_reminders
    try {
      await _client.from('debt_reminders').insert({
        'debt_id': debt.id,
        'sent_to_phone': cleanPhone,
        'message_content': message,
        'sent_by': _client.auth.currentUser?.id,
      });
    } catch (_) {
      // ignore logging error
    }

    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    final fallbackUri = Uri.parse('https://api.whatsapp.com/send/?phone=$cleanPhone&text=$encoded');

    try {
      if (await canLaunchUrl(waUri)) {
        return await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }
}
