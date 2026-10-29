'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { Order, MenuItem } from '@/types/database';
import Link from 'next/link';
import dynamic from 'next/dynamic';
import {
  DollarSign,
  ShoppingBag,
  TrendingUp,
  Receipt,
  Users,
  AlertTriangle,
  ArrowUpRight,
  ArrowDownRight,
  Clock,
  QrCode,
  Wallet,
  CreditCard,
  Banknote,
  Package,
  Calendar,
  Sparkles,
  RefreshCw,
  ExternalLink,
  ArrowRight,
  BarChart3,
  PieChart as PieIcon,
} from 'lucide-react';

const RevenueTrendChart = dynamic(
  () => import('@/components/merchant/charts/RevenueTrendChart'),
  { ssr: false, loading: () => <div className="h-64 flex items-center justify-center text-slate-400 text-xs">Memuat grafik...</div> }
);

const PaymentDistributionChart = dynamic(
  () => import('@/components/merchant/charts/PaymentDistributionChart'),
  { ssr: false, loading: () => <div className="h-64 flex items-center justify-center text-slate-400 text-xs">Memuat grafik...</div> }
);

type TimeRange = 'today' | '7days' | '30days' | 'this_month';

interface SalesMetric {
  totalRevenue: number;
  totalOrders: number;
  totalItemsSold: number;
  averageOrderValue: number;
  grossProfit: number;
}

interface HourlySales {
  hour: number;
  revenue: number;
  orderCount: number;
}

interface DailySales {
  date: string;
  label: string;
  revenue: number;
  orderCount: number;
}

interface PaymentBreakdown {
  method: string;
  label: string;
  count: number;
  amount: number;
  percentage: number;
}

interface TopProduct {
  id: string;
  name: string;
  qty: number;
  revenue: number;
}

export default function MerchantDashboardPage() {
  const { business, selectedOutletId, loading: shellLoading } = useMerchant();

  const [timeRange, setTimeRange] = useState<TimeRange>('today');
  const [loading, setLoading] = useState(true);
  const [metrics, setMetrics] = useState<SalesMetric>({
    totalRevenue: 0,
    totalOrders: 0,
    totalItemsSold: 0,
    averageOrderValue: 0,
    grossProfit: 0,
  });

  const [hourlyData, setHourlyData] = useState<HourlySales[]>([]);
  const [dailyData, setDailyData] = useState<DailySales[]>([]);
  const [paymentBreakdowns, setPaymentBreakdowns] = useState<PaymentBreakdown[]>([]);
  const [topProducts, setTopProducts] = useState<TopProduct[]>([]);
  const [lowStockItems, setLowStockItems] = useState<MenuItem[]>([]);
  const [recentOrders, setRecentOrders] = useState<Order[]>([]);

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadAnalytics = async () => {
    if (!business) return;

    try {
      setLoading(true);
      const supabase = createClient();

      // Hitung rentang tanggal
      const now = new Date();
      let startDate = new Date();

      if (timeRange === 'today') {
        startDate.setHours(0, 0, 0, 0);
      } else if (timeRange === '7days') {
        startDate.setDate(now.getDate() - 7);
        startDate.setHours(0, 0, 0, 0);
      } else if (timeRange === '30days') {
        startDate.setDate(now.getDate() - 30);
        startDate.setHours(0, 0, 0, 0);
      } else if (timeRange === 'this_month') {
        startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      }

      // Query Orders
      let query = supabase
        .from('orders')
        .select('*, order_items(*), order_payments(*)')
        .eq('business_id', business.id)
        .gte('created_at', startDate.toISOString())
        .order('created_at', { ascending: false });

      if (selectedOutletId !== 'all') {
        query = query.eq('outlet_id', selectedOutletId);
      }

      const { data: orders, error: ordersError } = await query;

      if (ordersError) {
        console.error('Error fetching orders:', ordersError);
        return;
      }

      const allOrders: any[] = orders || [];
      const paidOrders = allOrders.filter((o) => o.status === 'paid' || o.status === 'confirmed');

      // 1. Hitung Metrics
      let rev = 0;
      let itemsCount = 0;
      let totalCost = 0;

      const productSalesMap: Record<string, { id: string; name: string; qty: number; revenue: number }> = {};
      const paymentMap: Record<string, { count: number; amount: number }> = {};

      paidOrders.forEach((order) => {
        const orderTotal = Number(order.grand_total || order.total_amount || 0);
        rev += orderTotal;

        // Process items
        const items = order.order_items || [];
        items.forEach((it: any) => {
          const qty = Number(it.quantity || 1);
          const price = Number(it.unit_price ?? it.price ?? 0);
          const cost = Number(it.cost_price || 0);
          itemsCount += qty;
          totalCost += cost * qty;

          const pId = it.menu_item_id || it.name;
          if (!productSalesMap[pId]) {
            productSalesMap[pId] = {
              id: pId,
              name: it.name || 'Produk',
              qty: 0,
              revenue: 0,
            };
          }
          productSalesMap[pId].qty += qty;
          productSalesMap[pId].revenue += Number(it.subtotal != null ? it.subtotal : price * qty);
        });

        // Process payments
        let method = (order.payment_method || '').toLowerCase();
        if (!method && order.order_payments && order.order_payments.length > 0) {
          method = (order.order_payments[0].method_name || order.order_payments[0].method_type || 'cash').toLowerCase();
        }
        if (!method) method = 'cash';
        if (!paymentMap[method]) {
          paymentMap[method] = { count: 0, amount: 0 };
        }
        paymentMap[method].count += 1;
        paymentMap[method].amount += orderTotal;
      });

      const orderCount = paidOrders.length;
      const aov = orderCount > 0 ? Math.round(rev / orderCount) : 0;
      const profit = Math.max(0, rev - totalCost);

      setMetrics({
        totalRevenue: rev,
        totalOrders: orderCount,
        totalItemsSold: itemsCount,
        averageOrderValue: aov,
        grossProfit: profit,
      });

      // 2. Breakdown Metode Pembayaran
      const paymentList: PaymentBreakdown[] = Object.entries(paymentMap).map(([method, data]) => {
        let label = 'Tunai (Cash)';
        if (method.includes('qris')) label = 'QRIS';
        else if (method.includes('transfer') || method.includes('bank')) label = 'Transfer Bank';
        else if (method.includes('card') || method.includes('debit')) label = 'Kartu / EDC';
        else if (method.includes('online')) label = 'Online Payment';

        return {
          method,
          label,
          count: data.count,
          amount: data.amount,
          percentage: rev > 0 ? Math.round((data.amount / rev) * 100) : 0,
        };
      });
      paymentList.sort((a, b) => b.amount - a.amount);
      setPaymentBreakdowns(paymentList);

      // 3. Top Products
      const topList = Object.values(productSalesMap);
      topList.sort((a, b) => b.qty - a.qty);
      setTopProducts(topList.slice(0, 5));

      // 4. Hourly Sales (khusus jika 'today')
      if (timeRange === 'today') {
        const hourlyMap: Record<number, { revenue: number; orderCount: number }> = {};
        for (let h = 8; h <= 22; h++) {
          hourlyMap[h] = { revenue: 0, orderCount: 0 };
        }

        paidOrders.forEach((order) => {
          const h = new Date(order.created_at).getHours();
          if (hourlyMap[h]) {
            hourlyMap[h].revenue += Number(order.grand_total || order.total_amount || 0);
            hourlyMap[h].orderCount += 1;
          }
        });

        const hourlyArr: HourlySales[] = Object.entries(hourlyMap).map(([h, val]) => ({
          hour: Number(h),
          revenue: val.revenue,
          orderCount: val.orderCount,
        }));
        setHourlyData(hourlyArr);
      } else {
        // Daily Sales
        const dailyMap: Record<string, { date: string; label: string; revenue: number; orderCount: number }> = {};
        const daysCount = timeRange === '7days' ? 7 : timeRange === '30days' ? 30 : 31;

        for (let i = daysCount - 1; i >= 0; i--) {
          const d = new Date();
          d.setDate(d.getDate() - i);
          const key = d.toISOString().split('T')[0];
          const label = d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
          dailyMap[key] = { date: key, label, revenue: 0, orderCount: 0 };
        }

        paidOrders.forEach((order) => {
          const key = new Date(order.created_at).toISOString().split('T')[0];
          if (dailyMap[key]) {
            dailyMap[key].revenue += Number(order.grand_total || order.total_amount || 0);
            dailyMap[key].orderCount += 1;
          }
        });

        setDailyData(Object.values(dailyMap));
      }

      // 5. Recent Orders
      setRecentOrders(allOrders.slice(0, 6));

      // 6. Low stock items
      const { data: lowStock } = await supabase
        .from('menu_items')
        .select('*, menu_categories(name)')
        .eq('business_id', business.id)
        .lte('stock_quantity', 5)
        .order('stock_quantity', { ascending: true })
        .limit(5);

      setLowStockItems(lowStock || []);
    } catch (err) {
      console.error('Error in loadAnalytics:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAnalytics();
  }, [business?.id, selectedOutletId, timeRange]);

  if (shellLoading) {
    return (
      <div className="flex items-center justify-center min-h-[50vh]">
        <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Max value for chart scaling
  const maxChartValue =
    timeRange === 'today'
      ? Math.max(...hourlyData.map((d) => d.revenue), 100000)
      : Math.max(...dailyData.map((d) => d.revenue), 100000);

  return (
    <div className="space-y-6">
      {/* Header & Filter Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Executive Summary
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Dashboard Analitik Penjualan
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Performa omzet dan aktivitas transaksi bisnis Anda secara realtime
          </p>
        </div>

        {/* Timeframe Chips */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl overflow-x-auto text-xs font-bold text-slate-600">
          <button
            onClick={() => setTimeRange('today')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              timeRange === 'today'
                ? 'bg-orange-500 text-white shadow-xs'
                : 'hover:text-slate-900 hover:bg-slate-200/60'
            }`}
          >
            Hari Ini
          </button>
          <button
            onClick={() => setTimeRange('7days')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              timeRange === '7days'
                ? 'bg-orange-500 text-white shadow-xs'
                : 'hover:text-slate-900 hover:bg-slate-200/60'
            }`}
          >
            7 Hari
          </button>
          <button
            onClick={() => setTimeRange('30days')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              timeRange === '30days'
                ? 'bg-orange-500 text-white shadow-xs'
                : 'hover:text-slate-900 hover:bg-slate-200/60'
            }`}
          >
            30 Hari
          </button>
          <button
            onClick={() => setTimeRange('this_month')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              timeRange === 'this_month'
                ? 'bg-orange-500 text-white shadow-xs'
                : 'hover:text-slate-900 hover:bg-slate-200/60'
            }`}
          >
            Bulan Ini
          </button>
        </div>
      </div>

      {/* Top 4 Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total Omzet */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Total Omzet Bersih
            </span>
            <div className="w-8 h-8 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">
            {formatRupiah(metrics.totalRevenue)}
          </div>
          <div className="text-[11px] font-semibold text-emerald-600 mt-2 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5" />
            <span>{metrics.totalOrders} transaksi berhasil</span>
          </div>
        </div>

        {/* Total Transaksi */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Total Pesanan
            </span>
            <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <Receipt className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">
            {metrics.totalOrders}
          </div>
          <div className="text-[11px] font-semibold text-slate-500 mt-2 flex items-center gap-1">
            <ShoppingBag className="w-3.5 h-3.5" />
            <span>{metrics.totalItemsSold} produk terjual</span>
          </div>
        </div>

        {/* Average Order Value (AOV) */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Rata-rata Belanja (AOV)
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <Sparkles className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">
            {formatRupiah(metrics.averageOrderValue)}
          </div>
          <div className="text-[11px] font-semibold text-slate-500 mt-2">
            Nilai transaksi rata-rata per pelanggan
          </div>
        </div>

        {/* Estimasi Laba Kotor */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Estimasi Laba Kotor
            </span>
            <div className="w-8 h-8 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
              <Wallet className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">
            {formatRupiah(metrics.grossProfit)}
          </div>
          <div className="text-[11px] font-semibold text-purple-700 mt-2">
            {metrics.totalRevenue > 0
              ? `${Math.round((metrics.grossProfit / metrics.totalRevenue) * 100)}% Margin Penjualan`
              : 'Omzet dikurangi HPP'}
          </div>
        </div>
      </div>

      {/* Main Charts & Visualizations */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Sales Chart (2 cols) */}
        {/* Sales Chart (2 cols) */}
        <div className="lg:col-span-2 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4">
            <div>
              <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-orange-600" />
                <span>{timeRange === 'today' ? 'Aktivitas Penjualan Jam-ke-Jam' : 'Tren Penjualan Harian'}</span>
              </h3>
              <p className="text-xs text-slate-500">
                {timeRange === 'today'
                  ? 'Melihat jam-jam tersibuk (Peak Hours) toko Anda hari ini'
                  : 'Grafik interaktif perkembangan omzet harian'}
              </p>
            </div>
            <span className="text-[11px] font-bold text-slate-400 bg-slate-50 px-2.5 py-1 rounded-lg border border-slate-100 self-start sm:self-auto">
              Hover grafik untuk melihat omzet & transaksi
            </span>
          </div>

          {/* Interactive Recharts Component */}
          <RevenueTrendChart
            data={
              timeRange === 'today'
                ? hourlyData.map((d) => ({
                    label: `${d.hour}:00`,
                    revenue: d.revenue,
                    orderCount: d.orderCount,
                  }))
                : dailyData.map((d) => ({
                    label: d.label,
                    revenue: d.revenue,
                    orderCount: d.orderCount,
                  }))
            }
            isHourly={timeRange === 'today'}
          />
        </div>

        {/* Payment Methods Breakdown (1 col) */}
        <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-2">
              <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                <PieIcon className="w-4 h-4 text-blue-600" />
                <span>Metode Pembayaran</span>
              </h3>
              <span className="text-xs font-semibold text-slate-500">
                {paymentBreakdowns.length} Jenis
              </span>
            </div>
            <p className="text-xs text-slate-500 mb-3">
              Porsi pembayaran transaksi pelanggan
            </p>

            {/* Interactive Donut Chart */}
            <PaymentDistributionChart
              data={paymentBreakdowns.map((p) => ({
                name: p.label,
                value: p.amount,
                count: p.count,
              }))}
            />
          </div>

          <div className="pt-4 border-t border-slate-100 text-center">
            <Link
              href="/merchant/reports"
              className="text-xs font-bold text-orange-600 hover:text-orange-700 inline-flex items-center gap-1"
            >
              <span>Lihat Laporan Detail</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        </div>
      </div>

      {/* Bottom Grid: Top Products & Low Stock Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top 5 Best Sellers */}
        <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="font-bold text-slate-900 text-sm sm:text-base">
                Top 5 Produk Terlaris
              </h3>
              <p className="text-xs text-slate-500">
                Menu / produk dengan kontribusi penjualan terbesar
              </p>
            </div>
            <Link
              href="/merchant/products"
              className="text-xs font-bold text-orange-600 hover:text-orange-700"
            >
              Semua Produk
            </Link>
          </div>

          <div className="divide-y divide-slate-100">
            {topProducts.length === 0 ? (
              <div className="text-center py-8 text-xs text-slate-400">
                Belum ada produk terjual
              </div>
            ) : (
              topProducts.map((p, idx) => (
                <div key={p.id} className="py-3 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <span
                      className={`w-6 h-6 rounded-lg flex items-center justify-center text-xs font-black ${
                        idx === 0
                          ? 'bg-amber-100 text-amber-800'
                          : idx === 1
                          ? 'bg-slate-200 text-slate-700'
                          : idx === 2
                          ? 'bg-orange-100 text-orange-800'
                          : 'bg-slate-100 text-slate-500'
                      }`}
                    >
                      {idx + 1}
                    </span>
                    <div>
                      <span className="font-bold text-xs sm:text-sm text-slate-900 block">
                        {p.name}
                      </span>
                      <span className="text-[11px] text-slate-400">
                        {p.qty} unit terjual
                      </span>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="font-black text-xs sm:text-sm text-slate-900 block">
                      {formatRupiah(p.revenue)}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Low Stock Warning */}
        <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-lg bg-red-50 text-red-600 flex items-center justify-center">
                <AlertTriangle className="w-4 h-4" />
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-sm sm:text-base">
                  Peringatan Stok Menipis
                </h3>
                <p className="text-xs text-slate-500">
                  Item dengan sisa stok ≤ 5 unit
                </p>
              </div>
            </div>
            <Link
              href="/merchant/products"
              className="text-xs font-bold text-orange-600 hover:text-orange-700"
            >
              Kelola Stok
            </Link>
          </div>

          <div className="divide-y divide-slate-100">
            {lowStockItems.length === 0 ? (
              <div className="text-center py-8 text-xs text-slate-400">
                ✅ Semua stok produk dalam batas aman
              </div>
            ) : (
              lowStockItems.map((item) => (
                <div key={item.id} className="py-3 flex items-center justify-between">
                  <div>
                    <span className="font-bold text-xs sm:text-sm text-slate-900 block">
                      {item.name}
                    </span>
                    <span className="text-[11px] text-slate-400">
                      Harga: {formatRupiah(item.price)}
                    </span>
                  </div>
                  <div className="text-right">
                    <span
                      className={`inline-block px-2.5 py-1 rounded-lg text-xs font-black ${
                        (item.stock_quantity ?? item.stock ?? 0) === 0
                          ? 'bg-red-100 text-red-700'
                          : 'bg-amber-100 text-amber-700'
                      }`}
                    >
                      {(item.stock_quantity ?? item.stock ?? 0) === 0 ? 'Habis (0)' : `Sisa ${item.stock_quantity ?? item.stock ?? 0}`}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Recent Transactions Table */}
      <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="font-bold text-slate-900 text-sm sm:text-base">
              Transaksi Terkini
            </h3>
            <p className="text-xs text-slate-500">
              Daftar transaksi kasir dan pesanan online yang baru masuk
            </p>
          </div>
          <Link
            href="/merchant/transactions"
            className="text-xs font-bold text-orange-600 hover:text-orange-700 inline-flex items-center gap-1"
          >
            <span>Lihat Semua</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-2.5 px-3">No. Invoice</th>
                <th className="py-2.5 px-3">Waktu</th>
                <th className="py-2.5 px-3">Pelanggan / Meja</th>
                <th className="py-2.5 px-3">Metode Bayar</th>
                <th className="py-2.5 px-3">Status</th>
                <th className="py-2.5 px-3 text-right">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {recentOrders.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-400">
                    Belum ada riwayat transaksi
                  </td>
                </tr>
              ) : (
                recentOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-3 px-3 font-bold text-slate-900 font-mono">
                      {order.invoice_number}
                    </td>
                    <td className="py-3 px-3 text-slate-500">
                      {new Date(order.created_at).toLocaleTimeString('id-ID', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td className="py-3 px-3 font-medium text-slate-700">
                      {order.customer_name ||
                        (order.table_number ? `Meja ${order.table_number}` : 'Tamu Kasir')}
                    </td>
                    <td className="py-3 px-3">
                      <span className="capitalize px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 font-bold text-[10px]">
                        {order.payment_method || 'Cash'}
                      </span>
                    </td>
                    <td className="py-3 px-3">
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
                          ? 'Dikonfirmasi'
                          : order.status}
                      </span>
                    </td>
                    <td className="py-3 px-3 text-right font-black text-slate-900">
                      {formatRupiah(order.grand_total || order.total_amount || 0)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
