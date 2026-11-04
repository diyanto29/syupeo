'use client';

import { useState, useEffect, useMemo } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Warehouse, PackageFulfillmentOrder } from '@/types/database';
import {
  Truck,
  Building2,
  Calendar as CalendarIcon,
  Clock,
  CheckCircle2,
  AlertCircle,
  Search,
  Filter,
  Printer,
  ChevronRight,
  ChevronLeft,
  ShieldCheck,
  Send,
  X,
  Loader2,
  Check,
  Sparkles,
  ArrowRight,
  Navigation,
  Boxes,
  ChevronDown,
  ListChecks,
  FileText,
  RotateCcw,
  CalendarDays,
  CheckSquare,
  Square,
  Phone,
  MapPin,
  PackageCheck,
  User,
  ExternalLink,
} from 'lucide-react';

interface OrderManifestItem {
  name: string;
  quantity: number | string;
  unit: string;
  category?: string;
  barcode?: string;
}

// Manifest paket default fallback
const DEFAULT_PACKAGES_MANIFEST: Record<string, OrderManifestItem[]> = {
  'Paket 01 — Toko Pemula': [
    { name: 'Beras Premium 2 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'BRS-PRM-2K' },
    { name: 'Minyak Goreng 1 Liter', quantity: 1, unit: 'Pcs', category: 'Sembako', barcode: 'MYK-GRG-1L' },
    { name: 'Gula Pasir Kristal 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'GLA-PSR-1K' },
    { name: 'Tepung Terigu 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'TPG-TRG-1K' },
    { name: 'Mi Instan Pilihan (Indomie/Mie Sedaap)', quantity: 5, unit: 'Pcs', category: 'Makanan Cepat Saji', barcode: 'MI-INST-5P' },
    { name: 'Kopi Sachet Pilihan', quantity: 10, unit: 'Sachet', category: 'Minuman', barcode: 'KPI-SCH-10' },
    { name: 'Teh Celup Kotak', quantity: 1, unit: 'Kotak', category: 'Minuman', barcode: 'TEH-CLP-01' },
    { name: 'Sabun Mandi Batang', quantity: 2, unit: 'Pcs', category: 'Perawatan Tubuh', barcode: 'SBN-MND-02' },
    { name: 'Sabun Cuci Piring Cair 400ml', quantity: 1, unit: 'Pcs', category: 'Kebutuhan Rumah', barcode: 'SBN-CPR-01' },
    { name: 'Deterjen Pakaian Bersih 800g', quantity: 1, unit: 'Bks', category: 'Kebutuhan Rumah', barcode: 'DTR-PKN-01' },
    { name: 'Pasta Gigi Keluarga 120g', quantity: 1, unit: 'Pcs', category: 'Perawatan Tubuh', barcode: 'PST-GGI-01' },
    { name: 'Kecap Manis Botol 135ml', quantity: 1, unit: 'Botol', category: 'Bumbu Dapur', barcode: 'KCP-MNS-01' },
    { name: 'Tisu Wajah & Kemasan Syupeo Store', quantity: 1, unit: 'Paket', category: 'Perlengkapan Toko', barcode: 'TSU-KMS-01' },
  ],
  'Paket 02 — Gen Z Box': [
    { name: 'Phone Charm Kekinian Trendi', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-PHC-05' },
    { name: 'Pop Socket Karakter Viral', quantity: 3, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-PSK-03' },
    { name: 'Pelindung Kabel Handphone Spiral', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-KBL-05' },
    { name: 'Scrunchie Rambut Satin Estetik', quantity: 5, unit: 'Pcs', category: 'Fashion & Beauty', barcode: 'ACC-SCR-05' },
    { name: 'Jepit Rambut Korea Doff', quantity: 4, unit: 'Pcs', category: 'Fashion & Beauty', barcode: 'ACC-JPT-04' },
    { name: 'Gantungan Kunci Karakter Akrilik', quantity: 5, unit: 'Pcs', category: 'Merchandise', barcode: 'ACC-GCI-05' },
    { name: 'Sticker Pack Hologram Vinyl', quantity: 10, unit: 'Pack', category: 'Stationery', barcode: 'STK-HLG-10' },
    { name: 'Kaos Kaki Korea Stylish', quantity: 3, unit: 'Pasang', category: 'Fashion', barcode: 'FSH-KSK-03' },
    { name: 'Mini Canvas Tote Bag Estetik', quantity: 2, unit: 'Pcs', category: 'Fashion', barcode: 'BAG-MIN-02' },
    { name: 'Mini Makeup Pouch Velvet', quantity: 2, unit: 'Pcs', category: 'Fashion', barcode: 'PCH-VEL-02' },
  ],
  'Paket 03 — Beauty Box Makarizo': [
    { name: 'Makarizo Hair Energy Creambath 500g', quantity: 2, unit: 'Jar', category: 'Perawatan Rambut', barcode: 'MKZ-CRB-500' },
    { name: 'Makarizo Hair Energy Scentsations Spray 100ml', quantity: 4, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SCT-100' },
    { name: 'Makarizo Fibertherapy Conditioning Shampoo 170ml', quantity: 3, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SMP-170' },
    { name: 'Makarizo Advisor Hair Recovery Serum Vitamax 50ml', quantity: 2, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SRM-050' },
    { name: 'Makarizo Easy Straight Hair Straightening Kit 120ml', quantity: 2, unit: 'Set', category: 'Perawatan Rambut', barcode: 'MKZ-STR-120' },
    { name: 'Alat Sisir Salon & Display Stand Makarizo', quantity: 1, unit: 'Set', category: 'Display Toko', barcode: 'MKZ-DSP-001' },
  ],
};

export default function ShipmentsPage() {
  const [viewMode, setViewMode] = useState<'list' | 'timeline' | 'calendar'>('list');
  const [orders, setOrders] = useState<PackageFulfillmentOrder[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [starterKitItemsMap, setStarterKitItemsMap] = useState<Record<string, any[]>>({});
  const [loading, setLoading] = useState(true);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [warehouseFilter, setWarehouseFilter] = useState('ALL');
  const [datePreset, setDatePreset] = useState<
    'ALL' | 'today' | 'yesterday' | '7days' | '30days' | 'this_month' | 'custom'
  >('ALL');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  // Interactive UI States
  const [expandedOrderIds, setExpandedOrderIds] = useState<Set<string>>(new Set());
  const [checkedItemsMap, setCheckedItemsMap] = useState<Record<string, Set<number>>>({});
  const [selectedOrder, setSelectedOrder] = useState<PackageFulfillmentOrder | null>(null);
  const [isDispatchModalOpen, setIsDispatchModalOpen] = useState(false);
  const [isPrintModalOpen, setIsPrintModalOpen] = useState(false);
  const [selectedTimelineOrderId, setSelectedTimelineOrderId] = useState<string | null>(null);

  // Calendar State
  const [calendarDate, setCalendarDate] = useState<Date>(new Date());
  const [selectedCalendarDate, setSelectedCalendarDate] = useState<string | null>(null);
  const [isDatePopupOpen, setIsDatePopupOpen] = useState(false);

  // Form Dispatch
  const [driverName, setDriverName] = useState('');
  const [driverPhone, setDriverPhone] = useState('');
  const [trackingNumber, setTrackingNumber] = useState('');
  const [dispatchWarehouseId, setDispatchWarehouseId] = useState('');
  const [targetStatus, setTargetStatus] = useState<string>('in_transit');
  const [notifyWaOnDispatch, setNotifyWaOnDispatch] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Feedback Notifications
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    try {
      // 1. Fetch Warehouses
      const { data: whData } = await supabase
        .from('warehouses')
        .select('*')
        .order('name', { ascending: true });
      if (whData) setWarehouses(whData as Warehouse[]);

      // 2. Fetch Starter Kit Items Map
      try {
        const { data: skItems } = await supabase
          .from('retail_starter_kit_items')
          .select('*')
          .order('sort_order', { ascending: true });
        if (skItems && skItems.length > 0) {
          const map: Record<string, any[]> = {};
          skItems.forEach((it: any) => {
            const kitId = it.starter_kit_id || 'default';
            if (!map[kitId]) map[kitId] = [];
            map[kitId].push(it);
          });
          setStarterKitItemsMap(map);
        }
      } catch (e) {
        console.warn('Gagal memuat starter kit items, memakai fallback.');
      }

      // 3. Fetch Fulfillment Orders
      const { data: ordData, error } = await supabase
        .from('package_fulfillment_orders')
        .select('*, warehouse:warehouses(*)')
        .order('created_at', { ascending: false });

      if (error) throw error;
      if (ordData) {
        setOrders(ordData as PackageFulfillmentOrder[]);
        if (ordData.length > 0 && !selectedTimelineOrderId) {
          setSelectedTimelineOrderId(ordData[0].id);
        }
      }
    } catch (err: any) {
      console.error(err);
      setErrorMsg(`Gagal memuat data: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Helper Manifest Barang
  const getOrderManifestItems = (order: PackageFulfillmentOrder): OrderManifestItem[] => {
    if (order.notes) {
      try {
        const trimmed = order.notes.trim();
        if (trimmed.startsWith('{') || trimmed.includes('"wholesale_items"') || trimmed.includes('"items"')) {
          const parsed = JSON.parse(trimmed);
          if (Array.isArray(parsed.items) && parsed.items.length > 0) {
            return parsed.items.map((it: any) => ({
              name: it.name || it.product_name || 'Produk Kulakan',
              quantity: it.quantity || 1,
              unit: it.unit || 'Pcs',
              category: it.category || 'Kulakan Satuan',
              barcode: it.barcode || it.sku || it.catalog_id?.substring(0, 8) || '-',
            }));
          }
        }
      } catch {}
    }

    if (order.starter_kit_id && starterKitItemsMap[order.starter_kit_id]?.length > 0) {
      return starterKitItemsMap[order.starter_kit_id].map((it: any) => ({
        name: it.product_name,
        quantity: it.quantity || 1,
        unit: it.unit || 'Pcs',
        category: it.category || 'Starter Kit',
        barcode: it.barcode || '-',
      }));
    }

    const matchedKey = Object.keys(DEFAULT_PACKAGES_MANIFEST).find(
      (k) =>
        order.kit_name?.toLowerCase().includes(k.toLowerCase()) ||
        k.toLowerCase().includes(order.kit_name?.toLowerCase() || '')
    );
    if (matchedKey && DEFAULT_PACKAGES_MANIFEST[matchedKey]) {
      return DEFAULT_PACKAGES_MANIFEST[matchedKey];
    }

    return [
      {
        name: order.kit_name || 'Paket Usaha Retail Syupeo',
        quantity: 1,
        unit: 'Paket',
        category: 'Starter Kit Retail',
        barcode: order.order_code,
      },
    ];
  };

  // Helper Filter Tanggal
  const isOrderInDateRange = (createdAt?: string): boolean => {
    if (datePreset === 'ALL' && !startDate && !endDate) return true;
    if (!createdAt) return false;

    const orderDate = new Date(createdAt);
    if (isNaN(orderDate.getTime())) return true;

    const now = new Date();
    const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
    const endOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);

    if (datePreset === 'today') {
      return orderDate >= startOfDay(now) && orderDate <= endOfDay(now);
    }
    if (datePreset === 'yesterday') {
      const yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      return orderDate >= startOfDay(yesterday) && orderDate <= endOfDay(yesterday);
    }
    if (datePreset === '7days') {
      const past7 = new Date(now);
      past7.setDate(past7.getDate() - 7);
      return orderDate >= startOfDay(past7) && orderDate <= endOfDay(now);
    }
    if (datePreset === '30days') {
      const past30 = new Date(now);
      past30.setDate(past30.getDate() - 30);
      return orderDate >= startOfDay(past30) && orderDate <= endOfDay(now);
    }
    if (datePreset === 'this_month') {
      const firstDay = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      return orderDate >= firstDay && orderDate <= endOfDay(now);
    }
    if (datePreset === 'custom') {
      if (startDate) {
        const s = new Date(`${startDate}T00:00:00`);
        if (orderDate < s) return false;
      }
      if (endDate) {
        const e = new Date(`${endDate}T23:59:59.999`);
        if (orderDate > e) return false;
      }
      return true;
    }
    return true;
  };

  // Filtered Orders
  const filteredOrders = useMemo(() => {
    return orders.filter((o) => {
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch =
        !q ||
        o.order_code.toLowerCase().includes(q) ||
        o.recipient_name.toLowerCase().includes(q) ||
        o.kit_name.toLowerCase().includes(q) ||
        o.shipping_city.toLowerCase().includes(q) ||
        (o.tracking_number && o.tracking_number.toLowerCase().includes(q)) ||
        (o.driver_name && o.driver_name.toLowerCase().includes(q));

      const matchesStatus = statusFilter === 'ALL' || o.status === statusFilter;
      const matchesWarehouse = warehouseFilter === 'ALL' || o.assigned_warehouse_id === warehouseFilter;
      const matchesDate = isOrderInDateRange(o.created_at);

      return matchesSearch && matchesStatus && matchesWarehouse && matchesDate;
    });
  }, [orders, searchQuery, statusFilter, warehouseFilter, datePreset, startDate, endDate]);

  const resetAllFilters = () => {
    setSearchQuery('');
    setStatusFilter('ALL');
    setWarehouseFilter('ALL');
    setDatePreset('ALL');
    setStartDate('');
    setEndDate('');
  };

  const isAnyFilterActive =
    searchQuery !== '' ||
    statusFilter !== 'ALL' ||
    warehouseFilter !== 'ALL' ||
    datePreset !== 'ALL' ||
    startDate !== '' ||
    endDate !== '';

  // Expand / Toggle Checklist
  const toggleExpandOrder = (id: string) => {
    setExpandedOrderIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleItemCheck = (orderId: string, idx: number) => {
    setCheckedItemsMap((prev) => {
      const current = new Set(prev[orderId] || []);
      if (current.has(idx)) current.delete(idx);
      else current.add(idx);
      return { ...prev, [orderId]: current };
    });
  };

  // WhatsApp Notification Helper
  const sendWhatsAppNotification = (order: PackageFulfillmentOrder, status: string, kurir: string, resi: string) => {
    let cleanPhone = order.recipient_phone.replace(/\D/g, '');
    if (cleanPhone.startsWith('0')) cleanPhone = '62' + cleanPhone.substring(1);
    if (!cleanPhone.startsWith('62')) cleanPhone = '62' + cleanPhone;

    let msg = '';
    if (status === 'packing') {
      msg = `Halo Kak ${order.recipient_name}! 👋\n\nPesanan pasokan toko Anda (*${order.order_code}* - ${order.kit_name}) saat ini *SEDANG DIKEMAS* oleh tim Gudang Syupeo.\n\nBarang sedang disiapkan dengan teliti dan segera diserahkan ke armada pengiriman. Terima kasih! 🙏`;
    } else if (status === 'in_transit') {
      msg = `Halo Kak ${order.recipient_name}! 🚚\n\nPesanan pasokan toko Anda (*${order.order_code}* - ${order.kit_name}) saat ini *SEDANG DALAM PERJALANAN*:\n• Kurir / Ekspedisi: ${kurir}\n• No. Resi / AWB: ${resi}\n• Alamat Tujuan: ${order.shipping_address}, ${order.shipping_city}\n\nSilakan pantau status pengiriman melalui aplikasi Kasir Syupeo Anda.`;
    } else if (status === 'delivered') {
      msg = `Halo Kak ${order.recipient_name}! 🎉\n\nPesanan pasokan toko Anda (*${order.order_code}* - ${order.kit_name}) telah *SELESAI DITERIMA* di lokasi toko.\n\nSelamat berniaga dan sukses selalu bersama Syupeo! 🌟`;
    }

    if (msg) {
      window.open(`https://wa.me/${cleanPhone}?text=${encodeURIComponent(msg)}`, '_blank');
    }
  };

  // Update Status Order
  const handleUpdateOrderStatus = async (orderId: string, newStatus: string, extraData: any = {}) => {
    setIsSubmitting(true);
    try {
      const payload: any = {
        status: newStatus,
        updated_at: new Date().toISOString(),
        ...extraData,
      };
      if (newStatus === 'in_transit' && !payload.dispatched_at) {
        payload.dispatched_at = new Date().toISOString();
      }
      if (newStatus === 'delivered' && !payload.delivered_at) {
        payload.delivered_at = new Date().toISOString();
      }

      const { error } = await supabase.from('package_fulfillment_orders').update(payload).eq('id', orderId);
      if (error) throw error;

      if (notifyWaOnDispatch && selectedOrder) {
        const kurir = extraData.driver_name || selectedOrder.driver_name || 'Kurir Internal Syupeo Hub';
        const resi = extraData.tracking_number || selectedOrder.tracking_number || selectedOrder.order_code;
        sendWhatsAppNotification(selectedOrder, newStatus, kurir, resi);
      }

      setSuccessMsg(`Status order berhasil diubah menjadi "${newStatus.replace('_', ' ').toUpperCase()}".`);
      setIsDispatchModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal update status: ${err.message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Open Modal Dispatch
  const openDispatchModal = (order: PackageFulfillmentOrder, defaultStatus: string = 'in_transit') => {
    setSelectedOrder(order);
    setTargetStatus(defaultStatus);
    setDriverName(order.driver_name || 'Armada Syupeo Direct');
    setDriverPhone(order.driver_phone || '085624277920');
    setTrackingNumber(order.tracking_number || `SYU-${Date.now().toString().slice(-6)}`);
    setDispatchWarehouseId(order.assigned_warehouse_id || (warehouses[0]?.id ?? ''));
    setIsDispatchModalOpen(true);
  };

  // Calendar Helpers
  const calendarMonthYear = useMemo(() => {
    return calendarDate.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' });
  }, [calendarDate]);

  const calendarDays = useMemo(() => {
    const year = calendarDate.getFullYear();
    const month = calendarDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);

    const startingDayIndex = (firstDay.getDay() + 6) % 7; // Senin = 0, Minggu = 6
    const totalDays = lastDay.getDate();

    const days: Array<{
      dateString: string;
      dayNumber: number;
      isCurrentMonth: boolean;
      orders: PackageFulfillmentOrder[];
    }> = [];

    // Hari dari bulan sebelumnya
    const prevMonthLastDay = new Date(year, month, 0).getDate();
    for (let i = startingDayIndex - 1; i >= 0; i--) {
      const d = prevMonthLastDay - i;
      const prevDate = new Date(year, month - 1, d);
      const ds = prevDate.toISOString().split('T')[0];
      days.push({
        dateString: ds,
        dayNumber: d,
        isCurrentMonth: false,
        orders: orders.filter((o) => o.created_at?.startsWith(ds)),
      });
    }

    // Hari bulan aktif
    for (let d = 1; d <= totalDays; d++) {
      const current = new Date(year, month, d);
      const ds = `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      days.push({
        dateString: ds,
        dayNumber: d,
        isCurrentMonth: true,
        orders: orders.filter((o) => o.created_at?.startsWith(ds)),
      });
    }

    // Hari bulan berikutnya hingga kelipatan 7
    const remaining = (7 - (days.length % 7)) % 7;
    for (let d = 1; d <= remaining; d++) {
      const nextDate = new Date(year, month + 1, d);
      const ds = nextDate.toISOString().split('T')[0];
      days.push({
        dateString: ds,
        dayNumber: d,
        isCurrentMonth: false,
        orders: orders.filter((o) => o.created_at?.startsWith(ds)),
      });
    }

    return days;
  }, [calendarDate, orders]);

  const calendarSelectedOrders = useMemo(() => {
    if (!selectedCalendarDate) return [];
    return orders.filter((o) => o.created_at?.startsWith(selectedCalendarDate));
  }, [orders, selectedCalendarDate]);

  // Selected Order for Timeline
  const currentTimelineOrder = useMemo(() => {
    return orders.find((o) => o.id === selectedTimelineOrderId) || filteredOrders[0] || orders[0];
  }, [orders, filteredOrders, selectedTimelineOrderId]);

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-20">
      {/* ── Top Navbar ────────────────────────────────────────── */}
      <Navbar
        title="Logistik & Pengiriman Paket"
        description="Pantau alur dispatch pengiriman paket retail & kulakan, timeline pelacakan kurir, dan kalender pengiriman interaktif."
      />

      {/* ── Top Metric Highlights (KPI Cards) ─────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-[12px] bg-white border border-[rgba(0,0,0,0.08)] shadow-xs flex items-center gap-3.5 hover:shadow-md transition-shadow">
          <div className="w-12 h-12 rounded-[10px] bg-blue-50 border border-blue-200 flex items-center justify-center text-[#0070fc]">
            <Truck className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Total Order Pengiriman</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">{orders.length} Pesanan</h4>
          </div>
        </div>

        <div className="p-4 rounded-[12px] bg-white border border-[rgba(0,0,0,0.08)] shadow-xs flex items-center gap-3.5 hover:shadow-md transition-shadow">
          <div className="w-12 h-12 rounded-[10px] bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
            <Clock className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Menunggu Packing / Dispatch</p>
            <h4 className="text-xl font-black text-amber-700 mt-0.5">
              {orders.filter((o) => o.status === 'pending_dispatch' || o.status === 'packing').length} Paket
            </h4>
          </div>
        </div>

        <div className="p-4 rounded-[12px] bg-white border border-[rgba(0,0,0,0.08)] shadow-xs flex items-center gap-3.5 hover:shadow-md transition-shadow relative overflow-hidden">
          <div className="w-12 h-12 rounded-[10px] bg-orange-50 border border-orange-200 flex items-center justify-center text-orange-600">
            <Navigation className="w-6 h-6 animate-pulse" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Sedang Diantar Kurir</p>
            <h4 className="text-xl font-black text-orange-600 mt-0.5">
              {orders.filter((o) => o.status === 'in_transit').length} In-Transit
            </h4>
          </div>
        </div>

        <div className="p-4 rounded-[12px] bg-white border border-[rgba(0,0,0,0.08)] shadow-xs flex items-center gap-3.5 hover:shadow-md transition-shadow">
          <div className="w-12 h-12 rounded-[10px] bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Selesai Diterima Toko</p>
            <h4 className="text-xl font-black text-emerald-700 mt-0.5">
              {orders.filter((o) => o.status === 'delivered').length} Sukses
            </h4>
          </div>
        </div>
      </div>

      {/* ── Alerts ────────────────────────────────────────────── */}
      {errorMsg && (
        <div className="p-4 rounded-[10px] bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-center justify-between shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0 text-rose-600" />
            <span className="font-semibold">{errorMsg}</span>
          </div>
          <button onClick={() => setErrorMsg(null)} className="text-rose-600 hover:text-rose-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}
      {successMsg && (
        <div className="p-4 rounded-[10px] bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center justify-between shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-600" />
            <span className="font-semibold">{successMsg}</span>
          </div>
          <button onClick={() => setSuccessMsg(null)} className="text-emerald-600 hover:text-emerald-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* ── VIEW SWITCHER HEADER (Tabs: List, Timeline, Calendar) ─ */}
      <div className="bg-white p-3.5 rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-full w-fit">
          <button
            onClick={() => setViewMode('list')}
            className={`px-4 py-2 rounded-full text-xs font-bold transition-all flex items-center gap-2 ${
              viewMode === 'list'
                ? 'bg-white text-[#0070fc] shadow-xs scale-[1.02]'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <ListChecks className="w-4 h-4" />
            <span>Tampilan List & Tabel</span>
          </button>

          <button
            onClick={() => setViewMode('timeline')}
            className={`px-4 py-2 rounded-full text-xs font-bold transition-all flex items-center gap-2 ${
              viewMode === 'timeline'
                ? 'bg-white text-[#0070fc] shadow-xs scale-[1.02]'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Clock className="w-4 h-4" />
            <span>View Timeline Pelacakan</span>
          </button>

          <button
            onClick={() => setViewMode('calendar')}
            className={`px-4 py-2 rounded-full text-xs font-bold transition-all flex items-center gap-2 ${
              viewMode === 'calendar'
                ? 'bg-white text-[#0070fc] shadow-xs scale-[1.02]'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <CalendarDays className="w-4 h-4" />
            <span>Kalender Jadwal Kirim</span>
          </button>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={loadData}
            title="Refresh Data"
            className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 transition-colors flex items-center gap-1.5 text-xs font-semibold"
          >
            <RotateCcw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span className="hidden sm:inline">Segarkan</span>
          </button>
        </div>
      </div>

      {/* ── FILTER BAR LENGKAP (Pencarian, Status, Gudang & Tanggal) ── */}
      <div className="bg-white p-4 rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs space-y-3">
        {/* Row 1: Search & Status */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="relative flex-1">
            <Search className="w-4 h-4 absolute left-3 top-3 text-slate-400" />
            <input
              type="text"
              placeholder="Cari no resi, nama toko/penerima, kota, atau supir armada..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-4 py-2 text-xs rounded-[8px] border border-slate-200 focus:outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc]"
            />
          </div>

          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
            <span className="text-[11px] font-bold text-slate-400 whitespace-nowrap mr-1">Status:</span>
            {[
              { id: 'ALL', label: 'Semua' },
              { id: 'pending_dispatch', label: 'Menunggu' },
              { id: 'packing', label: 'Packing' },
              { id: 'in_transit', label: 'Diantar' },
              { id: 'delivered', label: 'Terkirim' },
            ].map((st) => (
              <button
                key={st.id}
                onClick={() => setStatusFilter(st.id)}
                className={`px-3 py-1.5 rounded-[6px] text-[11px] font-bold tracking-tight whitespace-nowrap transition-all ${
                  statusFilter === st.id
                    ? 'bg-[#0070fc] text-white shadow-2xs'
                    : 'bg-slate-100 hover:bg-slate-200 text-slate-600'
                }`}
              >
                {st.label}
              </button>
            ))}
          </div>
        </div>

        {/* Row 2: Filter Tanggal & Presets */}
        <div className="pt-2.5 border-t border-slate-100 flex flex-col lg:flex-row lg:items-center justify-between gap-3 text-xs">
          <div className="flex flex-wrap items-center gap-1.5">
            <div className="flex items-center gap-1.5 text-slate-500 font-bold text-[11px] mr-1">
              <CalendarIcon className="w-3.5 h-3.5 text-[#0070fc]" />
              <span>Tanggal:</span>
            </div>

            {[
              { id: 'ALL', label: 'Semua' },
              { id: 'today', label: 'Hari Ini' },
              { id: 'yesterday', label: 'Kemarin' },
              { id: '7days', label: '7 Hari Terakhir' },
              { id: '30days', label: '30 Hari Terakhir' },
              { id: 'this_month', label: 'Bulan Ini' },
              { id: 'custom', label: 'Rentang Kustom' },
            ].map((preset) => (
              <button
                key={preset.id}
                onClick={() => {
                  setDatePreset(preset.id as any);
                  if (preset.id !== 'custom') {
                    setStartDate('');
                    setEndDate('');
                  }
                }}
                className={`px-2.5 py-1 rounded-[6px] text-[11px] font-bold transition-all ${
                  datePreset === preset.id
                    ? 'bg-[#0070fc] text-white shadow-2xs'
                    : 'bg-slate-100 hover:bg-slate-200 text-slate-600'
                }`}
              >
                {preset.label}
              </button>
            ))}

            {/* Warehouse Dropdown */}
            {warehouses.length > 0 && (
              <div className="ml-2 flex items-center gap-1.5 pl-2 border-l border-slate-200">
                <span className="text-[11px] font-bold text-slate-400">Gudang:</span>
                <select
                  value={warehouseFilter}
                  onChange={(e) => setWarehouseFilter(e.target.value)}
                  className="px-2 py-1 text-[11px] font-bold rounded-[6px] border border-slate-200 bg-white text-slate-700 focus:outline-none focus:border-[#0070fc]"
                >
                  <option value="ALL">Semua Node Gudang</option>
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name} ({w.city})
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          {/* Matches & Reset Button */}
          <div className="flex items-center gap-2 self-end lg:self-center">
            <span className="text-[11px] text-slate-500 font-medium">
              Menampilkan <strong className="text-slate-900 font-bold">{filteredOrders.length}</strong> dari{' '}
              {orders.length} order
            </span>

            {isAnyFilterActive && (
              <button
                onClick={resetAllFilters}
                className="flex items-center gap-1 px-2.5 py-1 rounded-[6px] bg-rose-50 hover:bg-rose-100 text-rose-600 font-bold text-[11px] transition-colors"
                title="Reset semua filter pencarian"
              >
                <RotateCcw className="w-3 h-3" />
                <span>Reset Filter</span>
              </button>
            )}
          </div>
        </div>

        {/* Input Rentang Tanggal Kustom */}
        {datePreset === 'custom' && (
          <div className="p-3 bg-slate-50 border border-slate-200 rounded-[8px] flex flex-wrap items-center gap-3 text-xs animate-in fade-in duration-200">
            <div className="flex items-center gap-2">
              <span className="text-slate-500 font-semibold text-[11px]">Dari:</span>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="px-2.5 py-1.5 rounded-[6px] border border-slate-300 text-slate-800 text-xs bg-white focus:outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc]"
              />
            </div>

            <div className="flex items-center gap-2">
              <span className="text-slate-500 font-semibold text-[11px]">Sampai:</span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="px-2.5 py-1.5 rounded-[6px] border border-slate-300 text-slate-800 text-xs bg-white focus:outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc]"
              />
            </div>

            {(startDate || endDate) && (
              <button
                onClick={() => {
                  setStartDate('');
                  setEndDate('');
                }}
                className="text-[11px] font-bold text-slate-500 hover:text-slate-800 underline ml-auto"
              >
                Bersihkan Rentang
              </button>
            )}
          </div>
        )}
      </div>

      {/* ========================================================
          MODE 1: LIST / TABLE VIEW
          ======================================================== */}
      {viewMode === 'list' && (
        <div className="space-y-4">
          {filteredOrders.length === 0 ? (
            <div className="bg-white p-12 rounded-[12px] border border-[rgba(0,0,0,0.08)] text-center space-y-3 shadow-xs">
              <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center mx-auto text-slate-400">
                <Truck className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-slate-800 text-sm">Tidak Ada Order Pengiriman</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                Tidak ada data pesanan yang cocok dengan kriteria pencarian dan rentang tanggal yang dipilih.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-3.5">
              {filteredOrders.map((order) => {
                const assignedWh = order.warehouse || warehouses.find((w) => w.id === order.assigned_warehouse_id);
                const manifestItems = getOrderManifestItems(order);
                const isExpanded = expandedOrderIds.has(order.id);
                const checkedSet = checkedItemsMap[order.id] || new Set();
                const allChecked = manifestItems.length > 0 && checkedSet.size === manifestItems.length;

                return (
                  <div
                    key={order.id}
                    className="bg-white rounded-[12px] border border-[rgba(0,0,0,0.08)] hover:border-slate-300 shadow-xs hover:shadow-md transition-all overflow-hidden"
                  >
                    <div className="p-5 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                      {/* Left Details */}
                      <div className="space-y-2 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-mono text-xs font-black text-[#0070fc] bg-blue-50 px-2.5 py-0.5 rounded border border-blue-200">
                            {order.order_code}
                          </span>
                          <span className="text-xs font-bold text-slate-900">{order.kit_name}</span>

                          <span
                            className={`text-[10px] font-black uppercase px-2.5 py-0.5 rounded-full ${
                              order.status === 'delivered'
                                ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                                : order.status === 'in_transit'
                                ? 'bg-amber-100 text-amber-800 border border-amber-200 animate-pulse'
                                : order.status === 'packing'
                                ? 'bg-blue-100 text-blue-800 border border-blue-200'
                                : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            {order.status.replace('_', ' ')}
                          </span>

                          <span className="text-[11px] font-bold text-[#0070fc] bg-blue-50 px-2 py-0.5 rounded-full">
                            📦 {manifestItems.length} Item
                          </span>

                          {order.created_at && (
                            <span className="inline-flex items-center gap-1 text-[11px] font-bold text-slate-600 bg-slate-50 border border-slate-200 px-2 py-0.5 rounded-full">
                              <CalendarIcon className="w-3 h-3 text-slate-400" />
                              {new Date(order.created_at).toLocaleDateString('id-ID', {
                                day: '2-digit',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </span>
                          )}
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">
                          <div>
                            <p className="text-slate-400 text-[10px] font-semibold uppercase">Penerima (Toko Mitra):</p>
                            <p className="font-bold text-slate-800 mt-0.5">
                              {order.recipient_name} •{' '}
                              <span className="font-mono text-slate-600">{order.recipient_phone}</span>
                            </p>
                            <p className="text-slate-500 text-[11px] leading-snug mt-0.5">
                              {order.shipping_address}, {order.shipping_city}
                            </p>
                          </div>

                          <div>
                            <p className="text-slate-400 text-[10px] font-semibold uppercase">Node Gudang Pengirim:</p>
                            <div className="flex items-center gap-1.5 mt-0.5">
                              <Building2 className="w-3.5 h-3.5 text-[#0070fc]" />
                              <span className="font-bold text-slate-900">
                                {assignedWh ? assignedWh.name : 'Pusat Syupeo (Cleo Hub)'}
                              </span>
                            </div>
                            <div className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-2">
                              <span>
                                Jarak: <strong className="font-mono text-slate-700">{order.distance_km || '3.8'} km</strong>
                              </span>
                              <span>•</span>
                              <span className="text-blue-700 font-semibold bg-blue-50 px-1 rounded">
                                Kurir: {order.driver_name || 'Armada Toko'}
                              </span>
                            </div>
                          </div>
                        </div>

                        {/* Driver / Resi Banner if in_transit */}
                        {order.tracking_number && (
                          <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded bg-slate-100 border border-slate-200 text-[11px] text-slate-700">
                            <span className="font-bold">No. Resi / AWB:</span>
                            <span className="font-mono font-bold text-[#0070fc]">{order.tracking_number}</span>
                            {order.driver_phone && (
                              <span className="text-slate-500">({order.driver_name} - {order.driver_phone})</span>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Right Action Buttons */}
                      <div className="flex flex-wrap lg:flex-col items-center lg:items-end gap-2 shrink-0">
                        {order.status === 'pending_dispatch' && (
                          <button
                            onClick={() => handleUpdateOrderStatus(order.id, 'packing')}
                            className="px-3.5 py-1.5 rounded-[8px] bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-xs active:scale-95 transition-all flex items-center gap-1.5"
                          >
                            <Boxes className="w-3.5 h-3.5" />
                            <span>Mulai Packing</span>
                          </button>
                        )}

                        {order.status === 'packing' && (
                          <button
                            onClick={() => openDispatchModal(order, 'in_transit')}
                            className="px-3.5 py-1.5 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs shadow-xs active:scale-95 transition-all flex items-center gap-1.5"
                          >
                            <Truck className="w-3.5 h-3.5" />
                            <span>Serahkan ke Kurir</span>
                          </button>
                        )}

                        {order.status === 'in_transit' && (
                          <button
                            onClick={() => handleUpdateOrderStatus(order.id, 'delivered')}
                            className="px-3.5 py-1.5 rounded-[8px] bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs active:scale-95 transition-all flex items-center gap-1.5"
                          >
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            <span>Konfirmasi Terkirim</span>
                          </button>
                        )}

                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => {
                              setSelectedOrder(order);
                              setIsPrintModalOpen(true);
                            }}
                            className="p-1.5 rounded-[8px] border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-semibold flex items-center gap-1"
                            title="Cetak Surat Jalan & Label Pengiriman"
                          >
                            <Printer className="w-3.5 h-3.5" />
                            <span className="text-[11px]">Surat Jalan</span>
                          </button>

                          <button
                            onClick={() =>
                              sendWhatsAppNotification(
                                order,
                                order.status,
                                order.driver_name || 'Armada Syupeo Direct',
                                order.tracking_number || order.order_code
                              )
                            }
                            className="p-1.5 rounded-[8px] border border-emerald-200 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 text-xs font-semibold flex items-center gap-1"
                            title="Kirim Notifikasi WhatsApp ke Toko"
                          >
                            <Send className="w-3.5 h-3.5" />
                            <span className="text-[11px]">WA</span>
                          </button>

                          <button
                            onClick={() => toggleExpandOrder(order.id)}
                            className="p-1.5 rounded-[8px] border border-slate-200 hover:bg-slate-100 text-slate-600"
                            title="Buka / Tutup Rincian Barang"
                          >
                            <ChevronDown
                              className={`w-4 h-4 transition-transform duration-200 ${
                                isExpanded ? 'rotate-180 text-[#0070fc]' : ''
                              }`}
                            />
                          </button>
                        </div>
                      </div>
                    </div>

                    {/* Expandable Manifest Checklist */}
                    {isExpanded && (
                      <div className="border-t border-slate-100 bg-slate-50/70 p-4 space-y-3 animate-in fade-in duration-150">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <ListChecks className="w-4 h-4 text-[#0070fc]" />
                            <h5 className="font-bold text-slate-800 text-xs">
                              Manifest Fisik Barang ({manifestItems.length} SKU)
                            </h5>
                          </div>
                          {allChecked ? (
                            <span className="text-[10px] font-black text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-full flex items-center gap-1">
                              <CheckCircle2 className="w-3 h-3" /> Semua Barang Siap
                            </span>
                          ) : (
                            <span className="text-[10px] font-semibold text-slate-500">
                              Tercentang {checkedSet.size} dari {manifestItems.length}
                            </span>
                          )}
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2">
                          {manifestItems.map((item, idx) => {
                            const isChecked = checkedSet.has(idx);
                            return (
                              <div
                                key={idx}
                                onClick={() => toggleItemCheck(order.id, idx)}
                                className={`p-2.5 rounded-[8px] border text-xs cursor-pointer select-none transition-all flex items-start gap-2 ${
                                  isChecked
                                    ? 'bg-emerald-50/80 border-emerald-300 text-emerald-950'
                                    : 'bg-white border-slate-200 hover:border-slate-300 text-slate-800'
                                }`}
                              >
                                {isChecked ? (
                                  <CheckSquare className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                                ) : (
                                  <Square className="w-4 h-4 text-slate-400 shrink-0 mt-0.5" />
                                )}
                                <div className="flex-1 min-w-0">
                                  <p className={`font-bold leading-tight truncate ${isChecked ? 'line-through text-slate-500' : ''}`}>
                                    {item.name}
                                  </p>
                                  <p className="text-[10px] text-slate-400 mt-0.5">
                                    Qty: <strong className="text-slate-700 font-mono">{item.quantity} {item.unit}</strong>
                                    {item.barcode && ` • ${item.barcode}`}
                                  </p>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* ========================================================
          MODE 2: TIMELINE VIEW (Pelacakan Kronologis & Alur)
          ======================================================== */}
      {viewMode === 'timeline' && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
          {/* Kolom Kiri: Pemilih Order Timeline */}
          <div className="lg:col-span-5 bg-white p-4 rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100">
              <h4 className="font-bold text-slate-900 text-xs flex items-center gap-1.5">
                <Truck className="w-4 h-4 text-[#0070fc]" />
                <span>Pilih Pesanan untuk Dilacak</span>
              </h4>
              <span className="text-[11px] font-bold text-slate-400">{filteredOrders.length} Order</span>
            </div>

            <div className="space-y-2 max-h-[620px] overflow-y-auto pr-1">
              {filteredOrders.length === 0 ? (
                <p className="text-xs text-slate-400 p-4 text-center">Tidak ada pesanan.</p>
              ) : (
                filteredOrders.map((ord) => {
                  const isSelected = ord.id === currentTimelineOrder?.id;
                  return (
                    <div
                      key={ord.id}
                      onClick={() => setSelectedTimelineOrderId(ord.id)}
                      className={`p-3.5 rounded-[10px] border cursor-pointer transition-all ${
                        isSelected
                          ? 'bg-blue-50/60 border-[#0070fc] shadow-xs'
                          : 'bg-white border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-mono text-xs font-black text-[#0070fc]">{ord.order_code}</span>
                        <span
                          className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full ${
                            ord.status === 'delivered'
                              ? 'bg-emerald-100 text-emerald-800'
                              : ord.status === 'in_transit'
                              ? 'bg-amber-100 text-amber-800 animate-pulse'
                              : ord.status === 'packing'
                              ? 'bg-blue-100 text-blue-800'
                              : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {ord.status.replace('_', ' ')}
                        </span>
                      </div>
                      <p className="font-bold text-xs text-slate-900 mt-1 truncate">{ord.recipient_name}</p>
                      <p className="text-[11px] text-slate-500 truncate">{ord.shipping_address}, {ord.shipping_city}</p>
                      <div className="mt-2 flex items-center justify-between text-[10px] text-slate-400 font-medium">
                        <span>{ord.kit_name}</span>
                        <span>{ord.created_at ? new Date(ord.created_at).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }) : ''}</span>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Kolom Kanan: Visual Alur Timeline */}
          <div className="lg:col-span-7 bg-white p-6 rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs space-y-6">
            {currentTimelineOrder ? (
              <>
                {/* Header Info Order */}
                <div className="border-b border-slate-100 pb-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm font-black text-[#0070fc] bg-blue-50 px-2.5 py-0.5 rounded border border-blue-200">
                        {currentTimelineOrder.order_code}
                      </span>
                      <span className="text-sm font-bold text-slate-900">{currentTimelineOrder.kit_name}</span>
                    </div>
                    <p className="text-xs text-slate-500 mt-1">
                      Penerima: <strong className="text-slate-800">{currentTimelineOrder.recipient_name}</strong> ({currentTimelineOrder.recipient_phone})
                    </p>
                    <p className="text-xs text-slate-500">
                      Tujuan: {currentTimelineOrder.shipping_address}, {currentTimelineOrder.shipping_city}
                    </p>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => openDispatchModal(currentTimelineOrder)}
                      className="px-3 py-1.5 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs shadow-xs transition-all flex items-center gap-1.5"
                    >
                      <Truck className="w-3.5 h-3.5" />
                      <span>Update Kurir / Status</span>
                    </button>
                  </div>
                </div>

                {/* Progress Bar Persentase */}
                <div>
                  <div className="flex items-center justify-between text-xs font-bold text-slate-600 mb-1.5">
                    <span>Progress Pengiriman</span>
                    <span className="font-mono text-[#0070fc]">
                      {currentTimelineOrder.status === 'pending_dispatch'
                        ? '25%'
                        : currentTimelineOrder.status === 'packing'
                        ? '50%'
                        : currentTimelineOrder.status === 'in_transit'
                        ? '75%'
                        : '100%'}
                    </span>
                  </div>
                  <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      className={`h-full transition-all duration-500 rounded-full ${
                        currentTimelineOrder.status === 'delivered'
                          ? 'bg-emerald-500'
                          : 'bg-[#0070fc]'
                      }`}
                      style={{
                        width:
                          currentTimelineOrder.status === 'pending_dispatch'
                            ? '25%'
                            : currentTimelineOrder.status === 'packing'
                            ? '50%'
                            : currentTimelineOrder.status === 'in_transit'
                            ? '75%'
                            : '100%',
                      }}
                    />
                  </div>
                </div>

                {/* Vertical Interactive Timeline */}
                <div className="relative pl-6 space-y-8 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
                  {/* Step 1: Diterbitkan */}
                  <div className="relative">
                    <div className="absolute -left-6 top-0 w-5 h-5 rounded-full bg-emerald-500 text-white flex items-center justify-center text-[10px] shadow-sm">
                      <Check className="w-3 h-3 stroke-[3]" />
                    </div>
                    <div>
                      <h5 className="font-bold text-slate-900 text-xs">Pesanan Diterbitkan & Masuk Sistem</h5>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        {currentTimelineOrder.created_at
                          ? new Date(currentTimelineOrder.created_at).toLocaleString('id-ID', {
                              dateStyle: 'medium',
                              timeStyle: 'short',
                            })
                          : 'Waktu belum tercatat'}
                      </p>
                      <p className="text-[11px] text-slate-600 mt-1 bg-slate-50 p-2 rounded border border-slate-100">
                        Tiket restok toko dibuat otomatis dari sistem onboarding / pendaftaran paket.
                      </p>
                    </div>
                  </div>

                  {/* Step 2: Packing Gudang */}
                  <div className="relative">
                    <div
                      className={`absolute -left-6 top-0 w-5 h-5 rounded-full flex items-center justify-center text-[10px] shadow-sm ${
                        currentTimelineOrder.status === 'pending_dispatch'
                          ? 'bg-slate-300 text-slate-600'
                          : 'bg-emerald-500 text-white'
                      }`}
                    >
                      {currentTimelineOrder.status === 'pending_dispatch' ? (
                        <span className="w-2 h-2 rounded-full bg-white" />
                      ) : (
                        <Check className="w-3 h-3 stroke-[3]" />
                      )}
                    </div>
                    <div>
                      <h5 className="font-bold text-slate-900 text-xs">Pengepakan Barang di Gudang Syupeo</h5>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        {currentTimelineOrder.status === 'pending_dispatch'
                          ? 'Menunggu tim gudang memindai dan mengemas barang...'
                          : 'Barang telah dipacking rapi dan dipasangi label barcode manifest.'}
                      </p>
                    </div>
                  </div>

                  {/* Step 3: In Transit / Kurir */}
                  <div className="relative">
                    <div
                      className={`absolute -left-6 top-0 w-5 h-5 rounded-full flex items-center justify-center text-[10px] shadow-sm ${
                        currentTimelineOrder.status === 'in_transit'
                          ? 'bg-[#0070fc] text-white ring-4 ring-blue-100 animate-pulse'
                          : currentTimelineOrder.status === 'delivered'
                          ? 'bg-emerald-500 text-white'
                          : 'bg-slate-300 text-slate-600'
                      }`}
                    >
                      {currentTimelineOrder.status === 'delivered' ? (
                        <Check className="w-3 h-3 stroke-[3]" />
                      ) : (
                        <Truck className="w-3 h-3" />
                      )}
                    </div>
                    <div>
                      <h5 className="font-bold text-slate-900 text-xs">Penyerahan ke Armada & Dalam Perjalanan</h5>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        {currentTimelineOrder.dispatched_at
                          ? new Date(currentTimelineOrder.dispatched_at).toLocaleString('id-ID', {
                              dateStyle: 'medium',
                              timeStyle: 'short',
                            })
                          : currentTimelineOrder.status === 'in_transit'
                          ? 'Sedang berjalan menuju alamat toko'
                          : 'Belum diberangkatkan'}
                      </p>

                      {currentTimelineOrder.tracking_number && (
                        <div className="mt-1.5 p-2.5 rounded-[8px] bg-blue-50 border border-blue-200 text-xs text-blue-900 space-y-1">
                          <p className="font-bold flex items-center gap-1.5">
                            <Navigation className="w-3.5 h-3.5 text-[#0070fc]" />
                            <span>Kurir / Ekspedisi: {currentTimelineOrder.driver_name || 'Armada Syupeo Hub'}</span>
                          </p>
                          <p className="font-mono text-[11px]">No. Resi / AWB: <strong>{currentTimelineOrder.tracking_number}</strong></p>
                          {currentTimelineOrder.driver_phone && (
                            <p className="text-[11px]">Kontak Supir: {currentTimelineOrder.driver_phone}</p>
                          )}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Step 4: Selesai / Delivered */}
                  <div className="relative">
                    <div
                      className={`absolute -left-6 top-0 w-5 h-5 rounded-full flex items-center justify-center text-[10px] shadow-sm ${
                        currentTimelineOrder.status === 'delivered'
                          ? 'bg-emerald-500 text-white ring-4 ring-emerald-100'
                          : 'bg-slate-300 text-slate-600'
                      }`}
                    >
                      {currentTimelineOrder.status === 'delivered' ? (
                        <ShieldCheck className="w-3 h-3" />
                      ) : (
                        <span className="w-2 h-2 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <h5 className="font-bold text-slate-900 text-xs">Paket Telah Tiba & Diterima Toko</h5>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        {currentTimelineOrder.delivered_at
                          ? new Date(currentTimelineOrder.delivered_at).toLocaleString('id-ID', {
                              dateStyle: 'medium',
                              timeStyle: 'short',
                            })
                          : currentTimelineOrder.status === 'delivered'
                          ? 'Selesai serah terima'
                          : 'Menunggu konfirmasi penerimaan toko'}
                      </p>
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <p className="text-xs text-slate-400 p-8 text-center">Pilih pesanan dari kolom kiri untuk melihat timeline.</p>
            )}
          </div>
        </div>
      )}

      {/* ========================================================
          MODE 3: INTERACTIVE CALENDAR VIEW
          ======================================================== */}
      {viewMode === 'calendar' && (
        <div className="space-y-5">
          {/* Calendar Header Bar */}
          <div className="bg-white p-4 rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs flex items-center justify-between">
            <div className="flex items-center gap-3">
              <h3 className="text-base font-black text-slate-900 capitalize flex items-center gap-2">
                <CalendarDays className="w-5 h-5 text-[#0070fc]" />
                <span>{calendarMonthYear}</span>
              </h3>
              <button
                onClick={() => setCalendarDate(new Date())}
                className="px-2.5 py-1 text-[11px] font-bold text-[#0070fc] bg-blue-50 border border-blue-200 rounded-[6px] hover:bg-blue-100 transition-colors"
              >
                Hari Ini
              </button>
            </div>

            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setCalendarDate(new Date(calendarDate.getFullYear(), calendarDate.getMonth() - 1, 1))}
                className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-700 transition-colors"
                title="Bulan Sebelumnya"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                onClick={() => setCalendarDate(new Date(calendarDate.getFullYear(), calendarDate.getMonth() + 1, 1))}
                className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-700 transition-colors"
                title="Bulan Berikutnya"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Monthly Grid */}
          <div className="bg-white rounded-[12px] border border-[rgba(0,0,0,0.08)] shadow-xs overflow-hidden">
            {/* Day Header (Sen s/d Min) */}
            <div
              style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))' }}
              className="calendar-grid-7 grid grid-cols-7 border-b border-slate-200 bg-slate-50 text-center text-xs font-bold text-slate-500 py-2.5"
            >
              <span>Sen</span>
              <span>Sel</span>
              <span>Rab</span>
              <span>Kam</span>
              <span>Jum</span>
              <span className="text-blue-600">Sab</span>
              <span className="text-rose-600">Min</span>
            </div>

            {/* Days Cells */}
            <div
              style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))' }}
              className="calendar-grid-7 grid grid-cols-7 auto-rows-fr divide-x divide-y divide-slate-100"
            >
              {calendarDays.map((day, idx) => {
                const isToday = day.dateString === new Date().toISOString().split('T')[0];
                const isSelected = day.dateString === selectedCalendarDate;
                const count = day.orders.length;

                return (
                  <div
                    key={idx}
                    onClick={() => {
                      setSelectedCalendarDate(day.dateString);
                      setIsDatePopupOpen(true);
                    }}
                    className={`min-h-[96px] sm:min-h-[110px] p-2 transition-all cursor-pointer flex flex-col justify-between hover:bg-blue-50/40 relative group ${
                      !day.isCurrentMonth
                        ? 'bg-slate-50/50 text-slate-400'
                        : isSelected
                        ? 'bg-blue-50/80 ring-2 ring-inset ring-[#0070fc]'
                        : 'bg-white hover:bg-slate-50 text-slate-800'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span
                        className={`text-xs font-bold w-6 h-6 rounded-full flex items-center justify-center ${
                          isToday
                            ? 'bg-[#0070fc] text-white shadow-xs'
                            : isSelected
                            ? 'bg-blue-200 text-[#0070fc]'
                            : ''
                        }`}
                      >
                        {day.dayNumber}
                      </span>

                      {count > 0 && (
                        <span className="px-1.5 py-0.2 rounded-full bg-[#0070fc] text-white text-[9px] font-black">
                          {count}
                        </span>
                      )}
                    </div>

                    {/* Order Previews / Dots */}
                    <div className="space-y-1 mt-1">
                      {day.orders.slice(0, 2).map((o) => (
                        <div
                          key={o.id}
                          className={`px-1.5 py-0.5 rounded text-[9px] font-bold truncate ${
                            o.status === 'delivered'
                              ? 'bg-emerald-100 text-emerald-800'
                              : o.status === 'in_transit'
                              ? 'bg-amber-100 text-amber-800'
                              : 'bg-blue-100 text-blue-800'
                          }`}
                        >
                          {o.recipient_name}
                        </div>
                      ))}
                      {count > 2 && (
                        <p className="text-[8px] font-bold text-slate-400 text-center">+{count - 2} lagi</p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* ========================================================
              POPUP MODAL: DETAIL PESANAN DI TANGGAL TERPILIH
              ======================================================== */}
          {isDatePopupOpen && selectedCalendarDate && (
            <div
              className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150"
              onClick={() => setIsDatePopupOpen(false)}
            >
              <div
                className="bg-white w-full max-w-xl rounded-[16px] shadow-2xl border border-slate-200 overflow-hidden animate-in zoom-in-95 duration-150 max-h-[85vh] flex flex-col"
                onClick={(e) => e.stopPropagation()}
              >
                {/* Header */}
                <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/80 shrink-0">
                  <div className="flex items-center gap-2.5">
                    <div className="w-9 h-9 rounded-xl bg-blue-50 border border-blue-200 flex items-center justify-center text-[#0070fc]">
                      <CalendarDays className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-900 text-sm">
                        {new Date(`${selectedCalendarDate}T00:00:00`).toLocaleDateString('id-ID', {
                          weekday: 'long',
                          day: 'numeric',
                          month: 'long',
                          year: 'numeric',
                        })}
                      </h3>
                      <p className="text-[11px] text-slate-500">
                        {calendarSelectedOrders.length} order pengiriman tercatat
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => setIsDatePopupOpen(false)}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                  >
                    <X className="w-5 h-5" />
                  </button>
                </div>

                {/* Body */}
                <div className="p-5 overflow-y-auto space-y-3 flex-1 text-xs">
                  {calendarSelectedOrders.length === 0 ? (
                    <div className="py-12 text-center">
                      <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 mx-auto flex items-center justify-center mb-3">
                        <CalendarDays className="w-6 h-6" />
                      </div>
                      <p className="font-bold text-slate-700 text-sm">Tidak Ada Jadwal Pengiriman</p>
                      <p className="text-slate-400 text-xs mt-1">
                        Belum ada order pasokan gudang yang tercatat pada tanggal ini.
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {calendarSelectedOrders.map((ord) => (
                        <div
                          key={ord.id}
                          className="p-4 rounded-[12px] border border-slate-200 hover:border-blue-200 bg-white hover:bg-slate-50/50 transition-all space-y-3"
                        >
                          <div className="flex items-start justify-between gap-3">
                            <div>
                              <div className="flex items-center gap-2">
                                <span className="font-mono font-bold text-[#0070fc] text-sm">
                                  {ord.order_code}
                                </span>
                                <span
                                  className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full ${
                                    ord.status === 'delivered'
                                      ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                                      : ord.status === 'in_transit'
                                      ? 'bg-amber-100 text-amber-800 border border-amber-200'
                                      : ord.status === 'packing'
                                      ? 'bg-blue-100 text-blue-800 border border-blue-200'
                                      : 'bg-slate-100 text-slate-700'
                                  }`}
                                >
                                  {ord.status.replace('_', ' ')}
                                </span>
                              </div>
                              <h4 className="font-bold text-slate-900 mt-1">{ord.recipient_name}</h4>
                              <p className="text-slate-500 text-[11px]">{ord.recipient_phone}</p>
                            </div>

                            <div className="flex items-center gap-1.5 shrink-0">
                              <button
                                onClick={() => {
                                  setSelectedOrder(ord);
                                  setIsPrintModalOpen(true);
                                }}
                                className="px-2.5 py-1.5 rounded-[8px] border border-slate-200 hover:bg-slate-100 text-slate-700 font-bold text-xs flex items-center gap-1 transition-colors"
                                title="Cetak Surat Jalan"
                              >
                                <Printer className="w-3.5 h-3.5 text-slate-500" />
                                <span>Surat Jalan</span>
                              </button>
                              <button
                                onClick={() => {
                                  setSelectedOrder(ord);
                                  setIsDispatchModalOpen(true);
                                }}
                                className="px-3 py-1.5 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs flex items-center gap-1 transition-colors shadow-2xs"
                              >
                                <Truck className="w-3.5 h-3.5" />
                                <span>Kelola</span>
                              </button>
                            </div>
                          </div>

                          <div className="bg-slate-50 p-2.5 rounded-[8px] text-[11px] space-y-1 text-slate-600">
                            <p className="truncate">
                              <strong className="text-slate-700">Tujuan:</strong> {ord.shipping_address}, {ord.shipping_city}
                            </p>
                            <div className="flex items-center justify-between text-slate-500">
                              <span>Paket: <strong className="text-slate-700">{ord.kit_name}</strong></span>
                              {ord.driver_name && (
                                <span>Kurir: <strong className="text-slate-700">{ord.driver_name}</strong> {ord.tracking_number ? `(${ord.tracking_number})` : ''}</span>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Footer */}
                <div className="p-3.5 bg-slate-50 border-t border-slate-100 flex items-center justify-end shrink-0">
                  <button
                    onClick={() => setIsDatePopupOpen(false)}
                    className="px-4 py-2 rounded-[8px] bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold text-xs transition-colors"
                  >
                    Tutup
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ========================================================
          MODAL 1: DISPATCH ACTION & KURIR
          ======================================================== */}
      {isDispatchModalOpen && selectedOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white w-full max-w-md rounded-[16px] shadow-xl border border-slate-200 overflow-hidden animate-in zoom-in-95 duration-150">
            <div className="p-4 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Truck className="w-5 h-5 text-[#0070fc]" />
                <h3 className="font-bold text-slate-900 text-sm">Update Status & Dispatch Kurir</h3>
              </div>
              <button onClick={() => setIsDispatchModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-5 space-y-4 text-xs">
              <div>
                <label className="text-[11px] font-bold text-slate-500 uppercase">Status Pengiriman:</label>
                <select
                  value={targetStatus}
                  onChange={(e) => setTargetStatus(e.target.value)}
                  className="w-full mt-1 px-3 py-2 border border-slate-300 rounded-[8px] bg-white font-bold text-slate-800 focus:outline-none focus:border-[#0070fc]"
                >
                  <option value="pending_dispatch">Menunggu Dispatch (Pending)</option>
                  <option value="packing">Sedang Dikemas (Packing)</option>
                  <option value="in_transit">Sedang Dalam Perjalanan Kurir (In Transit)</option>
                  <option value="delivered">Selesai Diterima Toko (Delivered)</option>
                </select>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-500 uppercase">Gudang / Node Asal:</label>
                <select
                  value={dispatchWarehouseId}
                  onChange={(e) => setDispatchWarehouseId(e.target.value)}
                  className="w-full mt-1 px-3 py-2 border border-slate-300 rounded-[8px] bg-white text-slate-800 focus:outline-none focus:border-[#0070fc]"
                >
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name} ({w.city})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-500 uppercase">Nama Kurir / Driver / Ekspedisi:</label>
                <input
                  type="text"
                  value={driverName}
                  onChange={(e) => setDriverName(e.target.value)}
                  placeholder="Contoh: Pak Budi (Armada Syupeo Direct) / J&T"
                  className="w-full mt-1 px-3 py-2 border border-slate-300 rounded-[8px] focus:outline-none focus:border-[#0070fc]"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-500 uppercase">No. Resi / Surat Jalan:</label>
                <input
                  type="text"
                  value={trackingNumber}
                  onChange={(e) => setTrackingNumber(e.target.value)}
                  placeholder="Nomor resi atau kode tracking"
                  className="w-full mt-1 px-3 py-2 border border-slate-300 rounded-[8px] font-mono focus:outline-none focus:border-[#0070fc]"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-500 uppercase">No. HP Driver (Opsional):</label>
                <input
                  type="text"
                  value={driverPhone}
                  onChange={(e) => setDriverPhone(e.target.value)}
                  placeholder="081234567890"
                  className="w-full mt-1 px-3 py-2 border border-slate-300 rounded-[8px] focus:outline-none focus:border-[#0070fc]"
                />
              </div>

              <div className="pt-2 flex items-center gap-2">
                <input
                  type="checkbox"
                  id="wa_notif"
                  checked={notifyWaOnDispatch}
                  onChange={(e) => setNotifyWaOnDispatch(e.target.checked)}
                  className="w-4 h-4 text-[#0070fc] rounded border-slate-300 focus:ring-0"
                />
                <label htmlFor="wa_notif" className="text-xs text-slate-700 font-semibold cursor-pointer">
                  Kirim notifikasi pesan status ke WhatsApp Penerima
                </label>
              </div>
            </div>

            <div className="p-4 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setIsDispatchModalOpen(false)}
                className="px-4 py-2 rounded-[8px] border border-slate-200 text-slate-600 hover:bg-slate-100 font-bold text-xs"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={isSubmitting}
                onClick={() =>
                  handleUpdateOrderStatus(selectedOrder.id, targetStatus, {
                    driver_name: driverName,
                    driver_phone: driverPhone,
                    tracking_number: trackingNumber,
                    assigned_warehouse_id: dispatchWarehouseId,
                  })
                }
                className="px-5 py-2 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs shadow-xs flex items-center gap-1.5 disabled:opacity-50"
              >
                {isSubmitting && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                <span>Simpan & Update</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 2: CETAK SURAT JALAN & MANIFEST RESMI
          ======================================================== */}
      {isPrintModalOpen && selectedOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white w-full max-w-2xl rounded-[16px] shadow-xl border border-slate-200 overflow-hidden animate-in zoom-in-95 duration-150 max-h-[90vh] flex flex-col">
            <div className="p-4 border-b border-slate-100 flex items-center justify-between shrink-0">
              <div className="flex items-center gap-2">
                <Printer className="w-5 h-5 text-[#0070fc]" />
                <h3 className="font-bold text-slate-900 text-sm">Surat Jalan & Manifest Pengiriman Resmi</h3>
              </div>
              <button onClick={() => setIsPrintModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Print Area Preview */}
            <div className="p-6 overflow-y-auto space-y-5 text-xs text-slate-800" id="print-area">
              <div className="flex items-start justify-between border-b-2 border-slate-900 pb-3">
                <div>
                  <h2 className="text-xl font-black text-[#0070fc]">SYUPEO SUPPLY CHAIN</h2>
                  <p className="text-[11px] text-slate-500 font-semibold">
                    Surat Jalan & Manifest Penyerahan Paket Usaha
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-mono font-bold text-sm text-slate-900">{selectedOrder.order_code}</p>
                  <p className="text-[11px] text-slate-500">
                    Tanggal:{' '}
                    {new Date(selectedOrder.created_at || Date.now()).toLocaleDateString('id-ID', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4 p-3 bg-slate-50 rounded-[8px] border border-slate-200 text-[11px]">
                <div>
                  <p className="font-bold text-slate-400 uppercase">Pengirim (Node Gudang):</p>
                  <p className="font-bold text-slate-900 mt-0.5">
                    {selectedOrder.warehouse?.name || 'Gudang Pusat Syupeo'}
                  </p>
                  <p className="text-slate-600 mt-0.5">{selectedOrder.warehouse?.address || 'Jl. Raya Distribusi Cleo'}</p>
                </div>
                <div>
                  <p className="font-bold text-slate-400 uppercase">Tujuan Pengiriman (Mitra Toko):</p>
                  <p className="font-bold text-slate-900 mt-0.5">{selectedOrder.recipient_name}</p>
                  <p className="text-slate-600 mt-0.5">{selectedOrder.shipping_address}, {selectedOrder.shipping_city}</p>
                  <p className="font-mono text-slate-600 mt-0.5">{selectedOrder.recipient_phone}</p>
                </div>
              </div>

              {/* Items Table */}
              <div>
                <table className="w-full border border-slate-200 text-left text-xs">
                  <thead className="bg-slate-100 font-bold text-slate-700 border-b border-slate-200">
                    <tr>
                      <th className="p-2 border-r border-slate-200 w-10 text-center">No</th>
                      <th className="p-2 border-r border-slate-200">Nama Barang & Kemasan</th>
                      <th className="p-2 border-r border-slate-200 w-24 text-center">Qty</th>
                      <th className="p-2 border-r border-slate-200">Kategori</th>
                      <th className="p-2 w-28 text-center">Checklist</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {getOrderManifestItems(selectedOrder).map((it, idx) => (
                      <tr key={idx} className="hover:bg-slate-50">
                        <td className="p-2 border-r border-slate-200 text-center font-mono">{idx + 1}</td>
                        <td className="p-2 border-r border-slate-200 font-semibold">{it.name}</td>
                        <td className="p-2 border-r border-slate-200 text-center font-mono font-bold">
                          {it.quantity} {it.unit}
                        </td>
                        <td className="p-2 border-r border-slate-200 text-slate-500 text-[11px]">{it.category || '-'}</td>
                        <td className="p-2 text-center text-slate-300 font-mono">[ &nbsp; ]</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Signature Blocks */}
              <div className="pt-6 grid grid-cols-3 gap-4 text-center text-[11px]">
                <div>
                  <p className="font-bold text-slate-600">Petugas Gudang / Checker</p>
                  <div className="h-16 border-b border-dashed border-slate-300 mt-2" />
                  <p className="text-slate-400 mt-1">( Tanda Tangan & Nama )</p>
                </div>
                <div>
                  <p className="font-bold text-slate-600">Supir / Armada Ekspedisi</p>
                  <div className="h-16 border-b border-dashed border-slate-300 mt-2" />
                  <p className="text-slate-400 mt-1">( {selectedOrder.driver_name || 'Driver'} )</p>
                </div>
                <div>
                  <p className="font-bold text-slate-600">Penerima (Mitra Toko)</p>
                  <div className="h-16 border-b border-dashed border-slate-300 mt-2" />
                  <p className="text-slate-400 mt-1">( {selectedOrder.recipient_name} )</p>
                </div>
              </div>
            </div>

            <div className="p-4 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-2 shrink-0">
              <button
                type="button"
                onClick={() => setIsPrintModalOpen(false)}
                className="px-4 py-2 rounded-[8px] border border-slate-200 text-slate-600 hover:bg-slate-100 font-bold text-xs"
              >
                Tutup
              </button>
              <button
                type="button"
                onClick={() => window.print()}
                className="px-5 py-2 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs shadow-xs flex items-center gap-1.5"
              >
                <Printer className="w-3.5 h-3.5" />
                <span>Cetak / Cetak PDF</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

