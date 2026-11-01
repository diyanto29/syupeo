'use client';

import { useState, useEffect, useMemo, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Business, BusinessTypeTemplate, SubscriptionPlan, Order } from '@/types/database';
import {
  ArrowLeft,
  Building2,
  Crown,
  Store,
  Layers,
  Clock,
  Phone,
  Mail,
  MapPin,
  Calendar,
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
  Search,
  Filter,
  Package,
  Award,
  Flame,
  Tag,
  AlertCircle,
  X,
  Sparkles,
  ChevronLeft,
  ChevronRight,
  Download,
  AlertTriangle,
  RefreshCw,
  UserCheck,
} from 'lucide-react';

interface MenuItem {
  id: string;
  name: string;
  category: string;
  price: number;
  description?: string | null;
  image_url?: string | null;
  stock_available: boolean;
  stock_quantity?: number | null;
  unit?: string | null;
  sku?: string | null;
  barcode?: string | null;
  created_at?: string;
}

interface TopProduct {
  name: string;
  totalQty: number;
  totalRevenue: number;
  orderCount: number;
  menuItemId?: string | null;
}

const PRODUCTS_PER_PAGE = 15;
const TOP_PRODUCTS_PER_PAGE = 10;
const ORDERS_PER_PAGE = 15;

export default function BusinessDetailPage() {
  const params = useParams();
  const router = useRouter();
  const businessId = params.id as string;

  const [business, setBusiness] = useState<Business | null>(null);
  const [templates, setTemplates] = useState<BusinessTypeTemplate[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [outlets, setOutlets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // Active Main Tab
  const [activeTab, setActiveTab] = useState<'sales' | 'products' | 'orders' | 'profile'>('sales');

  // Sales Metrics State
  const [salesMetrics, setSalesMetrics] = useState({
    totalGMV: 0,
    paidCount: 0,
    voidCount: 0,
    refundCount: 0,
    draftCount: 0,
    totalDiscounts: 0,
    avgOrderValue: 0,
    todayGMV: 0,
    todayCount: 0,
    thirtyDaysGMV: 0,
    paymentBreakdown: [] as [string, { count: number; total: number }][],
  });

  // Top Selling Products State
  const [salesTimeRange, setSalesTimeRange] = useState<'all' | '30days' | '7days' | 'today'>('all');
  const [allTopProducts, setAllTopProducts] = useState<TopProduct[]>([]);
  const [topProductsPage, setTopProductsPage] = useState(1);
  const [loadingTopProducts, setLoadingTopProducts] = useState(false);

  // Products Catalog (Server-Side Paginated)
  const [menuItems, setMenuItems] = useState<MenuItem[]>([]);
  const [productsPage, setProductsPage] = useState(1);
  const [productsTotalCount, setProductsTotalCount] = useState(0);
  const [productSearch, setProductSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('ALL');
  const [categoriesList, setCategoriesList] = useState<string[]>([]);
  const [loadingProducts, setLoadingProducts] = useState(false);

  // Orders History (Server-Side Paginated)
  const [orders, setOrders] = useState<Order[]>([]);
  const [ordersPage, setOrdersPage] = useState(1);
  const [ordersTotalCount, setOrdersTotalCount] = useState(0);
  const [ordersStatusFilter, setOrdersStatusFilter] = useState('ALL');
  const [loadingOrders, setLoadingOrders] = useState(false);

  const [isUpdating, setIsUpdating] = useState(false);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState(false);

  const supabase = createClient();

  // 1. Initial Load: Business info, Outlets, Templates, Plans, Categories
  const loadBusinessProfile = async () => {
    if (!businessId) return;
    setLoading(true);

    try {
      // 1. Query businesses directly without joins to prevent schema cache / foreign key errors
      let bizData: any = null;
      const bizRes = await supabase
        .from('businesses')
        .select('*')
        .eq('id', businessId)
        .maybeSingle();

      if (bizRes.data) {
        bizData = bizRes.data;

        // Fetch starter kit details independently if available
        if (bizData.starter_kit_id) {
          const { data: kitData } = await supabase
            .from('retail_starter_kits')
            .select('*')
            .eq('id', bizData.starter_kit_id)
            .maybeSingle();
          if (kitData) {
            bizData.retail_starter_kits = kitData;
          }
        }

        // Fetch owner profile independently if available
        if (bizData.owner_user_id) {
          const { data: profData } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', bizData.owner_user_id)
            .maybeSingle();
          if (profData) {
            bizData.profiles = profData;
          }
        }

        const b = bizData as Business;
        setBusiness(b);
      }

      const [tplRes, outletRes, catRes] = await Promise.all([
        supabase.from('business_type_templates').select('*').order('name'),
        supabase
          .from('outlets')
          .select('id, name, address, phone, created_at')
          .eq('business_id', businessId),
        supabase
          .from('menu_items')
          .select('category')
          .eq('business_id', businessId),
      ]);

      if (tplRes.data) setTemplates(tplRes.data as BusinessTypeTemplate[]);
      if (outletRes.data) setOutlets(outletRes.data);

      if (catRes.data) {
        const set = new Set<string>();
        catRes.data.forEach((r: any) => {
          if (r.category) set.add(r.category);
        });
        setCategoriesList(Array.from(set));
      }
    } catch (err: any) {
      console.error('Error fetching business detail:', err);
    } finally {
      setLoading(false);
    }
  };

  // Aktivasi Akun Toko oleh Admin
  const handleActivateBusiness = async () => {
    if (!business) return;
    if (
      !confirm(
        `Aktivasi akun toko "${business.name}"?\nStatus toko akan aktif dan pesanan paket usaha akan diteruskan ke tim gudang untuk packing.`
      )
    ) {
      return;
    }
    try {
      const { error: rpcErr } = await supabase.rpc('activate_business', {
        p_business_id: business.id,
      });

      if (rpcErr) {
        console.warn('RPC activate_business warning, fallback direct update:', rpcErr);
        const { error: bizErr } = await supabase
          .from('businesses')
          .update({
            status: 'active',
            subscription_status: 'active',
          })
          .eq('id', business.id);

        if (bizErr) throw bizErr;

        if (business.phone) {
          await supabase
            .from('package_fulfillment_orders')
            .update({ status: 'packing' })
            .eq('recipient_phone', business.phone)
            .eq('status', 'pending_dispatch');
        }
      }

      setSuccessMsg(`Toko "${business.name}" berhasil diaktivasi!`);
      await loadBusinessProfile();
    } catch (err: any) {
      alert(`Gagal aktivasi toko: ${err?.message || err}`);
    }
  };

  // 2. Load Sales Metrics & Top Selling Items
  const loadSalesAndTopProducts = useCallback(async () => {
    if (!businessId) return;
    setLoadingTopProducts(true);

    try {
      // Calculate date filter for salesTimeRange
      let startDateStr: string | null = null;
      const now = new Date();
      if (salesTimeRange === 'today') {
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        startDateStr = today.toISOString();
      } else if (salesTimeRange === '7days') {
        const d = new Date();
        d.setDate(d.getDate() - 7);
        startDateStr = d.toISOString();
      } else if (salesTimeRange === '30days') {
        const d = new Date();
        d.setDate(d.getDate() - 30);
        startDateStr = d.toISOString();
      }

      let query = supabase
        .from('orders')
        .select(`
          id,
          status,
          grand_total,
          discount_total,
          created_at,
          order_payments (method_name, method_type, amount),
          order_items (name, quantity, unit_price, subtotal)
        `)
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (startDateStr) {
        query = query.gte('created_at', startDateStr);
      }

      const { data: orderList } = await query.limit(500);

      if (orderList) {
        const paid = orderList.filter((o) => o.status === 'paid');
        const voidList = orderList.filter((o) => o.status === 'void');
        const refundList = orderList.filter((o) => o.status === 'refunded');
        const draftList = orderList.filter((o) => o.status === 'draft');

        const gmv = paid.reduce((acc, o) => acc + (o.grand_total || 0), 0);
        const discounts = paid.reduce((acc, o) => acc + (o.discount_total || 0), 0);
        const aov = paid.length > 0 ? Math.round(gmv / paid.length) : 0;

        // Today metrics
        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0);
        const todayPaid = paid.filter((o) => new Date(o.created_at) >= startOfToday);
        const todayGMV = todayPaid.reduce((acc, o) => acc + (o.grand_total || 0), 0);

        // 30 days metrics
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const thirtyDaysPaid = paid.filter((o) => new Date(o.created_at) >= thirtyDaysAgo);
        const thirtyDaysGMV = thirtyDaysPaid.reduce((acc, o) => acc + (o.grand_total || 0), 0);

        // Payment breakdown
        const payMap: Record<string, { count: number; total: number }> = {};
        paid.forEach((o) => {
          if (o.order_payments && Array.isArray(o.order_payments) && o.order_payments.length > 0) {
            o.order_payments.forEach((p: any) => {
              const name = p.method_name || p.method_type || 'Tunai';
              if (!payMap[name]) payMap[name] = { count: 0, total: 0 };
              payMap[name].count += 1;
              payMap[name].total += p.amount || 0;
            });
          } else {
            const name = 'Tunai (Cash)';
            if (!payMap[name]) payMap[name] = { count: 0, total: 0 };
            payMap[name].count += 1;
            payMap[name].total += o.grand_total || 0;
          }
        });

        setSalesMetrics({
          totalGMV: gmv,
          paidCount: paid.length,
          voidCount: voidList.length,
          refundCount: refundList.length,
          draftCount: draftList.length,
          totalDiscounts: discounts,
          avgOrderValue: aov,
          todayGMV,
          todayCount: todayPaid.length,
          thirtyDaysGMV,
          paymentBreakdown: Object.entries(payMap).sort((a, b) => b[1].total - a[1].total),
        });

        // Calculate Top Selling Products
        const productMap: Record<string, TopProduct> = {};
        paid.forEach((order: any) => {
          if (order.order_items && Array.isArray(order.order_items)) {
            order.order_items.forEach((item: any) => {
              const rawName = (item.name || '').trim();
              if (!rawName) return;
              const key = rawName.toLowerCase();

              if (!productMap[key]) {
                productMap[key] = {
                  name: rawName,
                  totalQty: 0,
                  totalRevenue: 0,
                  orderCount: 0,
                  menuItemId: item.menu_item_id,
                };
              }

              const qty = Number(item.quantity) || 1;
              const subtotal = Number(item.subtotal) || Number(item.unit_price) * qty || 0;

              productMap[key].totalQty += qty;
              productMap[key].totalRevenue += subtotal;
              productMap[key].orderCount += 1;
            });
          }
        });

        const sortedTop = Object.values(productMap).sort((a, b) => b.totalQty - a.totalQty);
        setAllTopProducts(sortedTop);
        setTopProductsPage(1); // reset to page 1
      }
    } catch (err) {
      console.error('Error fetching sales & top items:', err);
    } finally {
      setLoadingTopProducts(false);
    }
  }, [businessId, salesTimeRange]);

  // 3. Load Products (Server-Side Paginated)
  const loadPaginatedProducts = useCallback(async () => {
    if (!businessId) return;
    setLoadingProducts(true);

    try {
      const from = (productsPage - 1) * PRODUCTS_PER_PAGE;
      const to = from + PRODUCTS_PER_PAGE - 1;

      let query = supabase
        .from('menu_items')
        .select('*', { count: 'exact' })
        .eq('business_id', businessId);

      if (productSearch.trim()) {
        query = query.ilike('name', `%${productSearch.trim()}%`);
      }

      if (selectedCategory !== 'ALL') {
        query = query.eq('category', selectedCategory);
      }

      const { data, count, error } = await query
        .order('name', { ascending: true })
        .range(from, to);

      if (!error && data) {
        setMenuItems(data as MenuItem[]);
        setProductsTotalCount(count ?? 0);
      }
    } catch (err) {
      console.error('Error fetching paginated products:', err);
    } finally {
      setLoadingProducts(false);
    }
  }, [businessId, productsPage, productSearch, selectedCategory]);

  // 4. Load Orders (Server-Side Paginated)
  const loadPaginatedOrders = useCallback(async () => {
    if (!businessId) return;
    setLoadingOrders(true);

    try {
      const from = (ordersPage - 1) * ORDERS_PER_PAGE;
      const to = from + ORDERS_PER_PAGE - 1;

      let query = supabase
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
        `, { count: 'exact' })
        .eq('business_id', businessId);

      if (ordersStatusFilter !== 'ALL') {
        query = query.eq('status', ordersStatusFilter);
      }

      const { data, count, error } = await query
        .order('created_at', { ascending: false })
        .range(from, to);

      if (!error && data) {
        setOrders(data as unknown as Order[]);
        setOrdersTotalCount(count ?? 0);
      }
    } catch (err) {
      console.error('Error fetching paginated orders:', err);
    } finally {
      setLoadingOrders(false);
    }
  }, [businessId, ordersPage, ordersStatusFilter]);

  // Trigger loads
  useEffect(() => {
    loadBusinessProfile();
  }, [businessId]);

  useEffect(() => {
    loadSalesAndTopProducts();
  }, [loadSalesAndTopProducts]);

  useEffect(() => {
    loadPaginatedProducts();
  }, [loadPaginatedProducts]);

  useEffect(() => {
    loadPaginatedOrders();
  }, [loadPaginatedOrders]);

  // Paginated Slice for Top Products (Client-Side from aggregated list)
  const paginatedTopProducts = useMemo(() => {
    const from = (topProductsPage - 1) * TOP_PRODUCTS_PER_PAGE;
    return allTopProducts.slice(from, from + TOP_PRODUCTS_PER_PAGE);
  }, [allTopProducts, topProductsPage]);

  const fullAddressString = useMemo(() => {
    if (!business) return '';
    const parts = [
      business.address,
      business.village ? `Desa/Kel. ${business.village}` : null,
      business.district ? `Kec. ${business.district}` : null,
      business.city,
      business.province ? `Prov. ${business.province}` : null,
      business.postal_code ? `Kode Pos ${business.postal_code}` : null,
    ].filter(Boolean);
    return parts.join(', ');
  }, [business]);

  const googleMapsUrl = useMemo(() => {
    if (business?.latitude && business?.longitude) {
      return `https://www.google.com/maps?q=${business.latitude},${business.longitude}`;
    }
    if (fullAddressString) {
      return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(fullAddressString)}`;
    }
    return null;
  }, [business?.latitude, business?.longitude, fullAddressString]);

  const topProductsTotalPages = Math.ceil(allTopProducts.length / TOP_PRODUCTS_PER_PAGE) || 1;
  const productsTotalPages = Math.ceil(productsTotalCount / PRODUCTS_PER_PAGE) || 1;
  const ordersTotalPages = Math.ceil(ordersTotalCount / ORDERS_PER_PAGE) || 1;

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(val);
  };

  const copyBusinessId = () => {
    if (!business?.id) return;
    navigator.clipboard.writeText(business.id);
    setCopiedId(true);
    setTimeout(() => setCopiedId(false), 2000);
  };

  // Export Data to CSV
  const exportProductsToCSV = () => {
    if (menuItems.length === 0) return;
    const headers = ['Nama Produk', 'Kategori', 'Barcode/SKU', 'Harga', 'Satuan', 'Stok'];
    const rows = menuItems.map((m) => [
      `"${m.name.replace(/"/g, '""')}"`,
      `"${m.category || ''}"`,
      `"${m.barcode || m.sku || ''}"`,
      m.price,
      `"${m.unit || 'pcs'}"`,
      m.stock_quantity ?? (m.stock_available ? 'Tersedia' : 'Habis'),
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `katalog_produk_${business?.name || 'toko'}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-50 flex flex-col">
        <Navbar title="Detail Akun Bisnis & Penjualan" />
        <div className="flex-1 flex items-center justify-center py-32">
          <div className="text-center">
            <div className="w-10 h-10 border-3 border-[#0070fc] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-sm font-semibold text-slate-600">Memuat profil toko retail, produk & analitik transaksi...</p>
          </div>
        </div>
      </div>
    );
  }

  if (!business) {
    return (
      <div className="min-h-screen bg-slate-50 flex flex-col">
        <Navbar title="Bisnis Tidak Ditemukan" />
        <div className="p-12 text-center space-y-4">
          <div className="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mx-auto text-slate-400">
            <Building2 className="w-8 h-8" />
          </div>
          <h2 className="text-lg font-bold text-slate-800">Toko Retail Tidak Ditemukan</h2>
          <p className="text-slate-500 max-w-md mx-auto text-sm">
            Data bisnis dengan ID <code className="bg-slate-100 px-2 py-0.5 rounded text-xs font-mono text-slate-700">{businessId}</code> tidak ditemukan di database. Pastikan toko sudah didaftarkan.
          </p>
          <div className="pt-2">
            <Link
              href="/dashboard/businesses"
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-[#0070fc] text-white rounded-xl text-sm font-bold shadow-md hover:bg-[#005cd0] transition-colors"
            >
              <ArrowLeft className="w-4 h-4" /> Kembali ke Daftar Bisnis
            </Link>
          </div>
        </div>
      </div>
    );
  }

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

  const cleanPhone = (business.phone || business.profiles?.phone || '').replace(/[^0-9]/g, '');
  const waNumber = cleanPhone.startsWith('0')
    ? '62' + cleanPhone.slice(1)
    : cleanPhone.startsWith('62')
    ? cleanPhone
    : cleanPhone ? '62' + cleanPhone : '';

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <Navbar
        title={business.name}
        description={`Profil & Analitik Toko • Owner: ${business.owner_name || business.profiles?.full_name || 'Owner'}`}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 space-y-6">
        {/* Navigation Back & Alerts */}
        <div className="flex items-center justify-between">
          <Link
            href="/dashboard/businesses"
            className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-50 text-xs font-bold transition-all shadow-2xs"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span>Kembali ke Daftar Bisnis</span>
          </Link>

          {successMsg && (
            <div className="px-4 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-800 flex items-center gap-2 text-xs font-semibold">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>{successMsg}</span>
              <button onClick={() => setSuccessMsg(null)} className="ml-2 hover:opacity-75">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          )}
        </div>

        {/* ======================================================== */}
        {/* HEADER CARD: PROFIL TOKO & QUICK ACTIONS                */}
        {/* ======================================================== */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 md:p-8 shadow-sm flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6">
          <div className="flex items-start gap-5">
            <div className="w-16 h-16 rounded-2xl bg-[#0070fc] text-white font-black text-2xl flex items-center justify-center shadow-md shadow-blue-500/20 shrink-0">
              {business.name?.charAt(0)?.toUpperCase() || 'T'}
            </div>
            <div className="space-y-2">
              <div className="flex flex-wrap items-center gap-2.5">
                <h1 className="text-2xl font-black text-slate-900 tracking-tight">{business.name}</h1>
                {business.status === 'pending' ? (
                  <span className="px-3 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200 flex items-center gap-1.5 shadow-2xs">
                    <Clock className="w-3.5 h-3.5 text-amber-600" /> Menunggu Aktivasi
                  </span>
                ) : (
                  <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 flex items-center gap-1.5 shadow-2xs">
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" /> Aktif
                  </span>
                )}
                {business.retail_starter_kits && (
                  <span className="px-3 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200 flex items-center gap-1.5 shadow-2xs">
                    <Package className="w-3.5 h-3.5 text-amber-600" /> {business.retail_starter_kits.name}
                  </span>
                )}
                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200 flex items-center gap-1.5 capitalize">
                  <Layers className="w-3.5 h-3.5 text-slate-500" /> {business.business_type || 'Retail'}
                </span>
              </div>

              <div className="flex flex-wrap items-center gap-x-5 gap-y-1.5 text-xs text-slate-500">
                <div className="flex items-center gap-1.5">
                  <User className="w-3.5 h-3.5 text-slate-400" />
                  <span className="font-bold text-slate-800">{business.owner_name || business.profiles?.full_name || 'Owner'}</span>
                  <span className="text-slate-400">({business.email || business.profiles?.email || '-'})</span>
                </div>
                {waNumber && (
                  <a
                    href={`https://wa.me/${waNumber}`}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-emerald-700 font-bold hover:underline"
                  >
                    <MessageCircle className="w-3.5 h-3.5 text-emerald-600" />
                    <span>+{waNumber}</span>
                  </a>
                )}
                <div className="flex items-center gap-1 text-slate-400">
                  <span>ID:</span>
                  <code className="font-mono text-[11px] bg-slate-100 px-1.5 py-0.5 rounded text-slate-700">
                    {business.id}
                  </code>
                  <button onClick={copyBusinessId} title="Salin Business ID" className="hover:text-slate-900 p-0.5">
                    {copiedId ? <Check className="w-3 h-3 text-emerald-500" /> : <Copy className="w-3 h-3 text-slate-400" />}
                  </button>
                </div>
              </div>

              {/* Alamat Lengkap & Koordinat GPS */}
              {fullAddressString && (
                <div className="flex flex-wrap items-center gap-2 pt-1 text-xs">
                  <div className="flex items-center gap-1.5 text-slate-700 bg-slate-50 border border-slate-200 px-2.5 py-1 rounded-lg">
                    <MapPin className="w-3.5 h-3.5 text-[#0070fc] shrink-0" />
                    <span className="font-medium text-slate-800">{fullAddressString}</span>
                  </div>
                  {business.latitude && business.longitude && (
                    <span className="inline-flex items-center gap-1 text-[11px] font-mono text-slate-500 bg-slate-100 px-2 py-1 rounded-lg">
                      GPS: {business.latitude.toFixed(6)}, {business.longitude.toFixed(6)}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Action Buttons: Clean & Direct */}
          <div className="flex items-center gap-2.5 w-full lg:w-auto">
            {business.status === 'pending' && (
              <button
                type="button"
                onClick={handleActivateBusiness}
                className="flex-1 sm:flex-initial px-4 py-2.5 rounded-xl text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white flex items-center justify-center gap-2 shadow-xs transition-colors"
                title="Aktivasi Akun Toko Sekarang"
              >
                <UserCheck className="w-4 h-4" />
                <span>Aktivasi Akun Toko</span>
              </button>
            )}
            {googleMapsUrl && (
              <a
                href={googleMapsUrl}
                target="_blank"
                rel="noreferrer"
                className="flex-1 sm:flex-initial px-4 py-2.5 rounded-xl text-xs font-bold bg-[#0070fc] hover:bg-[#005cd0] text-white flex items-center justify-center gap-2 shadow-xs transition-colors"
              >
                <MapPin className="w-4 h-4" />
                <span>Buka di Google Maps</span>
                <ArrowUpRight className="w-3.5 h-3.5 opacity-80" />
              </a>
            )}
          </div>
        </div>

        {/* ======================================================== */}
        {/* TOP 4 KEY METRIC CARDS                                  */}
        {/* ======================================================== */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white p-5 rounded-3xl border border-slate-200 shadow-xs">
            <div className="flex items-center justify-between text-emerald-700 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider">Total Omzet (GMV)</span>
              <div className="p-2 rounded-xl bg-emerald-50 text-emerald-600">
                <DollarSign className="w-4 h-4" />
              </div>
            </div>
            <div className="text-2xl font-black text-slate-900">{formatRupiah(salesMetrics.totalGMV)}</div>
            <p className="text-[11px] text-emerald-800/80 mt-1">
              Dari <strong>{salesMetrics.paidCount} transaksi</strong> sukses lunas
            </p>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-slate-200 shadow-xs">
            <div className="flex items-center justify-between text-blue-700 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider">Transaksi Sukses</span>
              <div className="p-2 rounded-xl bg-blue-50 text-blue-600">
                <CheckCircle2 className="w-4 h-4" />
              </div>
            </div>
            <div className="text-2xl font-black text-slate-900">
              {salesMetrics.paidCount} <span className="text-sm font-semibold text-slate-500">Order</span>
            </div>
            <p className="text-[11px] text-blue-800/80 mt-1">
              Total <strong>{ordersTotalCount} pesanan</strong> tercatat
            </p>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-slate-200 shadow-xs">
            <div className="flex items-center justify-between text-purple-700 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider">Rata-rata Nota (AOV)</span>
              <div className="p-2 rounded-xl bg-purple-50 text-purple-600">
                <TrendingUp className="w-4 h-4" />
              </div>
            </div>
            <div className="text-2xl font-black text-slate-900">{formatRupiah(salesMetrics.avgOrderValue)}</div>
            <p className="text-[11px] text-purple-800/80 mt-1">Nilai belanja rata-rata per transaksi</p>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-slate-200 shadow-xs">
            <div className="flex items-center justify-between text-orange-700 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider">Omzet 30 Hari Terakhir</span>
              <div className="p-2 rounded-xl bg-orange-50 text-orange-600">
                <Calendar className="w-4 h-4" />
              </div>
            </div>
            <div className="text-2xl font-black text-slate-900">{formatRupiah(salesMetrics.thirtyDaysGMV)}</div>
            <p className="text-[11px] text-orange-800/80 mt-1">
              Hari ini: <strong>{formatRupiah(salesMetrics.todayGMV)}</strong> ({salesMetrics.todayCount} order)
            </p>
          </div>
        </div>

        {/* ======================================================== */}
        {/* TABS NAVIGATION                                         */}
        {/* ======================================================== */}
        <div className="flex items-center gap-2 border-b border-slate-200 pb-0 overflow-x-auto">
          <button
            onClick={() => setActiveTab('sales')}
            className={`flex items-center gap-2 px-5 py-3 text-xs font-bold border-b-2 transition-all whitespace-nowrap ${
              activeTab === 'sales'
                ? 'border-[#0070fc] text-[#0070fc] bg-white rounded-t-2xl shadow-xs'
                : 'border-transparent text-slate-600 hover:text-slate-900'
            }`}
          >
            <Flame className="w-4 h-4" />
            <span>Produk Terlaris ({allTopProducts.length})</span>
          </button>
          <button
            onClick={() => setActiveTab('products')}
            className={`flex items-center gap-2 px-5 py-3 text-xs font-bold border-b-2 transition-all whitespace-nowrap ${
              activeTab === 'products'
                ? 'border-[#0070fc] text-[#0070fc] bg-white rounded-t-2xl shadow-xs'
                : 'border-transparent text-slate-600 hover:text-slate-900'
            }`}
          >
            <Package className="w-4 h-4" />
            <span>Katalog Produk ({productsTotalCount})</span>
          </button>
          <button
            onClick={() => setActiveTab('orders')}
            className={`flex items-center gap-2 px-5 py-3 text-xs font-bold border-b-2 transition-all whitespace-nowrap ${
              activeTab === 'orders'
                ? 'border-[#0070fc] text-[#0070fc] bg-white rounded-t-2xl shadow-xs'
                : 'border-transparent text-slate-600 hover:text-slate-900'
            }`}
          >
            <Receipt className="w-4 h-4" />
            <span>Riwayat Transaksi ({ordersTotalCount})</span>
          </button>
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex items-center gap-2 px-5 py-3 text-xs font-bold border-b-2 transition-all whitespace-nowrap ${
              activeTab === 'profile'
                ? 'border-[#0070fc] text-[#0070fc] bg-white rounded-t-2xl shadow-xs'
                : 'border-transparent text-slate-600 hover:text-slate-900'
            }`}
          >
            <Building2 className="w-4 h-4" />
            <span>Profil Toko Retail</span>
          </button>
        </div>

        {/* ======================================================== */}
        {/* TAB 1: PRODUK TERLARIS DENGAN PAGINASI & FILTER WAKTU    */}
        {/* ======================================================== */}
        {activeTab === 'sales' && (
          <div className="space-y-6">
            {/* ⭐ PRODUK TERLARIS */}
            <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 pb-4 border-b border-slate-100">
                <div>
                  <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
                    <Flame className="w-5 h-5 text-orange-500" />
                    Peringkat Produk Terlaris (Top Selling Items)
                  </h2>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Diurutkan berdasarkan kuantitas penjualan tertinggi dari pesanan lunas
                  </p>
                </div>

                {/* Filter Waktu Penjualan */}
                <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl text-xs font-semibold">
                  <button
                    onClick={() => setSalesTimeRange('all')}
                    className={`px-3 py-1.5 rounded-lg transition-all ${
                      salesTimeRange === 'all'
                        ? 'bg-white text-slate-900 shadow-2xs font-bold'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Semua Waktu
                  </button>
                  <button
                    onClick={() => setSalesTimeRange('30days')}
                    className={`px-3 py-1.5 rounded-lg transition-all ${
                      salesTimeRange === '30days'
                        ? 'bg-white text-slate-900 shadow-2xs font-bold'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    30 Hari
                  </button>
                  <button
                    onClick={() => setSalesTimeRange('7days')}
                    className={`px-3 py-1.5 rounded-lg transition-all ${
                      salesTimeRange === '7days'
                        ? 'bg-white text-slate-900 shadow-2xs font-bold'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    7 Hari
                  </button>
                  <button
                    onClick={() => setSalesTimeRange('today')}
                    className={`px-3 py-1.5 rounded-lg transition-all ${
                      salesTimeRange === 'today'
                        ? 'bg-white text-slate-900 shadow-2xs font-bold'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Hari Ini
                  </button>
                </div>
              </div>

              {loadingTopProducts ? (
                <div className="text-center py-16">
                  <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                  <p className="text-xs text-slate-500">Mengkalkulasi peringkat produk terlaris...</p>
                </div>
              ) : allTopProducts.length === 0 ? (
                <div className="text-center py-16 text-slate-400 text-xs bg-slate-50/50 rounded-2xl border border-dashed border-slate-200">
                  <Package className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                  Belum ada produk yang terjual pada rentang waktu ini.
                </div>
              ) : (
                <>
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 text-slate-500 uppercase font-bold text-[11px] border-b border-slate-200">
                        <tr>
                          <th className="py-3.5 px-4 w-16 text-center">Rank</th>
                          <th className="py-3.5 px-4">Nama Produk</th>
                          <th className="py-3.5 px-4 text-center">Kuantitas Terjual</th>
                          <th className="py-3.5 px-4 text-right">Total Pendapatan</th>
                          <th className="py-3.5 px-4 text-center">Frekuensi Transaksi</th>
                          <th className="py-3.5 px-4 w-44">Kontribusi Omzet</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {paginatedTopProducts.map((p, index) => {
                          const absoluteRank = (topProductsPage - 1) * TOP_PRODUCTS_PER_PAGE + index;
                          const percent =
                            salesMetrics.totalGMV > 0
                              ? Math.round((p.totalRevenue / salesMetrics.totalGMV) * 100)
                              : 0;
                          return (
                            <tr key={p.name} className="hover:bg-slate-50/70 transition-colors">
                              {/* Rank Badge */}
                              <td className="py-3.5 px-4 text-center">
                                {absoluteRank === 0 ? (
                                  <span className="w-6 h-6 rounded-full bg-amber-400 text-amber-950 font-black text-xs inline-flex items-center justify-center shadow-xs">
                                    1
                                  </span>
                                ) : absoluteRank === 1 ? (
                                  <span className="w-6 h-6 rounded-full bg-slate-300 text-slate-800 font-bold text-xs inline-flex items-center justify-center shadow-xs">
                                    2
                                  </span>
                                ) : absoluteRank === 2 ? (
                                  <span className="w-6 h-6 rounded-full bg-amber-700 text-amber-100 font-bold text-xs inline-flex items-center justify-center shadow-xs">
                                    3
                                  </span>
                                ) : (
                                  <span className="text-slate-400 font-bold">{absoluteRank + 1}</span>
                                )}
                              </td>

                              <td className="py-3.5 px-4">
                                <div className="font-bold text-slate-900 text-sm">{p.name}</div>
                              </td>

                              <td className="py-3.5 px-4 text-center">
                                <span className="px-2.5 py-1 rounded-lg bg-orange-50 text-orange-700 font-black text-xs">
                                  {p.totalQty} pcs
                                </span>
                              </td>

                              <td className="py-3.5 px-4 text-right font-black text-slate-900 text-sm">
                                {formatRupiah(p.totalRevenue)}
                              </td>

                              <td className="py-3.5 px-4 text-center text-slate-500 font-semibold">
                                {p.orderCount} nota
                              </td>

                              <td className="py-3.5 px-4">
                                <div className="space-y-1">
                                  <div className="flex items-center justify-between text-[11px]">
                                    <span className="text-slate-500 font-semibold">{percent}%</span>
                                  </div>
                                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                                    <div
                                      className="bg-orange-500 h-2 rounded-full transition-all"
                                      style={{ width: `${percent}%` }}
                                    />
                                  </div>
                                </div>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>

                  {/* Paginasi Produk Terlaris */}
                  {topProductsTotalPages > 1 && (
                    <div className="flex flex-col sm:flex-row items-center justify-between gap-3 pt-5 border-t border-slate-100 text-xs">
                      <span className="text-slate-500">
                        Menampilkan{' '}
                        <strong>
                          {(topProductsPage - 1) * TOP_PRODUCTS_PER_PAGE + 1} -{' '}
                          {Math.min(topProductsPage * TOP_PRODUCTS_PER_PAGE, allTopProducts.length)}
                        </strong>{' '}
                        dari <strong>{allTopProducts.length}</strong> produk terlaris
                      </span>

                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => setTopProductsPage((p) => Math.max(1, p - 1))}
                          disabled={topProductsPage === 1}
                          className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                        >
                          <ChevronLeft className="w-4 h-4" /> Prev
                        </button>

                        <span className="px-3 py-1.5 rounded-xl bg-orange-50 text-orange-700 font-bold border border-orange-200">
                          {topProductsPage} / {topProductsTotalPages}
                        </span>

                        <button
                          onClick={() => setTopProductsPage((p) => Math.min(topProductsTotalPages, p + 1))}
                          disabled={topProductsPage === topProductsTotalPages}
                          className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                        >
                          Next <ChevronRight className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Status Breakdown & Payment Methods Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Status Pesanan */}
              <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
                <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 border-b border-slate-100 pb-3">
                  <Receipt className="w-4 h-4 text-orange-600" />
                  Rangkuman Status Seluruh Pesanan
                </h3>

                <div className="grid grid-cols-2 gap-3.5">
                  <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-100">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-800">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                      Lunas (Paid)
                    </div>
                    <div className="text-xl font-black text-emerald-950 mt-1">{salesMetrics.paidCount}</div>
                    <div className="text-[11px] text-emerald-700 font-semibold">
                      {formatRupiah(salesMetrics.totalGMV)}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-rose-50 border border-rose-100">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-rose-800">
                      <XCircle className="w-3.5 h-3.5 text-rose-600" />
                      Dibatalkan (Void)
                    </div>
                    <div className="text-xl font-black text-rose-950 mt-1">{salesMetrics.voidCount}</div>
                    <div className="text-[11px] text-rose-700">Transaksi void kasir</div>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-amber-50 border border-amber-100">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-amber-800">
                      <RotateCcw className="w-3.5 h-3.5 text-amber-600" />
                      Refund
                    </div>
                    <div className="text-xl font-black text-amber-950 mt-1">{salesMetrics.refundCount}</div>
                    <div className="text-[11px] text-amber-700">Pengembalian dana</div>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700">
                      <Clock className="w-3.5 h-3.5 text-slate-500" />
                      Draft / Menggantung
                    </div>
                    <div className="text-xl font-black text-slate-900 mt-1">{salesMetrics.draftCount}</div>
                    <div className="text-[11px] text-slate-500">Order belum lunas</div>
                  </div>
                </div>

                {salesMetrics.totalDiscounts > 0 && (
                  <div className="p-3.5 rounded-2xl bg-slate-50 text-xs text-slate-600 flex items-center justify-between border border-slate-200">
                    <span>Total Diskon Promosi Diberikan Toko:</span>
                    <span className="font-bold text-slate-900">{formatRupiah(salesMetrics.totalDiscounts)}</span>
                  </div>
                )}
              </div>

              {/* Metode Pembayaran */}
              <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
                <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 border-b border-slate-100 pb-3">
                  <CreditCard className="w-4 h-4 text-orange-600" />
                  Pilihan Metode Pembayaran
                </h3>

                {salesMetrics.paymentBreakdown.length === 0 ? (
                  <div className="text-center py-10 text-slate-400 text-xs">Belum ada data pembayaran.</div>
                ) : (
                  <div className="space-y-3.5">
                    {salesMetrics.paymentBreakdown.map(([method, data]) => {
                      const percent =
                        salesMetrics.totalGMV > 0
                          ? Math.round((data.total / salesMetrics.totalGMV) * 100)
                          : 0;
                      return (
                        <div key={method} className="space-y-1">
                          <div className="flex items-center justify-between text-xs">
                            <span className="font-bold text-slate-800">{method}</span>
                            <div className="flex items-center gap-2 font-mono">
                              <span className="text-slate-500 text-[11px]">{data.count} tx</span>
                              <span className="font-extrabold text-slate-900">{formatRupiah(data.total)}</span>
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
          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 2: DAFTAR PRODUK TOKO (SERVER-SIDE PAGINATION)       */}
        {/* ======================================================== */}
        {activeTab === 'products' && (
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-100">
              <div>
                <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Package className="w-5 h-5 text-orange-500" />
                  Katalog Seluruh Produk Menu ({productsTotalCount} Produk)
                </h2>
                <p className="text-xs text-slate-500 mt-0.5">
                  Batas kuota produk:{' '}
                  <strong>
                    {business.max_products && business.max_products > 10000 ? 'Unlimited' : business.max_products ?? 50}
                  </strong>{' '}
                  item
                </p>
              </div>

              {/* Search, Filter & Export */}
              <div className="flex flex-wrap items-center gap-2.5">
                <div className="relative">
                  <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Cari nama produk / SKU..."
                    value={productSearch}
                    onChange={(e) => {
                      setProductSearch(e.target.value);
                      setProductsPage(1); // reset to page 1 on search
                    }}
                    className="pl-8.5 pr-4 py-2 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 focus:outline-none focus:border-orange-500 w-56"
                  />
                </div>

                <select
                  value={selectedCategory}
                  onChange={(e) => {
                    setSelectedCategory(e.target.value);
                    setProductsPage(1);
                  }}
                  className="px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-700 focus:outline-none focus:border-orange-500"
                >
                  <option value="ALL">Semua Kategori</option>
                  {categoriesList.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
                    </option>
                  ))}
                </select>

                <button
                  onClick={exportProductsToCSV}
                  title="Ekspor Katalog ke CSV"
                  className="px-3 py-2 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 text-xs font-bold flex items-center gap-1.5 shadow-2xs transition-colors"
                >
                  <Download className="w-3.5 h-3.5 text-slate-500" />
                  <span>Ekspor CSV</span>
                </button>
              </div>
            </div>

            {loadingProducts ? (
              <div className="text-center py-16">
                <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                <p className="text-xs text-slate-500">Memuat data produk...</p>
              </div>
            ) : menuItems.length === 0 ? (
              <div className="text-center py-16 text-slate-400 text-xs bg-slate-50/50 rounded-2xl border border-dashed border-slate-200">
                Tidak ada produk yang cocok dengan pencarian.
              </div>
            ) : (
              <>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-50 text-slate-500 uppercase font-bold text-[11px] border-b border-slate-200">
                      <tr>
                        <th className="py-3 px-4">Nama Produk</th>
                        <th className="py-3 px-4">Kategori</th>
                        <th className="py-3 px-4">Barcode / SKU</th>
                        <th className="py-3 px-4 text-right">Harga Jual</th>
                        <th className="py-3 px-4 text-center">Satuan</th>
                        <th className="py-3 px-4 text-center">Ketersediaan & Stok</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {menuItems.map((item) => {
                        const hasLowStock =
                          item.stock_quantity !== null &&
                          item.stock_quantity !== undefined &&
                          item.stock_quantity > 0 &&
                          item.stock_quantity <= 5;

                        return (
                          <tr key={item.id} className="hover:bg-slate-50/70 transition-colors">
                            <td className="py-3 px-4">
                              <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-lg bg-orange-50 border border-orange-200 flex items-center justify-center font-bold text-orange-700 text-xs flex-shrink-0">
                                  {item.name.charAt(0).toUpperCase()}
                                </div>
                                <div>
                                  <div className="font-bold text-slate-900 text-sm">{item.name}</div>
                                  {item.description && (
                                    <p className="text-[11px] text-slate-400 truncate max-w-xs">{item.description}</p>
                                  )}
                                </div>
                              </div>
                            </td>

                            <td className="py-3 px-4">
                              <span className="px-2 py-0.5 rounded-md bg-slate-100 border border-slate-200 text-slate-700 font-semibold text-[10px]">
                                {item.category || 'Umum'}
                              </span>
                            </td>

                            <td className="py-3 px-4 font-mono text-slate-500 text-[11px]">
                              {item.barcode || item.sku || '-'}
                            </td>

                            <td className="py-3 px-4 text-right font-black text-slate-900 text-sm">
                              {formatRupiah(item.price)}
                            </td>

                            <td className="py-3 px-4 text-center text-slate-600 font-semibold">
                              {item.unit || 'pcs'}
                            </td>

                            <td className="py-3 px-4 text-center">
                              {!item.stock_available ? (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800">
                                  Habis
                                </span>
                              ) : hasLowStock ? (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-900 flex items-center gap-1 justify-center w-fit mx-auto">
                                  <AlertTriangle className="w-3 h-3 text-amber-700" />
                                  Sisa {item.stock_quantity}
                                </span>
                              ) : (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                                  {item.stock_quantity !== null && item.stock_quantity !== undefined
                                    ? `Tersedia (${item.stock_quantity})`
                                    : 'Tersedia'}
                                </span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>

                {/* Paginasi Katalog Produk */}
                {productsTotalPages > 1 && (
                  <div className="flex flex-col sm:flex-row items-center justify-between gap-3 pt-5 border-t border-slate-100 text-xs">
                    <span className="text-slate-500">
                      Menampilkan{' '}
                      <strong>
                        {(productsPage - 1) * PRODUCTS_PER_PAGE + 1} -{' '}
                        {Math.min(productsPage * PRODUCTS_PER_PAGE, productsTotalCount)}
                      </strong>{' '}
                      dari <strong>{productsTotalCount}</strong> produk
                    </span>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => setProductsPage((p) => Math.max(1, p - 1))}
                        disabled={productsPage === 1}
                        className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                      >
                        <ChevronLeft className="w-4 h-4" /> Prev
                      </button>

                      <span className="px-3 py-1.5 rounded-xl bg-orange-50 text-orange-700 font-bold border border-orange-200">
                        {productsPage} / {productsTotalPages}
                      </span>

                      <button
                        onClick={() => setProductsPage((p) => Math.min(productsTotalPages, p + 1))}
                        disabled={productsPage === productsTotalPages}
                        className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                      >
                        Next <ChevronRight className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 3: RIWAYAT TRANSAKSI (SERVER-SIDE PAGINATION)        */}
        {/* ======================================================== */}
        {activeTab === 'orders' && (
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Receipt className="w-5 h-5 text-orange-500" />
                  Riwayat Seluruh Transaksi ({ordersTotalCount} Transaksi)
                </h2>
                <p className="text-xs text-slate-500 mt-0.5">Daftar transaksi kasir diurutkan dari yang terbaru</p>
              </div>

              {/* Status Filter */}
              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={ordersStatusFilter}
                  onChange={(e) => {
                    setOrdersStatusFilter(e.target.value);
                    setOrdersPage(1);
                  }}
                  className="px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-700 focus:outline-none focus:border-orange-500"
                >
                  <option value="ALL">Semua Status</option>
                  <option value="paid">Lunas (Paid)</option>
                  <option value="void">Void</option>
                  <option value="refunded">Refund</option>
                  <option value="draft">Draft</option>
                </select>

                <Link
                  href={`/dashboard/transactions?q=${encodeURIComponent(business.name)}`}
                  className="px-3.5 py-1.5 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold flex items-center gap-1.5 shadow-xs transition-colors"
                >
                  <span>Buka di Menu Transaksi</span>
                  <ArrowUpRight className="w-3.5 h-3.5" />
                </Link>
              </div>
            </div>

            {loadingOrders ? (
              <div className="text-center py-16">
                <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                <p className="text-xs text-slate-500">Memuat transaksi...</p>
              </div>
            ) : orders.length === 0 ? (
              <div className="p-16 text-center text-slate-400 text-xs bg-slate-50/50 rounded-2xl border border-dashed border-slate-200">
                Belum ada transaksi kasir yang tercatat untuk filter ini.
              </div>
            ) : (
              <>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-50 text-slate-500 uppercase font-bold text-[11px] border-b border-slate-200">
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
                      {orders.map((ord) => {
                        const dateStr = ord.created_at
                          ? new Date(ord.created_at).toLocaleString('id-ID', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric',
                              hour: '2-digit',
                              minute: '2-digit',
                            })
                          : '-';

                        const payMethod =
                          ord.order_payments && ord.order_payments.length > 0
                            ? ord.order_payments.map((p) => p.method_name || p.method_type).join(', ')
                            : 'Tunai';

                        return (
                          <tr key={ord.id} className="hover:bg-slate-50/70 transition-colors">
                            <td className="py-3 px-4 font-mono font-bold text-slate-900">{ord.invoice_number}</td>
                            <td className="py-3 px-4 text-slate-500">{dateStr}</td>
                            <td className="py-3 px-4 text-slate-700">{ord.customer_name || 'Pelanggan Umum'}</td>
                            <td className="py-3 px-4">
                              <span className="px-2 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-700 font-semibold text-[10px]">
                                {payMethod}
                              </span>
                            </td>
                            <td className="py-3 px-4 text-right font-black text-slate-900 text-sm">
                              {formatRupiah(ord.grand_total)}
                            </td>
                            <td className="py-3 px-4 text-center">
                              {ord.status === 'paid' && (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                                  Lunas
                                </span>
                              )}
                              {ord.status === 'void' && (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800">
                                  Void
                                </span>
                              )}
                              {ord.status === 'refunded' && (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800">
                                  Refund
                                </span>
                              )}
                              {ord.status === 'draft' && (
                                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-700">
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

                {/* Paginasi Transaksi */}
                {ordersTotalPages > 1 && (
                  <div className="flex flex-col sm:flex-row items-center justify-between gap-3 pt-5 border-t border-slate-100 text-xs">
                    <span className="text-slate-500">
                      Menampilkan{' '}
                      <strong>
                        {(ordersPage - 1) * ORDERS_PER_PAGE + 1} -{' '}
                        {Math.min(ordersPage * ORDERS_PER_PAGE, ordersTotalCount)}
                      </strong>{' '}
                      dari <strong>{ordersTotalCount}</strong> transaksi
                    </span>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => setOrdersPage((p) => Math.max(1, p - 1))}
                        disabled={ordersPage === 1}
                        className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                      >
                        <ChevronLeft className="w-4 h-4" /> Prev
                      </button>

                      <span className="px-3 py-1.5 rounded-xl bg-orange-50 text-orange-700 font-bold border border-orange-200">
                        {ordersPage} / {ordersTotalPages}
                      </span>

                      <button
                        onClick={() => setOrdersPage((p) => Math.min(ordersTotalPages, p + 1))}
                        disabled={ordersPage === ordersTotalPages}
                        className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-bold flex items-center gap-1"
                      >
                        Next <ChevronRight className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 4: PROFIL LENGKAP TOKO RETAIL & ALAMAT               */}
        {/* ======================================================== */}
        {activeTab === 'profile' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Owner Info */}
              <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
                <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 border-b border-slate-100 pb-3">
                  <User className="w-4 h-4 text-[#0070fc]" />
                  Identitas Pemilik (Owner)
                </h3>
                <div className="space-y-3.5 text-xs">
                  <div>
                    <span className="text-slate-400">Nama Lengkap:</span>
                    <div className="font-bold text-slate-900 text-sm mt-0.5">
                      {business.owner_name || business.profiles?.full_name || 'Tidak dicantumkan'}
                    </div>
                  </div>
                  <div>
                    <span className="text-slate-400">Email:</span>
                    <div className="font-medium text-slate-800 flex items-center gap-1.5 mt-0.5">
                      <Mail className="w-3.5 h-3.5 text-slate-400" />
                      <a
                        href={`mailto:${business.profiles?.email || business.email}`}
                        className="text-[#0070fc] hover:underline"
                      >
                        {business.profiles?.email || business.email || '-'}
                      </a>
                    </div>
                  </div>
                  <div>
                    <span className="text-slate-400">No Telepon / WhatsApp:</span>
                    <div className="flex items-center gap-2 mt-0.5">
                      <Phone className="w-3.5 h-3.5 text-slate-400" />
                      <span className="font-bold text-slate-800">
                        {business.phone || business.profiles?.phone || '-'}
                      </span>
                      {waNumber && (
                        <a
                          href={`https://wa.me/${waNumber}`}
                          target="_blank"
                          rel="noreferrer"
                          className="px-2.5 py-0.5 rounded-md bg-emerald-100 hover:bg-emerald-200 text-emerald-800 font-bold text-[10px] flex items-center gap-1"
                        >
                          <MessageCircle className="w-3 h-3 text-emerald-600" /> Chat WA
                        </a>
                      )}
                    </div>
                  </div>
                  <div>
                    <span className="text-slate-400">Metode Pendaftaran:</span>
                    <div className="font-medium text-slate-700 flex items-center gap-1.5 mt-0.5">
                      <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                      <span>{business.owner_user_id ? 'Akun Pengguna Mandiri' : 'Onboarding Terpadu (Super Admin / Sales Syupeo)'}</span>
                    </div>
                  </div>
                  <div>
                    <span className="text-slate-400">Bergabung Sejak:</span>
                    <div className="font-medium text-slate-700 flex items-center gap-1.5 mt-0.5">
                      <Calendar className="w-3.5 h-3.5 text-slate-400" />
                      <span>{createdAtFormatted}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Store Identity & Full Detailed Address */}
              <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-[#0070fc]" />
                    Alamat Lengkap & Wilayah Toko
                  </h3>
                  {googleMapsUrl && (
                    <a
                      href={googleMapsUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="px-2.5 py-1 rounded-lg bg-blue-50 text-[#0070fc] hover:bg-blue-100 text-[11px] font-bold flex items-center gap-1 transition-colors"
                    >
                      <ExternalLink className="w-3 h-3" /> Buka Google Maps
                    </a>
                  )}
                </div>

                <div className="space-y-3.5 text-xs">
                  <div>
                    <span className="text-slate-400">Nama Toko Retail:</span>
                    <div className="font-black text-slate-900 text-base mt-0.5">{business.name}</div>
                  </div>

                  <div className="p-3 bg-slate-50 border border-slate-200/80 rounded-xl space-y-1">
                    <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Alamat Lengkap / Patokan Jalan</span>
                    <div className="font-medium text-slate-800 text-xs">
                      {business.address || 'Belum diisi'}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3 pt-1">
                    <div className="p-2.5 bg-slate-50 border border-slate-200/60 rounded-xl">
                      <span className="text-[10px] font-semibold text-slate-400 uppercase">Desa / Kelurahan</span>
                      <div className="font-bold text-slate-800 text-xs mt-0.5">{business.village || '-'}</div>
                    </div>
                    <div className="p-2.5 bg-slate-50 border border-slate-200/60 rounded-xl">
                      <span className="text-[10px] font-semibold text-slate-400 uppercase">Kecamatan</span>
                      <div className="font-bold text-slate-800 text-xs mt-0.5">{business.district || '-'}</div>
                    </div>
                    <div className="p-2.5 bg-slate-50 border border-slate-200/60 rounded-xl">
                      <span className="text-[10px] font-semibold text-slate-400 uppercase">Kabupaten / Kota</span>
                      <div className="font-bold text-slate-800 text-xs mt-0.5">{business.city || '-'}</div>
                    </div>
                    <div className="p-2.5 bg-slate-50 border border-slate-200/60 rounded-xl">
                      <span className="text-[10px] font-semibold text-slate-400 uppercase">Provinsi</span>
                      <div className="font-bold text-slate-800 text-xs mt-0.5">{business.province || '-'}</div>
                    </div>
                  </div>

                  {business.latitude && business.longitude ? (
                    <div className="p-3 bg-emerald-50/60 border border-emerald-200/80 rounded-xl flex items-center justify-between">
                      <div>
                        <span className="text-[10px] font-bold text-emerald-800 uppercase">Koordinat GPS Presisi</span>
                        <div className="font-mono text-xs text-emerald-900 font-bold mt-0.5">
                          {business.latitude.toFixed(6)}, {business.longitude.toFixed(6)}
                        </div>
                      </div>
                      {googleMapsUrl && (
                        <a
                          href={googleMapsUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold shadow-2xs flex items-center gap-1"
                        >
                          <MapPin className="w-3.5 h-3.5" /> Peta
                        </a>
                      )}
                    </div>
                  ) : (
                    <div className="text-slate-400 italic">Koordinat GPS belum dikunci.</div>
                  )}
                </div>
              </div>
            </div>

            {/* Paket Starter Kit Usaha & Cabang Toko */}
            <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
              <h3 className="text-sm font-bold text-slate-900 flex items-center justify-between border-b border-slate-100 pb-3">
                <div className="flex items-center gap-2">
                  <Package className="w-4 h-4 text-[#0070fc]" />
                  Informasi Paket Usaha Starter Kit & Outlet
                </div>
                <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3 text-emerald-600" /> Siap Operasional POS
                </span>
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200">
                  <div className="text-xs text-slate-500 font-medium">Paket Usaha Terdaftar:</div>
                  <div className="text-base font-black text-slate-900 mt-1">
                    {business.retail_starter_kits?.name || 'Paket Usaha Retail'}
                  </div>
                  <p className="text-xs font-bold text-emerald-700 mt-1">
                    Investasi Awal: Rp 200.000 (1x di Muka)
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200">
                  <div className="text-xs text-slate-500 font-medium">Katalog Menu & Stok Awal:</div>
                  <div className="text-2xl font-black text-slate-900 mt-1">
                    {productsTotalCount} <span className="text-xs font-normal text-slate-500">item produk</span>
                  </div>
                  <p className="text-[11px] text-slate-500 mt-1">Otomatis di-seed dari paket perdana</p>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200">
                  <div className="text-xs text-slate-500 font-medium">Outlet Aktif:</div>
                  <div className="text-2xl font-black text-slate-900 mt-1">
                    {outlets.length} <span className="text-xs font-normal text-slate-500">outlet</span>
                  </div>
                  <p className="text-[11px] text-slate-500 mt-1">
                    {outlets.length > 0 ? outlets.map((o) => o.name).join(', ') : 'Toko Utama'}
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
