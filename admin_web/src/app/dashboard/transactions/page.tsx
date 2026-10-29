'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Navbar from '@/components/Navbar';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Order } from '@/types/database';
import {
  Receipt,
  TrendingUp,
  DollarSign,
  CreditCard,
  Building2,
  Calendar,
  Search,
  Filter,
  RefreshCw,
  CheckCircle2,
  XCircle,
  Clock,
  ArrowUpRight,
  Eye,
  X,
  ChevronLeft,
  ChevronRight,
  ShoppingBag,
  Store,
  Wallet,
  Sparkles,
  Radio,
  Volume2,
  VolumeX,
  BellRing,
} from 'lucide-react';

const PAGE_SIZE = 20;

interface TransactionSummary {
  totalGMV: number;
  paidCount: number;
  voidCount: number;
  refundCount: number;
  draftCount: number;
  avgOrderValue: number;
  paymentBreakdown: Record<string, { count: number; total: number }>;
  topMerchants: Array<{
    businessId: string;
    businessName: string;
    totalRevenue: number;
    orderCount: number;
  }>;
}

interface IncomingTransactionAlert {
  id: string;
  invoice: string;
  amount: number;
  businessName?: string;
  status: string;
}

export default function TransactionsPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [page, setPage] = useState<number>(1);
  const [loading, setLoading] = useState<boolean>(true);
  const [summaryLoading, setSummaryLoading] = useState<boolean>(true);

  // Realtime States
  const [isLive, setIsLive] = useState<boolean>(false);
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [latestIncoming, setLatestIncoming] = useState<IncomingTransactionAlert | null>(null);
  const [highlightedOrderId, setHighlightedOrderId] = useState<string | null>(null);

  // Filter States
  const [timeFilter, setTimeFilter] = useState<'today' | '7days' | '30days' | 'all'>('30days');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Selected Order for Detail Modal
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [orderItems, setOrderItems] = useState<any[]>([]);
  const [loadingItems, setLoadingItems] = useState<boolean>(false);

  // Summary Metrics
  const [summary, setSummary] = useState<TransactionSummary>({
    totalGMV: 0,
    paidCount: 0,
    voidCount: 0,
    refundCount: 0,
    draftCount: 0,
    avgOrderValue: 0,
    paymentBreakdown: {},
    topMerchants: [],
  });

  const supabase = createClient();
  const alertTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const highlightTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Web Audio API Cashier Chime Sound Generator (No external MP3 needed)
  const playCashierChime = useCallback(() => {
    if (!soundEnabled) return;
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();

      // Dual note bell chime (pleasant & modern)
      const now = ctx.currentTime;
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();

      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(587.33, now); // D5
      osc1.frequency.exponentialRampToValueAtTime(880, now + 0.15); // A5

      osc2.type = 'triangle';
      osc2.frequency.setValueAtTime(880, now + 0.15);
      osc2.frequency.exponentialRampToValueAtTime(1174.66, now + 0.35); // D6

      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(now);
      osc1.stop(now + 0.3);
      osc2.start(now + 0.15);
      osc2.stop(now + 0.6);
    } catch (e) {
      // Audio autoplay policy fallback
    }
  }, [soundEnabled]);

  // Helper to get start timestamp based on filter
  const getFilterStartDate = (filter: 'today' | '7days' | '30days' | 'all'): string | null => {
    const now = new Date();
    if (filter === 'today') {
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      return today.toISOString();
    }
    if (filter === '7days') {
      const past7 = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return past7.toISOString();
    }
    if (filter === '30days') {
      const past30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return past30.toISOString();
    }
    return null;
  };

  // Load High-Level Analytics Summary
  const fetchSummary = useCallback(async () => {
    try {
      setSummaryLoading(true);
      const startDate = getFilterStartDate(timeFilter);

      let query = supabase
        .from('orders')
        .select('id, business_id, grand_total, status, created_at, businesses(id, name), order_payments(method_name, amount)');

      if (startDate) {
        query = query.gte('created_at', startDate);
      }

      const { data, error } = await query;
      if (error) throw error;

      let gmv = 0;
      let paid = 0;
      let voided = 0;
      let refunded = 0;
      let draft = 0;
      const paymentsMap: Record<string, { count: number; total: number }> = {};
      const merchantsMap: Record<string, { businessId: string; businessName: string; totalRevenue: number; orderCount: number }> = {};

      (data || []).forEach((ord: any) => {
        const grandTotal = Number(ord.grand_total || 0);

        if (ord.status === 'paid') {
          gmv += grandTotal;
          paid++;

          // Aggregate Payments
          if (ord.order_payments && Array.isArray(ord.order_payments)) {
            ord.order_payments.forEach((p: any) => {
              const method = p.method_name || 'Tunai';
              const amt = Number(p.amount || 0);
              if (!paymentsMap[method]) {
                paymentsMap[method] = { count: 0, total: 0 };
              }
              paymentsMap[method].count += 1;
              paymentsMap[method].total += amt;
            });
          }

          // Aggregate Merchant Leaderboard
          const bId = ord.business_id || 'unknown';
          const bName = ord.businesses?.name || 'Toko Tanpa Nama';
          if (!merchantsMap[bId]) {
            merchantsMap[bId] = {
              businessId: bId,
              businessName: bName,
              totalRevenue: 0,
              orderCount: 0,
            };
          }
          merchantsMap[bId].totalRevenue += grandTotal;
          merchantsMap[bId].orderCount += 1;
        } else if (ord.status === 'void') {
          voided++;
        } else if (ord.status === 'refunded') {
          refunded++;
        } else {
          draft++;
        }
      });

      const topMerchants = Object.values(merchantsMap)
        .sort((a, b) => b.totalRevenue - a.totalRevenue)
        .slice(0, 5);

      setSummary({
        totalGMV: gmv,
        paidCount: paid,
        voidCount: voided,
        refundCount: refunded,
        draftCount: draft,
        avgOrderValue: paid > 0 ? gmv / paid : 0,
        paymentBreakdown: paymentsMap,
        topMerchants,
      });
    } catch (err) {
      console.error('Error fetching transactions summary:', err);
    } finally {
      setSummaryLoading(false);
    }
  }, [timeFilter]);

  // Load Paginated Order Table
  const fetchOrders = useCallback(async () => {
    try {
      setLoading(true);
      const startDate = getFilterStartDate(timeFilter);

      let query = supabase
        .from('orders')
        .select(
          `
          id,
          outlet_id,
          business_id,
          invoice_number,
          customer_name,
          customer_phone,
          table_number,
          status,
          notes,
          void_reason,
          subtotal,
          discount_total,
          tax_amount,
          grand_total,
          paid_amount,
          change_amount,
          created_at,
          paid_at,
          businesses (id, name),
          outlets (id, name),
          order_payments (id, method_name, method_type, amount)
        `,
          { count: 'exact' }
        );

      if (startDate) {
        query = query.gte('created_at', startDate);
      }

      if (statusFilter !== 'ALL') {
        query = query.eq('status', statusFilter);
      }

      if (searchQuery.trim()) {
        const q = searchQuery.trim();
        query = query.or(`invoice_number.ilike.%${q}%,customer_name.ilike.%${q}%`);
      }

      const from = (page - 1) * PAGE_SIZE;
      const to = from + PAGE_SIZE - 1;

      const { data, count, error } = await query
        .order('created_at', { ascending: false })
        .range(from, to);

      if (error) throw error;

      setOrders((data as any) || []);
      setTotalCount(count || 0);
    } catch (err) {
      console.error('Error fetching orders:', err);
    } finally {
      setLoading(false);
    }
  }, [page, timeFilter, statusFilter, searchQuery]);

  useEffect(() => {
    fetchSummary();
  }, [fetchSummary]);

  useEffect(() => {
    fetchOrders();
  }, [fetchOrders]);

  // -------------------------------------------------------------
  // SUPABASE REALTIME SUBSCRIPTION (LIVE STREAMING ORDERS)
  // -------------------------------------------------------------
  useEffect(() => {
    const channel = supabase
      .channel('realtime-orders-admin')
      .on(
        'postgres_changes',
        {
          event: '*', // Listen to INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'orders',
        },
        async (payload: any) => {
          console.log('[Supabase Realtime] Event received:', payload);

          const newRow = payload.new;
          if (newRow && newRow.id) {
            // Trigger Chime
            playCashierChime();

            // Set Live Alert Banner
            setLatestIncoming({
              id: newRow.id,
              invoice: newRow.invoice_number || 'Transaksi Baru',
              amount: Number(newRow.grand_total || 0),
              status: newRow.status || 'paid',
            });

            // Highlight the affected row
            setHighlightedOrderId(newRow.id);

            if (alertTimeoutRef.current) clearTimeout(alertTimeoutRef.current);
            alertTimeoutRef.current = setTimeout(() => {
              setLatestIncoming(null);
            }, 5000);

            if (highlightTimeoutRef.current) clearTimeout(highlightTimeoutRef.current);
            highlightTimeoutRef.current = setTimeout(() => {
              setHighlightedOrderId(null);
            }, 4000);
          }

          // Re-sync metrics & table immediately
          fetchSummary();
          fetchOrders();
        }
      )
      .subscribe((status) => {
        setIsLive(status === 'SUBSCRIBED');
      });

    // Auto-polling fallback every 60s
    const heartbeat = setInterval(() => {
      fetchSummary();
      fetchOrders();
    }, 60000);

    return () => {
      supabase.removeChannel(channel);
      clearInterval(heartbeat);
      if (alertTimeoutRef.current) clearTimeout(alertTimeoutRef.current);
      if (highlightTimeoutRef.current) clearTimeout(highlightTimeoutRef.current);
    };
  }, [fetchSummary, fetchOrders, playCashierChime]);

  // Load Order Items for Modal
  const openOrderDetail = async (order: Order) => {
    setSelectedOrder(order);
    try {
      setLoadingItems(true);
      const { data, error } = await supabase
        .from('order_items')
        .select('*')
        .eq('order_id', order.id);

      if (!error && data) {
        setOrderItems(data);
      }
    } catch (e) {
      console.error('Error fetching order items:', e);
    } finally {
      setLoadingItems(false);
    }
  };

  const totalPages = Math.ceil(totalCount / PAGE_SIZE) || 1;
  const fromRecord = totalCount === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const toRecord = Math.min(page * PAGE_SIZE, totalCount);

  return (
    <div className="space-y-8 pb-12">
      {/* Live Incoming Transaction Toast Notification */}
      {latestIncoming && (
        <div className="fixed top-6 right-8 z-50 animate-in slide-in-from-top-4 fade-in duration-300">
          <div className="flex items-center gap-3 p-4 rounded-2xl bg-slate-900 text-white shadow-2xl border border-orange-500/40">
            <div className="w-10 h-10 rounded-xl bg-orange-500/20 text-orange-400 flex items-center justify-center flex-shrink-0">
              <BellRing className="w-5 h-5 animate-bounce" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-orange-500 text-white">
                  Realtime Alert
                </span>
                <span className="text-xs font-mono text-slate-300">
                  {latestIncoming.invoice}
                </span>
              </div>
              <div className="text-sm font-bold text-white mt-0.5">
                Transaksi Masuk:{' '}
                <span className="text-emerald-400 font-mono">
                  Rp {latestIncoming.amount.toLocaleString('id-ID')}
                </span>
              </div>
            </div>
            <button
              onClick={() => setLatestIncoming(null)}
              className="p-1 text-slate-400 hover:text-white ml-2 rounded-lg"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      <Navbar
        title="Monitoring Transaksi & GMV Platform"
        description="Pantau perputaran omset transaksi (GMV), tren harian, metode pembayaran, dan riwayat penjualan seluruh merchant"
      />

      {/* Realtime Live Bar & Filters */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 bg-white p-4 rounded-3xl border border-slate-200/90 shadow-xs">
        {/* Live Status Badge & Sound Toggle */}
        <div className="flex items-center gap-3">
          {/* Live Indicator */}
          <div
            className={`inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full text-xs font-bold border transition-colors ${
              isLive
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                : 'bg-amber-50 text-amber-700 border-amber-200'
            }`}
          >
            <span
              className={`w-2.5 h-2.5 rounded-full ${
                isLive ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'
              }`}
            />
            <span>{isLive ? 'LIVE REALTIME' : 'Menghubungkan Stream...'}</span>
          </div>

          {/* Sound Toggle */}
          <button
            onClick={() => {
              setSoundEnabled(!soundEnabled);
              if (!soundEnabled) playCashierChime();
            }}
            title={soundEnabled ? 'Matikan Suara Notifikasi' : 'Aktifkan Suara Notifikasi'}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-all ${
              soundEnabled
                ? 'bg-orange-50 border-orange-200 text-orange-700'
                : 'bg-slate-100 border-slate-200 text-slate-500'
            }`}
          >
            {soundEnabled ? (
              <>
                <Volume2 className="w-3.5 h-3.5 text-orange-600" />
                <span>Suara Aktif</span>
              </>
            ) : (
              <>
                <VolumeX className="w-3.5 h-3.5 text-slate-400" />
                <span>Mute</span>
              </>
            )}
          </button>
        </div>

        {/* Date Filter & Manual Refresh */}
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex items-center gap-1 bg-slate-50 p-1 rounded-2xl border border-slate-200/80">
            {[
              { id: 'today', label: 'Hari Ini' },
              { id: '7days', label: '7 Hari' },
              { id: '30days', label: '30 Hari' },
              { id: 'all', label: 'Semua' },
            ].map((btn) => (
              <button
                key={btn.id}
                onClick={() => {
                  setTimeFilter(btn.id as any);
                  setPage(1);
                }}
                className={`px-3 py-1 rounded-xl text-xs font-bold transition-all ${
                  timeFilter === btn.id
                    ? 'bg-white text-orange-600 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {btn.label}
              </button>
            ))}
          </div>

          <button
            onClick={() => {
              fetchSummary();
              fetchOrders();
            }}
            title="Refresh Manual"
            className="p-2 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition-colors"
          >
            <RefreshCw className={`w-4 h-4 ${summaryLoading || loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Top 4 KPI Metrics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Total GMV */}
        <div className="p-6 rounded-3xl bg-gradient-to-br from-orange-500 to-amber-600 text-white shadow-md shadow-orange-500/10 relative overflow-hidden">
          <div className="absolute -top-8 -right-8 w-28 h-28 bg-white/10 rounded-full blur-xl pointer-events-none" />
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-orange-100">
              Total GMV (Omset Lunas)
            </span>
            <div className="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-white" />
            </div>
          </div>
          <div className="text-2xl sm:text-3xl font-black tracking-tight">
            Rp {summary.totalGMV.toLocaleString('id-ID')}
          </div>
          <div className="text-[11px] text-orange-100/90 mt-1 font-medium">
            Perputaran penjualan seluruh toko
          </div>
        </div>

        {/* Total Transaksi Sukses */}
        <div className="p-6 rounded-3xl bg-white border border-slate-200/90 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Transaksi Lunas
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <CheckCircle2 className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl sm:text-3xl font-black text-slate-900">
            {summary.paidCount.toLocaleString('id-ID')}
          </div>
          <div className="text-[11px] text-emerald-600 font-semibold mt-1 flex items-center gap-1">
            <span>Selesai diproses kasir</span>
          </div>
        </div>

        {/* Average Order Value (AOV) */}
        <div className="p-6 rounded-3xl bg-white border border-slate-200/90 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Rata-rata Transaksi (AOV)
            </span>
            <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <Receipt className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl sm:text-3xl font-black text-slate-900">
            Rp {Math.round(summary.avgOrderValue).toLocaleString('id-ID')}
          </div>
          <div className="text-[11px] text-slate-500 mt-1 font-medium">
            Rata-rata keranjang per belanja
          </div>
        </div>

        {/* Void / Batal / Refund */}
        <div className="p-6 rounded-3xl bg-white border border-slate-200/90 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Batal / Refund
            </span>
            <div className="w-8 h-8 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center">
              <XCircle className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl sm:text-3xl font-black text-slate-900">
            {(summary.voidCount + summary.refundCount).toLocaleString('id-ID')}
          </div>
          <div className="text-[11px] text-slate-500 mt-1 font-medium">
            {summary.voidCount} void • {summary.refundCount} refund
          </div>
        </div>
      </div>

      {/* Visual Analytics Row: Payment Breakdown & Top Merchants */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Payment Methods Breakdown */}
        <div className="p-6 rounded-3xl bg-white border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-bold text-base text-slate-900">Pecahan Metode Pembayaran</h3>
              <p className="text-xs text-slate-500">Distribusi cara bayar yang dipakai pelanggan</p>
            </div>
            <Wallet className="w-5 h-5 text-orange-500" />
          </div>

          {Object.keys(summary.paymentBreakdown).length === 0 ? (
            <div className="py-8 text-center text-slate-400 text-xs font-medium">
              Belum ada data pembayaran pada periode ini.
            </div>
          ) : (
            <div className="space-y-3.5 pt-2">
              {Object.entries(summary.paymentBreakdown)
                .sort(([, a], [, b]) => b.total - a.total)
                .map(([method, data]) => {
                  const percentage =
                    summary.totalGMV > 0
                      ? Math.round((data.total / summary.totalGMV) * 100)
                      : 0;
                  return (
                    <div key={method} className="space-y-1.5">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-slate-700 capitalize">{method}</span>
                        <div className="flex items-center gap-2">
                          <span className="text-slate-500">
                            {data.count} transaksi ({percentage}%)
                          </span>
                          <span className="font-bold text-slate-900 font-mono">
                            Rp {data.total.toLocaleString('id-ID')}
                          </span>
                        </div>
                      </div>
                      <div className="w-full h-2 rounded-full bg-slate-100 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-orange-500 transition-all duration-500"
                          style={{ width: `${Math.max(percentage, 3)}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
            </div>
          )}
        </div>

        {/* Top Active Merchants */}
        <div className="p-6 rounded-3xl bg-white border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-bold text-base text-slate-900">Top Merchant Teraktif</h3>
              <p className="text-xs text-slate-500">Toko dengan omset & frekuensi transaksi tertinggi</p>
            </div>
            <Store className="w-5 h-5 text-orange-500" />
          </div>

          {summary.topMerchants.length === 0 ? (
            <div className="py-8 text-center text-slate-400 text-xs font-medium">
              Belum ada transaksi aktif pada periode ini.
            </div>
          ) : (
            <div className="space-y-3 pt-2">
              {summary.topMerchants.map((merchant, idx) => (
                <div
                  key={merchant.businessId}
                  className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100 hover:border-orange-200 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-xl bg-orange-100 text-orange-700 font-black text-xs flex items-center justify-center">
                      #{idx + 1}
                    </div>
                    <div>
                      <div className="font-bold text-xs text-slate-900">
                        {merchant.businessName}
                      </div>
                      <div className="text-[11px] text-slate-500">
                        {merchant.orderCount} transaksi sukses
                      </div>
                    </div>
                  </div>

                  <div className="text-right">
                    <div className="font-bold text-xs font-mono text-slate-900">
                      Rp {merchant.totalRevenue.toLocaleString('id-ID')}
                    </div>
                    <Link
                      href="/dashboard/businesses"
                      className="text-[10px] font-bold text-orange-600 hover:text-orange-700 inline-flex items-center gap-0.5 mt-0.5"
                    >
                      <span>Lihat Toko</span>
                      <ArrowUpRight className="w-3 h-3" />
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Order Table with Filter & Search */}
      <div className="bg-white rounded-3xl border border-slate-200/90 shadow-xs overflow-hidden">
        {/* Table Filter Bar */}
        <div className="p-4 sm:p-5 border-b border-slate-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari no invoice (INV-...) atau nama pelanggan..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setPage(1);
              }}
              className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-xs"
            />
          </div>

          <div className="flex items-center gap-2">
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 focus:outline-hidden"
            >
              <option value="ALL">Semua Status</option>
              <option value="paid">Lunas (Paid)</option>
              <option value="refunded">Refund</option>
              <option value="void">Void / Batal</option>
              <option value="draft">Draft / Belum Bayar</option>
              <option value="confirmed">Confirmed</option>
            </select>
          </div>
        </div>

        {/* Table Content */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50/80 border-b border-slate-200/80 text-[11px] uppercase tracking-wider text-slate-500 font-bold">
              <tr>
                <th className="py-4 px-6">Invoice & Waktu</th>
                <th className="py-4 px-6">Toko / Outlet</th>
                <th className="py-4 px-6">Pelanggan</th>
                <th className="py-4 px-6">Metode Bayar</th>
                <th className="py-4 px-6">Status</th>
                <th className="py-4 px-6 text-right">Total Transaksi</th>
                <th className="py-4 px-6 text-right">Detail</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-14 text-center text-slate-400">
                    <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                    <span>Memuat riwayat transaksi...</span>
                  </td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-14 text-center text-slate-400">
                    <Receipt className="w-10 h-10 text-slate-300 mx-auto mb-2" />
                    <p className="font-semibold text-slate-600">Belum ada transaksi ditemukan</p>
                    <p className="text-xs text-slate-400 mt-1">
                      Transaksi yang dibuat oleh aplikasi kasir mobile akan muncul di sini secara otomatis.
                    </p>
                  </td>
                </tr>
              ) : (
                orders.map((order) => {
                  const paymentMethod =
                    order.order_payments && order.order_payments.length > 0
                      ? order.order_payments[0].method_name
                      : 'Tunai';

                  const isHighlighted = highlightedOrderId === order.id;

                  return (
                    <tr
                      key={order.id}
                      className={`transition-colors duration-500 ${
                        isHighlighted
                          ? 'bg-emerald-50/90 ring-2 ring-emerald-400'
                          : 'hover:bg-slate-50/70'
                      }`}
                    >
                      {/* Invoice & Time */}
                      <td className="py-4 px-6">
                        <div className="font-mono font-bold text-xs text-slate-900 flex items-center gap-1.5">
                          <span>{order.invoice_number}</span>
                          {isHighlighted && (
                            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
                          )}
                        </div>
                        <div className="text-[11px] text-slate-400 mt-0.5">
                          {new Date(order.created_at).toLocaleString('id-ID', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </div>
                      </td>

                      {/* Business & Outlet */}
                      <td className="py-4 px-6">
                        <div className="font-bold text-xs text-slate-800">
                          {order.businesses?.name || 'Toko UMKM'}
                        </div>
                        <div className="text-[11px] text-slate-400">
                          {order.outlets?.name || 'Outlet Utama'}
                        </div>
                      </td>

                      {/* Customer / Table */}
                      <td className="py-4 px-6 text-xs">
                        <div className="font-medium text-slate-800">
                          {order.customer_name || 'Pelanggan Umum'}
                        </div>
                        {order.table_number && (
                          <div className="text-[11px] text-orange-600 font-semibold">
                            Meja #{order.table_number}
                          </div>
                        )}
                      </td>

                      {/* Payment Method */}
                      <td className="py-4 px-6 text-xs">
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700 font-semibold text-[11px]">
                          <CreditCard className="w-3 h-3 text-slate-400" />
                          <span>{paymentMethod}</span>
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        {order.status === 'paid' ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                            <span>Lunas</span>
                          </span>
                        ) : order.status === 'refunded' ? (
                          <div>
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-50 text-rose-700 border border-rose-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-rose-500" />
                              <span>Refund</span>
                            </span>
                            {order.void_reason && (
                              <div
                                className="text-[11px] text-rose-600 font-medium mt-1 max-w-[200px] truncate"
                                title={order.void_reason}
                              >
                                &quot;{order.void_reason}&quot;
                              </div>
                            )}
                          </div>
                        ) : order.status === 'void' ? (
                          <div>
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-50 text-red-700 border border-red-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                              <span>Batal (Void)</span>
                            </span>
                            {order.void_reason && (
                              <div
                                className="text-[11px] text-red-600 font-medium mt-1 max-w-[200px] truncate"
                                title={order.void_reason}
                              >
                                &quot;{order.void_reason}&quot;
                              </div>
                            )}
                          </div>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
                            <span>{order.status}</span>
                          </span>
                        )}
                      </td>

                      {/* Total */}
                      <td className="py-4 px-6 text-right font-mono font-bold text-xs text-slate-900">
                        Rp {Number(order.grand_total || 0).toLocaleString('id-ID')}
                      </td>

                      {/* Action */}
                      <td className="py-4 px-6 text-right">
                        <button
                          onClick={() => openOrderDetail(order)}
                          className="p-2 text-slate-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                          title="Lihat Detail Transaksi"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Controls */}
        <div className="px-6 py-4 border-t border-slate-100 flex flex-col sm:flex-row items-center justify-between gap-4 bg-slate-50/50">
          <div className="text-xs text-slate-500">
            Menampilkan <strong className="text-slate-800">{fromRecord}</strong> sampai{' '}
            <strong className="text-slate-800">{toRecord}</strong> dari{' '}
            <strong className="text-slate-800">{totalCount.toLocaleString('id-ID')}</strong> transaksi
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page <= 1 || loading}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-white disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              <span>Sebelumnya</span>
            </button>

            <span className="text-xs font-semibold text-slate-700 px-2">
              Halaman {page} dari {totalPages}
            </span>

            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page >= totalPages || loading}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-white disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <span>Berikutnya</span>
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Detail Order Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="p-6 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center">
                  <Receipt className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-900">
                    {selectedOrder.invoice_number}
                  </h3>
                  <p className="text-xs text-slate-500">
                    {selectedOrder.businesses?.name} •{' '}
                    {new Date(selectedOrder.created_at).toLocaleString('id-ID')}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedOrder(null)}
                className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
              {/* Order Info Pills */}
              <div className="grid grid-cols-2 gap-3 p-3.5 rounded-2xl bg-slate-50 text-xs">
                <div>
                  <span className="text-slate-400 block text-[11px]">Pelanggan</span>
                  <span className="font-bold text-slate-800">
                    {selectedOrder.customer_name || 'Pelanggan Umum'}
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-[11px]">Status</span>
                  <span
                    className={`font-bold capitalize ${
                      selectedOrder.status === 'paid'
                        ? 'text-emerald-600'
                        : selectedOrder.status === 'refunded'
                        ? 'text-rose-600'
                        : selectedOrder.status === 'void'
                        ? 'text-red-600'
                        : 'text-amber-600'
                    }`}
                  >
                    {selectedOrder.status}
                  </span>
                </div>
              </div>

              {/* Alasan Void / Refund Banner */}
              {(selectedOrder.status === 'refunded' ||
                selectedOrder.status === 'void' ||
                selectedOrder.void_reason) && (
                <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-xs">
                  <div className="flex items-center gap-2 font-bold text-rose-800 mb-1">
                    <XCircle className="w-4 h-4 text-rose-600 flex-shrink-0" />
                    <span>
                      Alasan{' '}
                      {selectedOrder.status === 'refunded'
                        ? 'Refund (Pengembalian Dana)'
                        : 'Pembatalan (Void)'}
                      :
                    </span>
                  </div>
                  <p className="text-rose-700 font-semibold pl-6 leading-relaxed text-sm">
                    {selectedOrder.void_reason ||
                      selectedOrder.notes ||
                      'Tidak ada keterangan alasan yang diinput oleh kasir.'}
                  </p>
                </div>
              )}

              {/* Catatan Pesanan jika ada dan beda dengan void_reason */}
              {selectedOrder.notes &&
                selectedOrder.notes !== selectedOrder.void_reason && (
                  <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs">
                    <span className="font-bold text-slate-700 block mb-0.5">Catatan Pesanan:</span>
                    <span className="text-slate-600">{selectedOrder.notes}</span>
                  </div>
                )}

              {/* Items List */}
              <div>
                <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                  Daftar Pesanan (Items)
                </h4>
                {loadingItems ? (
                  <div className="py-6 text-center text-slate-400 text-xs">
                    Memuat rincian pesanan...
                  </div>
                ) : orderItems.length === 0 ? (
                  <div className="py-4 text-center text-slate-400 text-xs">
                    Tidak ada item tercatat.
                  </div>
                ) : (
                  <div className="divide-y divide-slate-100 border border-slate-100 rounded-2xl overflow-hidden">
                    {orderItems.map((item) => (
                      <div
                        key={item.id}
                        className="p-3 flex items-center justify-between text-xs bg-white"
                      >
                        <div>
                          <div className="font-bold text-slate-900">{item.name}</div>
                          <div className="text-[11px] text-slate-400">
                            {item.quantity} x Rp {Number(item.unit_price).toLocaleString('id-ID')}
                          </div>
                        </div>
                        <div className="font-bold font-mono text-slate-900">
                          Rp {Number(item.subtotal).toLocaleString('id-ID')}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Price Breakdown */}
              <div className="space-y-1.5 pt-2 border-t border-slate-100 text-xs">
                <div className="flex justify-between text-slate-500">
                  <span>Subtotal</span>
                  <span className="font-mono">
                    Rp {Number(selectedOrder.subtotal || 0).toLocaleString('id-ID')}
                  </span>
                </div>
                {Number(selectedOrder.discount_total || 0) > 0 && (
                  <div className="flex justify-between text-emerald-600">
                    <span>Diskon</span>
                    <span className="font-mono">
                      -Rp {Number(selectedOrder.discount_total).toLocaleString('id-ID')}
                    </span>
                  </div>
                )}
                {Number(selectedOrder.tax_amount || 0) > 0 && (
                  <div className="flex justify-between text-slate-500">
                    <span>Pajak (PB1/PPN)</span>
                    <span className="font-mono">
                      Rp {Number(selectedOrder.tax_amount).toLocaleString('id-ID')}
                    </span>
                  </div>
                )}
                <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-100">
                  <span>Grand Total</span>
                  <span className="font-mono text-orange-600">
                    Rp {Number(selectedOrder.grand_total || 0).toLocaleString('id-ID')}
                  </span>
                </div>
              </div>
            </div>

            <div className="p-4 border-t border-slate-100 bg-slate-50 flex justify-end">
              <button
                onClick={() => setSelectedOrder(null)}
                className="px-5 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold transition-colors"
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
