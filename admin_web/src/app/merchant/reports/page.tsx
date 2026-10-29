'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import * as XLSX from 'xlsx';
import dynamic from 'next/dynamic';
import {
  TrendingUp,
  DollarSign,
  Download,
  Calendar,
  Filter,
  Receipt,
  FileSpreadsheet,
  FileText,
  Building2,
  RefreshCw,
  CreditCard,
  QrCode,
  Banknote,
  PieChart as PieIcon,
  BarChart3,
} from 'lucide-react';

const FinancialComparisonChart = dynamic(
  () => import('@/components/merchant/charts/FinancialComparisonChart'),
  { ssr: false, loading: () => <div className="h-80 flex items-center justify-center text-slate-400 text-xs">Memuat grafik...</div> }
);

const PaymentDistributionChart = dynamic(
  () => import('@/components/merchant/charts/PaymentDistributionChart'),
  { ssr: false, loading: () => <div className="h-72 flex items-center justify-center text-slate-400 text-xs">Memuat grafik...</div> }
);

const OutletComparisonChart = dynamic(
  () => import('@/components/merchant/charts/OutletComparisonChart'),
  { ssr: false, loading: () => <div className="h-72 flex items-center justify-center text-slate-400 text-xs">Memuat grafik...</div> }
);

export default function MerchantReportsPage() {
  const { business, selectedOutletId, outlets, loading: shellLoading } = useMerchant();

  const [dateRange, setDateRange] = useState<'today' | 'yesterday' | '7days' | 'this_month' | 'last_month'>('this_month');
  const [loading, setLoading] = useState(true);

  const [dailyFinancialData, setDailyFinancialData] = useState<{
    label: string;
    gross: number;
    net: number;
    discount: number;
    tax: number;
  }[]>([]);

  const [reportData, setReportData] = useState<{
    totalGrossRevenue: number;
    totalDiscount: number;
    totalTax: number;
    totalNetRevenue: number;
    totalOrders: number;
    paymentBreakdowns: Record<string, { count: number; total: number }>;
    outletBreakdowns: Record<string, { name: string; count: number; total: number }>;
  }>({
    totalGrossRevenue: 0,
    totalDiscount: 0,
    totalTax: 0,
    totalNetRevenue: 0,
    totalOrders: 0,
    paymentBreakdowns: {},
    outletBreakdowns: {},
  });

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadReport = async () => {
    if (!business) return;

    try {
      setLoading(true);
      const supabase = createClient();

      const now = new Date();
      let start = new Date();
      let end = new Date();

      if (dateRange === 'today') {
        start.setHours(0, 0, 0, 0);
        end.setHours(23, 59, 59, 999);
      } else if (dateRange === 'yesterday') {
        start.setDate(now.getDate() - 1);
        start.setHours(0, 0, 0, 0);
        end.setDate(now.getDate() - 1);
        end.setHours(23, 59, 59, 999);
      } else if (dateRange === '7days') {
        start.setDate(now.getDate() - 7);
        start.setHours(0, 0, 0, 0);
      } else if (dateRange === 'this_month') {
        start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      } else if (dateRange === 'last_month') {
        start = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0);
        end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
      }

      let query = supabase
        .from('orders')
        .select('*, outlets(id, name), order_payments(*)')
        .eq('business_id', business.id)
        .gte('created_at', start.toISOString())
        .lte('created_at', end.toISOString())
        .in('status', ['paid', 'confirmed']);

      if (selectedOutletId !== 'all') {
        query = query.eq('outlet_id', selectedOutletId);
      }

      const { data: orders, error } = await query;
      if (error) {
        console.error('Error fetching report:', error);
        return;
      }

      let gross = 0;
      let discount = 0;
      let tax = 0;
      let net = 0;
      const paymentMap: Record<string, { count: number; total: number }> = {};
      const outletMap: Record<string, { name: string; count: number; total: number }> = {};
      const dailyFinMap: Record<string, { label: string; gross: number; net: number; discount: number; tax: number }> = {};

      (orders || []).forEach((o: any) => {
        const orderTotal = Number(o.grand_total || o.total_amount || 0);
        const d = Number(o.discount_total || 0);
        const t = Number(o.tax_amount || 0);
        const itemGross = o.subtotal ? Number(o.subtotal) : orderTotal;

        gross += itemGross;
        discount += d;
        tax += t;
        net += orderTotal;

        // Daily chart points
        const dObj = new Date(o.created_at);
        const dKey = dObj.toISOString().split('T')[0];
        const dLabel = dObj.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
        if (!dailyFinMap[dKey]) {
          dailyFinMap[dKey] = { label: dLabel, gross: 0, net: 0, discount: 0, tax: 0 };
        }
        dailyFinMap[dKey].gross += itemGross;
        dailyFinMap[dKey].net += orderTotal;
        dailyFinMap[dKey].discount += d;
        dailyFinMap[dKey].tax += t;

        // Payment map
        let method = (o.payment_method || '').toLowerCase();
        if (!method && o.order_payments && o.order_payments.length > 0) {
          method = (o.order_payments[0].method_name || o.order_payments[0].method_type || 'cash').toLowerCase();
        }
        if (!method) method = 'cash';
        if (!paymentMap[method]) paymentMap[method] = { count: 0, total: 0 };
        paymentMap[method].count += 1;
        paymentMap[method].total += orderTotal;

        // Outlet map
        const oId = o.outlet_id || 'default';
        const oName = o.outlets?.name || 'Utama';
        if (!outletMap[oId]) outletMap[oId] = { name: oName, count: 0, total: 0 };
        outletMap[oId].count += 1;
        outletMap[oId].total += orderTotal;
      });

      const chartPoints = Object.keys(dailyFinMap)
        .sort()
        .map((k) => dailyFinMap[k]);
      setDailyFinancialData(chartPoints);

      setReportData({
        totalGrossRevenue: gross,
        totalDiscount: discount,
        totalTax: tax,
        totalNetRevenue: net,
        totalOrders: orders?.length || 0,
        paymentBreakdowns: paymentMap,
        outletBreakdowns: outletMap,
      });
    } catch (err) {
      console.error('Report error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadReport();
  }, [business?.id, selectedOutletId, dateRange]);

  // Export Report to Excel
  const handleExportReportExcel = () => {
    const summaryData = [
      { Indikator: 'Nama Bisnis', Nilai: business?.name || 'DPOS' },
      { Indikator: 'Periode Laporan', Nilai: dateRange },
      { Indikator: 'Total Transaksi Sukses', Nilai: reportData.totalOrders },
      { Indikator: 'Penjualan Kotor (Subtotal)', Nilai: reportData.totalGrossRevenue },
      { Indikator: 'Total Potongan Diskon', Nilai: reportData.totalDiscount },
      { Indikator: 'Total Pajak (PB1)', Nilai: reportData.totalTax },
      { Indikator: 'Total Penjualan Bersih (Omzet)', Nilai: reportData.totalNetRevenue },
    ];

    const paymentRows = Object.entries(reportData.paymentBreakdowns).map(([method, val]) => ({
      'Metode Pembayaran': method.toUpperCase(),
      'Jumlah Transaksi': val.count,
      'Total Nominal (Rp)': val.total,
    }));

    const workbook = XLSX.utils.book_new();
    const sheet1 = XLSX.utils.json_to_sheet(summaryData);
    const sheet2 = XLSX.utils.json_to_sheet(paymentRows);

    XLSX.utils.book_append_sheet(workbook, sheet1, 'Ringkasan Keuangan');
    XLSX.utils.book_append_sheet(workbook, sheet2, 'Metode Pembayaran');

    const fileName = `Laporan_Keuangan_${business?.name || 'DPOS'}_${dateRange}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Audit & Pembukuan
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Laporan Keuangan & Penjualan
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Rekap omzet bersih, potongan diskon, pajak, dan rincian kas toko Anda
          </p>
        </div>

        <button
          onClick={handleExportReportExcel}
          className="px-4 py-2 text-xs font-bold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white flex items-center gap-1.5 shadow-sm shadow-emerald-600/20 transition-all self-start sm:self-auto"
        >
          <FileSpreadsheet className="w-4 h-4" />
          <span>Download Excel</span>
        </button>
      </div>

      {/* Date Filter Tabs */}
      <div className="flex p-1.5 bg-slate-100 rounded-2xl overflow-x-auto text-xs font-bold text-slate-600 gap-1">
        <button
          onClick={() => setDateRange('today')}
          className={`px-4 py-2 rounded-xl transition-all ${
            dateRange === 'today' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
          }`}
        >
          Hari Ini
        </button>
        <button
          onClick={() => setDateRange('yesterday')}
          className={`px-4 py-2 rounded-xl transition-all ${
            dateRange === 'yesterday' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
          }`}
        >
          Kemarin
        </button>
        <button
          onClick={() => setDateRange('7days')}
          className={`px-4 py-2 rounded-xl transition-all ${
            dateRange === '7days' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
          }`}
        >
          7 Hari Terakhir
        </button>
        <button
          onClick={() => setDateRange('this_month')}
          className={`px-4 py-2 rounded-xl transition-all ${
            dateRange === 'this_month' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
          }`}
        >
          Bulan Ini
        </button>
        <button
          onClick={() => setDateRange('last_month')}
          className={`px-4 py-2 rounded-xl transition-all ${
            dateRange === 'last_month' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
          }`}
        >
          Bulan Lalu
        </button>
      </div>

      {/* Financial Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Penjualan Bersih */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
            Penjualan Bersih (Net Revenue)
          </span>
          <div className="text-2xl font-black text-orange-600">
            {formatRupiah(reportData.totalNetRevenue)}
          </div>
          <span className="text-[11px] text-slate-400 mt-2 block">
            {reportData.totalOrders} transaksi berhasil
          </span>
        </div>

        {/* Penjualan Kotor */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
            Penjualan Kotor (Subtotal)
          </span>
          <div className="text-2xl font-black text-slate-900">
            {formatRupiah(reportData.totalGrossRevenue)}
          </div>
          <span className="text-[11px] text-slate-400 mt-2 block">
            Sebelum potongan diskon
          </span>
        </div>

        {/* Total Diskon */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
            Total Diskon Diberikan
          </span>
          <div className="text-2xl font-black text-red-600">
            - {formatRupiah(reportData.totalDiscount)}
          </div>
          <span className="text-[11px] text-slate-400 mt-2 block">
            Promo item & voucher
          </span>
        </div>

        {/* Total Pajak */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
            Pajak Resto / PB1
          </span>
          <div className="text-2xl font-black text-blue-600">
            {formatRupiah(reportData.totalTax)}
          </div>
          <span className="text-[11px] text-slate-400 mt-2 block">
            Kewajiban pajak tercatat
          </span>
        </div>
      </div>

      {/* Interactive Financial Trend Chart */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4">
          <div>
            <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
              <BarChart3 className="w-4 h-4 text-orange-600" />
              <span>Grafik Komparasi Finansial Interaktif</span>
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Perbandingan penjualan bersih, penjualan kotor, potongan diskon, dan pajak per hari
            </p>
          </div>
          <span className="text-[11px] font-bold text-slate-400 bg-slate-50 px-2.5 py-1 rounded-lg border border-slate-100 self-start sm:self-auto">
            Hover balok grafik untuk melihat detail angka
          </span>
        </div>
        <FinancialComparisonChart data={dailyFinancialData} />
      </div>

      {/* Two Column Grid: Payment Breakdown & Outlet Breakdown with Interactive Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Payment Methods Chart & Table */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                <PieIcon className="w-4 h-4 text-blue-600" />
                <span>Distribusi Metode Pembayaran</span>
              </h3>
              <span className="text-xs font-semibold text-slate-500">
                {Object.keys(reportData.paymentBreakdowns).length} Metode
              </span>
            </div>

            {/* Interactive Donut Chart */}
            <PaymentDistributionChart
              data={Object.entries(reportData.paymentBreakdowns).map(([name, val]) => ({
                name,
                value: val.total,
                count: val.count,
              }))}
            />
          </div>

          <div className="divide-y divide-slate-100 mt-4 border-t border-slate-100 pt-2">
            {Object.entries(reportData.paymentBreakdowns).length === 0 ? (
              <div className="text-center py-6 text-xs text-slate-400">
                Belum ada data pembayaran di periode ini
              </div>
            ) : (
              Object.entries(reportData.paymentBreakdowns).map(([method, val]) => (
                <div key={method} className="py-2.5 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2.5">
                    {method.includes('qris') ? (
                      <QrCode className="w-4 h-4 text-blue-600" />
                    ) : method.includes('transfer') ? (
                      <CreditCard className="w-4 h-4 text-purple-600" />
                    ) : (
                      <Banknote className="w-4 h-4 text-emerald-600" />
                    )}
                    <div>
                      <span className="font-bold text-slate-800 capitalize block">
                        {method}
                      </span>
                      <span className="text-[11px] text-slate-400">
                        {val.count} kali transaksi
                      </span>
                    </div>
                  </div>
                  <span className="font-black text-slate-900">
                    {formatRupiah(val.total)}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Outlet Breakdown Chart & Table */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                <Building2 className="w-4 h-4 text-orange-600" />
                <span>Performa Penjualan Antar-Outlet</span>
              </h3>
              <span className="text-xs font-semibold text-slate-500">
                {Object.keys(reportData.outletBreakdowns).length} Outlet Aktif
              </span>
            </div>

            {/* Interactive Outlet Bar Chart */}
            <OutletComparisonChart
              data={Object.values(reportData.outletBreakdowns).map((val) => ({
                name: val.name,
                revenue: val.total,
                orders: val.count,
              }))}
            />
          </div>

          <div className="divide-y divide-slate-100 mt-4 border-t border-slate-100 pt-2">
            {Object.entries(reportData.outletBreakdowns).length === 0 ? (
              <div className="text-center py-6 text-xs text-slate-400">
                Belum ada data outlet di periode ini
              </div>
            ) : (
              Object.entries(reportData.outletBreakdowns).map(([oId, val]) => (
                <div key={oId} className="py-2.5 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2.5">
                    <Building2 className="w-4 h-4 text-orange-600" />
                    <div>
                      <span className="font-bold text-slate-800 block">{val.name}</span>
                      <span className="text-[11px] text-slate-400">
                        {val.count} pesanan
                      </span>
                    </div>
                  </div>
                  <span className="font-black text-slate-900">
                    {formatRupiah(val.total)}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
