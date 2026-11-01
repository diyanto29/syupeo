'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { Order, OrderItem } from '@/types/database';
import * as XLSX from 'xlsx';
import {
  Receipt,
  Search,
  Filter,
  Download,
  Calendar,
  Eye,
  X,
  CreditCard,
  Banknote,
  QrCode,
  Clock,
  User,
  ShoppingBag,
  RefreshCw,
} from 'lucide-react';

export default function MerchantTransactionsPage() {
  const { business, selectedOutletId, loading: shellLoading } = useMerchant();

  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [selectedOrder, setSelectedOrder] = useState<any | null>(null);
  const [modalItems, setModalItems] = useState<any[]>([]);
  const [loadingItems, setLoadingItems] = useState(false);

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const getPaymentMethodDisplay = (order: any) => {
    if (!order) return 'Cash';
    if (order.payment_method) return order.payment_method;
    if (order.order_payments && Array.isArray(order.order_payments) && order.order_payments.length > 0) {
      return order.order_payments
        .map((p: any) => p.method_name || p.method_type)
        .filter(Boolean)
        .join(', ');
    }
    return 'Cash';
  };

  const openOrderDetail = async (order: any) => {
    setSelectedOrder(order);
    if (order.order_items && Array.isArray(order.order_items) && order.order_items.length > 0) {
      setModalItems(order.order_items);
      return;
    }

    try {
      setLoadingItems(true);
      const supabase = createClient();
      const { data, error } = await supabase
        .from('order_items')
        .select('*')
        .eq('order_id', order.id);

      if (!error && data) {
        setModalItems(data);
      } else {
        setModalItems([]);
      }
    } catch (err) {
      console.error('Error fetching order items:', err);
      setModalItems([]);
    } finally {
      setLoadingItems(false);
    }
  };

  const closeOrderDetail = () => {
    setSelectedOrder(null);
    setModalItems([]);
  };

  const loadTransactions = async () => {
    if (!business) return;

    try {
      setLoading(true);
      const supabase = createClient();

      let query = supabase
        .from('orders')
        .select('*, order_items(*), order_payments(*), outlets(name)')
        .eq('business_id', business.id)
        .order('created_at', { ascending: false })
        .limit(100);

      if (selectedOutletId !== 'all') {
        query = query.eq('outlet_id', selectedOutletId);
      }

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      const { data, error } = await query;
      if (!error) {
        setOrders(data || []);
      }
    } catch (err) {
      console.error('Error fetching transactions:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTransactions();
  }, [business?.id, selectedOutletId, statusFilter]);

  // Export transactions to Excel
  const handleExportExcel = () => {
    if (orders.length === 0) {
      alert('Tidak ada transaksi untuk diexport.');
      return;
    }

    const exportData = orders.map((o) => ({
      'No. Invoice': o.invoice_number,
      Tanggal: new Date(o.created_at).toLocaleDateString('id-ID'),
      Jam: new Date(o.created_at).toLocaleTimeString('id-ID'),
      Outlet: (o as any).outlets?.name || 'Utama',
      Pelanggan: o.customer_name || (o.table_number ? `Meja ${o.table_number}` : 'Tamu'),
      'Metode Bayar': getPaymentMethodDisplay(o),
      Status: o.status,
      Subtotal: o.subtotal || 0,
      Diskon: o.discount_total || 0,
      'Total Akhir': o.grand_total || o.total_amount || 0,
    }));

    const worksheet = XLSX.utils.json_to_sheet(exportData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Riwayat Transaksi');

    const fileName = `Transaksi_${business?.name || 'Syupeo'}_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  };

  // Filter Search
  const filteredOrders = orders.filter((o) => {
    const s = search.toLowerCase();
    return (
      o.invoice_number.toLowerCase().includes(s) ||
      (o.customer_name && o.customer_name.toLowerCase().includes(s))
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Aktivitas Penjualan
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Riwayat Transaksi & Struk
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Daftar seluruh transaksi yang masuk dari kasir, waiter, dan toko online
          </p>
        </div>

        <button
          onClick={handleExportExcel}
          className="px-4 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors self-start sm:self-auto"
        >
          <Download className="w-4 h-4 text-purple-600" />
          <span>Export Excel</span>
        </button>
      </div>

      {/* Filter & Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        {/* Search */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari invoice atau nama pelanggan..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
          />
        </div>

        {/* Status Filter */}
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-slate-400" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full sm:w-48 text-xs font-bold py-2 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="all">Semua Status</option>
            <option value="paid">Lunas (Paid)</option>
            <option value="confirmed">Pesanan Masuk (Confirmed)</option>
            <option value="void">Dibatalkan (Void)</option>
            <option value="draft">Draft</option>
          </select>
        </div>
      </div>

      {/* Transactions Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4">Invoice</th>
                <th className="py-3 px-4">Waktu</th>
                <th className="py-3 px-4">Outlet</th>
                <th className="py-3 px-4">Pelanggan / Meja</th>
                <th className="py-3 px-4">Metode Bayar</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4 text-right">Total Akhir</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat transaksi...</span>
                  </td>
                </tr>
              ) : filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    Tidak ada transaksi ditemukan.
                  </td>
                </tr>
              ) : (
                filteredOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-3.5 px-4 font-mono font-bold text-slate-900">
                      {order.invoice_number}
                    </td>
                    <td className="py-3.5 px-4 text-slate-500 whitespace-nowrap">
                      <div>{new Date(order.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}</div>
                      <div className="text-[10px] text-slate-400">
                        {new Date(order.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-700">
                      {(order as any).outlets?.name || 'Utama'}
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-800">
                      {order.customer_name || (order.table_number ? `Meja ${order.table_number}` : 'Tamu Kasir')}
                    </td>
                    <td className="py-3.5 px-4">
                      <span className="capitalize px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 font-bold text-[10px]">
                        {getPaymentMethodDisplay(order)}
                      </span>
                    </td>
                    <td className="py-3.5 px-4">
                      <span
                        className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                          order.status === 'paid'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : order.status === 'confirmed'
                            ? 'bg-blue-50 text-blue-700 border border-blue-200'
                            : order.status === 'void'
                            ? 'bg-red-50 text-red-700 border border-red-200'
                            : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {order.status === 'paid'
                          ? 'Lunas'
                          : order.status === 'confirmed'
                          ? 'Pesanan Masuk'
                          : order.status}
                      </span>
                    </td>
                    <td className="py-3.5 px-4 text-right font-black text-slate-900">
                      {formatRupiah(order.grand_total || order.total_amount || 0)}
                    </td>
                    <td className="py-3.5 px-4 text-right">
                      <button
                        onClick={() => openOrderDetail(order)}
                        className="px-2.5 py-1 text-xs font-bold rounded-lg border border-slate-200 hover:bg-orange-50 hover:text-orange-600 hover:border-orange-200 transition-colors inline-flex items-center gap-1"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Rincian</span>
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Order Detail Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-lg p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150 max-h-[90vh] flex flex-col">
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Rincian Transaksi
                </span>
                <h3 className="font-mono font-black text-slate-900 text-base">
                  {selectedOrder.invoice_number}
                </h3>
              </div>
              <button
                onClick={closeOrderDetail}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Content */}
            <div className="flex-1 overflow-y-auto py-4 space-y-4 text-xs">
              {/* Info grid */}
              <div className="grid grid-cols-2 gap-3 p-3 bg-slate-50 rounded-xl">
                <div>
                  <span className="text-slate-400 block text-[10px]">Waktu Transaksi</span>
                  <span className="font-bold text-slate-800">
                    {new Date(selectedOrder.created_at).toLocaleString('id-ID')}
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-[10px]">Pelanggan / Meja</span>
                  <span className="font-bold text-slate-800">
                    {selectedOrder.customer_name ||
                      (selectedOrder.table_number ? `Meja ${selectedOrder.table_number}` : 'Tamu')}
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-[10px]">Metode Pembayaran</span>
                  <span className="font-bold text-slate-800 capitalize">
                    {getPaymentMethodDisplay(selectedOrder)}
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-[10px]">Status</span>
                  <span
                    className={`font-bold uppercase ${
                      selectedOrder.status === 'paid'
                        ? 'text-emerald-600'
                        : selectedOrder.status === 'confirmed'
                        ? 'text-blue-600'
                        : selectedOrder.status === 'void'
                        ? 'text-red-600'
                        : 'text-slate-600'
                    }`}
                  >
                    {selectedOrder.status === 'paid'
                      ? 'Lunas'
                      : selectedOrder.status === 'confirmed'
                      ? 'Pesanan Masuk'
                      : selectedOrder.status}
                  </span>
                </div>
                {selectedOrder.cashier_name && (
                  <div>
                    <span className="text-slate-400 block text-[10px]">Kasir</span>
                    <span className="font-bold text-slate-800">{selectedOrder.cashier_name}</span>
                  </div>
                )}
                {(selectedOrder as any).outlets?.name && (
                  <div>
                    <span className="text-slate-400 block text-[10px]">Outlet</span>
                    <span className="font-bold text-slate-800">{(selectedOrder as any).outlets?.name}</span>
                  </div>
                )}
              </div>

              {/* Catatan / Void Reason jika ada */}
              {(selectedOrder.void_reason || selectedOrder.notes) && (
                <div className="p-3 bg-amber-50 rounded-xl border border-amber-200 text-[11px] text-amber-800">
                  <span className="font-bold block mb-0.5">
                    {selectedOrder.status === 'void' ? 'Alasan Pembatalan (Void):' : 'Catatan Pesanan:'}
                  </span>
                  <span>{selectedOrder.void_reason || selectedOrder.notes}</span>
                </div>
              )}

              {/* Items List */}
              <div>
                <h4 className="font-bold text-slate-700 text-xs mb-2">Item Pesanan:</h4>
                {loadingItems ? (
                  <div className="py-6 text-center text-slate-400">
                    <RefreshCw className="w-4 h-4 animate-spin mx-auto mb-1 text-orange-500" />
                    <span>Memuat rincian item...</span>
                  </div>
                ) : modalItems.length === 0 ? (
                  <div className="py-4 text-center text-slate-400 bg-slate-50 rounded-xl">
                    Tidak ada rincian item pesanan.
                  </div>
                ) : (
                  <div className="divide-y divide-slate-100 border border-slate-100 rounded-xl overflow-hidden">
                    {modalItems.map((it, idx) => {
                      const unitPrice = Number(it.unit_price ?? it.price ?? 0);
                      const qty = Number(it.quantity || 1);
                      const itemSubtotal = Number(it.subtotal != null ? it.subtotal : unitPrice * qty);
                      const discountApplied = Number(it.discount_applied || 0);

                      return (
                        <div key={idx} className="p-3 flex items-center justify-between">
                          <div>
                            <span className="font-bold text-slate-900 block">
                              {it.name}
                              {it.variant_name ? ` (${it.variant_name})` : ''}
                            </span>
                            <div className="text-slate-400 text-[11px] flex items-center gap-1.5 flex-wrap">
                              <span>
                                {qty} x {formatRupiah(unitPrice)}
                              </span>
                              {discountApplied > 0 && (
                                <span className="text-emerald-600 font-medium">
                                  (Diskon -{formatRupiah(discountApplied)})
                                </span>
                              )}
                            </div>
                            {it.notes && (
                              <span className="text-[10px] text-slate-500 italic block mt-0.5">
                                Catatan: {it.notes}
                              </span>
                            )}
                          </div>
                          <span className="font-black text-slate-900">
                            {formatRupiah(itemSubtotal)}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Totals Calculation */}
              <div className="space-y-1.5 pt-2 border-t border-slate-100 text-slate-600">
                <div className="flex justify-between">
                  <span>Subtotal</span>
                  <span className="font-bold">{formatRupiah(selectedOrder.subtotal || selectedOrder.grand_total || 0)}</span>
                </div>
                {Number(selectedOrder.discount_total || 0) > 0 && (
                  <div className="flex justify-between text-red-600">
                    <span>Diskon</span>
                    <span className="font-bold">- {formatRupiah(selectedOrder.discount_total)}</span>
                  </div>
                )}
                {Number(selectedOrder.tax_amount || 0) > 0 && (
                  <div className="flex justify-between">
                    <span>Pajak (PB1)</span>
                    <span className="font-bold">{formatRupiah(selectedOrder.tax_amount)}</span>
                  </div>
                )}
                <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-200">
                  <span>Total Tagihan</span>
                  <span className="text-orange-600">
                    {formatRupiah(selectedOrder.grand_total || selectedOrder.total_amount || 0)}
                  </span>
                </div>

                {/* Pembayaran & Kembalian */}
                {(Number(selectedOrder.paid_amount || 0) > 0 || Number(selectedOrder.change_amount || 0) > 0) && (
                  <div className="pt-2 border-t border-dashed border-slate-200 space-y-1 text-slate-700">
                    <div className="flex justify-between">
                      <span>Total Dibayar</span>
                      <span className="font-bold">{formatRupiah(selectedOrder.paid_amount || selectedOrder.grand_total || 0)}</span>
                    </div>
                    {Number(selectedOrder.change_amount || 0) > 0 && (
                      <div className="flex justify-between text-emerald-600">
                        <span>Kembalian</span>
                        <span className="font-bold">{formatRupiah(selectedOrder.change_amount)}</span>
                      </div>
                    )}
                  </div>
                )}

                {/* Rincian Order Payments jika ada */}
                {selectedOrder.order_payments && selectedOrder.order_payments.length > 0 && (
                  <div className="pt-2 border-t border-dashed border-slate-200 space-y-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block">Rincian Pembayaran</span>
                    {selectedOrder.order_payments.map((p: any, idx: number) => (
                      <div key={idx} className="flex justify-between text-[11px] text-slate-600">
                        <span>{p.method_name || p.method_type || 'Tunai'}</span>
                        <span className="font-semibold font-mono">{formatRupiah(p.amount)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Modal Footer */}
            <div className="pt-3 border-t border-slate-100 flex justify-end">
              <button
                onClick={closeOrderDetail}
                className="px-4 py-2 text-xs font-bold rounded-xl bg-slate-900 text-white hover:bg-slate-800"
              >
                Tutup
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
