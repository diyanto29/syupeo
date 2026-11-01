'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { CashFlowEntry, CashShift } from '@/types/database';
import * as XLSX from 'xlsx';
import {
  Wallet,
  ArrowUpRight,
  ArrowDownLeft,
  Calendar,
  Filter,
  Plus,
  RefreshCw,
  Search,
  Download,
  Clock,
  User,
  AlertCircle,
  CheckCircle2,
  X,
  Layers,
  TrendingDown,
  TrendingUp,
  Eye,
  Receipt,
  CreditCard,
  ChevronDown,
  ChevronUp,
  FileText,
  Coins,
  Store,
  ShoppingBag,
} from 'lucide-react';

export default function MerchantCashFlowPage() {
  const { business, selectedOutletId, outlets } = useMerchant();

  const [activeTab, setActiveTab] = useState<'flow' | 'shifts'>('flow');
  const [entries, setEntries] = useState<CashFlowEntry[]>([]);
  const [shifts, setShifts] = useState<CashShift[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'today' | '7days' | 'this_month' | 'all'>('today');
  const [search, setSearch] = useState('');

  // Shift Detail Modal State
  const [selectedShift, setSelectedShift] = useState<CashShift | null>(null);
  const [shiftLoading, setShiftLoading] = useState(false);
  const [shiftOrders, setShiftOrders] = useState<any[]>([]);
  const [shiftEntries, setShiftEntries] = useState<CashFlowEntry[]>([]);
  const [detailTab, setDetailTab] = useState<'transactions' | 'mutations' | 'payments'>('transactions');
  const [expandedOrderId, setExpandedOrderId] = useState<string | null>(null);
  const [shiftScope, setShiftScope] = useState<'shift_only' | 'outlet_all'>('shift_only');

  // Modal Catat Kas State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    type: 'out' as 'in' | 'out',
    category: 'Belanja Bahan',
    amount: '',
    payment_source: 'cash',
    outlet_id: '',
    notes: '',
  });

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  // Helper memformat jam shift dengan penyesuaian otomatis timezone naive UTC (+7 jam)
  const formatShiftTime = (isoString?: string | null) => {
    if (!isoString) return '-';
    try {
      const d = new Date(isoString);
      if (isNaN(d.getTime())) return '-';

      // Toleransi timezone: jika jam di database lebih besar dari waktu sekarang (> now + 1 menit),
      // dipastikan ini adalah dampak naive UTC (+7 jam lebih maju dari waktu riil kasir).
      // Kita mundurkan 7 jam agar jam yang ditampilkan adalah jam riil kasir buka shift.
      let adjusted = d;
      if (d.getTime() > Date.now() + 60000) {
        adjusted = new Date(d.getTime() - 7 * 60 * 60 * 1000);
      }

      return adjusted.toLocaleString('id-ID', {
        day: 'numeric',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return String(isoString);
    }
  };

  const getStartDate = () => {
    const now = new Date();
    if (timeRange === 'today') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      return start.toISOString();
    }
    if (timeRange === '7days') {
      const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return start.toISOString();
    }
    if (timeRange === 'this_month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      return start.toISOString();
    }
    return null;
  };

  const loadData = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();
      const startDate = getStartDate();

      // Query Cash Flow Entries
      let flowQuery = supabase
        .from('cash_flow_entries')
        .select('*, outlets(name)')
        .eq('business_id', business.id)
        .order('created_at', { ascending: false });

      if (selectedOutletId !== 'all') {
        flowQuery = flowQuery.eq('outlet_id', selectedOutletId);
      }
      if (startDate) {
        flowQuery = flowQuery.gte('created_at', startDate);
      }

      const { data: flowData } = await flowQuery;
      setEntries(flowData || []);

      // Query Cash Shifts
      let shiftQuery = supabase
        .from('cash_shifts')
        .select('*, outlets(name)')
        .eq('business_id', business.id)
        .order('opened_at', { ascending: false });

      if (selectedOutletId !== 'all') {
        shiftQuery = shiftQuery.eq('outlet_id', selectedOutletId);
      }
      if (startDate) {
        shiftQuery = shiftQuery.gte('opened_at', startDate);
      }

      const { data: shiftData } = await shiftQuery;
      setShifts(shiftData || []);
    } catch (err) {
      console.error('Error fetching cash flow data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    if (outlets.length > 0 && !formData.outlet_id) {
      setFormData((prev) => ({
        ...prev,
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0].id,
      }));
    }
  }, [business?.id, selectedOutletId, timeRange]);

  // Calculations
  const totalIn = entries
    .filter((e) => e.type === 'in')
    .reduce((sum, e) => sum + Number(e.amount || 0), 0);

  const totalOut = entries
    .filter((e) => e.type === 'out')
    .reduce((sum, e) => sum + Number(e.amount || 0), 0);

  const netCash = totalIn - totalOut;

  // Handle Save Entry
  const handleSaveEntry = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    const amountNum = parseFloat(formData.amount.replace(/[^0-9]/g, ''));
    if (!amountNum || amountNum <= 0) {
      alert('Masukkan nominal yang valid.');
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();
      const targetOutlet = formData.outlet_id || (outlets.length > 0 ? outlets[0].id : null);

      const payload = {
        business_id: business.id,
        outlet_id: targetOutlet,
        type: formData.type,
        category: formData.category,
        amount: amountNum,
        payment_source: formData.payment_source,
        notes: formData.notes || null,
        cashier_name: 'Owner (Web)',
        created_at: new Date().toISOString(),
      };

      const { error } = await supabase.from('cash_flow_entries').insert([payload]);

      if (error) throw error;

      setIsModalOpen(false);
      setFormData({
        type: 'out',
        category: 'Belanja Bahan',
        amount: '',
        payment_source: 'cash',
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0]?.id || '',
        notes: '',
      });
      loadData();
    } catch (err: any) {
      console.error('Error saving cash flow entry:', err);
      alert('Gagal menyimpan arus kas: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Export Excel
  const handleExportExcel = () => {
    if (activeTab === 'flow') {
      if (entries.length === 0) {
        alert('Tidak ada data arus kas untuk diekspor.');
        return;
      }
      const data = entries.map((e) => ({
        Tanggal: new Date(e.created_at).toLocaleDateString('id-ID'),
        Jam: new Date(e.created_at).toLocaleTimeString('id-ID'),
        Outlet: (e as any).outlets?.name || 'Utama',
        Tipe: e.type === 'in' ? 'Kas Masuk' : 'Kas Keluar',
        Kategori: e.category,
        Nominal: e.amount,
        Sumber: e.payment_source,
        Pencatat: e.user_name || 'Kasir',
        Catatan: e.notes || '-',
      }));
      const ws = XLSX.utils.json_to_sheet(data);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Arus Kas');
      XLSX.writeFile(wb, `Arus_Kas_${business?.name || 'Syupeo'}_${new Date().toISOString().split('T')[0]}.xlsx`);
    } else {
      if (shifts.length === 0) {
        alert('Tidak ada data shift untuk diekspor.');
        return;
      }
      const data = shifts.map((s) => ({
        Kasir: s.cashier_name || 'Kasir',
        Outlet: (s as any).outlets?.name || 'Utama',
        'Buka Shift': formatShiftTime(s.opened_at),
        'Tutup Shift': s.closed_at ? formatShiftTime(s.closed_at) : 'Masih Buka',
        'Modal Awal': s.starting_cash || 0,
        'Kas Sistem': s.expected_cash ?? s.expected_ending_cash ?? ((s.starting_cash || 0) + (s.total_sales_cash || 0) + (s.total_cash_in || 0) - (s.total_cash_out || 0)),
        'Kas Fisik': (s.actual_cash ?? s.actual_ending_cash) || 0,
        Selisih: (s.difference_amount ?? s.difference) || 0,
        Status: s.status === 'open' ? 'Buka' : 'Ditutup',
        Catatan: s.notes || '-',
      }));
      const ws = XLSX.utils.json_to_sheet(data);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Shift Kasir');
      XLSX.writeFile(wb, `Shift_Kasir_${business?.name || 'Syupeo'}_${new Date().toISOString().split('T')[0]}.xlsx`);
    }
  };

  // Buka Modal Detail Shift & Ambil Transaksi serta Mutasi Kas
  const openShiftDetails = async (s: CashShift, scope: 'shift_only' | 'outlet_all' = 'shift_only') => {
    setSelectedShift(s);
    setShiftLoading(true);
    setShiftScope(scope);
    setDetailTab('transactions');
    setExpandedOrderId(null);

    try {
      const supabase = createClient();
      const openTime = new Date(s.opened_at).getTime();
      const closeTime = s.closed_at ? new Date(s.closed_at).getTime() : Date.now();
      const offset7h = 7 * 60 * 60 * 1000;

      // 1. Ambil order/transaksi
      // Tangani perbedaan timezone: di mobile lama, opened_at tersimpan tanpa offset UTC (naive WIB),
      // sedangkan orders.created_at selalu tersimpan dengan true UTC (Postgres timezone('utc', now())).
      // Jadi rentang waktu order sebenarnya adalah (opened_at - 7 jam) s/d (closed_at - 7 jam).
      // Sedangkan shift baru / perbaikan menggunakan true UTC langsung.
      let ordQuery = supabase
        .from('orders')
        .select('*, order_items(*), order_payments(*)')
        .eq('outlet_id', s.outlet_id);

      if (scope === 'shift_only') {
        // Coba Kueri 1: Rentang waktu dengan kompensasi naive WIB (-7 jam) dengan buffer 5 menit
        const shiftedStart = new Date(openTime - offset7h - 5 * 60 * 1000).toISOString();
        let qShifted = supabase
          .from('orders')
          .select('*, order_items(*), order_payments(*)')
          .eq('outlet_id', s.outlet_id)
          .gte('created_at', shiftedStart);

        if (s.closed_at) {
          const shiftedEnd = new Date(closeTime - offset7h + 5 * 60 * 1000).toISOString();
          qShifted = qShifted.lte('created_at', shiftedEnd);
        }

        const { data: oDataShifted, error: oErrShifted } = await qShifted.order('created_at', { ascending: false });

        if (oDataShifted && oDataShifted.length > 0) {
          setShiftOrders(oDataShifted);
        } else {
          // Coba Kueri 2: Rentang UTC normal (jika shift tersimpan dengan true UTC)
          let qUtc = supabase
            .from('orders')
            .select('*, order_items(*), order_payments(*)')
            .eq('outlet_id', s.outlet_id)
            .gte('created_at', new Date(openTime - 5 * 60 * 1000).toISOString());

          if (s.closed_at) {
            qUtc = qUtc.lte('created_at', new Date(closeTime + 5 * 60 * 1000).toISOString());
          }

          const { data: oDataUtc, error: oErrUtc } = await qUtc.order('created_at', { ascending: false });
          if (oErrUtc) console.warn('Error fetching shift orders UTC:', oErrUtc);
          setShiftOrders(oDataUtc || []);
        }
      } else {
        const { data: oDataAll, error: oErrAll } = await ordQuery.order('created_at', { ascending: false });
        if (oErrAll) console.warn('Error fetching all outlet orders:', oErrAll);
        setShiftOrders(oDataAll || []);
      }

      // 2. Ambil mutasi kas masuk dan keluar selama shift
      let entQuery = supabase
        .from('cash_flow_entries')
        .select('*')
        .eq('outlet_id', s.outlet_id);

      if (scope === 'shift_only') {
        // Cek langsung berdasarkan shift_id jika terisi
        const { data: eByShift } = await supabase
          .from('cash_flow_entries')
          .select('*')
          .eq('shift_id', s.id)
          .order('created_at', { ascending: false });

        if (eByShift && eByShift.length > 0) {
          setShiftEntries(eByShift);
        } else {
          // Coba ambil berdasarkan rentang waktu shift asli
          let qEntRaw = supabase
            .from('cash_flow_entries')
            .select('*')
            .eq('outlet_id', s.outlet_id)
            .gte('created_at', new Date(openTime - 5 * 60 * 1000).toISOString());

          if (s.closed_at) {
            qEntRaw = qEntRaw.lte('created_at', new Date(closeTime + 5 * 60 * 1000).toISOString());
          }
          const { data: eDataRaw } = await qEntRaw.order('created_at', { ascending: false });

          if (eDataRaw && eDataRaw.length > 0) {
            setShiftEntries(eDataRaw);
          } else {
            // Coba dengan rentang shifted -7 jam
            let qEntShifted = supabase
              .from('cash_flow_entries')
              .select('*')
              .eq('outlet_id', s.outlet_id)
              .gte('created_at', new Date(openTime - offset7h - 5 * 60 * 1000).toISOString());

            if (s.closed_at) {
              qEntShifted = qEntShifted.lte('created_at', new Date(closeTime - offset7h + 5 * 60 * 1000).toISOString());
            }
            const { data: eDataShifted } = await qEntShifted.order('created_at', { ascending: false });
            setShiftEntries(eDataShifted || []);
          }
        }
      } else {
        const { data: eDataAll, error: eErrAll } = await entQuery.order('created_at', { ascending: false });
        if (eErrAll) console.warn('Error fetching all outlet entries:', eErrAll);
        setShiftEntries(eDataAll || []);
      }
    } catch (err) {
      console.error('Error loading shift details:', err);
    } finally {
      setShiftLoading(false);
    }
  };

  // Export Detail Shift Ini ke Excel
  const exportSingleShiftToExcel = () => {
    if (!selectedShift) return;
    const wb = XLSX.utils.book_new();

    // Sheet 1: Transaksi Penjualan
    const ordersData = shiftOrders.map((o) => ({
      Invoice: o.invoice_number,
      Waktu: new Date(o.created_at).toLocaleString('id-ID'),
      Customer: o.customer_name || 'Pelanggan Umum',
      Metode_Bayar: o.order_payments && o.order_payments.length > 0 
        ? o.order_payments.map((p: any) => p.payment_method).join(', ')
        : o.payment_method || 'Tunai',
      Status: o.status,
      Total: Number(o.grand_total || 0),
    }));
    const wsOrders = XLSX.utils.json_to_sheet(ordersData.length > 0 ? ordersData : [{ Catatan: 'Tidak ada transaksi' }]);
    XLSX.utils.book_append_sheet(wb, wsOrders, 'Transaksi Penjualan');

    // Sheet 2: Mutasi Kas (Pengeluaran & Pemasukan)
    const mutData = shiftEntries.map((e) => ({
      Waktu: new Date(e.created_at).toLocaleString('id-ID'),
      Tipe: e.type === 'in' ? 'Kas Masuk' : 'Kas Keluar',
      Kategori: e.category,
      Nominal: Number(e.amount || 0),
      Sumber_Bayar: e.payment_source,
      Catatan: e.notes || '-',
    }));
    const wsMut = XLSX.utils.json_to_sheet(mutData.length > 0 ? mutData : [{ Catatan: 'Tidak ada mutasi kas' }]);
    XLSX.utils.book_append_sheet(wb, wsMut, 'Mutasi Kas Masuk & Keluar');

    XLSX.writeFile(
      wb,
      `Rekap_Shift_${selectedShift.cashier_name || 'Kasir'}_${new Date(selectedShift.opened_at).toISOString().split('T')[0]}.xlsx`
    );
  };

  // Perhitungan Keuangan Shift yang Dipilih
  const shiftCashSales = shiftOrders
    .filter((o) => o.status === 'paid')
    .reduce((sum, o) => {
      if (o.order_payments && o.order_payments.length > 0) {
        const cashAmt = o.order_payments
          .filter((p: any) => ['cash', 'tunai'].includes((p.payment_method || '').toLowerCase()))
          .reduce((pSum: number, p: any) => pSum + Number(p.amount || 0), 0);
        return sum + cashAmt;
      }
      const m = (o.payment_method || '').toLowerCase();
      if (m === 'cash' || m === 'tunai' || !m) {
        return sum + Number(o.grand_total || 0);
      }
      return sum;
    }, 0);

  const shiftNonCashSales = shiftOrders
    .filter((o) => o.status === 'paid')
    .reduce((sum, o) => {
      if (o.order_payments && o.order_payments.length > 0) {
        const nonCashAmt = o.order_payments
          .filter((p: any) => !['cash', 'tunai'].includes((p.payment_method || '').toLowerCase()))
          .reduce((pSum: number, p: any) => pSum + Number(p.amount || 0), 0);
        return sum + nonCashAmt;
      }
      const m = (o.payment_method || '').toLowerCase();
      if (m && m !== 'cash' && m !== 'tunai') {
        return sum + Number(o.grand_total || 0);
      }
      return sum;
    }, 0);

  const shiftTotalRevenue = shiftCashSales + shiftNonCashSales;

  const shiftTotalCashIn = shiftEntries
    .filter((e) => e.type === 'in')
    .reduce((sum, e) => sum + Number(e.amount || 0), 0);

  const shiftTotalCashOut = shiftEntries
    .filter((e) => e.type === 'out')
    .reduce((sum, e) => sum + Number(e.amount || 0), 0);

  const startingCash = selectedShift?.starting_cash || 0;
  const liveExpectedDrawerCash = startingCash + shiftCashSales + shiftTotalCashIn - shiftTotalCashOut;
  const actualDrawerCash = selectedShift?.actual_cash ?? selectedShift?.actual_ending_cash;
  const shiftDiff = actualDrawerCash != null ? actualDrawerCash - liveExpectedDrawerCash : null;

  // Breakdown pembayaran per metode
  const paymentBreakdown = {
    cash: { count: 0, total: 0 },
    qris: { count: 0, total: 0 },
    transfer: { count: 0, total: 0 },
    other: { count: 0, total: 0 },
  };

  shiftOrders.filter((o) => o.status === 'paid').forEach((o) => {
    const m = (o.payment_method || '').toLowerCase();
    const amt = Number(o.grand_total || 0);
    if (m === 'cash' || m === 'tunai' || !m) {
      paymentBreakdown.cash.count += 1;
      paymentBreakdown.cash.total += amt;
    } else if (m.includes('qris')) {
      paymentBreakdown.qris.count += 1;
      paymentBreakdown.qris.total += amt;
    } else if (m.includes('transfer') || m.includes('bank')) {
      paymentBreakdown.transfer.count += 1;
      paymentBreakdown.transfer.total += amt;
    } else {
      paymentBreakdown.other.count += 1;
      paymentBreakdown.other.total += amt;
    }
  });

  // Filtered entries
  const filteredEntries = entries.filter((e) => {
    const q = search.toLowerCase();
    return (
      e.category.toLowerCase().includes(q) ||
      (e.notes && e.notes.toLowerCase().includes(q)) ||
      (e.user_name && e.user_name.toLowerCase().includes(q))
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Manajemen Keuangan & Kas
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Arus Kas & Shift Kasir
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Pantau kas masuk, pengeluaran operasional toko, dan rekap selisih kas kasir
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
            onClick={() => setIsModalOpen(true)}
            className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Catat Kas</span>
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Kas Masuk */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Kas Masuk
            </span>
            <span className="text-xl font-black text-emerald-600">
              {formatRupiah(totalIn)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Modal tambahan & penerimaan lain
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <ArrowDownLeft className="w-5 h-5" />
          </div>
        </div>

        {/* Kas Keluar */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Kas Keluar (Biaya)
            </span>
            <span className="text-xl font-black text-rose-600">
              {formatRupiah(totalOut)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Belanja bahan & operasional
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-rose-50 text-rose-600 flex items-center justify-center flex-shrink-0">
            <ArrowUpRight className="w-5 h-5" />
          </div>
        </div>

        {/* Net Cash */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Arus Kas Bersih (Net)
            </span>
            <span className={`text-xl font-black ${netCash >= 0 ? 'text-slate-900' : 'text-rose-600'}`}>
              {formatRupiah(netCash)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Surplus / Defisit kas periode ini
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Wallet className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Filter Bar & Tabs */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        {/* Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl w-full sm:w-auto">
          <button
            onClick={() => setActiveTab('flow')}
            className={`flex-1 sm:flex-none px-4 py-1.5 text-xs font-bold rounded-lg transition-all ${
              activeTab === 'flow'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            Arus Kas (Mutasi)
          </button>
          <button
            onClick={() => setActiveTab('shifts')}
            className={`flex-1 sm:flex-none px-4 py-1.5 text-xs font-bold rounded-lg transition-all ${
              activeTab === 'shifts'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            Shift Kasir
          </button>
        </div>

        <div className="flex items-center gap-2.5 w-full sm:w-auto flex-wrap">
          {/* Search */}
          {activeTab === 'flow' && (
            <div className="relative flex-1 sm:w-64">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Cari kategori / catatan..."
                className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
              />
            </div>
          )}

          {/* Time range */}
          <select
            value={timeRange}
            onChange={(e: any) => setTimeRange(e.target.value)}
            className="text-xs font-bold py-1.5 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="today">Hari Ini</option>
            <option value="7days">7 Hari Terakhir</option>
            <option value="this_month">Bulan Ini</option>
            <option value="all">Semua Waktu</option>
          </select>
        </div>
      </div>

      {/* Main Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        {activeTab === 'flow' ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                  <th className="py-3 px-4">Waktu</th>
                  <th className="py-3 px-4">Outlet</th>
                  <th className="py-3 px-4">Tipe</th>
                  <th className="py-3 px-4">Kategori</th>
                  <th className="py-3 px-4">Sumber Kas</th>
                  <th className="py-3 px-4">Catatan</th>
                  <th className="py-3 px-4 text-right">Nominal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {loading ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                      <span>Memuat arus kas...</span>
                    </td>
                  </tr>
                ) : filteredEntries.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      Belum ada pencatatan arus kas pada periode ini.
                    </td>
                  </tr>
                ) : (
                  filteredEntries.map((item) => (
                    <tr key={item.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-3.5 px-4 text-slate-500 whitespace-nowrap">
                        <div>{new Date(item.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}</div>
                        <div className="text-[10px] text-slate-400">
                          {new Date(item.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </div>
                      </td>
                      <td className="py-3.5 px-4 font-medium text-slate-700">
                        {(item as any).outlets?.name || 'Utama'}
                      </td>
                      <td className="py-3.5 px-4">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full font-bold text-[10px] ${
                            item.type === 'in'
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : 'bg-rose-50 text-rose-700 border border-rose-200'
                          }`}
                        >
                          {item.type === 'in' ? (
                            <>
                              <ArrowDownLeft className="w-3 h-3" />
                              <span>Kas Masuk</span>
                            </>
                          ) : (
                            <>
                              <ArrowUpRight className="w-3 h-3" />
                              <span>Kas Keluar</span>
                            </>
                          )}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 font-bold text-slate-900">
                        {item.category}
                      </td>
                      <td className="py-3.5 px-4 capitalize text-slate-600">
                        {item.payment_source}
                      </td>
                      <td className="py-3.5 px-4 text-slate-500 max-w-xs truncate">
                        {item.notes || '-'}
                      </td>
                      <td
                        className={`py-3.5 px-4 text-right font-black ${
                          item.type === 'in' ? 'text-emerald-600' : 'text-rose-600'
                        }`}
                      >
                        {item.type === 'in' ? '+' : '-'} {formatRupiah(item.amount)}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                  <th className="py-3 px-4">Kasir / Shift</th>
                  <th className="py-3 px-4">Outlet</th>
                  <th className="py-3 px-4">Waktu Buka</th>
                  <th className="py-3 px-4">Waktu Tutup</th>
                  <th className="py-3 px-4 text-right">Modal Awal</th>
                  <th className="py-3 px-4 text-right">Kas Sistem</th>
                  <th className="py-3 px-4 text-right">Kas Fisik</th>
                  <th className="py-3 px-4 text-right">Selisih</th>
                  <th className="py-3 px-4 text-center">Status</th>
                  <th className="py-3 px-4 text-center">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {loading ? (
                  <tr>
                    <td colSpan={10} className="py-12 text-center text-slate-400">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                      <span>Memuat rekap shift...</span>
                    </td>
                  </tr>
                ) : shifts.length === 0 ? (
                  <tr>
                    <td colSpan={10} className="py-12 text-center text-slate-400">
                      Belum ada rekapan shift kasir pada periode ini.
                    </td>
                  </tr>
                ) : (
                  shifts.map((s) => {
                    const sysCash = s.expected_cash ?? s.expected_ending_cash ?? ((s.starting_cash || 0) + (s.total_sales_cash || 0) + (s.total_cash_in || 0) - (s.total_cash_out || 0));
                    const actCash = s.actual_cash ?? s.actual_ending_cash;
                    const diffVal = s.difference_amount ?? s.difference;

                    return (
                      <tr
                        key={s.id}
                        onClick={() => openShiftDetails(s)}
                        className="hover:bg-orange-50/40 cursor-pointer transition-colors group"
                      >
                        <td className="py-3.5 px-4 font-bold text-slate-900">
                          <div className="flex items-center gap-1.5">
                            <span className="group-hover:text-orange-600 transition-colors">{s.cashier_name || 'Kasir'}</span>
                          </div>
                          <div className="text-[10px] text-slate-400">{s.shift_name || 'Shift POS'}</div>
                        </td>
                        <td className="py-3.5 px-4 text-slate-700">
                          {(s as any).outlets?.name || 'Utama'}
                        </td>
                        <td className="py-3.5 px-4 text-slate-500">
                          {formatShiftTime(s.opened_at)}
                        </td>
                        <td className="py-3.5 px-4 text-slate-500">
                          {s.closed_at ? (
                            formatShiftTime(s.closed_at)
                          ) : (
                            <span className="text-emerald-600 font-bold flex items-center gap-1">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                              <span>Sedang Berjalan</span>
                            </span>
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-right font-medium text-slate-700">
                          {formatRupiah(s.starting_cash || 0)}
                        </td>
                        <td className="py-3.5 px-4 text-right font-bold text-slate-900">
                          {formatRupiah(sysCash)}
                        </td>
                        <td className="py-3.5 px-4 text-right font-bold text-slate-900">
                          {actCash != null ? (
                            formatRupiah(actCash)
                          ) : s.status === 'open' ? (
                            <span className="text-slate-400 font-normal italic text-[11px]">Sedang Buka</span>
                          ) : (
                            '-'
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-right font-black">
                          {diffVal != null ? (
                            <span className={diffVal === 0 ? 'text-slate-600' : diffVal > 0 ? 'text-emerald-600' : 'text-rose-600'}>
                              {diffVal > 0 ? '+' : ''}
                              {formatRupiah(diffVal)}
                            </span>
                          ) : (
                            '-'
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-center">
                          <span
                            className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                              s.status === 'open'
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                : 'bg-slate-100 text-slate-600'
                            }`}
                          >
                            {s.status === 'open' ? 'Buka' : 'Ditutup'}
                          </span>
                        </td>
                        <td className="py-3.5 px-4 text-center">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              openShiftDetails(s);
                            }}
                            className="px-2.5 py-1 text-xs font-bold rounded-lg border border-orange-200 bg-orange-50 text-orange-600 hover:bg-orange-100 flex items-center gap-1 transition-all mx-auto shadow-2xs"
                          >
                            <Eye className="w-3.5 h-3.5" />
                            <span>Detail</span>
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal Catat Kas */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Pencatatan Keuangan
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  Catat Kas Masuk / Keluar
                </h3>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveEntry} className="py-4 space-y-4 text-xs">
              {/* Tipe Kas */}
              <div>
                <label className="font-bold text-slate-700 block mb-1.5">Tipe Mutasi</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, type: 'out', category: 'Belanja Bahan' })}
                    className={`p-3 rounded-xl border flex items-center justify-center gap-2 font-bold transition-all ${
                      formData.type === 'out'
                        ? 'border-rose-500 bg-rose-50 text-rose-700'
                        : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    <ArrowUpRight className="w-4 h-4 text-rose-600" />
                    <span>Kas Keluar (Biaya)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, type: 'in', category: 'Modal Tambahan' })}
                    className={`p-3 rounded-xl border flex items-center justify-center gap-2 font-bold transition-all ${
                      formData.type === 'in'
                        ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                        : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    <ArrowDownLeft className="w-4 h-4 text-emerald-600" />
                    <span>Kas Masuk</span>
                  </button>
                </div>
              </div>

              {/* Outlet */}
              {outlets.length > 1 && (
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Outlet</label>
                  <select
                    value={formData.outlet_id}
                    onChange={(e) => setFormData({ ...formData, outlet_id: e.target.value })}
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

              {/* Kategori */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Kategori</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                >
                  {formData.type === 'out' ? (
                    <>
                      <option value="Belanja Bahan">Belanja Bahan & Stok</option>
                      <option value="Operasional Toko">Operasional Toko</option>
                      <option value="Listrik & Air">Listrik & Air</option>
                      <option value="Gaji & Bonus">Gaji & Upah Karyawan</option>
                      <option value="Kas Kecil">Kas Kecil (Petty Cash)</option>
                      <option value="Pengeluaran Lain">Pengeluaran Lainnya</option>
                    </>
                  ) : (
                    <>
                      <option value="Modal Tambahan">Modal Tambahan</option>
                      <option value="Penerimaan Kasbon">Penerimaan Pelunasan Kasbon</option>
                      <option value="Penerimaan Lain">Penerimaan Lainnya</option>
                    </>
                  )}
                </select>
              </div>

              {/* Nominal */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Nominal (Rp)</label>
                <input
                  type="text"
                  required
                  value={formData.amount}
                  onChange={(e) => {
                    const num = e.target.value.replace(/[^0-9]/g, '');
                    setFormData({ ...formData, amount: num ? Number(num).toLocaleString('id-ID') : '' });
                  }}
                  placeholder="Contoh: 50.000"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-bold text-base focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Catatan */}
              <div>
                <label className="font-bold text-slate-700 block mb-1">Catatan / Keterangan</label>
                <textarea
                  rows={2}
                  value={formData.notes}
                  onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  placeholder="Keterangan transaksi..."
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Submit Buttons */}
              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Transaksi'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Detail Shift Kasir (Rincian Penjualan, Mutasi Kas, & Transaksi Jaga) */}
      {selectedShift && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-4xl max-h-[92vh] flex flex-col shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150 overflow-hidden">
            {/* Header Modal */}
            <div className="p-4 sm:p-6 border-b border-slate-100 flex items-start justify-between bg-gradient-to-r from-orange-50/60 via-slate-50/40 to-slate-50/60">
              <div className="flex items-start gap-3">
                <div className="w-11 h-11 rounded-2xl bg-orange-600 text-white flex items-center justify-center flex-shrink-0 shadow-sm mt-0.5">
                  <Receipt className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider bg-orange-100 px-2 py-0.5 rounded-md">
                      Rincian Sesi Shift
                    </span>
                    <span
                      className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                        selectedShift.status === 'open'
                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {selectedShift.status === 'open' ? '🟢 Sedang Berjalan (Shift Buka)' : '⚪ Shift Ditutup'}
                    </span>
                  </div>
                  <h3 className="font-black text-slate-900 text-base sm:text-xl mt-1">
                    {selectedShift.cashier_name || 'Kasir'} — {(selectedShift as any).outlets?.name || 'Outlet Utama'}
                  </h3>
                  <div className="flex items-center gap-2 text-[11px] sm:text-xs text-slate-500 mt-1 flex-wrap">
                    <div className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Buka: {formatShiftTime(selectedShift.opened_at)}
                      </span>
                    </div>
                    <span>•</span>
                    <div className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Tutup:{' '}
                        {selectedShift.closed_at
                          ? formatShiftTime(selectedShift.closed_at)
                          : 'Sedang Aktif'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-1.5 flex-shrink-0">
                <button
                  onClick={exportSingleShiftToExcel}
                  title="Unduh Excel Shift Ini"
                  className="px-3 py-1.5 rounded-xl border border-slate-200 hover:bg-slate-100 text-slate-700 transition-colors flex items-center gap-1.5 text-xs font-bold shadow-2xs"
                >
                  <Download className="w-3.5 h-3.5 text-orange-600" />
                  <span className="hidden sm:inline">Export Excel</span>
                </button>
                <button
                  onClick={() => setSelectedShift(null)}
                  className="p-1.5 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Scrollable Content */}
            <div className="p-4 sm:p-6 overflow-y-auto space-y-5">
              {/* 6 Mini Financial KPI Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2.5 sm:gap-3">
                {/* Modal Awal */}
                <div className="bg-slate-50 p-3 rounded-2xl border border-slate-200/80">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                    Modal Awal
                  </span>
                  <div className="font-black text-slate-900 text-sm mt-0.5">
                    {formatRupiah(startingCash)}
                  </div>
                  <span className="text-[9px] text-slate-400 block mt-0.5">Uang kas buka shift</span>
                </div>

                {/* Penjualan Tunai */}
                <div className="bg-emerald-50/70 p-3 rounded-2xl border border-emerald-200/80">
                  <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider block">
                    Penjualan Tunai
                  </span>
                  <div className="font-black text-emerald-700 text-sm mt-0.5">
                    +{formatRupiah(shiftCashSales)}
                  </div>
                  <span className="text-[9px] text-emerald-600 block mt-0.5">Masuk ke laci kasir</span>
                </div>

                {/* Penjualan Non-Tunai */}
                <div className="bg-blue-50/70 p-3 rounded-2xl border border-blue-200/80">
                  <span className="text-[10px] font-bold text-blue-700 uppercase tracking-wider block">
                    Non-Tunai (QRIS/Trf)
                  </span>
                  <div className="font-black text-blue-700 text-sm mt-0.5">
                    {formatRupiah(shiftNonCashSales)}
                  </div>
                  <span className="text-[9px] text-blue-600 block mt-0.5">E-Wallet & Bank</span>
                </div>

                {/* Kas Masuk Lain */}
                <div className="bg-purple-50/70 p-3 rounded-2xl border border-purple-200/80">
                  <span className="text-[10px] font-bold text-purple-700 uppercase tracking-wider block">
                    Kas Masuk (+)
                  </span>
                  <div className="font-black text-purple-700 text-sm mt-0.5">
                    +{formatRupiah(shiftTotalCashIn)}
                  </div>
                  <span className="text-[9px] text-purple-600 block mt-0.5">Penerimaan lain</span>
                </div>

                {/* Kas Keluar / Biaya */}
                <div className="bg-rose-50/70 p-3 rounded-2xl border border-rose-200/80">
                  <span className="text-[10px] font-bold text-rose-700 uppercase tracking-wider block">
                    Pengeluaran (-)
                  </span>
                  <div className="font-black text-rose-700 text-sm mt-0.5">
                    -{formatRupiah(shiftTotalCashOut)}
                  </div>
                  <span className="text-[9px] text-rose-600 block mt-0.5">Biaya belanja / operasional</span>
                </div>

                {/* Kas Sistem di Laci */}
                <div className="bg-orange-50/90 p-3 rounded-2xl border border-orange-200 shadow-2xs">
                  <span className="text-[10px] font-bold text-orange-700 uppercase tracking-wider block">
                    Kas Sistem Laci
                  </span>
                  <div className="font-black text-orange-800 text-sm mt-0.5">
                    {formatRupiah(liveExpectedDrawerCash)}
                  </div>
                  <span className="text-[9px] text-orange-600 block mt-0.5">
                    {selectedShift.status === 'open' ? 'Live di laci saat ini' : 'Target rekonsiliasi'}
                  </span>
                </div>
              </div>

              {/* Rekonsiliasi Tutup Shift (Jika sudah ditutup) */}
              {selectedShift.status === 'closed' ? (
                <div className="p-4 rounded-2xl border bg-slate-50/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-slate-200 text-slate-800 flex items-center justify-center font-black flex-shrink-0">
                      <Coins className="w-5 h-5 text-slate-700" />
                    </div>
                    <div>
                      <span className="text-slate-500 font-medium">Uang Fisik Dihitung Kasir Saat Tutup:</span>
                      <div className="font-black text-slate-900 text-sm">
                        {actualDrawerCash != null ? formatRupiah(actualDrawerCash) : '-'}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 flex-wrap">
                    <div>
                      <span className="text-slate-500 font-medium">Selisih Kasir:</span>
                      <div
                        className={`font-black text-sm ${
                          shiftDiff === 0
                            ? 'text-emerald-600'
                            : (shiftDiff || 0) > 0
                            ? 'text-blue-600'
                            : 'text-rose-600'
                        }`}
                      >
                        {shiftDiff === 0
                          ? '✓ Pas (Rp 0)'
                          : `${(shiftDiff || 0) > 0 ? '+' : ''}${formatRupiah(shiftDiff || 0)} (${
                              (shiftDiff || 0) > 0 ? 'Lebih Kas' : 'Kurang Kas'
                            })`}
                      </div>
                    </div>
                    {selectedShift.notes && (
                      <div className="border-l border-slate-200 pl-3">
                        <span className="text-slate-400 block text-[10px]">Catatan Shift:</span>
                        <span className="text-slate-700 italic font-medium">"{selectedShift.notes}"</span>
                      </div>
                    )}
                  </div>
                </div>
              ) : (
                <div className="p-3.5 rounded-2xl border border-emerald-200 bg-emerald-50/60 flex items-center gap-3 text-xs">
                  <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping flex-shrink-0"></div>
                  <div className="flex-1">
                    <span className="font-bold text-emerald-800">Sesi Shift Sedang Berjalan:</span>
                    <p className="text-emerald-700 text-[11px] mt-0.5">
                      Transaksi dan pengeluaran di bawah terus diperbarui secara real-time selama kasir aktif berjaga.
                    </p>
                  </div>
                </div>
              )}

              {/* Sub-Tabs Navigation */}
              <div className="flex border-b border-slate-200 gap-4 sm:gap-6 text-xs font-bold overflow-x-auto">
                <button
                  onClick={() => setDetailTab('transactions')}
                  className={`pb-3 relative flex items-center gap-1.5 transition-colors whitespace-nowrap ${
                    detailTab === 'transactions'
                      ? 'text-orange-600 border-b-2 border-orange-600 font-black'
                      : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  <Receipt className="w-4 h-4" />
                  <span>Transaksi Penjualan</span>
                  <span className="ml-1 px-1.5 py-0.2 rounded-full text-[10px] bg-slate-100 text-slate-700">
                    {shiftOrders.length}
                  </span>
                </button>

                <button
                  onClick={() => setDetailTab('mutations')}
                  className={`pb-3 relative flex items-center gap-1.5 transition-colors whitespace-nowrap ${
                    detailTab === 'mutations'
                      ? 'text-orange-600 border-b-2 border-orange-600 font-black'
                      : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  <ArrowUpRight className="w-4 h-4 text-rose-500" />
                  <span>Pengeluaran & Kas Masuk</span>
                  <span className="ml-1 px-1.5 py-0.2 rounded-full text-[10px] bg-slate-100 text-slate-700">
                    {shiftEntries.length}
                  </span>
                </button>

                <button
                  onClick={() => setDetailTab('payments')}
                  className={`pb-3 relative flex items-center gap-1.5 transition-colors whitespace-nowrap ${
                    detailTab === 'payments'
                      ? 'text-orange-600 border-b-2 border-orange-600 font-black'
                      : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  <CreditCard className="w-4 h-4" />
                  <span>Rekap Metode Bayar</span>
                </button>
              </div>

              {/* Tab 1: Transaksi Penjualan Saat Shift Jaga */}
              {detailTab === 'transactions' && (
                <div className="space-y-3">
                  {/* Scope Switcher: Hanya Shift Ini vs Semua Riwayat Outlet */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-1.5 bg-slate-100/80 rounded-2xl">
                    <div className="flex items-center gap-1 text-xs font-bold">
                      <button
                        onClick={() => openShiftDetails(selectedShift, 'shift_only')}
                        className={`px-3 py-1.5 rounded-xl transition-all ${
                          shiftScope === 'shift_only'
                            ? 'bg-white text-orange-600 shadow-xs'
                            : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        <span>⏱️ Hanya Jam Shift Ini</span>
                      </button>
                      <button
                        onClick={() => openShiftDetails(selectedShift, 'outlet_all')}
                        className={`px-3 py-1.5 rounded-xl transition-all ${
                          shiftScope === 'outlet_all'
                            ? 'bg-white text-orange-600 shadow-xs'
                            : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        <span>🏪 Semua Riwayat Outlet Ini</span>
                      </button>
                    </div>

                    {shiftScope === 'outlet_all' ? (
                      <span className="text-[11px] text-amber-800 bg-amber-50 px-2.5 py-1 rounded-xl border border-amber-200">
                        Menampilkan seluruh riwayat invoice transaksi pada outlet ini
                      </span>
                    ) : (
                      <span className="text-[11px] text-slate-500 px-2">
                        Menyaring transaksi sejak shift dibuka
                      </span>
                    )}
                  </div>

                  {shiftLoading ? (
                    <div className="py-12 text-center text-slate-400 text-xs">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                      <span>Memuat transaksi penjualan kasir...</span>
                    </div>
                  ) : shiftOrders.length === 0 ? (
                    <div className="py-10 px-4 text-center text-slate-400 bg-slate-50 rounded-2xl border border-dashed border-slate-200">
                      <Receipt className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                      <p className="font-bold text-slate-700 text-xs sm:text-sm">
                        {shiftScope === 'shift_only'
                          ? 'Belum Ada Transaksi Selama Jam Shift Ini'
                          : 'Belum Ada Transaksi Tercatat di Outlet Ini'}
                      </p>
                      <p className="text-[11px] text-slate-400 mt-1 max-w-md mx-auto">
                        {shiftScope === 'shift_only'
                          ? `Shift ini dibuka pada ${formatShiftTime(selectedShift.opened_at)}. Belum ada transaksi baru yang di-checkout di mesin kasir sejak shift dibuka.`
                          : 'Belum ada riwayat pesanan penjualan yang tersimpan untuk outlet ini.'}
                      </p>
                      {shiftScope === 'shift_only' && (
                        <div className="mt-4 flex items-center justify-center gap-2 flex-wrap">
                          <button
                            onClick={() => openShiftDetails(selectedShift, 'outlet_all')}
                            className="inline-flex items-center gap-1.5 px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white font-bold rounded-xl text-xs transition-colors shadow-xs"
                          >
                            <Store className="w-3.5 h-3.5" />
                            <span>Lihat Semua Riwayat Transaksi Outlet Ini</span>
                          </button>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="border border-slate-200/90 rounded-2xl overflow-hidden shadow-xs">
                      <div className="overflow-x-auto">
                        <table className="w-full text-left text-xs">
                          <thead>
                            <tr className="border-b border-slate-100 bg-slate-50/80 text-slate-400 uppercase text-[10px] tracking-wider">
                              <th className="py-3 px-4">Invoice / Waktu</th>
                              <th className="py-3 px-4">Pelanggan</th>
                              <th className="py-3 px-4">Metode Bayar</th>
                              <th className="py-3 px-4">Status</th>
                              <th className="py-3 px-4 text-center">Item</th>
                              <th className="py-3 px-4 text-right">Total Transaksi</th>
                              <th className="py-3 px-4 text-center">Rincian</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100">
                            {shiftOrders.map((ord) => {
                              const isExpanded = expandedOrderId === ord.id;
                              const itemsCount = ord.order_items?.length || 0;
                              const payMethod =
                                ord.order_payments && ord.order_payments.length > 0
                                  ? ord.order_payments.map((p: any) => p.payment_method).join(', ')
                                  : ord.payment_method || 'Tunai';

                              return (
                                <tr key={ord.id} className="hover:bg-slate-50/60 transition-colors">
                                  <td className="py-3 px-4 font-mono">
                                    <div className="font-bold text-slate-900">{ord.invoice_number}</div>
                                    <div className="text-[10px] text-slate-400">
                                      {new Date(ord.created_at).toLocaleTimeString('id-ID', {
                                        hour: '2-digit',
                                        minute: '2-digit',
                                      })}{' '}
                                      WIB
                                    </div>
                                  </td>
                                  <td className="py-3 px-4 font-medium text-slate-700">
                                    {ord.customer_name || 'Pelanggan Umum'}
                                    {ord.table_number && (
                                      <span className="block text-[10px] text-slate-400">
                                        Meja #{ord.table_number}
                                      </span>
                                    )}
                                  </td>
                                  <td className="py-3 px-4">
                                    <span
                                      className={`px-2 py-0.5 rounded-md font-bold text-[10px] uppercase ${
                                        payMethod.toLowerCase().includes('cash') ||
                                        payMethod.toLowerCase().includes('tunai')
                                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                          : 'bg-blue-50 text-blue-700 border border-blue-200'
                                      }`}
                                    >
                                      {payMethod}
                                    </span>
                                  </td>
                                  <td className="py-3 px-4">
                                    <span
                                      className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                                        ord.status === 'paid'
                                          ? 'bg-emerald-50 text-emerald-700'
                                          : ord.status === 'draft'
                                          ? 'bg-amber-50 text-amber-700'
                                          : 'bg-rose-50 text-rose-700'
                                      }`}
                                    >
                                      {ord.status === 'paid' ? 'Lunas' : ord.status}
                                    </span>
                                  </td>
                                  <td className="py-3 px-4 text-center font-bold text-slate-700">
                                    {itemsCount} item
                                  </td>
                                  <td className="py-3 px-4 text-right font-black text-slate-900">
                                    {formatRupiah(ord.grand_total)}
                                  </td>
                                  <td className="py-3 px-4 text-center">
                                    <button
                                      onClick={() => setExpandedOrderId(isExpanded ? null : ord.id)}
                                      className="p-1 rounded-lg border border-slate-200 hover:bg-slate-100 text-slate-500 hover:text-slate-800 transition-colors inline-flex items-center gap-0.5 text-[11px] font-bold"
                                    >
                                      <span>{isExpanded ? 'Tutup' : 'Menu'}</span>
                                      {isExpanded ? (
                                        <ChevronUp className="w-3.5 h-3.5" />
                                      ) : (
                                        <ChevronDown className="w-3.5 h-3.5" />
                                      )}
                                    </button>
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>

                      {/* Detail Accordion Menu yang Terjual */}
                      {expandedOrderId && (
                        <div className="p-4 bg-slate-50 border-t border-slate-200 animate-in fade-in">
                          {(() => {
                            const activeOrder = shiftOrders.find((o) => o.id === expandedOrderId);
                            if (!activeOrder || !activeOrder.order_items?.length) {
                              return (
                                <p className="text-xs text-slate-400 italic">
                                  Tidak ada item menu tercatat untuk transaksi ini.
                                </p>
                              );
                            }
                            return (
                              <div>
                                <h4 className="font-bold text-slate-800 text-xs mb-2 flex items-center gap-1.5">
                                  <ShoppingBag className="w-3.5 h-3.5 text-orange-600" />
                                  <span>Daftar Menu Terjual ({activeOrder.invoice_number}):</span>
                                </h4>
                                <div className="space-y-1.5 text-xs">
                                  {activeOrder.order_items.map((it: any, idx: number) => {
                                    const unitPrice = it.unit_price ?? it.price ?? 0;
                                    const itemSubtotal = it.subtotal ?? unitPrice * it.quantity;
                                    return (
                                      <div
                                        key={it.id || idx}
                                        className="flex items-center justify-between p-2 rounded-xl bg-white border border-slate-200/80"
                                      >
                                        <div className="flex items-center gap-2">
                                          <span className="w-5 h-5 rounded-md bg-orange-100 text-orange-700 flex items-center justify-center font-bold text-[10px]">
                                            {it.quantity}x
                                          </span>
                                          <div>
                                            <span className="font-bold text-slate-800">{it.name}</span>
                                            {it.variant_name && (
                                              <span className="text-[10px] text-slate-400 block">
                                                Varian: {it.variant_name}
                                              </span>
                                            )}
                                          </div>
                                        </div>
                                        <div className="text-right font-black text-slate-900">
                                          {formatRupiah(itemSubtotal)}
                                          <span className="text-[10px] font-normal text-slate-400 block">
                                            @{formatRupiah(unitPrice)}
                                          </span>
                                        </div>
                                      </div>
                                    );
                                  })}
                                </div>
                              </div>
                            );
                          })()}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}

              {/* Tab 2: Pengeluaran & Pemasukan Kas Saat Shift */}
              {detailTab === 'mutations' && (
                <div className="space-y-3">
                  {shiftLoading ? (
                    <div className="py-12 text-center text-slate-400 text-xs">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                      <span>Memuat mutasi pengeluaran & kas masuk...</span>
                    </div>
                  ) : shiftEntries.length === 0 ? (
                    <div className="py-10 text-center text-slate-400 bg-slate-50 rounded-2xl border border-dashed border-slate-200">
                      <Wallet className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                      <p className="font-bold text-slate-600 text-xs">Tidak Ada Pengeluaran / Kas Masuk</p>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Kasir tidak mencatat mutasi pengeluaran operasional maupun kas masuk saat shift ini.
                      </p>
                    </div>
                  ) : (
                    <div className="border border-slate-200/90 rounded-2xl overflow-hidden shadow-xs">
                      <div className="overflow-x-auto">
                        <table className="w-full text-left text-xs">
                          <thead>
                            <tr className="border-b border-slate-100 bg-slate-50/80 text-slate-400 uppercase text-[10px] tracking-wider">
                              <th className="py-3 px-4">Waktu</th>
                              <th className="py-3 px-4">Tipe Mutasi</th>
                              <th className="py-3 px-4">Kategori</th>
                              <th className="py-3 px-4">Sumber Kas</th>
                              <th className="py-3 px-4">Catatan / Keterangan</th>
                              <th className="py-3 px-4 text-right">Nominal</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100">
                            {shiftEntries.map((e) => (
                              <tr key={e.id} className="hover:bg-slate-50/60 transition-colors">
                                <td className="py-3 px-4 font-mono text-slate-500">
                                  {new Date(e.created_at).toLocaleTimeString('id-ID', {
                                    hour: '2-digit',
                                    minute: '2-digit',
                                  })}{' '}
                                  WIB
                                </td>
                                <td className="py-3 px-4">
                                  <span
                                    className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full font-bold text-[10px] ${
                                      e.type === 'in'
                                        ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                        : 'bg-rose-50 text-rose-700 border border-rose-200'
                                    }`}
                                  >
                                    {e.type === 'in' ? (
                                      <>
                                        <ArrowDownLeft className="w-3 h-3" />
                                        <span>Kas Masuk</span>
                                      </>
                                    ) : (
                                      <>
                                        <ArrowUpRight className="w-3 h-3" />
                                        <span>Pengeluaran</span>
                                      </>
                                    )}
                                  </span>
                                </td>
                                <td className="py-3 px-4 font-bold text-slate-900">{e.category}</td>
                                <td className="py-3 px-4 capitalize text-slate-600">
                                  {e.payment_source === 'cash' ? 'Tunai di Laci Kasir' : e.payment_source}
                                </td>
                                <td className="py-3 px-4 text-slate-500 max-w-xs truncate">
                                  {e.notes || '-'}
                                </td>
                                <td
                                  className={`py-3 px-4 text-right font-black ${
                                    e.type === 'in' ? 'text-emerald-600' : 'text-rose-600'
                                  }`}
                                >
                                  {e.type === 'in' ? '+' : '-'} {formatRupiah(e.amount)}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Tab 3: Rekap Metode Pembayaran Shift */}
              {detailTab === 'payments' && (
                <div className="space-y-4">
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                    {/* Tunai */}
                    <div className="p-4 rounded-2xl border border-emerald-200 bg-emerald-50/50">
                      <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider block">
                        Tunai (Cash di Laci)
                      </span>
                      <div className="font-black text-emerald-700 text-lg mt-1">
                        {formatRupiah(paymentBreakdown.cash.total)}
                      </div>
                      <span className="text-[10px] text-emerald-600 block mt-1">
                        {paymentBreakdown.cash.count} Transaksi
                      </span>
                    </div>

                    {/* QRIS */}
                    <div className="p-4 rounded-2xl border border-blue-200 bg-blue-50/50">
                      <span className="text-[10px] font-bold text-blue-700 uppercase tracking-wider block">
                        QRIS (E-Wallet)
                      </span>
                      <div className="font-black text-blue-700 text-lg mt-1">
                        {formatRupiah(paymentBreakdown.qris.total)}
                      </div>
                      <span className="text-[10px] text-blue-600 block mt-1">
                        {paymentBreakdown.qris.count} Transaksi
                      </span>
                    </div>

                    {/* Transfer */}
                    <div className="p-4 rounded-2xl border border-purple-200 bg-purple-50/50">
                      <span className="text-[10px] font-bold text-purple-700 uppercase tracking-wider block">
                        Transfer Bank
                      </span>
                      <div className="font-black text-purple-700 text-lg mt-1">
                        {formatRupiah(paymentBreakdown.transfer.total)}
                      </div>
                      <span className="text-[10px] text-purple-600 block mt-1">
                        {paymentBreakdown.transfer.count} Transaksi
                      </span>
                    </div>

                    {/* Lainnya */}
                    <div className="p-4 rounded-2xl border border-slate-200 bg-slate-50">
                      <span className="text-[10px] font-bold text-slate-600 uppercase tracking-wider block">
                        Kartu Debit / Lainnya
                      </span>
                      <div className="font-black text-slate-800 text-lg mt-1">
                        {formatRupiah(paymentBreakdown.other.total)}
                      </div>
                      <span className="text-[10px] text-slate-500 block mt-1">
                        {paymentBreakdown.other.count} Transaksi
                      </span>
                    </div>
                  </div>

                  <div className="p-4 rounded-2xl bg-orange-50/70 border border-orange-200 flex items-center justify-between">
                    <div>
                      <span className="text-xs font-bold text-orange-800 block">
                        Total Seluruh Omset Penjualan Shift
                      </span>
                      <span className="text-[11px] text-orange-600">
                        Akumulasi semua transaksi berhasil saat kasir bertugas
                      </span>
                    </div>
                    <div className="text-right">
                      <span className="text-xl font-black text-orange-700">
                        {formatRupiah(shiftTotalRevenue)}
                      </span>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Footer Modal */}
            <div className="p-4 border-t border-slate-100 flex items-center justify-between bg-slate-50/80">
              <span className="text-[11px] text-slate-400">
                Shift ID: <span className="font-mono text-slate-600">{selectedShift.id}</span>
              </span>
              <button
                type="button"
                onClick={() => setSelectedShift(null)}
                className="px-5 py-2 rounded-xl bg-slate-800 hover:bg-slate-900 text-white font-bold text-xs transition-colors"
              >
                Tutup Rekapan
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
