'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Business, Order } from '@/types/database';
import {
  Building2,
  X,
  Crown,
  Store,
  Clock,
  Phone,
  Mail,
  MapPin,
  Calendar,
  Layers,
  ShoppingBag,
  TrendingUp,
  Receipt,
  DollarSign,
  CreditCard,
  CheckCircle2,
  XCircle,
  RotateCcw,
  Sliders,
  ExternalLink,
  MessageCircle,
  Copy,
  Check,
  BarChart3,
  User,
  ArrowUpRight,
  ShieldCheck,
} from 'lucide-react';

interface BusinessProfileModalProps {
  business: Business | null;
  onClose: () => void;
  onOpenPlanModal?: (biz: Business) => void;
  onOpenTemplateModal?: (biz: Business) => void;
  onOpenLimitsModal?: (biz: Business) => void;
}

interface OutletInfo {
  id: string;
  name: string;
  address?: string | null;
  phone?: string | null;
  created_at?: string;
}

export default function BusinessProfileModal({
  business,
  onClose,
  onOpenPlanModal,
  onOpenTemplateModal,
  onOpenLimitsModal,
}: BusinessProfileModalProps) {
  const [activeTab, setActiveTab] = useState<'sales' | 'profile' | 'orders'>('sales');
  const [loading, setLoading] = useState<boolean>(true);
  const [orders, setOrders] = useState<Order[]>([]);
  const [outlets, setOutlets] = useState<OutletInfo[]>([]);
  const [productCount, setProductCount] = useState<number>(0);
  const [copiedId, setCopiedId] = useState<boolean>(false);

  const supabase = createClient();

  useEffect(() => {
    if (!business) return;

    let isMounted = true;
    const fetchBusinessMetrics = async () => {
      setLoading(true);

      const [ordersRes, outletsRes, productsRes] = await Promise.all([
        supabase
          .from('orders')
          .select(`
            id,
            business_id,
            outlet_id,
            invoice_number,
            customer_name,
            customer_phone,
            status,
            subtotal,
            discount_total,
            tax_amount,
            grand_total,
            paid_amount,
            change_amount,
            created_at,
            paid_at,
            order_payments (
              id,
              method_name,
              method_type,
              amount
            )
          `)
          .eq('business_id', business.id)
          .order('created_at', { ascending: false })
          .limit(100),
        supabase
          .from('outlets')
          .select('id, name, address, phone, created_at')
          .eq('business_id', business.id),
        supabase
          .from('menu_items')
          .select('id', { count: 'exact', head: true })
          .eq('business_id', business.id),
      ]);

      if (isMounted) {
        if (!ordersRes.error && ordersRes.data) {
          setOrders(ordersRes.data as unknown as Order[]);
        }
        if (!outletsRes.error && outletsRes.data) {
          setOutlets(outletsRes.data as OutletInfo[]);
        }
        if (productsRes.count !== null && productsRes.count !== undefined) {
          setProductCount(productsRes.count);
        }
        setLoading(false);
      }
    };

    fetchBusinessMetrics();

    return () => {
      isMounted = false;
    };
  }, [business]);

  if (!business) return null;

  const isPro = business.subscription_plans?.code === 'pro';
  const hasEndAt = !!business.subscription_end_at;
  const endAtFormatted = hasEndAt
    ? new Date(business.subscription_end_at!).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      })
    : 'Lifetime';

  const createdAtFormatted = business.created_at
    ? new Date(business.created_at).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
    : '-';

  // --- Calculations for Sales Summary ---
  const paidOrders = orders.filter((o) => o.status === 'paid');
  const voidOrders = orders.filter((o) => o.status === 'void');
  const refundOrders = orders.filter((o) => o.status === 'refunded');
  const draftOrders = orders.filter((o) => o.status === 'draft');

  const totalGMV = paidOrders.reduce((acc, o) => acc + (o.grand_total || 0), 0);
  const totalDiscounts = paidOrders.reduce((acc, o) => acc + (o.discount_total || 0), 0);
  const avgOrderValue = paidOrders.length > 0 ? Math.round(totalGMV / paidOrders.length) : 0;

  // Today Sales
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const todayPaidOrders = paidOrders.filter((o) => new Date(o.created_at) >= startOfToday);
  const todayGMV = todayPaidOrders.reduce((acc, o) => acc + (o.grand_total || 0), 0);

  // 30 Days Sales
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const thirtyDaysPaidOrders = paidOrders.filter((o) => new Date(o.created_at) >= thirtyDaysAgo);
  const thirtyDaysGMV = thirtyDaysPaidOrders.reduce((acc, o) => acc + (o.grand_total || 0), 0);

  // Payment Breakdown
  const paymentBreakdown: Record<string, { count: number; total: number }> = {};
  paidOrders.forEach((o) => {
    if (o.order_payments && o.order_payments.length > 0) {
      o.order_payments.forEach((p) => {
        const name = p.method_name || p.method_type || 'Tunai';
        if (!paymentBreakdown[name]) {
          paymentBreakdown[name] = { count: 0, total: 0 };
        }
        paymentBreakdown[name].count += 1;
        paymentBreakdown[name].total += p.amount || 0;
      });
    } else {
      const name = 'Tunai (Cash)';
      if (!paymentBreakdown[name]) {
        paymentBreakdown[name] = { count: 0, total: 0 };
      }
      paymentBreakdown[name].count += 1;
      paymentBreakdown[name].total += o.grand_total || 0;
    }
  });

  const paymentList = Object.entries(paymentBreakdown).sort((a, b) => b[1].total - a[1].total);

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(val);
  };

  const copyBusinessId = () => {
    if (!business.id) return;
    navigator.clipboard.writeText(business.id);
    setCopiedId(true);
    setTimeout(() => setCopiedId(false), 2000);
  };

  const cleanPhone = (business.phone || business.profiles?.phone || '').replace(/[^0-9]/g, '');
  const waNumber = cleanPhone.startsWith('0')
    ? '62' + cleanPhone.slice(1)
    : cleanPhone.startsWith('62')
    ? cleanPhone
    : cleanPhone ? '62' + cleanPhone : '';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 md:p-6 bg-slate-900/50 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="bg-white w-full max-w-4xl max-h-[92vh] rounded-3xl border border-slate-200 shadow-2xl flex flex-col overflow-hidden">
        {/* ======================================================== */}
        {/* MODAL HEADER                                             */}
        {/* ======================================================== */}
        <div className="px-6 py-5 border-b border-slate-100 flex items-start justify-between bg-gradient-to-r from-slate-50 via-white to-orange-50/30">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-orange-500 to-amber-600 text-white font-extrabold text-2xl flex items-center justify-center shadow-md shadow-orange-500/20 flex-shrink-0">
              {business.name?.charAt(0)?.toUpperCase() || 'B'}
            </div>
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-xl font-bold text-slate-900 tracking-tight">
                  {business.name}
                </h2>
                {isPro ? (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-extrabold bg-amber-100 text-amber-800 border border-amber-200 flex items-center gap-1 shadow-2xs">
                    <Crown className="w-3.5 h-3.5 text-amber-600" /> PRO PLAN
                  </span>
                ) : (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-600 border border-slate-200 flex items-center gap-1">
                    <Store className="w-3.5 h-3.5 text-slate-500" /> FREE PLAN
                  </span>
                )}
                <span className="px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600 border border-slate-200 flex items-center gap-1">
                  <Layers className="w-3 h-3 text-slate-500" /> {business.business_type || 'default'}
                </span>
              </div>

              <div className="flex flex-wrap items-center gap-x-4 gap-y-1 mt-1.5 text-xs text-slate-500">
                <div className="flex items-center gap-1">
                  <User className="w-3.5 h-3.5 text-slate-400" />
                  <span className="font-semibold text-slate-700">
                    {business.profiles?.full_name || 'Owner Bisnis'}
                  </span>
                  <span>({business.profiles?.email || '-'})</span>
                </div>
                <div className="flex items-center gap-1 text-slate-400">
                  <span>ID:</span>
                  <code className="font-mono text-[11px] text-slate-600 bg-slate-100 px-1 py-0.5 rounded">
                    {business.id.slice(0, 8)}...
                  </code>
                  <button
                    onClick={copyBusinessId}
                    className="hover:text-slate-900 transition-colors p-0.5"
                    title="Salin Business ID Lengkap"
                  >
                    {copiedId ? (
                      <Check className="w-3 h-3 text-emerald-500" />
                    ) : (
                      <Copy className="w-3 h-3 text-slate-400 hover:text-slate-700" />
                    )}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* ======================================================== */}
        {/* NAVIGATION TABS                                          */}
        {/* ======================================================== */}
        <div className="flex items-center gap-2 px-6 border-b border-slate-100 bg-slate-50/50">
          <button
            onClick={() => setActiveTab('sales')}
            className={`flex items-center gap-2 py-3.5 px-4 text-xs font-bold border-b-2 transition-all ${
              activeTab === 'sales'
                ? 'border-orange-500 text-orange-600 bg-white'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <BarChart3 className="w-4 h-4" />
            <span>Ringkasan Penjualan (Sales Summary)</span>
          </button>
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex items-center gap-2 py-3.5 px-4 text-xs font-bold border-b-2 transition-all ${
              activeTab === 'profile'
                ? 'border-orange-500 text-orange-600 bg-white'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <Building2 className="w-4 h-4" />
            <span>Profil Bisnis & Owner</span>
          </button>
          <button
            onClick={() => setActiveTab('orders')}
            className={`flex items-center gap-2 py-3.5 px-4 text-xs font-bold border-b-2 transition-all ${
              activeTab === 'orders'
                ? 'border-orange-500 text-orange-600 bg-white'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <Receipt className="w-4 h-4" />
            <span>Transaksi Terakhir ({orders.length})</span>
          </button>
        </div>

        {/* ======================================================== */}
        {/* MODAL BODY (CONTENT BY TAB)                              */}
        {/* ======================================================== */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {loading ? (
            <div className="text-center py-20">
              <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
              <p className="text-sm text-slate-500">Menghitung metrik performa penjualan bisnis...</p>
            </div>
          ) : (
            <>
              {/* TAB 1: SALES SUMMARY */}
              {activeTab === 'sales' && (
                <div className="space-y-6">
                  {/* Top 4 KPI Cards */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    {/* GMV Total */}
                    <div className="bg-gradient-to-br from-emerald-50 to-emerald-100/50 p-4 rounded-2xl border border-emerald-200">
                      <div className="flex items-center justify-between text-emerald-700 mb-2">
                        <span className="text-xs font-bold uppercase tracking-wider">Total Omzet (GMV)</span>
                        <DollarSign className="w-4 h-4" />
                      </div>
                      <div className="text-xl font-extrabold text-slate-900">
                        {formatRupiah(totalGMV)}
                      </div>
                      <p className="text-[11px] text-emerald-800/80 mt-1">
                        Dari {paidOrders.length} transaksi berstatus lunas
                      </p>
                    </div>

                    {/* Transaksi Lunas */}
                    <div className="bg-gradient-to-br from-blue-50 to-blue-100/50 p-4 rounded-2xl border border-blue-200">
                      <div className="flex items-center justify-between text-blue-700 mb-2">
                        <span className="text-xs font-bold uppercase tracking-wider">Transaksi Sukses</span>
                        <CheckCircle2 className="w-4 h-4" />
                      </div>
                      <div className="text-xl font-extrabold text-slate-900">
                        {paidOrders.length}{' '}
                        <span className="text-xs font-normal text-slate-500">Order</span>
                      </div>
                      <p className="text-[11px] text-blue-800/80 mt-1">
                        Total {orders.length} pesanan dicatat
                      </p>
                    </div>

                    {/* Average Order Value (AOV) */}
                    <div className="bg-gradient-to-br from-purple-50 to-purple-100/50 p-4 rounded-2xl border border-purple-200">
                      <div className="flex items-center justify-between text-purple-700 mb-2">
                        <span className="text-xs font-bold uppercase tracking-wider">Rata-rata Nota</span>
                        <TrendingUp className="w-4 h-4" />
                      </div>
                      <div className="text-xl font-extrabold text-slate-900">
                        {formatRupiah(avgOrderValue)}
                      </div>
                      <p className="text-[11px] text-purple-800/80 mt-1">
                        Nilai rata-rata per transaksi kasir
                      </p>
                    </div>

                    {/* Omzet 30 Hari Terakhir */}
                    <div className="bg-gradient-to-br from-orange-50 to-orange-100/50 p-4 rounded-2xl border border-orange-200">
                      <div className="flex items-center justify-between text-orange-700 mb-2">
                        <span className="text-xs font-bold uppercase tracking-wider">Omzet 30 Hari</span>
                        <Calendar className="w-4 h-4" />
                      </div>
                      <div className="text-xl font-extrabold text-slate-900">
                        {formatRupiah(thirtyDaysGMV)}
                      </div>
                      <p className="text-[11px] text-orange-800/80 mt-1">
                        Hari ini: {formatRupiah(todayGMV)} ({todayPaidOrders.length} order)
                      </p>
                    </div>
                  </div>

                  {/* Status Breakdown & Payment Methods */}
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
                    {/* Status Transaksi Breakdown */}
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                      <h3 className="text-sm font-bold text-slate-900 mb-4 flex items-center gap-2">
                        <Receipt className="w-4 h-4 text-orange-600" />
                        Status Seluruh Pesanan
                      </h3>

                      <div className="grid grid-cols-2 gap-3">
                        <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-100">
                          <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-800">
                            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                            Lunas (Paid)
                          </div>
                          <div className="text-lg font-extrabold text-emerald-950 mt-1">
                            {paidOrders.length}
                          </div>
                          <div className="text-[11px] text-emerald-700/80">
                            {formatRupiah(totalGMV)}
                          </div>
                        </div>

                        <div className="p-3 rounded-xl bg-rose-50 border border-rose-100">
                          <div className="flex items-center gap-1.5 text-xs font-bold text-rose-800">
                            <XCircle className="w-3.5 h-3.5 text-rose-600" />
                            Dibatalkan (Void)
                          </div>
                          <div className="text-lg font-extrabold text-rose-950 mt-1">
                            {voidOrders.length}
                          </div>
                          <div className="text-[11px] text-rose-700/80">Transaksi dibatalkan kasir</div>
                        </div>

                        <div className="p-3 rounded-xl bg-amber-50 border border-amber-100">
                          <div className="flex items-center gap-1.5 text-xs font-bold text-amber-800">
                            <RotateCcw className="w-3.5 h-3.5 text-amber-600" />
                            Refund
                          </div>
                          <div className="text-lg font-extrabold text-amber-950 mt-1">
                            {refundOrders.length}
                          </div>
                          <div className="text-[11px] text-amber-700/80">Pengembalian dana</div>
                        </div>

                        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200">
                          <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700">
                            <Clock className="w-3.5 h-3.5 text-slate-500" />
                            Draft / Menggantung
                          </div>
                          <div className="text-lg font-extrabold text-slate-900 mt-1">
                            {draftOrders.length}
                          </div>
                          <div className="text-[11px] text-slate-500">Order belum dibayar</div>
                        </div>
                      </div>

                      {totalDiscounts > 0 && (
                        <div className="mt-4 p-3 rounded-xl bg-slate-50 text-xs text-slate-600 flex items-center justify-between border border-slate-200">
                          <span>Total Potongan Diskon Diberikan:</span>
                          <span className="font-bold text-slate-900">{formatRupiah(totalDiscounts)}</span>
                        </div>
                      )}
                    </div>

                    {/* Metode Pembayaran Populer */}
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                      <h3 className="text-sm font-bold text-slate-900 mb-4 flex items-center gap-2">
                        <CreditCard className="w-4 h-4 text-orange-600" />
                        Metode Pembayaran
                      </h3>

                      {paymentList.length === 0 ? (
                        <div className="text-center py-10 text-slate-400 text-xs">
                          Belum ada data pembayaran transaksi.
                        </div>
                      ) : (
                        <div className="space-y-3">
                          {paymentList.map(([method, data]) => {
                            const percent = totalGMV > 0 ? Math.round((data.total / totalGMV) * 100) : 0;
                            return (
                              <div key={method} className="space-y-1.5">
                                <div className="flex items-center justify-between text-xs">
                                  <span className="font-semibold text-slate-800">{method}</span>
                                  <div className="flex items-center gap-2 font-mono">
                                    <span className="text-slate-500 text-[11px]">{data.count} tx</span>
                                    <span className="font-bold text-slate-900">{formatRupiah(data.total)}</span>
                                    <span className="text-orange-600 font-bold text-[11px]">({percent}%)</span>
                                  </div>
                                </div>
                                <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                                  <div
                                    className="bg-orange-500 h-2 rounded-full transition-all"
                                    style={{ width: `${percent}%` }}
                                  />
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Link ke Halaman Transaksi */}
                  <div className="p-4 rounded-2xl bg-orange-50/60 border border-orange-200/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                    <div className="text-xs text-orange-950">
                      <div className="font-bold flex items-center gap-1.5">
                        <Receipt className="w-4 h-4 text-orange-600" />
                        Ingin mengecek seluruh riwayat transaksi bisnis ini secara realtime?
                      </div>
                      <p className="text-orange-800/80 mt-0.5">
                        Anda dapat memeriksa detail nota, daftar item belanja, dan invoice lengkap di menu Transaksi.
                      </p>
                    </div>
                    <Link
                      href={`/dashboard/transactions?q=${encodeURIComponent(business.name)}`}
                      className="px-3.5 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold flex items-center gap-1.5 shadow-xs transition-colors flex-shrink-0"
                    >
                      <span>Lihat di Menu Transaksi</span>
                      <ArrowUpRight className="w-3.5 h-3.5" />
                    </Link>
                  </div>
                </div>
              )}

              {/* TAB 2: PROFIL BISNIS & OWNER */}
              {activeTab === 'profile' && (
                <div className="space-y-6">
                  {/* Grid Data Pemilik & Usaha */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                    {/* Kartu Profil Pemilik */}
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                      <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 border-b border-slate-100 pb-3">
                        <User className="w-4 h-4 text-orange-600" />
                        Informasi Pemilik (Owner)
                      </h3>

                      <div className="space-y-3 text-xs">
                        <div>
                          <div className="text-slate-400">Nama Lengkap:</div>
                          <div className="font-bold text-slate-900 text-sm mt-0.5">
                            {business.profiles?.full_name || 'Tidak dicantumkan'}
                          </div>
                        </div>

                        <div>
                          <div className="text-slate-400">Email Akun:</div>
                          <div className="font-medium text-slate-800 flex items-center gap-1.5 mt-0.5">
                            <Mail className="w-3.5 h-3.5 text-slate-400" />
                            <a
                              href={`mailto:${business.profiles?.email || business.email}`}
                              className="text-orange-600 hover:underline"
                            >
                              {business.profiles?.email || business.email || '-'}
                            </a>
                          </div>
                        </div>

                        <div>
                          <div className="text-slate-400">Nomor Telepon / WhatsApp:</div>
                          <div className="flex items-center gap-2 mt-0.5">
                            <Phone className="w-3.5 h-3.5 text-slate-400" />
                            <span className="font-semibold text-slate-800">
                              {business.phone || business.profiles?.phone || '-'}
                            </span>
                            {waNumber && (
                              <a
                                href={`https://wa.me/${waNumber}`}
                                target="_blank"
                                rel="noreferrer"
                                className="px-2 py-0.5 rounded-md bg-emerald-100 hover:bg-emerald-200 text-emerald-800 font-bold text-[10px] flex items-center gap-1 transition-colors"
                              >
                                <MessageCircle className="w-3 h-3 text-emerald-600" /> Hubungi WA
                              </a>
                            )}
                          </div>
                        </div>

                        <div>
                          <div className="text-slate-400">User ID (Auth UID):</div>
                          <code className="font-mono text-[11px] text-slate-600 bg-slate-100 px-2 py-1 rounded block mt-0.5 break-all">
                            {business.owner_user_id}
                          </code>
                        </div>
                      </div>
                    </div>

                    {/* Kartu Profil Toko & Usaha */}
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                      <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 border-b border-slate-100 pb-3">
                        <Store className="w-4 h-4 text-orange-600" />
                        Identitas Usaha & Lokasi
                      </h3>

                      <div className="space-y-3 text-xs">
                        <div>
                          <div className="text-slate-400">Nama Bisnis:</div>
                          <div className="font-bold text-slate-900 text-sm mt-0.5">{business.name}</div>
                        </div>

                        <div>
                          <div className="text-slate-400">Tipe Template Usaha:</div>
                          <div className="font-semibold text-slate-800 flex items-center gap-1.5 mt-0.5">
                            <Layers className="w-3.5 h-3.5 text-slate-400" />
                            <span className="uppercase">{business.business_type || 'default'}</span>
                          </div>
                        </div>

                        <div>
                          <div className="text-slate-400">Alamat Usaha:</div>
                          <div className="text-slate-800 flex items-start gap-1.5 mt-0.5">
                            <MapPin className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                            <span>{business.address || 'Alamat belum diatur'}</span>
                          </div>
                        </div>

                        <div>
                          <div className="text-slate-400">Terdaftar Sejak:</div>
                          <div className="font-medium text-slate-700 flex items-center gap-1.5 mt-0.5">
                            <Calendar className="w-3.5 h-3.5 text-slate-400" />
                            <span>{createdAtFormatted}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Penggunaan Kuota & Limit Toko */}
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                    <h3 className="text-sm font-bold text-slate-900 mb-4 flex items-center justify-between border-b border-slate-100 pb-3">
                      <div className="flex items-center gap-2">
                        <ShieldCheck className="w-4 h-4 text-orange-600" />
                        Status Langganan & Kapasitas Kuota
                      </div>
                      <span className="text-xs font-semibold text-slate-500">
                        Masa Aktif: <strong className="text-slate-900">{endAtFormatted}</strong>
                      </span>
                    </h3>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      {/* Outlets */}
                      <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                        <div className="text-xs text-slate-500">Jumlah Outlet / Cabang:</div>
                        <div className="text-xl font-extrabold text-slate-900 mt-1">
                          {outlets.length}{' '}
                          <span className="text-xs font-normal text-slate-500">
                            / {business.max_outlets ?? 1} maks
                          </span>
                        </div>
                        <div className="text-[11px] text-slate-500 mt-1">
                          {outlets.length > 0 ? outlets.map((o) => o.name).join(', ') : 'Belum ada outlet'}
                        </div>
                      </div>

                      {/* Products */}
                      <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                        <div className="text-xs text-slate-500">Katalog Produk Menu:</div>
                        <div className="text-xl font-extrabold text-slate-900 mt-1">
                          {productCount}{' '}
                          <span className="text-xs font-normal text-slate-500">
                            / {business.max_products && business.max_products > 10000 ? 'Unlimited' : business.max_products ?? 50} maks
                          </span>
                        </div>
                        <div className="text-[11px] text-slate-500 mt-1">Produk terdaftar di toko</div>
                      </div>

                      {/* Transactions */}
                      <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                        <div className="text-xs text-slate-500">Batas Transaksi:</div>
                        <div className="text-xl font-extrabold text-slate-900 mt-1">
                          {business.max_transactions && business.max_transactions > 10000
                            ? 'Unlimited'
                            : `${business.max_transactions ?? 100} /bln`}
                        </div>
                        <div className="text-[11px] text-slate-500 mt-1">
                          Terpakai: {paidOrders.length} transaksi tercatat
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 3: RIWAYAT TRANSAKSI TERAKHIR */}
              {activeTab === 'orders' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-bold text-slate-900">
                      10 Transaksi Kasir Terbaru
                    </h3>
                    <Link
                      href={`/dashboard/transactions?q=${encodeURIComponent(business.name)}`}
                      className="text-xs text-orange-600 hover:text-orange-700 font-semibold flex items-center gap-1"
                    >
                      Buka di Halaman Transaksi <ArrowUpRight className="w-3.5 h-3.5" />
                    </Link>
                  </div>

                  {orders.length === 0 ? (
                    <div className="p-12 text-center text-slate-400 text-sm bg-slate-50 rounded-2xl border border-dashed border-slate-200">
                      Bisnis ini belum memiliki transaksi penjualan tercatat.
                    </div>
                  ) : (
                    <div className="overflow-x-auto rounded-2xl border border-slate-200">
                      <table className="w-full text-left text-xs">
                        <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase font-bold text-[11px]">
                          <tr>
                            <th className="py-3 px-4">No Invoice</th>
                            <th className="py-3 px-4">Waktu</th>
                            <th className="py-3 px-4">Pelanggan</th>
                            <th className="py-3 px-4">Metode Bayar</th>
                            <th className="py-3 px-4 text-right">Total Belanja</th>
                            <th className="py-3 px-4 text-center">Status</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                          {orders.slice(0, 10).map((ord) => {
                            const dateStr = ord.created_at
                              ? new Date(ord.created_at).toLocaleString('id-ID', {
                                  day: 'numeric',
                                  month: 'short',
                                  hour: '2-digit',
                                  minute: '2-digit',
                                })
                              : '-';

                            const payMethod =
                              ord.order_payments && ord.order_payments.length > 0
                                ? ord.order_payments.map((p) => p.method_name || p.method_type).join(', ')
                                : 'Tunai';

                            return (
                              <tr key={ord.id} className="hover:bg-slate-50 transition-colors">
                                <td className="py-3 px-4 font-mono font-bold text-slate-900">
                                  {ord.invoice_number}
                                </td>
                                <td className="py-3 px-4 text-slate-500">{dateStr}</td>
                                <td className="py-3 px-4 text-slate-700">
                                  {ord.customer_name || 'Pelanggan Umum'}
                                </td>
                                <td className="py-3 px-4 text-slate-600">
                                  <span className="px-2 py-0.5 rounded bg-slate-100 border border-slate-200 text-[10px] font-semibold">
                                    {payMethod}
                                  </span>
                                </td>
                                <td className="py-3 px-4 text-right font-bold text-slate-900">
                                  {formatRupiah(ord.grand_total)}
                                </td>
                                <td className="py-3 px-4 text-center">
                                  {ord.status === 'paid' && (
                                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                                      Lunas
                                    </span>
                                  )}
                                  {ord.status === 'void' && (
                                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800">
                                      Void
                                    </span>
                                  )}
                                  {ord.status === 'refunded' && (
                                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800">
                                      Refund
                                    </span>
                                  )}
                                  {ord.status === 'draft' && (
                                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-700">
                                      Draft
                                    </span>
                                  )}
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}
            </>
          )}
        </div>

        {/* ======================================================== */}
        {/* MODAL FOOTER & QUICK ACTIONS                             */}
        {/* ======================================================== */}
        <div className="px-6 py-4 border-t border-slate-100 bg-slate-50 flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2">
            {onOpenPlanModal && (
              <button
                onClick={() => {
                  onClose();
                  onOpenPlanModal(business);
                }}
                className="px-3 py-2 rounded-xl text-xs font-bold bg-amber-500 hover:bg-amber-600 text-white flex items-center gap-1.5 shadow-xs transition-colors"
              >
                <Crown className="w-3.5 h-3.5" />
                <span>{isPro ? 'Atur Masa Aktif PRO' : 'Upgrade ke PRO'}</span>
              </button>
            )}

            {onOpenTemplateModal && (
              <button
                onClick={() => {
                  onClose();
                  onOpenTemplateModal(business);
                }}
                className="px-3 py-2 rounded-xl text-xs font-semibold bg-white hover:bg-slate-100 border border-slate-200 text-slate-700 flex items-center gap-1.5 shadow-2xs transition-colors"
              >
                <Layers className="w-3.5 h-3.5 text-slate-500" />
                <span>Ubah Template Usaha</span>
              </button>
            )}

            {onOpenLimitsModal && (
              <button
                onClick={() => {
                  onClose();
                  onOpenLimitsModal(business);
                }}
                className="px-3 py-2 rounded-xl text-xs font-semibold bg-white hover:bg-slate-100 border border-slate-200 text-slate-700 flex items-center gap-1.5 shadow-2xs transition-colors"
              >
                <Sliders className="w-3.5 h-3.5 text-slate-500" />
                <span>Override Limit Kuota</span>
              </button>
            )}
          </div>

          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold bg-slate-200 hover:bg-slate-300 text-slate-800 transition-colors"
          >
            Tutup
          </button>
        </div>
      </div>
    </div>
  );
}
