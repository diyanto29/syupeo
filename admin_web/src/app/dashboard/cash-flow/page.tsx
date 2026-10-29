'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { CashShift, CashFlowEntry, Business } from '@/types/database';
import {
  Wallet,
  Clock,
  ArrowDownRight,
  ArrowUpRight,
  AlertTriangle,
  CheckCircle2,
  Search,
  Filter,
  RefreshCw,
  Building2,
  Calendar,
  X,
  Layers,
  FileSpreadsheet,
  ChevronRight,
  Receipt,
  UserCheck,
} from 'lucide-react';

export default function CashFlowPage() {
  const [shifts, setShifts] = useState<CashShift[]>([]);
  const [entries, setEntries] = useState<CashFlowEntry[]>([]);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // Filter States
  const [activeTab, setActiveTab] = useState<'shifts' | 'entries'>('shifts');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [businessFilter, setBusinessFilter] = useState<string>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'open' | 'closed'>('all');
  const [entryTypeFilter, setEntryTypeFilter] = useState<'all' | 'in' | 'out'>('all');
  const [timeFilter, setTimeFilter] = useState<'today' | '7days' | '30days' | 'all'>('7days');

  // Modal State
  const [selectedShift, setSelectedShift] = useState<CashShift | null>(null);

  const supabase = createClient();

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // 1. Fetch businesses for filter dropdown
      const { data: bizData } = await supabase
        .from('businesses')
        .select('id, name')
        .order('name', { ascending: true });

      if (bizData) setBusinesses(bizData as Business[]);

      // 2. Fetch cash shifts with join
      let shiftsQuery = supabase
        .from('cash_shifts')
        .select(`
          *,
          businesses (id, name),
          outlets (id, name)
        `)
        .order('opened_at', { ascending: false });

      if (businessFilter !== 'all') {
        shiftsQuery = shiftsQuery.eq('business_id', businessFilter);
      }
      if (statusFilter !== 'all') {
        shiftsQuery = shiftsQuery.eq('status', statusFilter);
      }

      // Time filter for shifts
      const now = new Date();
      if (timeFilter === 'today') {
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
        shiftsQuery = shiftsQuery.gte('opened_at', startOfDay);
      } else if (timeFilter === '7days') {
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
        shiftsQuery = shiftsQuery.gte('opened_at', sevenDaysAgo);
      } else if (timeFilter === '30days') {
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
        shiftsQuery = shiftsQuery.gte('opened_at', thirtyDaysAgo);
      }

      const { data: shiftData, error: shiftError } = await shiftsQuery.limit(100);
      if (!shiftError && shiftData) {
        setShifts(shiftData as CashShift[]);
      }

      // 3. Fetch cash flow entries with join
      let entriesQuery = supabase
        .from('cash_flow_entries')
        .select(`
          *,
          businesses (id, name),
          outlets (id, name)
        `)
        .order('created_at', { ascending: false });

      if (businessFilter !== 'all') {
        entriesQuery = entriesQuery.eq('business_id', businessFilter);
      }
      if (entryTypeFilter !== 'all') {
        entriesQuery = entriesQuery.eq('type', entryTypeFilter);
      }

      if (timeFilter === 'today') {
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
        entriesQuery = entriesQuery.gte('created_at', startOfDay);
      } else if (timeFilter === '7days') {
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
        entriesQuery = entriesQuery.gte('created_at', sevenDaysAgo);
      } else if (timeFilter === '30days') {
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
        entriesQuery = entriesQuery.gte('created_at', thirtyDaysAgo);
      }

      const { data: entryData, error: entryError } = await entriesQuery.limit(150);
      if (!entryError && entryData) {
        setEntries(entryData as CashFlowEntry[]);
      }
    } catch (err) {
      console.error('Error fetching cash flow data:', err);
    } finally {
      setLoading(false);
    }
  }, [supabase, businessFilter, statusFilter, entryTypeFilter, timeFilter]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Currency Formatter
  const formatRupiah = (val?: number | null) => {
    if (val === undefined || val === null) return 'Rp 0';
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val);
  };

  // Date Formatter
  const formatDate = (dateString?: string | null) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleString('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Calculate Metrics
  const metrics = useMemo(() => {
    const openShiftsCount = shifts.filter((s) => s.status === 'open').length;
    const totalCashIn = entries
      .filter((e) => e.type === 'in')
      .reduce((sum, e) => sum + (e.amount || 0), 0);
    const totalCashOut = entries
      .filter((e) => e.type === 'out')
      .reduce((sum, e) => sum + (e.amount || 0), 0);
    const totalDiscrepancy = shifts
      .filter((s) => s.status === 'closed' && s.difference !== null)
      .reduce((sum, s) => sum + (s.difference || 0), 0);
    const discrepancyShiftCount = shifts.filter(
      (s) => s.status === 'closed' && (s.difference || 0) < 0
    ).length;

    return {
      openShiftsCount,
      totalCashIn,
      totalCashOut,
      totalDiscrepancy,
      discrepancyShiftCount,
    };
  }, [shifts, entries]);

  // Filtered Lists by Search Query
  const filteredShifts = useMemo(() => {
    if (!searchQuery.trim()) return shifts;
    const q = searchQuery.toLowerCase();
    return shifts.filter(
      (s) =>
        s.cashier_name?.toLowerCase().includes(q) ||
        s.shift_name?.toLowerCase().includes(q) ||
        s.businesses?.name?.toLowerCase().includes(q) ||
        s.outlets?.name?.toLowerCase().includes(q) ||
        s.notes?.toLowerCase().includes(q)
    );
  }, [shifts, searchQuery]);

  const filteredEntries = useMemo(() => {
    if (!searchQuery.trim()) return entries;
    const q = searchQuery.toLowerCase();
    return entries.filter(
      (e) =>
        e.category?.toLowerCase().includes(q) ||
        e.user_name?.toLowerCase().includes(q) ||
        e.notes?.toLowerCase().includes(q) ||
        e.businesses?.name?.toLowerCase().includes(q) ||
        e.outlets?.name?.toLowerCase().includes(q)
    );
  }, [entries, searchQuery]);

  // Related entries for selected shift modal
  const shiftEntries = useMemo(() => {
    if (!selectedShift) return [];
    return entries.filter((e) => e.shift_id === selectedShift.id);
  }, [selectedShift, entries]);

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Arus Kas & Shift Kasir"
        description="Monitoring rekonsiliasi kas laci kasir, mutasi kas kecil, pengeluaran operasional, dan audit selisih kas fisik"
      />

      {/* KPI Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-5">
        {/* Active Open Shifts */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Shift Kasir Aktif
            </p>
            <div className="flex items-center gap-2 mt-2">
              <span className="text-2xl font-bold text-slate-900">
                {metrics.openShiftsCount}
              </span>
              <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                Live Laci
              </span>
            </div>
            <p className="text-xs text-slate-500 mt-1">Laci kasir sedang beroperasi</p>
          </div>
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
            <Clock className="w-6 h-6" />
          </div>
        </div>

        {/* Total Cash In */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Total Kas Masuk
            </p>
            <p className="text-2xl font-bold text-emerald-600 mt-2">
              {formatRupiah(metrics.totalCashIn)}
            </p>
            <p className="text-xs text-slate-500 mt-1">Modal tambahan / uang masuk</p>
          </div>
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
            <ArrowDownRight className="w-6 h-6" />
          </div>
        </div>

        {/* Total Cash Out */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Total Kas Keluar (Beban)
            </p>
            <p className="text-2xl font-bold text-rose-600 mt-2">
              {formatRupiah(metrics.totalCashOut)}
            </p>
            <p className="text-xs text-slate-500 mt-1">Petty cash & biaya operasional</p>
          </div>
          <div className="w-12 h-12 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center">
            <ArrowUpRight className="w-6 h-6" />
          </div>
        </div>

        {/* Total Discrepancy */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Audit Selisih Laci
            </p>
            <p
              className={`text-2xl font-bold mt-2 ${
                metrics.totalDiscrepancy < 0
                  ? 'text-rose-600'
                  : metrics.totalDiscrepancy > 0
                  ? 'text-emerald-600'
                  : 'text-slate-700'
              }`}
            >
              {metrics.totalDiscrepancy > 0 ? '+' : ''}
              {formatRupiah(metrics.totalDiscrepancy)}
            </p>
            <p className="text-xs text-slate-500 mt-1">
              {metrics.discrepancyShiftCount > 0
                ? `${metrics.discrepancyShiftCount} shift ada selisih minus`
                : 'Semua rekonsiliasi seimbang'}
            </p>
          </div>
          <div
            className={`w-12 h-12 rounded-xl flex items-center justify-center ${
              metrics.totalDiscrepancy < 0
                ? 'bg-rose-50 text-rose-600'
                : 'bg-slate-100 text-slate-600'
            }`}
          >
            {metrics.totalDiscrepancy < 0 ? (
              <AlertTriangle className="w-6 h-6" />
            ) : (
              <CheckCircle2 className="w-6 h-6" />
            )}
          </div>
        </div>
      </div>

      {/* Info Card: Sinkronisasi Arus Kas & Laba Bersih */}
      <div className="p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-orange-500/10 via-amber-500/10 to-emerald-500/10 border border-orange-200/80 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-start gap-3.5">
          <div className="w-10 h-10 rounded-xl bg-orange-500 text-white flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-sm">
            💡
          </div>
          <div>
            <h3 className="text-sm font-bold text-slate-900">
              Sinkronisasi Arus Kas Kasir dengan Laba Bersih Toko
            </h3>
            <p className="text-xs text-slate-600 mt-0.5 leading-relaxed">
              Setiap <strong>Kas Keluar</strong> yang dicatat kasir untuk belanja operasional (es batu, gas, bensin, konsumsi) otomatis <strong>mengurangi Laba Bersih</strong> secara real-time pada Dashboard dan Laporan Keuangan Toko.
            </p>
          </div>
        </div>
        <a
          href="https://pos.mudahkan.online/panduan#bab-11"
          target="_blank"
          rel="noopener noreferrer"
          className="px-4 py-2 bg-orange-600 hover:bg-orange-500 text-white rounded-xl text-xs font-bold shadow-sm transition-all whitespace-nowrap self-end md:self-auto flex items-center gap-1.5"
        >
          <span>Pelajari Panduan HPP & Laba</span>
          <span>↗</span>
        </a>
      </div>

      {/* Main Section Card */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
        {/* Navigation Tabs & Toolbar */}
        <div className="p-5 border-b border-slate-100 flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4 bg-slate-50/50">
          {/* Tabs */}
          <div className="flex items-center gap-1 p-1 bg-slate-200/60 rounded-xl w-fit">
            <button
              onClick={() => setActiveTab('shifts')}
              className={`flex items-center gap-2 px-4 py-2 text-xs font-bold rounded-lg transition-all ${
                activeTab === 'shifts'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <Clock className="w-3.5 h-3.5" />
              Shift Kasir & Drawer ({filteredShifts.length})
            </button>
            <button
              onClick={() => setActiveTab('entries')}
              className={`flex items-center gap-2 px-4 py-2 text-xs font-bold rounded-lg transition-all ${
                activeTab === 'entries'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <Wallet className="w-3.5 h-3.5" />
              Mutasi Kas Masuk / Keluar ({filteredEntries.length})
            </button>
          </div>

          {/* Filters & Search */}
          <div className="flex flex-wrap items-center gap-3">
            {/* Search */}
            <div className="relative min-w-[220px]">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder={
                  activeTab === 'shifts'
                    ? 'Cari kasir, outlet, bisnis...'
                    : 'Cari kategori, catatan, kasir...'
                }
                className="w-full pl-9 pr-3 py-2 text-xs rounded-xl border border-slate-200 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all"
              />
            </div>

            {/* Business Dropdown */}
            <select
              value={businessFilter}
              onChange={(e) => setBusinessFilter(e.target.value)}
              className="px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            >
              <option value="all">Semua Bisnis</option>
              {businesses.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
            </select>

            {/* Time Filter */}
            <select
              value={timeFilter}
              onChange={(e) => setTimeFilter(e.target.value as any)}
              className="px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            >
              <option value="today">Hari Ini</option>
              <option value="7days">7 Hari Terakhir</option>
              <option value="30days">30 Hari Terakhir</option>
              <option value="all">Semua Periode</option>
            </select>

            {/* Shift Status Filter */}
            {activeTab === 'shifts' && (
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as any)}
                className="px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
              >
                <option value="all">Semua Status</option>
                <option value="open">Sedang Berjalan (Open)</option>
                <option value="closed">Sudah Tutup (Closed)</option>
              </select>
            )}

            {/* Entry Type Filter */}
            {activeTab === 'entries' && (
              <select
                value={entryTypeFilter}
                onChange={(e) => setEntryTypeFilter(e.target.value as any)}
                className="px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
              >
                <option value="all">Semua Tipe Mutasi</option>
                <option value="in">Kas Masuk Saja</option>
                <option value="out">Kas Keluar Saja</option>
              </select>
            )}

            {/* Refresh */}
            <button
              onClick={fetchData}
              disabled={loading}
              className="p-2 rounded-xl border border-slate-200 hover:bg-slate-100 text-slate-600 transition-colors disabled:opacity-50"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {/* Tab 1: Shift Kasir Table */}
        {activeTab === 'shifts' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider bg-slate-50/50">
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4">Bisnis / Outlet</th>
                  <th className="py-3.5 px-4">Kasir & Shift</th>
                  <th className="py-3.5 px-4">Waktu Buka / Tutup</th>
                  <th className="py-3.5 px-4 text-right">Kas Awal</th>
                  <th className="py-3.5 px-4 text-right">Kas Akhir Fisik</th>
                  <th className="py-3.5 px-4 text-right">Sistem (Expected)</th>
                  <th className="py-3.5 px-4 text-right">Selisih</th>
                  <th className="py-3.5 px-4 text-center">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {loading ? (
                  <tr>
                    <td colSpan={9} className="py-12 text-center text-slate-400">
                      <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-blue-500" />
                      Memuat data shift kasir...
                    </td>
                  </tr>
                ) : filteredShifts.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-12 text-center text-slate-400">
                      Tidak ada data shift yang cocok dengan filter.
                    </td>
                  </tr>
                ) : (
                  filteredShifts.map((shift) => {
                    const diff = shift.difference ?? 0;
                    const isMinus = diff < 0;
                    const isPlus = diff > 0;

                    return (
                      <tr
                        key={shift.id}
                        onClick={() => setSelectedShift(shift)}
                        className="hover:bg-slate-50/80 transition-colors cursor-pointer group"
                      >
                        <td className="py-3.5 px-4 whitespace-nowrap">
                          {shift.status === 'open' ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                              BERJALAN
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 text-slate-700">
                              TUTUP
                            </span>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <p className="font-semibold text-slate-900">
                            {shift.businesses?.name || 'Toko'}
                          </p>
                          <p className="text-[11px] text-slate-500">
                            {shift.outlets?.name || 'Outlet Utama'}
                          </p>
                        </td>
                        <td className="py-3.5 px-4">
                          <p className="font-semibold text-slate-800">
                            {shift.cashier_name || 'Kasir'}
                          </p>
                          <p className="text-[11px] text-slate-500">
                            {shift.shift_name || 'Shift Harian'}
                          </p>
                        </td>
                        <td className="py-3.5 px-4 text-slate-600 whitespace-nowrap text-[11px]">
                          <div>
                            <span className="font-medium text-slate-800">Buka:</span>{' '}
                            {formatDate(shift.opened_at)}
                          </div>
                          {shift.closed_at && (
                            <div>
                              <span className="font-medium text-slate-800">Tutup:</span>{' '}
                              {formatDate(shift.closed_at)}
                            </div>
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-right font-medium text-slate-700 whitespace-nowrap">
                          {formatRupiah(shift.starting_cash)}
                        </td>
                        <td className="py-3.5 px-4 text-right font-bold text-slate-900 whitespace-nowrap">
                          {shift.actual_ending_cash !== null &&
                          shift.actual_ending_cash !== undefined
                            ? formatRupiah(shift.actual_ending_cash)
                            : '-'}
                        </td>
                        <td className="py-3.5 px-4 text-right font-medium text-slate-600 whitespace-nowrap">
                          {shift.expected_ending_cash !== null &&
                          shift.expected_ending_cash !== undefined
                            ? formatRupiah(shift.expected_ending_cash)
                            : '-'}
                        </td>
                        <td className="py-3.5 px-4 text-right whitespace-nowrap">
                          {shift.status === 'open' ? (
                            <span className="text-slate-400 font-medium">-</span>
                          ) : diff === 0 ? (
                            <span className="font-bold text-emerald-600">Pas (Rp 0)</span>
                          ) : (
                            <span
                              className={`font-bold px-2 py-0.5 rounded-md text-[11px] ${
                                isMinus
                                  ? 'bg-rose-100 text-rose-700'
                                  : 'bg-emerald-100 text-emerald-700'
                              }`}
                            >
                              {isPlus ? '+' : ''}
                              {formatRupiah(diff)}
                            </span>
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-center whitespace-nowrap">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedShift(shift);
                            }}
                            className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
                          >
                            Rincian
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

        {/* Tab 2: Mutasi Kas Entries Table */}
        {activeTab === 'entries' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider bg-slate-50/50">
                  <th className="py-3.5 px-4">Waktu</th>
                  <th className="py-3.5 px-4">Bisnis & Outlet</th>
                  <th className="py-3.5 px-4">Tipe Mutasi</th>
                  <th className="py-3.5 px-4">Kategori</th>
                  <th className="py-3.5 px-4 text-right">Nominal</th>
                  <th className="py-3.5 px-4">Kasir / Pencatat</th>
                  <th className="py-3.5 px-4">Sumber Kas</th>
                  <th className="py-3.5 px-4">Catatan</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {loading ? (
                  <tr>
                    <td colSpan={8} className="py-12 text-center text-slate-400">
                      <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-blue-500" />
                      Memuat data mutasi kas...
                    </td>
                  </tr>
                ) : filteredEntries.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-12 text-center text-slate-400">
                      Tidak ada mutasi kas yang cocok dengan filter.
                    </td>
                  </tr>
                ) : (
                  filteredEntries.map((entry) => {
                    const isIn = entry.type === 'in';
                    return (
                      <tr key={entry.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 px-4 text-slate-600 whitespace-nowrap text-[11px]">
                          {formatDate(entry.created_at)}
                        </td>
                        <td className="py-3.5 px-4">
                          <p className="font-semibold text-slate-900">
                            {entry.businesses?.name || 'Toko'}
                          </p>
                          <p className="text-[11px] text-slate-500">
                            {entry.outlets?.name || 'Outlet Utama'}
                          </p>
                        </td>
                        <td className="py-3.5 px-4 whitespace-nowrap">
                          {isIn ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">
                              <ArrowDownRight className="w-3 h-3 text-emerald-600" />
                              KAS MASUK
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-100 text-rose-800">
                              <ArrowUpRight className="w-3 h-3 text-rose-600" />
                              KAS KELUAR
                            </span>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="px-2 py-0.5 rounded-md bg-slate-100 font-semibold text-slate-700 text-[11px]">
                            {entry.category}
                          </span>
                        </td>
                        <td
                          className={`py-3.5 px-4 text-right font-bold whitespace-nowrap ${
                            isIn ? 'text-emerald-600' : 'text-rose-600'
                          }`}
                        >
                          {isIn ? '+' : '-'} {formatRupiah(entry.amount)}
                        </td>
                        <td className="py-3.5 px-4 font-medium text-slate-800">
                          {entry.user_name || 'Staff'}
                        </td>
                        <td className="py-3.5 px-4 text-slate-600 capitalize text-[11px]">
                          {entry.payment_source}
                        </td>
                        <td className="py-3.5 px-4 text-slate-600 max-w-xs truncate">
                          {entry.notes || '-'}
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

      {/* Modal Detail Rekonsiliasi Shift */}
      {selectedShift && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-in fade-in">
          <div className="bg-white w-full max-w-2xl rounded-2xl shadow-xl border border-slate-200 overflow-hidden max-h-[90vh] flex flex-col">
            {/* Modal Header */}
            <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center font-bold">
                  <Clock className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-900">
                    Audit Rekonsiliasi Shift
                  </h3>
                  <p className="text-xs text-slate-500">
                    {selectedShift.businesses?.name} • {selectedShift.outlets?.name}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedShift(null)}
                className="p-2 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-6 overflow-y-auto space-y-6">
              {/* Shift Meta Banner */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                <div>
                  <p className="text-slate-400 font-medium">Kasir Bertugas</p>
                  <p className="font-bold text-slate-800 mt-0.5">
                    {selectedShift.cashier_name || 'Kasir'}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 font-medium">Status Shift</p>
                  <p className="font-bold text-slate-800 mt-0.5 uppercase">
                    {selectedShift.status === 'open' ? '🟢 BERJALAN' : '⚪ SELESAI'}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 font-medium">Jam Buka</p>
                  <p className="font-bold text-slate-800 mt-0.5">
                    {formatDate(selectedShift.opened_at)}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 font-medium">Jam Tutup</p>
                  <p className="font-bold text-slate-800 mt-0.5">
                    {selectedShift.closed_at ? formatDate(selectedShift.closed_at) : '-'}
                  </p>
                </div>
              </div>

              {/* Cash Reconciliation Formula Box */}
              <div className="rounded-xl border border-slate-200 overflow-hidden">
                <div className="p-3 bg-slate-100/70 border-b border-slate-200 text-xs font-bold text-slate-700 uppercase tracking-wide">
                  Perhitungan Laci Kasir (Cash Drawer)
                </div>
                <div className="p-4 space-y-3 text-sm">
                  <div className="flex justify-between items-center text-slate-700">
                    <span>Kas Awal (Modal Tunai)</span>
                    <span className="font-bold text-slate-900">
                      {formatRupiah(selectedShift.starting_cash)}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-slate-700">
                    <span>Kas Fisik Dihitung Kasir</span>
                    <span className="font-bold text-slate-900">
                      {selectedShift.actual_ending_cash !== null &&
                      selectedShift.actual_ending_cash !== undefined
                        ? formatRupiah(selectedShift.actual_ending_cash)
                        : '(Shift Masih Buka)'}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-slate-700">
                    <span>Estimasi Kas Seharusnya (Sistem)</span>
                    <span className="font-bold text-slate-900">
                      {selectedShift.expected_ending_cash !== null &&
                      selectedShift.expected_ending_cash !== undefined
                        ? formatRupiah(selectedShift.expected_ending_cash)
                        : '(Shift Masih Buka)'}
                    </span>
                  </div>

                  {/* Discrepancy Alert */}
                  {selectedShift.status === 'closed' && (
                    <div
                      className={`mt-3 p-3 rounded-xl border flex items-center justify-between ${
                        (selectedShift.difference ?? 0) === 0
                          ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                          : (selectedShift.difference ?? 0) < 0
                          ? 'bg-rose-50 border-rose-200 text-rose-800'
                          : 'bg-blue-50 border-blue-200 text-blue-800'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        {(selectedShift.difference ?? 0) === 0 ? (
                          <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                        ) : (
                          <AlertTriangle className="w-5 h-5 text-rose-600" />
                        )}
                        <span className="font-bold text-xs">
                          {(selectedShift.difference ?? 0) === 0
                            ? 'Rekonsiliasi Pas (Tidak Ada Selisih)'
                            : (selectedShift.difference ?? 0) < 0
                            ? 'Uang Fisik Kasir Kurang (Selisih Minus)'
                            : 'Uang Fisik Kasir Lebih (Selisih Plus)'}
                        </span>
                      </div>
                      <span className="text-sm font-extrabold">
                        {(selectedShift.difference ?? 0) > 0 ? '+' : ''}
                        {formatRupiah(selectedShift.difference)}
                      </span>
                    </div>
                  )}
                </div>
              </div>

              {/* Notes if available */}
              {selectedShift.notes && (
                <div className="p-3.5 rounded-xl bg-amber-50/70 border border-amber-200 text-xs text-amber-900">
                  <p className="font-bold mb-1">Catatan Closing dari Kasir:</p>
                  <p className="italic">{selectedShift.notes}</p>
                </div>
              )}

              {/* Mutasi Kas During This Shift */}
              <div>
                <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wide mb-2">
                  Mutasi Kas Selama Shift Ini ({shiftEntries.length})
                </h4>
                {shiftEntries.length === 0 ? (
                  <p className="text-xs text-slate-400 italic">
                    Tidak ada catatan kas masuk/keluar petty cash selama shift ini.
                  </p>
                ) : (
                  <div className="divide-y divide-slate-100 border border-slate-200 rounded-xl overflow-hidden text-xs">
                    {shiftEntries.map((e) => (
                      <div
                        key={e.id}
                        className="p-3 flex items-center justify-between hover:bg-slate-50 transition-colors"
                      >
                        <div>
                          <div className="flex items-center gap-2">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                e.type === 'in'
                                  ? 'bg-emerald-100 text-emerald-800'
                                  : 'bg-rose-100 text-rose-800'
                              }`}
                            >
                              {e.type === 'in' ? 'MASUK' : 'KELUAR'}
                            </span>
                            <span className="font-semibold text-slate-800">
                              {e.category}
                            </span>
                          </div>
                          {e.notes && (
                            <p className="text-slate-500 mt-0.5">{e.notes}</p>
                          )}
                        </div>
                        <span
                          className={`font-bold ${
                            e.type === 'in' ? 'text-emerald-600' : 'text-rose-600'
                          }`}
                        >
                          {e.type === 'in' ? '+' : '-'} {formatRupiah(e.amount)}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-4 border-t border-slate-100 bg-slate-50/50 flex justify-end">
              <button
                onClick={() => setSelectedShift(null)}
                className="px-4 py-2 text-xs font-bold rounded-xl bg-slate-900 text-white hover:bg-slate-800 transition-colors"
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
