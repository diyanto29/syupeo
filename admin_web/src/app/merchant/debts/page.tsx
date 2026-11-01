'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { CustomerDebt, Customer, DebtPayment } from '@/types/database';
import * as XLSX from 'xlsx';
import {
  BookOpen,
  Plus,
  Search,
  Filter,
  Download,
  Calendar,
  DollarSign,
  User,
  Phone,
  MessageCircle,
  CheckCircle2,
  Clock,
  AlertTriangle,
  CreditCard,
  RefreshCw,
  X,
  Eye,
  History,
} from 'lucide-react';

export default function MerchantDebtsPage() {
  const { business, selectedOutletId, outlets } = useMerchant();

  const [debts, setDebts] = useState<CustomerDebt[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('unpaid_all');
  const [search, setSearch] = useState('');

  // Modals
  const [isNewDebtOpen, setIsNewDebtOpen] = useState(false);
  const [isPaymentOpen, setIsPaymentOpen] = useState(false);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [selectedDebt, setSelectedDebt] = useState<CustomerDebt | null>(null);
  const [paymentHistory, setPaymentHistory] = useState<DebtPayment[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // New Debt Form
  const [newDebtData, setNewDebtData] = useState({
    customer_id: '',
    customer_name: '',
    customer_phone: '',
    outlet_id: '',
    total_amount: '',
    due_date: '',
    notes: '',
  });

  // Payment Form
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'transfer' | 'qris'>('cash');
  const [paymentNotes, setPaymentNotes] = useState('');

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadData = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();

      // Query Customers
      const { data: custData } = await supabase
        .from('customers')
        .select('*')
        .eq('business_id', business.id)
        .order('name');
      setCustomers(custData || []);

      // Query Debts
      let debtQuery = supabase
        .from('customer_debts')
        .select('*, customers(*), outlets(name)')
        .eq('business_id', business.id)
        .order('created_at', { ascending: false });

      if (selectedOutletId !== 'all') {
        debtQuery = debtQuery.eq('outlet_id', selectedOutletId);
      }

      if (statusFilter === 'unpaid_all') {
        debtQuery = debtQuery.in('status', ['unpaid', 'partially_paid']);
      } else if (statusFilter !== 'all') {
        debtQuery = debtQuery.eq('status', statusFilter);
      }

      const { data: debtData } = await debtQuery;
      setDebts(debtData || []);
    } catch (err) {
      console.error('Error fetching customer debts:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    if (outlets.length > 0 && !newDebtData.outlet_id) {
      setNewDebtData((prev) => ({
        ...prev,
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0].id,
      }));
    }
  }, [business?.id, selectedOutletId, statusFilter]);

  // Calculations
  const totalActiveDebt = debts
    .filter((d) => d.status !== 'paid')
    .reduce((sum, d) => sum + Number(d.remaining_amount || 0), 0);

  const totalPaidDebt = debts
    .filter((d) => d.status === 'paid')
    .reduce((sum, d) => sum + Number(d.total_amount || 0), 0);

  const activeDebtorCount = new Set(
    debts.filter((d) => d.status !== 'paid').map((d) => d.customer_id)
  ).size;

  // Handle Save New Debt
  const handleSaveNewDebt = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    const amountNum = parseFloat(newDebtData.total_amount.replace(/[^0-9]/g, ''));
    if (!amountNum || amountNum <= 0) {
      alert('Masukkan nominal kasbon yang valid.');
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();

      let targetCustomerId = newDebtData.customer_id;

      // Buat customer baru jika belum dipilih
      if (!targetCustomerId) {
        if (!newDebtData.customer_name.trim() || !newDebtData.customer_phone.trim()) {
          alert('Harap masukkan nama dan no telepon pelanggan.');
          return;
        }

        const { data: newCust, error: custErr } = await supabase
          .from('customers')
          .insert([
            {
              business_id: business.id,
              name: newDebtData.customer_name.trim(),
              phone: newDebtData.customer_phone.trim(),
              current_debt: 0,
            },
          ])
          .select()
          .single();

        if (custErr) throw custErr;
        targetCustomerId = newCust.id;
      }

      const targetOutlet = newDebtData.outlet_id || (outlets.length > 0 ? outlets[0].id : null);
      const invoiceNum = `KB-${Date.now().toString().slice(-6)}`;

      const { error: debtErr } = await supabase.from('customer_debts').insert([
        {
          business_id: business.id,
          outlet_id: targetOutlet,
          customer_id: targetCustomerId,
          invoice_number: invoiceNum,
          total_amount: amountNum,
          remaining_amount: amountNum,
          due_date: newDebtData.due_date || null,
          status: 'unpaid',
          notes: newDebtData.notes || null,
          created_at: new Date().toISOString(),
        },
      ]);

      if (debtErr) throw debtErr;

      setIsNewDebtOpen(false);
      setNewDebtData({
        customer_id: '',
        customer_name: '',
        customer_phone: '',
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0]?.id || '',
        total_amount: '',
        due_date: '',
        notes: '',
      });
      loadData();
    } catch (err: any) {
      console.error('Error recording debt:', err);
      alert('Gagal mencatat kasbon: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Open Payment Modal
  const openPaymentModal = (debt: CustomerDebt) => {
    setSelectedDebt(debt);
    setPaymentAmount(Number(debt.remaining_amount || 0).toLocaleString('id-ID'));
    setPaymentMethod('cash');
    setPaymentNotes('');
    setIsPaymentOpen(true);
  };

  // Handle Submit Payment
  const handleSavePayment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDebt || !business) return;

    const payNum = parseFloat(paymentAmount.replace(/[^0-9]/g, ''));
    if (!payNum || payNum <= 0) {
      alert('Masukkan nominal pembayaran yang valid.');
      return;
    }

    if (payNum > Number(selectedDebt.remaining_amount)) {
      alert(`Nominal pembayaran melebihi sisa hutang (${formatRupiah(selectedDebt.remaining_amount)}).`);
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();

      const newRemaining = Number(selectedDebt.remaining_amount) - payNum;
      const newStatus = newRemaining <= 0 ? 'paid' : 'partially_paid';

      // 1. Insert ke debt_payments
      const { error: payErr } = await supabase.from('debt_payments').insert([
        {
          debt_id: selectedDebt.id,
          customer_id: selectedDebt.customer_id,
          outlet_id: selectedDebt.outlet_id,
          amount_paid: payNum,
          payment_method: paymentMethod,
          notes: paymentNotes || null,
          created_at: new Date().toISOString(),
        },
      ]);
      if (payErr) throw payErr;

      // 2. Update status & sisa di customer_debts
      const { error: updateDebtErr } = await supabase
        .from('customer_debts')
        .update({
          remaining_amount: newRemaining,
          status: newStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedDebt.id);
      if (updateDebtErr) throw updateDebtErr;

      // 3. Catat juga ke cash_flow_entries jika dibayar cash
      if (paymentMethod === 'cash') {
        await supabase.from('cash_flow_entries').insert([
          {
            business_id: business.id,
            outlet_id: selectedDebt.outlet_id,
            type: 'in',
            category: 'Penerimaan Kasbon',
            amount: payNum,
            payment_source: 'cash',
            notes: `Pelunasan kasbon ${selectedDebt.customers?.name || ''} (${selectedDebt.invoice_number || ''})`,
            cashier_name: 'Owner (Web)',
            created_at: new Date().toISOString(),
          },
        ]);
      }

      setIsPaymentOpen(false);
      setSelectedDebt(null);
      loadData();
    } catch (err: any) {
      console.error('Error saving payment:', err);
      alert('Gagal menyimpan pembayaran: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // View Payment History
  const openHistoryModal = async (debt: CustomerDebt) => {
    setSelectedDebt(debt);
    setIsHistoryOpen(true);
    try {
      setLoadingHistory(true);
      const supabase = createClient();
      const { data } = await supabase
        .from('debt_payments')
        .select('*')
        .eq('debt_id', debt.id)
        .order('created_at', { ascending: false });
      setPaymentHistory(data || []);
    } catch (err) {
      console.error('Error fetching debt payments:', err);
    } finally {
      setLoadingHistory(false);
    }
  };

  // WhatsApp Reminder Link
  const sendWhatsAppReminder = (debt: CustomerDebt) => {
    const rawPhone = debt.customers?.phone || '';
    if (!rawPhone) {
      alert('Nomor telepon pelanggan tidak tercatat.');
      return;
    }

    let phone = rawPhone.replace(/[^0-9]/g, '');
    if (phone.startsWith('0')) {
      phone = '62' + phone.slice(1);
    }

    const customerName = debt.customers?.name || 'Pelanggan';
    const storeName = business?.name || 'Syupeo Toko';
    const remaining = formatRupiah(debt.remaining_amount);
    const invoice = debt.invoice_number || '-';
    const dueDate = debt.due_date ? new Date(debt.due_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }) : '-';

    const text = encodeURIComponent(
      `Halo Kak *${customerName}*,\n\nSalam dari *${storeName}* 🙏\nKami menginformasikan catatan tagihan kasbon Anda:\n` +
      `• No. Tagihan: *${invoice}*\n` +
      `• Sisa Tagihan: *${remaining}*\n` +
      (debt.due_date ? `• Jatuh Tempo: *${dueDate}*\n\n` : `\n`) +
      `Pembayaran dapat dilakukan melalui kasir atau transfer toko kami. Terima kasih banyak atas kerjasamanya! 😊`
    );

    window.open(`https://wa.me/${phone}?text=${text}`, '_blank');
  };

  // Export Excel
  const handleExportExcel = () => {
    if (debts.length === 0) {
      alert('Tidak ada data kasbon untuk diexport.');
      return;
    }
    const data = debts.map((d) => ({
      Invoice: d.invoice_number,
      Pelanggan: d.customers?.name || 'Pelanggan',
      'No. Telepon': d.customers?.phone || '-',
      Outlet: (d as any).outlets?.name || 'Utama',
      'Total Kasbon': d.total_amount,
      'Sisa Hutang': d.remaining_amount,
      'Jatuh Tempo': d.due_date ? new Date(d.due_date).toLocaleDateString('id-ID') : '-',
      Status: d.status === 'paid' ? 'Lunas' : d.status === 'partially_paid' ? 'Dicicil' : 'Belum Lunas',
      Catatan: d.notes || '-',
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Buku Kasbon');
    XLSX.writeFile(wb, `Buku_Kasbon_${business?.name || 'Syupeo'}_${new Date().toISOString().split('T')[0]}.xlsx`);
  };

  // Filtered
  const filteredDebts = debts.filter((d) => {
    const q = search.toLowerCase();
    const custName = d.customers?.name?.toLowerCase() || '';
    const custPhone = d.customers?.phone?.toLowerCase() || '';
    const inv = d.invoice_number?.toLowerCase() || '';
    return custName.includes(q) || custPhone.includes(q) || inv.includes(q);
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Buku Hutang & Piutang
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Buku Kasbon Pelanggan
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Kelola tagihan kasbon pelanggan, catat cicilan pembayaran, dan kirim pengingat tagihan WhatsApp
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <button
            onClick={handleExportExcel}
            className="px-3.5 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
          >
            <Download className="w-4 h-4 text-emerald-600" />
            <span>Export Excel</span>
          </button>
          <button
            onClick={() => setIsNewDebtOpen(true)}
            className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Catat Kasbon Baru</span>
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Total Piutang Berjalan */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Piutang Berjalan
            </span>
            <span className="text-xl font-black text-rose-600">
              {formatRupiah(totalActiveDebt)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Dana yang belum diterima dari kasbon
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-rose-50 text-rose-600 flex items-center justify-center flex-shrink-0">
            <AlertTriangle className="w-5 h-5" />
          </div>
        </div>

        {/* Pelanggan Kasbon Aktif */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Pelanggan Kasbon Aktif
            </span>
            <span className="text-xl font-black text-slate-900">
              {activeDebtorCount} <span className="text-xs font-normal text-slate-500">Orang</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Memiliki tagihan yang belum lunas
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <User className="w-5 h-5" />
          </div>
        </div>

        {/* Total Terbayar */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Kasbon Lunas
            </span>
            <span className="text-xl font-black text-emerald-600">
              {formatRupiah(totalPaidDebt)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Piutang yang sudah dilunasi
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <CheckCircle2 className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari pelanggan / invoice / nomor HP..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-slate-400" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full sm:w-56 text-xs font-bold py-2 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="unpaid_all">Belum Lunas & Dicicil (Aktif)</option>
            <option value="unpaid">Hanya Belum Lunas (Unpaid)</option>
            <option value="partially_paid">Hanya Sedang Dicicil</option>
            <option value="paid">Hanya Sudah Lunas (Paid)</option>
            <option value="all">Semua Status</option>
          </select>
        </div>
      </div>

      {/* Main Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4">Invoice / Tgl</th>
                <th className="py-3 px-4">Pelanggan</th>
                <th className="py-3 px-4">Outlet</th>
                <th className="py-3 px-4">Jatuh Tempo</th>
                <th className="py-3 px-4 text-right">Total Kasbon</th>
                <th className="py-3 px-4 text-right">Sisa Tagihan</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat data kasbon...</span>
                  </td>
                </tr>
              ) : filteredDebts.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    Tidak ada catatan kasbon yang sesuai filter.
                  </td>
                </tr>
              ) : (
                filteredDebts.map((item) => {
                  const isOverdue =
                    item.status !== 'paid' &&
                    item.due_date &&
                    new Date(item.due_date) < new Date(new Date().setHours(0, 0, 0, 0));

                  return (
                    <tr key={item.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-3.5 px-4 font-mono font-bold text-slate-900">
                        <div>{item.invoice_number || 'KB-AUTO'}</div>
                        <div className="text-[10px] font-normal text-slate-400 font-sans">
                          {new Date(item.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-800">{item.customers?.name || 'Pelanggan'}</div>
                        <div className="text-[11px] text-slate-400 flex items-center gap-1">
                          <Phone className="w-3 h-3" />
                          <span>{item.customers?.phone || '-'}</span>
                        </div>
                      </td>
                      <td className="py-3.5 px-4 text-slate-700">
                        {(item as any).outlets?.name || 'Utama'}
                      </td>
                      <td className="py-3.5 px-4">
                        {item.due_date ? (
                          <div>
                            <span className={`font-semibold ${isOverdue ? 'text-rose-600 font-bold' : 'text-slate-700'}`}>
                              {new Date(item.due_date).toLocaleDateString('id-ID', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </span>
                            {isOverdue && (
                              <span className="block text-[9px] font-bold text-rose-600 uppercase tracking-wider">
                                Lewat Tempo!
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-right font-medium text-slate-600">
                        {formatRupiah(item.total_amount)}
                      </td>
                      <td className="py-3.5 px-4 text-right font-black text-rose-600">
                        {formatRupiah(item.remaining_amount)}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                            item.status === 'paid'
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : item.status === 'partially_paid'
                              ? 'bg-blue-50 text-blue-700 border border-blue-200'
                              : 'bg-rose-50 text-rose-700 border border-rose-200'
                          }`}
                        >
                          {item.status === 'paid'
                            ? 'Lunas'
                            : item.status === 'partially_paid'
                            ? 'Dicicil'
                            : 'Belum Lunas'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Bayar Cicilan */}
                          {item.status !== 'paid' && (
                            <button
                              onClick={() => openPaymentModal(item)}
                              title="Catat Pembayaran Cicilan / Pelunasan"
                              className="px-2.5 py-1 text-xs font-bold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white transition-colors"
                            >
                              Bayar
                            </button>
                          )}

                          {/* WhatsApp Reminder */}
                          {item.status !== 'paid' && (
                            <button
                              onClick={() => sendWhatsAppReminder(item)}
                              title="Kirim Pesan WhatsApp Pengingat Tagihan"
                              className="p-1.5 rounded-lg border border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors"
                            >
                              <MessageCircle className="w-3.5 h-3.5" />
                            </button>
                          )}

                          {/* Riwayat Pembayaran */}
                          <button
                            onClick={() => openHistoryModal(item)}
                            title="Lihat Riwayat Pembayaran"
                            className="p-1.5 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-100 transition-colors"
                          >
                            <History className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Catat Kasbon Baru */}
      {isNewDebtOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Buku Kasbon
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  Catat Kasbon Baru
                </h3>
              </div>
              <button
                onClick={() => setIsNewDebtOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveNewDebt} className="py-4 space-y-4 text-xs">
              {/* Pilih Pelanggan atau Input Baru */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Pilih Pelanggan Terdaftar</label>
                <select
                  value={newDebtData.customer_id}
                  onChange={(e) => {
                    const id = e.target.value;
                    const found = customers.find((c) => c.id === id);
                    setNewDebtData({
                      ...newDebtData,
                      customer_id: id,
                      customer_name: found ? found.name : '',
                      customer_phone: found ? found.phone : '',
                    });
                  }}
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                >
                  <option value="">-- Pelanggan Baru (Input Manual) --</option>
                  {customers.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name} ({c.phone})
                    </option>
                  ))}
                </select>
              </div>

              {!newDebtData.customer_id && (
                <div className="grid grid-cols-2 gap-2 p-3 bg-slate-50 rounded-xl border border-slate-100">
                  <div>
                    <label className="font-bold text-slate-700 block mb-1">Nama Pelanggan *</label>
                    <input
                      type="text"
                      required={!newDebtData.customer_id}
                      value={newDebtData.customer_name}
                      onChange={(e) => setNewDebtData({ ...newDebtData, customer_name: e.target.value })}
                      placeholder="Contoh: Pak Budi"
                      className="w-full py-1.5 px-2.5 rounded-lg border border-slate-200 font-medium focus:outline-none focus:border-orange-500 bg-white"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-slate-700 block mb-1">No. WhatsApp *</label>
                    <input
                      type="text"
                      required={!newDebtData.customer_id}
                      value={newDebtData.customer_phone}
                      onChange={(e) => setNewDebtData({ ...newDebtData, customer_phone: e.target.value })}
                      placeholder="0812xxxx"
                      className="w-full py-1.5 px-2.5 rounded-lg border border-slate-200 font-medium focus:outline-none focus:border-orange-500 bg-white"
                    />
                  </div>
                </div>
              )}

              {/* Outlet */}
              {outlets.length > 1 && (
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Outlet</label>
                  <select
                    value={newDebtData.outlet_id}
                    onChange={(e) => setNewDebtData({ ...newDebtData, outlet_id: e.target.value })}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                  >
                    {outlets.map((o) => (
                      <option key={o.id} value={o.id}>
                        {o.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {/* Nominal Kasbon */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Total Tagihan Kasbon (Rp) *</label>
                <input
                  type="text"
                  required
                  value={newDebtData.total_amount}
                  onChange={(e) => {
                    const num = e.target.value.replace(/[^0-9]/g, '');
                    setNewDebtData({ ...newDebtData, total_amount: num ? Number(num).toLocaleString('id-ID') : '' });
                  }}
                  placeholder="Contoh: 150.000"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-bold text-base focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Jatuh Tempo */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Tanggal Jatuh Tempo (Opsional)</label>
                <input
                  type="date"
                  value={newDebtData.due_date}
                  onChange={(e) => setNewDebtData({ ...newDebtData, due_date: e.target.value })}
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Catatan */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Catatan / Keterangan</label>
                <textarea
                  rows={2}
                  value={newDebtData.notes}
                  onChange={(e) => setNewDebtData({ ...newDebtData, notes: e.target.value })}
                  placeholder="Catatan belanja / pesanan..."
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Submit Buttons */}
              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsNewDebtOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Kasbon'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Pembayaran Kasbon */}
      {isPaymentOpen && selectedDebt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-emerald-600 uppercase tracking-wider block">
                  Pelunasan Kasbon
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  Catat Pembayaran
                </h3>
              </div>
              <button
                onClick={() => setIsPaymentOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Info Pelanggan & Tagihan */}
            <div className="p-3 my-4 bg-slate-50 rounded-xl space-y-1 text-xs">
              <div className="flex justify-between">
                <span className="text-slate-400">Pelanggan:</span>
                <span className="font-bold text-slate-800">{selectedDebt.customers?.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Invoice:</span>
                <span className="font-mono font-semibold text-slate-700">{selectedDebt.invoice_number}</span>
              </div>
              <div className="flex justify-between pt-1 border-t border-slate-200">
                <span className="font-bold text-slate-700">Sisa Tagihan:</span>
                <span className="font-black text-rose-600">{formatRupiah(selectedDebt.remaining_amount)}</span>
              </div>
            </div>

            <form onSubmit={handleSavePayment} className="space-y-4 text-xs">
              {/* Nominal Pembayaran */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Nominal Pembayaran (Rp) *</label>
                <input
                  type="text"
                  required
                  value={paymentAmount}
                  onChange={(e) => {
                    const num = e.target.value.replace(/[^0-9]/g, '');
                    setPaymentAmount(num ? Number(num).toLocaleString('id-ID') : '');
                  }}
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-bold text-base text-emerald-600 focus:outline-none focus:border-emerald-500"
                />
              </div>

              {/* Metode Pembayaran */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Metode Bayar</label>
                <div className="grid grid-cols-3 gap-2">
                  {(['cash', 'transfer', 'qris'] as const).map((m) => (
                    <button
                      key={m}
                      type="button"
                      onClick={() => setPaymentMethod(m)}
                      className={`py-2 px-3 rounded-xl border text-center font-bold capitalize transition-all ${
                        paymentMethod === m
                          ? 'border-emerald-600 bg-emerald-50 text-emerald-700 shadow-xs'
                          : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                      }`}
                    >
                      {m === 'cash' ? 'Tunai' : m.toUpperCase()}
                    </button>
                  ))}
                </div>
              </div>

              {/* Catatan Pembayaran */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Catatan (Opsional)</label>
                <input
                  type="text"
                  value={paymentNotes}
                  onChange={(e) => setPaymentNotes(e.target.value)}
                  placeholder="Contoh: Titip lewat tetangga..."
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-emerald-500"
                />
              </div>

              {/* Action Buttons */}
              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsPaymentOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Pembayaran'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Riwayat Cicilan */}
      {isHistoryOpen && selectedDebt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150 flex flex-col max-h-[85vh]">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Riwayat Cicilan Kasbon
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  {selectedDebt.customers?.name} ({selectedDebt.invoice_number})
                </h3>
              </div>
              <button
                onClick={() => setIsHistoryOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto py-4 space-y-3 text-xs">
              {loadingHistory ? (
                <div className="py-8 text-center text-slate-400">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                  <span>Memuat riwayat pembayaran...</span>
                </div>
              ) : paymentHistory.length === 0 ? (
                <div className="py-6 text-center text-slate-400 bg-slate-50 rounded-xl">
                  Belum ada pembayaran yang dicatat untuk tagihan ini.
                </div>
              ) : (
                <div className="divide-y divide-slate-100 border border-slate-100 rounded-2xl overflow-hidden">
                  {paymentHistory.map((p) => (
                    <div key={p.id} className="p-3 flex items-center justify-between bg-white">
                      <div>
                        <div className="font-bold text-slate-900">
                          {formatRupiah(p.amount_paid)}
                        </div>
                        <div className="text-[10px] text-slate-400 flex items-center gap-2 mt-0.5">
                          <span>{new Date(p.created_at).toLocaleString('id-ID')}</span>
                          <span className="capitalize font-medium text-slate-600">({p.payment_method})</span>
                        </div>
                        {p.notes && <div className="text-[10px] text-slate-500 italic mt-0.5">{p.notes}</div>}
                      </div>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700">
                        Sukses
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="pt-3 border-t border-slate-100 flex justify-end">
              <button
                onClick={() => setIsHistoryOpen(false)}
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
