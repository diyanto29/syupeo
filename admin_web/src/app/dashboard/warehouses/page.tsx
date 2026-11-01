'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Warehouse, PackageFulfillmentOrder } from '@/types/database';
import WilayahSelector, { WilayahSelection } from '@/components/WilayahSelector';
import GooglePlacesAutocomplete, { PlaceResult } from '@/components/GooglePlacesAutocomplete';
import {
  Building2,
  Truck,
  Package,
  MapPin,
  Phone,
  CheckCircle2,
  Clock,
  AlertCircle,
  PlusCircle,
  Search,
  Filter,
  Printer,
  ExternalLink,
  ChevronRight,
  ShieldCheck,
  Send,
  X,
  Loader2,
  Check,
  Sparkles,
  ArrowRight,
  UserCheck,
  Navigation,
  Boxes,
  ChevronDown,
  ListChecks,
  FileText,
  CheckSquare,
  Square,
} from 'lucide-react';

interface OrderManifestItem {
  name: string;
  quantity: number | string;
  unit: string;
  category?: string;
  barcode?: string;
}

// Paket default fallback jika database belum terisi
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

export default function WarehousesPage() {
  const [activeTab, setActiveTab] = useState<'dispatch' | 'warehouses'>('dispatch');
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [orders, setOrders] = useState<PackageFulfillmentOrder[]>([]);
  const [starterKitItemsMap, setStarterKitItemsMap] = useState<Record<string, any[]>>({});
  const [expandedOrderIds, setExpandedOrderIds] = useState<Set<string>>(new Set());
  const [checkedItemsMap, setCheckedItemsMap] = useState<Record<string, Set<number>>>({});
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Modal States
  const [isWarehouseModalOpen, setIsWarehouseModalOpen] = useState(false);
  const [isDispatchModalOpen, setIsDispatchModalOpen] = useState(false);
  const [isPrintLabelOpen, setIsPrintLabelOpen] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState<PackageFulfillmentOrder | null>(null);
  const [notifyWaOnDispatch, setNotifyWaOnDispatch] = useState(true);

  // Form Warehouse State
  const [formName, setFormName] = useState('');
  const [formCode, setFormCode] = useState('');
  const [formType, setFormType] = useState<'syupeo_hub' | 'principal_agent' | 'third_party_3pl'>('principal_agent');
  const [formBrand, setFormBrand] = useState('Cleo');
  const [formProvince, setFormProvince] = useState('');
  const [formCity, setFormCity] = useState('');
  const [formDistrict, setFormDistrict] = useState('');
  const [formVillage, setFormVillage] = useState('');
  const [formAddress, setFormAddress] = useState('');
  const [formLat, setFormLat] = useState<number | null>(null);
  const [formLng, setFormLng] = useState<number | null>(null);
  const [formRadius, setFormRadius] = useState(25);
  const [formPicName, setFormPicName] = useState('');
  const [formPicPhone, setFormPicPhone] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  // Form Dispatch Action
  const [driverName, setDriverName] = useState('');
  const [driverPhone, setDriverPhone] = useState('');
  const [trackingNumber, setTrackingNumber] = useState('');
  const [dispatchWarehouseId, setDispatchWarehouseId] = useState('');

  // Alerts
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    try {
      // 1. Fetch Warehouses (Data baru selalu muncul di paling atas)
      const { data: whData } = await supabase
        .from('warehouses')
        .select('*')
        .order('created_at', { ascending: false });

      if (whData) setWarehouses(whData as Warehouse[]);

      // 2. Fetch Starter Kit Items jika ada di database
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
      } catch (err) {
        console.warn('Gagal memuat retail_starter_kit_items, menggunakan fallback manifest.', err);
      }

      // 3. Fetch Fulfillment Orders
      const { data: ordData } = await supabase
        .from('package_fulfillment_orders')
        .select('*, warehouse:warehouses(*)')
        .order('created_at', { ascending: false });

      if (ordData) setOrders(ordData as PackageFulfillmentOrder[]);
    } catch (err: any) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Helper untuk mengekstrak rincian barang pesanan (kulakan satuan atau starter kit)
  const getOrderManifestItems = (order: PackageFulfillmentOrder): OrderManifestItem[] => {
    // 1. Cek apakah ini kulakan satuan (JSON di notes)
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

    // 2. Cek apakah ada di starterKitItemsMap (dari Supabase)
    if (order.starter_kit_id && starterKitItemsMap[order.starter_kit_id]?.length > 0) {
      return starterKitItemsMap[order.starter_kit_id].map((it: any) => ({
        name: it.product_name,
        quantity: it.quantity || 1,
        unit: it.unit || 'Pcs',
        category: it.category || 'Starter Kit',
        barcode: it.barcode || '-',
      }));
    }

    // 3. Cek apakah ada di DEFAULT_PACKAGES_MANIFEST berdasarkan kesamaan nama paket
    const matchedKey = Object.keys(DEFAULT_PACKAGES_MANIFEST).find(
      (k) => order.kit_name?.toLowerCase().includes(k.toLowerCase()) || k.toLowerCase().includes(order.kit_name?.toLowerCase() || '')
    );
    if (matchedKey && DEFAULT_PACKAGES_MANIFEST[matchedKey]) {
      return DEFAULT_PACKAGES_MANIFEST[matchedKey];
    }

    // 4. Fallback umum
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

  const toggleExpandOrder = (orderId: string) => {
    setExpandedOrderIds((prev) => {
      const next = new Set(prev);
      if (next.has(orderId)) {
        next.delete(orderId);
      } else {
        next.add(orderId);
      }
      return next;
    });
  };

  const toggleItemCheck = (orderId: string, itemIndex: number) => {
    setCheckedItemsMap((prev) => {
      const orderSet = new Set(prev[orderId] || []);
      if (orderSet.has(itemIndex)) {
        orderSet.delete(itemIndex);
      } else {
        orderSet.add(itemIndex);
      }
      return {
        ...prev,
        [orderId]: orderSet,
      };
    });
  };

  // Save new Warehouse
  const handleSaveWarehouse = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setErrorMsg(null);
    try {
      const codeGenerated = formCode.trim() || `WH-${Date.now().toString().slice(-4)}`;
      const payload = {
        code: codeGenerated,
        name: formName.trim(),
        warehouse_type: formType,
        brand_partner: formType === 'principal_agent' ? formBrand.trim() : 'Syupeo Internal',
        province: formProvince.trim() || null,
        city: formCity.trim(),
        district: formDistrict.trim() || null,
        village: formVillage.trim() || null,
        address: formAddress.trim(),
        latitude: formLat,
        longitude: formLng,
        coverage_radius_km: Number(formRadius) || 25,
        pic_name: formPicName.trim(),
        pic_phone: formPicPhone.trim(),
        is_active: true,
      };

      const { error } = await supabase.from('warehouses').insert(payload);
      if (error) throw error;

      setSuccessMsg(`Gudang/Agen "${formName}" berhasil ditambahkan!`);
      setIsWarehouseModalOpen(false);
      resetWarehouseForm();
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const resetWarehouseForm = () => {
    setFormName('');
    setFormCode('');
    setFormType('principal_agent');
    setFormBrand('Cleo');
    setFormProvince('');
    setFormCity('');
    setFormDistrict('');
    setFormVillage('');
    setFormAddress('');
    setFormLat(null);
    setFormLng(null);
    setFormRadius(25);
    setFormPicName('');
    setFormPicPhone('');
  };

  // Kirim template notifikasi update status ke WhatsApp pembeli / toko mitra
  const notifyBuyerViaWhatsApp = (
    order: PackageFulfillmentOrder,
    status: 'packing' | 'in_transit' | 'delivered' | string,
    driver?: string,
    tracking?: string
  ) => {
    const rawPhone = order.recipient_phone?.replace(/\D/g, '') || '';
    if (!rawPhone) return;
    const phone = rawPhone.startsWith('62')
      ? rawPhone
      : rawPhone.startsWith('0')
      ? `62${rawPhone.slice(1)}`
      : rawPhone;

    let msg = '';
    if (status === 'packing') {
      msg = `Halo Kak ${order.recipient_name}! 👋\n\nPesanan restok Anda (${order.order_code} - ${order.kit_name}) saat ini SEDANG DIKEMAS oleh tim Gudang Syupeo.\n\nBarang sedang disiapkan dengan baik dan segera diserahkan ke kurir pengiriman. Terima kasih telah mempercayakan pasokan toko Anda pada Syupeo! 🙏`;
    } else if (status === 'in_transit') {
      const kurir = driver || order.driver_name || 'Kurir Ekspedisi';
      const resi = tracking || order.tracking_number || '-';
      msg = `Halo Kak ${order.recipient_name}! 🚚\n\nPesanan restok Anda (${order.order_code} - ${order.kit_name}) saat ini SEDANG DALAM PERJALANAN KURIR:\n• Kurir / Ekspedisi: ${kurir}\n• No. Resi / AWB: ${resi}\n• Alamat Tujuan: ${order.shipping_address}, ${order.shipping_city}\n\nSilakan pantau status pengiriman atau konfirmasi penerimaan melalui menu 'Status Pengiriman Paket' di aplikasi Kasir Syupeo Anda.`;
    } else if (status === 'delivered') {
      msg = `Halo Kak ${order.recipient_name}! ✅\n\nPesanan restok Anda (${order.order_code} - ${order.kit_name}) telah tercatat SELESAI / SAMPAI di toko.\n\nKatalog dan stok kasir POS Anda telah otomatis bertambah. Selamat berjualan dan semoga laris manis! 🛒🎉`;
    } else {
      msg = `Halo Kak ${order.recipient_name}, status pesanan restok Anda (${order.order_code}) saat ini adalah: ${status}. Silakan periksa di aplikasi Kasir Syupeo Anda.`;
    }

    if (msg) {
      window.open(`https://wa.me/${phone}?text=${encodeURIComponent(msg)}`, '_blank');
    }
  };

  // Update Dispatch Order Status
  const handleUpdateOrderStatus = async (
    orderId: string,
    newStatus: 'packing' | 'in_transit' | 'delivered',
    extraData: any = {}
  ) => {
    try {
      if (!orderId || typeof orderId !== 'string' || !orderId.trim()) {
        throw new Error('ID pesanan tidak valid.');
      }

      const payload: any = {
        status: newStatus,
        ...extraData,
      };

      // Sanitasi menyeluruh: ubah semua string kosong "" menjadi null agar kolom UUID & nullable di PostgreSQL tidak error
      Object.keys(payload).forEach((key) => {
        if (payload[key] === '') {
          payload[key] = null;
        }
      });

      if (newStatus === 'in_transit' && !payload.dispatched_at) {
        payload.dispatched_at = new Date().toISOString();
      }
      if (newStatus === 'delivered' && !payload.delivered_at) {
        payload.delivered_at = new Date().toISOString();
      }

      const { error } = await supabase
        .from('package_fulfillment_orders')
        .update(payload)
        .eq('id', orderId);

      if (error) throw error;

      // Jika delivered, panggil juga RPC konfirmasi untuk mengaktifkan toko & isi katalog
      if (newStatus === 'delivered') {
        try {
          await supabase.rpc('confirm_starter_kit_delivery', {
            p_order_id: orderId,
          });
        } catch (rpcErr) {
          console.warn('confirm_starter_kit_delivery RPC note:', rpcErr);
        }
      }

      setSuccessMsg(`Status pengiriman pesanan diperbarui menjadi "${newStatus.replace('_', ' ').toUpperCase()}".`);
      setIsDispatchModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal memperbarui order: ${err.message}`);
    }
  };

  // Filtered Orders
  const filteredOrders = orders.filter((o) => {
    const matchesSearch =
      o.order_code.toLowerCase().includes(searchQuery.toLowerCase()) ||
      o.recipient_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      o.kit_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      o.shipping_city.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus = statusFilter === 'ALL' || o.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6 max-w-7xl pb-16">
      <Navbar
        title="Gudang & Dispatch Rantai Pasok"
        description="Pantau jaringan multi-node agen pabrik (Cleo, Unilever, Makarizo), routing otomatis pengiriman terdekat, dan surat jalan white-label Syupeo."
      />

      {/* Highlights KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-[#eff6ff] border border-[#bfdbfe] flex items-center justify-center text-[#0070fc]">
            <Building2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Total Node Gudang</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">
              {warehouses.filter((w) => w.is_active).length} Titik Distribusi
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
            <Truck className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Sedang Dikirim (In-Transit)</p>
            <h4 className="text-xl font-black text-amber-700 mt-0.5">
              {orders.filter((o) => o.status === 'in_transit').length} Pesanan
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-blue-50 border border-blue-200 flex items-center justify-center text-blue-600">
            <Clock className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Menunggu Dispatch / Packing</p>
            <h4 className="text-xl font-black text-blue-900 mt-0.5">
              {orders.filter((o) => o.status === 'pending_dispatch' || o.status === 'packing').length} Paket
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Selesai Terkirim</p>
            <h4 className="text-xl font-black text-emerald-700 mt-0.5">
              {orders.filter((o) => o.status === 'delivered').length} Paket Sukses
            </h4>
          </div>
        </div>
      </div>

      {/* Alerts */}
      {errorMsg && (
        <div className="p-4 rounded-[8px] bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-center justify-between shadow-xs">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span className="font-semibold">{errorMsg}</span>
          </div>
          <button onClick={() => setErrorMsg(null)} className="text-rose-600 hover:text-rose-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}
      {successMsg && (
        <div className="p-4 rounded-[8px] bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center justify-between shadow-xs">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
            <span className="font-semibold">{successMsg}</span>
          </div>
          <button onClick={() => setSuccessMsg(null)} className="text-emerald-600 hover:text-emerald-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Tabs Navigation & Action */}
      <div className="bg-white p-4 rounded-[12px] border border-[rgba(26,26,26,0.12)] shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveTab('dispatch')}
            className={`px-4 py-2 rounded-[8px] text-xs font-bold transition-all flex items-center gap-2 ${
              activeTab === 'dispatch'
                ? 'bg-[#0070fc] text-white shadow-xs'
                : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
            }`}
          >
            <Truck className="w-4 h-4" />
            <span>Order Dispatch & Pengiriman ({orders.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('warehouses')}
            className={`px-4 py-2 rounded-[8px] text-xs font-bold transition-all flex items-center gap-2 ${
              activeTab === 'warehouses'
                ? 'bg-[#0070fc] text-white shadow-xs'
                : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
            }`}
          >
            <Building2 className="w-4 h-4" />
            <span>Jaringan Gudang & Agen ({warehouses.length})</span>
          </button>
        </div>

        <div>
          {activeTab === 'warehouses' && (
            <button
              onClick={() => {
                resetWarehouseForm();
                setIsWarehouseModalOpen(true);
              }}
              className="flex items-center gap-2 px-4 py-2 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs shadow-xs active:scale-95 transition-all"
            >
              <PlusCircle className="w-4 h-4" />
              <span>+ Daftarkan Gudang / Agen Baru</span>
            </button>
          )}
        </div>
      </div>

      {/* ========================================================
          TAB 1: ORDER DISPATCH & PENGIRIMAN PAKET
          ======================================================== */}
      {activeTab === 'dispatch' && (
        <div className="space-y-4">
          {/* Filter Bar */}
          <div className="bg-white p-3.5 rounded-[12px] border border-[rgba(26,26,26,0.12)] shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div className="relative flex-1">
              <Search className="w-4 h-4 absolute left-3 top-3 text-slate-400" />
              <input
                type="text"
                placeholder="Cari no resi, nama penerima, kota, atau nama paket..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-4 py-2 text-xs rounded-[8px] border border-slate-200 focus:outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc]"
              />
            </div>

            <div className="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0">
              <span className="text-[11px] font-bold text-slate-400 whitespace-nowrap">Filter Status:</span>
              {['ALL', 'pending_dispatch', 'packing', 'in_transit', 'delivered'].map((st) => (
                <button
                  key={st}
                  onClick={() => setStatusFilter(st)}
                  className={`px-3 py-1.5 rounded-[6px] text-[11px] font-bold tracking-tight whitespace-nowrap transition-all ${
                    statusFilter === st
                      ? 'bg-[#0070fc] text-white'
                      : 'bg-slate-100 hover:bg-slate-200 text-slate-600'
                  }`}
                >
                  {st === 'ALL'
                    ? 'Semua'
                    : st === 'pending_dispatch'
                    ? 'Menunggu'
                    : st === 'packing'
                    ? 'Packing'
                    : st === 'in_transit'
                    ? 'Diantar'
                    : 'Terkirim'}
                </button>
              ))}
            </div>
          </div>

          {/* Orders List */}
          {filteredOrders.length === 0 ? (
            <div className="bg-white p-12 rounded-[12px] border border-[rgba(26,26,26,0.12)] text-center space-y-3">
              <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center mx-auto text-slate-400">
                <Truck className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-slate-800 text-sm">Tidak Ada Order Pengiriman</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                Belum ada pesanan yang sesuai dengan filter pencarian ini.
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
                    className="bg-white rounded-[12px] border border-[rgba(26,26,26,0.12)] hover:border-slate-300 shadow-xs transition-all overflow-hidden"
                  >
                    <div className="p-5 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                      {/* Left: Order Info & Recipient */}
                      <div className="space-y-2 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-mono text-xs font-black text-[#0070fc] bg-blue-50 px-2 py-0.5 rounded border border-blue-200">
                            {order.order_code}
                          </span>
                          <span className="text-xs font-bold text-slate-900">{order.kit_name}</span>
                          <span
                            className={`text-[10px] font-black uppercase px-2 py-0.5 rounded-full ${
                              order.status === 'delivered'
                                ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                                : order.status === 'in_transit'
                                ? 'bg-amber-100 text-amber-800 border border-amber-200'
                                : order.status === 'packing'
                                ? 'bg-blue-100 text-blue-800 border border-blue-200'
                                : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            {order.status.replace('_', ' ')}
                          </span>
                          <span className="text-[11px] font-bold text-[#0070fc] bg-blue-50 px-2 py-0.5 rounded-full">
                            📦 {manifestItems.length} Jenis Barang
                          </span>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">
                          <div>
                            <p className="text-slate-400 text-[10px] font-semibold uppercase">Penerima (Toko Retail):</p>
                            <p className="font-bold text-slate-800 mt-0.5">
                              {order.recipient_name} • <span className="font-mono text-slate-600">{order.recipient_phone}</span>
                            </p>
                            <p className="text-slate-500 text-[11px] leading-snug mt-0.5">
                              {order.shipping_address}, {order.shipping_city}
                            </p>
                          </div>

                          {/* Node Gudang Pengirim */}
                          <div>
                            <p className="text-slate-400 text-[10px] font-semibold uppercase">Gudang / Agen Pengirim:</p>
                            <div className="flex items-center gap-1.5 mt-0.5">
                              <Building2 className="w-3.5 h-3.5 text-[#0070fc]" />
                              <span className="font-bold text-slate-900">
                                {assignedWh ? assignedWh.name : 'Belum Ditugaskan'}
                              </span>
                            </div>
                            <div className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-2">
                              <span>Jarak: <strong className="font-mono text-slate-700">{order.distance_km || '4.5'} km</strong></span>
                              <span>•</span>
                              <span className="text-blue-700 font-semibold bg-blue-50 px-1 rounded">Label: {order.sender_alias}</span>
                            </div>
                          </div>
                        </div>

                        {(order.driver_name || order.tracking_number) && (
                          <div className="pt-2 border-t border-slate-100 flex flex-wrap items-center gap-3 text-xs text-slate-600">
                            {order.driver_name && (
                              <div className="flex items-center gap-1.5">
                                <span className="font-semibold text-slate-700">Kurir/Armada:</span>
                                <span className="font-bold text-slate-900">{order.driver_name}</span>
                                {order.driver_phone && <span className="font-mono text-slate-500">({order.driver_phone})</span>}
                              </div>
                            )}
                            {order.tracking_number && (
                              <div className="flex items-center gap-1.5">
                                <span className="font-semibold text-slate-700">No. Resi:</span>
                                <span className="font-mono font-bold text-[#0070fc] bg-blue-50 px-2 py-0.5 rounded border border-blue-200">
                                  {order.tracking_number}
                                </span>
                              </div>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Right: Actions */}
                      <div className="flex flex-wrap lg:flex-col items-end gap-2 shrink-0">
                        {/* Tombol Lihat Rincian Barang */}
                        <button
                          onClick={() => toggleExpandOrder(order.id)}
                          className={`px-3 py-1.5 rounded-[8px] font-bold text-xs flex items-center gap-1.5 transition-all border ${
                            isExpanded
                              ? 'bg-[#0070fc] text-white border-[#0070fc]'
                              : 'bg-blue-50 hover:bg-blue-100 text-[#0070fc] border-blue-200'
                          }`}
                        >
                          <Boxes className="w-3.5 h-3.5" />
                          <span>Rincian Barang ({manifestItems.length})</span>
                          <ChevronDown className={`w-3.5 h-3.5 transition-transform ${isExpanded ? 'rotate-180' : ''}`} />
                        </button>

                        <button
                          onClick={() => {
                            setSelectedOrder(order);
                            setIsPrintLabelOpen(true);
                          }}
                          className="px-3 py-1.5 rounded-[8px] bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs flex items-center gap-1.5 transition-all"
                        >
                          <Printer className="w-3.5 h-3.5" />
                          <span>Cetak Label & Surat Jalan</span>
                        </button>

                        {order.status === 'pending_dispatch' && (
                          <button
                            onClick={async () => {
                              await handleUpdateOrderStatus(order.id, 'packing');
                              notifyBuyerViaWhatsApp(order, 'packing');
                            }}
                            className="px-3.5 py-1.5 rounded-[8px] bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs flex items-center gap-1.5 transition-all shadow-xs"
                          >
                            <Package className="w-3.5 h-3.5" />
                            <span>Siapkan & Packing</span>
                          </button>
                        )}

                        {order.status === 'packing' && (
                          <button
                            onClick={() => {
                              setSelectedOrder(order);
                              setDispatchWarehouseId(order.assigned_warehouse_id || warehouses[0]?.id || '');
                              setDriverName(order.driver_name || '');
                              setDriverPhone(order.driver_phone || '');
                              setTrackingNumber(order.tracking_number || '');
                              setIsDispatchModalOpen(true);
                            }}
                            className="px-3.5 py-1.5 rounded-[8px] bg-amber-600 hover:bg-amber-700 text-white font-bold text-xs flex items-center gap-1.5 transition-all shadow-xs"
                          >
                            <Truck className="w-3.5 h-3.5" />
                            <span>Kirimkan ke Toko</span>
                          </button>
                        )}

                        {order.status === 'in_transit' && (
                          <button
                            onClick={async () => {
                              await handleUpdateOrderStatus(order.id, 'delivered');
                              notifyBuyerViaWhatsApp(order, 'delivered');
                            }}
                            className="px-3.5 py-1.5 rounded-[8px] bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center gap-1.5 transition-all shadow-xs"
                          >
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            <span>Konfirmasi Diterima</span>
                          </button>
                        )}

                        {order.recipient_phone && (
                          <button
                            onClick={() => notifyBuyerViaWhatsApp(order, order.status)}
                            className="px-3 py-1.5 rounded-[8px] bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 font-bold text-xs flex items-center gap-1.5 transition-all shadow-xs"
                            title="Kirim Notifikasi WhatsApp ke Toko Pembeli"
                          >
                            <Send className="w-3.5 h-3.5 text-emerald-600" />
                            <span>Notifikasi WA</span>
                          </button>
                        )}
                      </div>
                    </div>

                    {/* ========================================================
                        EXPANDABLE PANEL: RINCIAN DAFTAR BARANG YANG HARUS DIKIRIM
                        ======================================================== */}
                    {isExpanded && (
                      <div className="border-t border-slate-200 bg-slate-50/70 p-5 space-y-3">
                        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-slate-200/80">
                          <div className="flex items-center gap-2">
                            <ListChecks className="w-4 h-4 text-[#0070fc]" />
                            <h4 className="font-bold text-xs text-slate-900 uppercase tracking-wide">
                              Daftar Barang yang Harus Diambil dari Rak Gudang & Dikemas:
                            </h4>
                          </div>
                          <div className="flex items-center gap-2 text-xs">
                            <span className="text-slate-500">
                              Checklist: <strong className="text-slate-800">{checkedSet.size}</strong> dari{' '}
                              <strong className="text-slate-800">{manifestItems.length}</strong> siap
                            </span>
                            {allChecked && (
                              <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold text-[10px] flex items-center gap-1">
                                <Check className="w-3 h-3" /> Siap Packing
                              </span>
                            )}
                          </div>
                        </div>

                        {/* Manifest Table */}
                        <div className="overflow-x-auto rounded-[8px] border border-slate-200 bg-white shadow-xs">
                          <table className="w-full text-left text-xs border-collapse">
                            <thead>
                              <tr className="bg-slate-100/80 text-slate-600 font-bold border-b border-slate-200">
                                <th className="p-2.5 w-10 text-center">Cek</th>
                                <th className="p-2.5 w-10 text-center">No</th>
                                <th className="p-2.5">Nama Produk / Barang</th>
                                <th className="p-2.5">Kategori / Rak</th>
                                <th className="p-2.5 font-mono">Barcode / SKU</th>
                                <th className="p-2.5 text-right">Jumlah Dikirim</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                              {manifestItems.map((item, idx) => {
                                const isChecked = checkedSet.has(idx);
                                return (
                                  <tr
                                    key={idx}
                                    onClick={() => toggleItemCheck(order.id, idx)}
                                    className={`cursor-pointer transition-colors ${
                                      isChecked ? 'bg-emerald-50/50 hover:bg-emerald-50' : 'hover:bg-slate-50'
                                    }`}
                                  >
                                    <td className="p-2.5 text-center">
                                      <button
                                        type="button"
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          toggleItemCheck(order.id, idx);
                                        }}
                                        className="text-slate-400 hover:text-emerald-600 transition-colors"
                                      >
                                        {isChecked ? (
                                          <CheckSquare className="w-4 h-4 text-emerald-600" />
                                        ) : (
                                          <Square className="w-4 h-4 text-slate-300" />
                                        )}
                                      </button>
                                    </td>
                                    <td className="p-2.5 text-center font-mono text-slate-400 font-semibold">{idx + 1}</td>
                                    <td className="p-2.5 font-bold text-slate-900">
                                      <span className={isChecked ? 'line-through text-slate-400' : ''}>{item.name}</span>
                                    </td>
                                    <td className="p-2.5">
                                      <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-600 font-medium text-[11px]">
                                        {item.category || 'Gudang'}
                                      </span>
                                    </td>
                                    <td className="p-2.5 font-mono text-slate-500 text-[11px]">{item.barcode || '-'}</td>
                                    <td className="p-2.5 text-right font-black text-slate-900 font-mono text-[13px]">
                                      <span className="px-2 py-0.5 rounded bg-blue-50 text-[#0070fc] border border-blue-200">
                                        {item.quantity} {item.unit}
                                      </span>
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>

                        {order.notes && !order.notes.startsWith('{') && (
                          <div className="p-2.5 rounded-[8px] bg-amber-50 border border-amber-200 text-xs text-amber-900">
                            <strong>Catatan Tambahan Pengiriman:</strong> {order.notes}
                          </div>
                        )}
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
          TAB 2: JARINGAN GUDANG & AGEN PABRIK
          ======================================================== */}
      {activeTab === 'warehouses' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {warehouses.map((wh) => (
              <div
                key={wh.id}
                className="bg-white p-5 rounded-[12px] border border-[rgba(26,26,26,0.12)] shadow-xs hover:border-slate-300 transition-all flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-mono text-[10px] font-bold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded">
                      {wh.code}
                    </span>
                    <span
                      className={`text-[9.5px] font-black uppercase px-2 py-0.5 rounded-full ${
                        wh.warehouse_type === 'syupeo_hub'
                          ? 'bg-[#eff6ff] text-[#0070fc] border border-[#bfdbfe]'
                          : 'bg-amber-50 text-amber-800 border border-amber-200'
                      }`}
                    >
                      {wh.warehouse_type === 'syupeo_hub' ? 'Gudang Pusat Syupeo' : `Agen ${wh.brand_partner || 'Pabrik'}`}
                    </span>
                  </div>

                  <h3 className="font-bold text-sm text-slate-900 leading-snug">{wh.name}</h3>
                  <p className="text-xs text-slate-500 mt-1 flex items-start gap-1">
                    <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
                    <span>
                      {wh.address}
                      {wh.district ? `, Kec. ${wh.district}` : ''}
                      {wh.city ? `, ${wh.city}` : ''}
                      {wh.province ? `, ${wh.province}` : ''}
                    </span>
                  </p>

                  {/* Koordinat GPS & Link Google Maps */}
                  {wh.latitude && wh.longitude ? (
                    <div className="mt-2 flex items-center justify-between bg-blue-50/70 border border-blue-100 rounded-md px-2 py-1 text-[11px]">
                      <span className="font-mono text-blue-800 flex items-center gap-1">
                        <Navigation className="w-3 h-3 text-[#0070fc]" />
                        {wh.latitude.toFixed(4)}, {wh.longitude.toFixed(4)}
                      </span>
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${wh.latitude},${wh.longitude}`}
                        target="_blank"
                        rel="noreferrer"
                        className="text-[#0070fc] hover:underline font-semibold flex items-center gap-0.5"
                      >
                        <span>Peta</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                      </a>
                    </div>
                  ) : (
                    <div className="mt-2 text-[10px] text-slate-400 italic">
                      Koordinat GPS belum dikalibrasi
                    </div>
                  )}

                  <div className="mt-3 p-2 rounded-[8px] bg-slate-50 border border-slate-100 space-y-1 text-xs">
                    <div className="flex items-center justify-between text-slate-600">
                      <span>Jangkauan Radius:</span>
                      <strong className="font-mono text-slate-900">{wh.coverage_radius_km} km</strong>
                    </div>
                    <div className="flex items-center justify-between text-slate-600">
                      <span>PIC Gudang:</span>
                      <strong className="text-slate-900">{wh.pic_name}</strong>
                    </div>
                    <div className="flex items-center justify-between text-slate-600">
                      <span>Kontak WA:</span>
                      <strong className="font-mono text-blue-700">{wh.pic_phone}</strong>
                    </div>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
                  <span className="flex items-center gap-1 text-emerald-600 font-semibold text-[11px]">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    Siap Dispatch
                  </span>
                  <a
                    href={`https://wa.me/${wh.pic_phone.replace(/[^0-9]/g, '')}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[#0070fc] hover:underline font-bold text-[11px] flex items-center gap-1"
                  >
                    <span>Hubungi PIC</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL: TAMBAH GUDANG / AGEN PABRIK BARU
          ======================================================== */}
      {isWarehouseModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-[16px] max-w-lg w-full p-6 border border-slate-200 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <Building2 className="w-5 h-5 text-[#0070fc]" />
                <h3 className="font-bold text-base text-slate-900">Daftarkan Node Gudang Baru</h3>
              </div>
              <button onClick={() => setIsWarehouseModalOpen(false)} className="text-slate-400 hover:text-slate-700">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveWarehouse} className="space-y-3.5 text-xs">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Tipe Kepemilikan Gudang</label>
                <select
                  value={formType}
                  onChange={(e: any) => setFormType(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200 font-medium bg-white"
                >
                  <option value="principal_agent">Gudang Agen Pabrik (Cleo, Unilever, Makarizo, dll)</option>
                  <option value="syupeo_hub">Hub Milik Syupeo Sendiri (Packing & Cross-docking)</option>
                  <option value="third_party_3pl">Gudang Mitra Ekspedisi 3PL</option>
                </select>
              </div>

              {formType === 'principal_agent' && (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Brand Prinsipal Rekanan</label>
                  <input
                    type="text"
                    required
                    placeholder="Contoh: Cleo, Unilever, VICA, Makarizo"
                    value={formBrand}
                    onChange={(e) => setFormBrand(e.target.value)}
                    className="w-full p-2.5 rounded-[8px] border border-slate-200"
                  />
                </div>
              )}

              <div>
                <label className="block font-bold text-slate-700 mb-1">Nama Node Gudang</label>
                <input
                  type="text"
                  required
                  placeholder="Contoh: Depo Cleo Surabaya Rungkut"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200"
                />
              </div>

              {/* 1. Integrasi Wilayah Indonesia (wilayah.id) */}
              <div>
                <label className="block font-bold text-slate-700 mb-1.5">Wilayah Administratif (BPS / Kemendagri)</label>
                <WilayahSelector
                  initialProvince={formProvince}
                  initialCity={formCity}
                  initialDistrict={formDistrict}
                  initialVillage={formVillage}
                  onChange={(sel: WilayahSelection) => {
                    setFormProvince(sel.provinceName);
                    setFormCity(sel.regencyName);
                    setFormDistrict(sel.districtName);
                    setFormVillage(sel.villageName);
                    if (!formAddress && sel.formattedText) {
                      setFormAddress(sel.formattedText);
                    }
                  }}
                />
              </div>

              {/* 2. Integrasi Google Places API & Geocoding DPOS */}
              <div>
                <GooglePlacesAutocomplete
                  initialAddress={formAddress}
                  initialLat={formLat}
                  initialLng={formLng}
                  placeholder="Cari lokasi gudang / patokan jalan via Google Places..."
                  onSelectPlace={(place: PlaceResult) => {
                    setFormAddress(place.formattedAddress);
                    setFormLat(place.latitude);
                    setFormLng(place.longitude);
                  }}
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Kota / Regency Terpilih</label>
                  <input
                    type="text"
                    required
                    placeholder="Kota akan otomatis terisi"
                    value={formCity}
                    onChange={(e) => setFormCity(e.target.value)}
                    className="w-full p-2.5 rounded-[8px] border border-slate-200 bg-slate-50 font-medium"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Radius Jangkauan (KM)</label>
                  <input
                    type="number"
                    required
                    value={formRadius}
                    onChange={(e) => setFormRadius(Number(e.target.value))}
                    className="w-full p-2.5 rounded-[8px] border border-slate-200"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Alamat Lengkap / Patokan Fisik</label>
                <textarea
                  required
                  rows={2}
                  placeholder="Alamat jalan gudang fisik untuk rute supir..."
                  value={formAddress}
                  onChange={(e) => setFormAddress(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Nama PIC Gudang</label>
                  <input
                    type="text"
                    required
                    placeholder="Contoh: Pak Agus"
                    value={formPicName}
                    onChange={(e) => setFormPicName(e.target.value)}
                    className="w-full p-2.5 rounded-[8px] border border-slate-200"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">No. WhatsApp PIC</label>
                  <input
                    type="text"
                    required
                    placeholder="0812-xxxx-xxxx"
                    value={formPicPhone}
                    onChange={(e) => setFormPicPhone(e.target.value)}
                    className="w-full p-2.5 rounded-[8px] border border-slate-200"
                  />
                </div>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsWarehouseModalOpen(false)}
                  className="px-4 py-2 rounded-[8px] bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="px-4 py-2 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold flex items-center gap-2"
                >
                  {isSaving && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>Simpan Gudang</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL: UPDATE DISPATCH / KIRIM PESANAN
          ======================================================== */}
      {isDispatchModalOpen && selectedOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-[16px] max-w-md w-full p-6 border border-slate-200 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <Truck className="w-5 h-5 text-amber-600" />
                <h3 className="font-bold text-base text-slate-900">Kirim Paket ke Toko</h3>
              </div>
              <button onClick={() => setIsDispatchModalOpen(false)} className="text-slate-400 hover:text-slate-700">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div className="p-3 rounded-[8px] bg-slate-50 border border-slate-200 space-y-1">
                <p className="text-slate-500">Order: <strong className="text-slate-900">{selectedOrder.order_code}</strong></p>
                <p className="text-slate-500">Tujuan: <strong className="text-slate-900">{selectedOrder.recipient_name} ({selectedOrder.shipping_city})</strong></p>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Gudang / Agen yang Mengirimkan</label>
                <select
                  value={dispatchWarehouseId}
                  onChange={(e) => setDispatchWarehouseId(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200 font-medium bg-white"
                >
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name} ({w.city})
                    </option>
                  ))}
                </select>
              </div>

              {/* No Resi Pengiriman (Opsional / Kurir Ekspedisi) */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  Nomor Resi / AWB Tracking <span className="font-normal text-slate-400">(Wajib jika via Kurir Ekspedisi)</span>
                </label>
                <input
                  type="text"
                  placeholder="Contoh: JNT8829103982 / SOCAG-0021"
                  value={trackingNumber}
                  onChange={(e) => setTrackingNumber(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200 font-mono font-bold tracking-wider uppercase text-slate-900 bg-slate-50 focus:bg-white"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="font-bold text-slate-700">Nama Kurir / Jasa Ekspedisi</label>
                  <div className="flex flex-wrap gap-1">
                    {['Kurir Syupeo', 'J&T Express', 'JNE', 'SiCepat'].map((c) => (
                      <button
                        key={c}
                        type="button"
                        onClick={() => setDriverName(c)}
                        className="px-1.5 py-0.5 rounded bg-slate-100 hover:bg-slate-200 text-[10px] font-semibold text-slate-600"
                      >
                        {c}
                      </button>
                    ))}
                  </div>
                </div>
                <input
                  type="text"
                  placeholder="Contoh: J&T Express / Pak Joko (Armada Syupeo)"
                  value={driverName}
                  onChange={(e) => setDriverName(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">No. WhatsApp Supir / CS Ekspedisi (Opsional)</label>
                <input
                  type="text"
                  placeholder="0819-xxxx-xxxx"
                  value={driverPhone}
                  onChange={(e) => setDriverPhone(e.target.value)}
                  className="w-full p-2.5 rounded-[8px] border border-slate-200"
                />
              </div>

              {/* Toggle Kirim Notifikasi WhatsApp ke Toko Pembeli */}
              <div className="p-3 rounded-[8px] bg-emerald-50 border border-emerald-200 flex items-center justify-between">
                <div>
                  <p className="font-bold text-emerald-900 text-xs">Kirim Notifikasi WhatsApp ke Toko</p>
                  <p className="text-[11px] text-emerald-700">Kirim detail kurir & no. resi ke WhatsApp toko ({selectedOrder.recipient_phone || 'Nomor Pembeli'})</p>
                </div>
                <input
                  type="checkbox"
                  checked={notifyWaOnDispatch}
                  onChange={(e) => setNotifyWaOnDispatch(e.target.checked)}
                  className="w-4 h-4 text-emerald-600 rounded cursor-pointer accent-emerald-600"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsDispatchModalOpen(false)}
                  className="px-4 py-2 rounded-[8px] bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold"
                >
                  Batal
                </button>
                <button
                  onClick={async () => {
                    await handleUpdateOrderStatus(selectedOrder.id, 'in_transit', {
                      assigned_warehouse_id: dispatchWarehouseId.trim() ? dispatchWarehouseId.trim() : null,
                      driver_name: driverName.trim() || null,
                      driver_phone: driverPhone.trim() || null,
                      tracking_number: trackingNumber.trim() ? trackingNumber.trim() : null,
                    });
                    if (notifyWaOnDispatch) {
                      notifyBuyerViaWhatsApp(selectedOrder, 'in_transit', driverName.trim(), trackingNumber.trim());
                    }
                  }}
                  className="px-4 py-2 rounded-[8px] bg-amber-600 hover:bg-amber-700 text-white font-bold"
                >
                  Mulai Pengantaran
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL: CETAK LABEL WHITE-LABEL SYUPEO & SURAT JALAN LENGKAP
          ======================================================== */}
      {isPrintLabelOpen && selectedOrder && (() => {
        const printManifestItems = getOrderManifestItems(selectedOrder);
        return (
          <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
            <div className="bg-white rounded-[16px] max-w-2xl w-full p-6 border border-slate-200 shadow-2xl space-y-4 my-8">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-2">
                  <Printer className="w-5 h-5 text-[#0070fc]" />
                  <h3 className="font-bold text-base text-slate-900">Surat Jalan & Manifest Pengiriman Resmi</h3>
                </div>
                <button onClick={() => setIsPrintLabelOpen(false)} className="text-slate-400 hover:text-slate-700">
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Printable Area Container */}
              <div id="print-label-card" className="p-6 border-2 border-slate-900 rounded-[8px] bg-white text-slate-900 space-y-4 font-sans">
                {/* Header Surat Jalan */}
                <div className="flex items-center justify-between border-b-2 border-slate-900 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="w-9 h-9 rounded bg-[#0070fc] flex items-center justify-center text-white font-black text-base">
                      S
                    </div>
                    <div>
                      <h4 className="font-black text-base text-[#0070fc] leading-none tracking-tight">SYUPEO LOGISTICS</h4>
                      <p className="text-[10px] text-slate-500 font-bold uppercase tracking-wider mt-0.5">
                        Surat Jalan & Bukti Serah Terima Barang
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-mono text-sm font-black text-slate-900">{selectedOrder.order_code}</div>
                    <div className="text-[10px] font-bold text-slate-500 uppercase">
                      Tanggal: {new Date(selectedOrder.created_at || Date.now()).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })}
                    </div>
                  </div>
                </div>

                {/* Sender & Receiver Box */}
                <div className="grid grid-cols-2 gap-3 text-xs border-b border-slate-200 pb-3">
                  <div className="p-3 rounded bg-slate-50 border border-slate-200 space-y-0.5">
                    <p className="text-[9px] font-bold text-slate-400 uppercase tracking-wide">PENGIRIM (GUDANG / DISTRIBUTOR):</p>
                    <p className="font-black text-slate-900 text-xs">{selectedOrder.sender_alias}</p>
                    <p className="text-[11px] text-slate-600">
                      Gudang: <strong>{selectedOrder.warehouse?.name || 'Depo Logistik Syupeo'}</strong>
                    </p>
                    <p className="text-[10px] text-slate-500">CS / Hotline Pengiriman: 0856-2427-7920</p>
                  </div>

                  <div className="p-3 rounded bg-blue-50/60 border border-blue-200 space-y-0.5">
                    <p className="text-[9px] font-bold text-blue-700 uppercase tracking-wide">PENERIMA (MITRA TOKO RETAIL):</p>
                    <p className="font-black text-slate-900 text-xs">{selectedOrder.recipient_name}</p>
                    <p className="font-mono text-[11px] font-bold text-slate-700">{selectedOrder.recipient_phone}</p>
                    <p className="text-[10px] text-slate-600 leading-snug">
                      {selectedOrder.shipping_address}, {selectedOrder.shipping_city}
                    </p>
                  </div>
                </div>

                {/* Kurir & Resi Box */}
                <div className="p-2.5 rounded bg-slate-100/70 border border-slate-200 flex flex-wrap items-center justify-between text-xs gap-2">
                  <div>
                    <span className="text-slate-500 font-medium">Paket: </span>
                    <strong className="text-slate-900">{selectedOrder.kit_name}</strong>
                  </div>
                  <div className="flex items-center gap-3">
                    {selectedOrder.driver_name && (
                      <div>
                        <span className="text-slate-500 font-medium">Kurir/Armada: </span>
                        <strong className="text-slate-900">{selectedOrder.driver_name}</strong>
                      </div>
                    )}
                    {selectedOrder.tracking_number && (
                      <div>
                        <span className="text-slate-500 font-medium">No. Resi: </span>
                        <strong className="font-mono font-bold text-[#0070fc] bg-white px-2 py-0.5 rounded border border-blue-200">
                          {selectedOrder.tracking_number}
                        </strong>
                      </div>
                    )}
                  </div>
                </div>

                {/* TABEL MANIFEST RINCIAN BARANG */}
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between text-xs">
                    <p className="text-[10px] font-black text-slate-900 uppercase tracking-wider flex items-center gap-1.5">
                      <ListChecks className="w-3.5 h-3.5 text-[#0070fc]" />
                      <span>Rincian Barang yang Dikirim ({printManifestItems.length} Item Fisik)</span>
                    </p>
                    <span className="text-[10px] font-mono text-slate-500 font-bold">Harap cek kondisi fisik barang</span>
                  </div>

                  <table className="w-full text-left text-[11px] border-collapse border border-slate-300">
                    <thead>
                      <tr className="bg-slate-100 text-slate-800 font-bold border-b border-slate-300">
                        <th className="p-1.5 w-8 text-center border-r border-slate-300">No</th>
                        <th className="p-1.5 w-24 border-r border-slate-300 font-mono">Kode</th>
                        <th className="p-1.5 border-r border-slate-300">Nama Barang / Deskripsi</th>
                        <th className="p-1.5 w-28 border-r border-slate-300">Kategori / Rak</th>
                        <th className="p-1.5 w-20 text-right border-r border-slate-300">Qty</th>
                        <th className="p-1.5 w-12 text-center">Cek</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-200">
                      {printManifestItems.map((item, idx) => (
                        <tr key={idx} className="hover:bg-slate-50">
                          <td className="p-1.5 text-center font-mono text-slate-500 border-r border-slate-300">{idx + 1}</td>
                          <td className="p-1.5 font-mono text-[10px] text-slate-600 border-r border-slate-300">{item.barcode || '-'}</td>
                          <td className="p-1.5 font-bold text-slate-900 border-r border-slate-300">{item.name}</td>
                          <td className="p-1.5 text-slate-600 border-r border-slate-300">{item.category || 'Gudang'}</td>
                          <td className="p-1.5 text-right font-black font-mono text-slate-900 border-r border-slate-300">
                            {item.quantity} {item.unit}
                          </td>
                          <td className="p-1.5 text-center font-mono font-bold text-slate-400">[  ]</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Lembar Tanda Tangan Serah Terima */}
                <div className="pt-2 border-t border-slate-200">
                  <p className="text-[9px] font-bold text-slate-400 uppercase text-center mb-2 tracking-wider">
                    Lembar Verifikasi & Serah Terima Barang
                  </p>
                  <div className="grid grid-cols-3 gap-2 text-center text-[10px]">
                    <div className="p-2 border border-slate-200 rounded">
                      <p className="text-slate-500 font-semibold mb-8">Disiapkan (Gudang/Checker)</p>
                      <p className="font-bold text-slate-800 border-t border-slate-300 pt-1">( ................................ )</p>
                    </div>
                    <div className="p-2 border border-slate-200 rounded">
                      <p className="text-slate-500 font-semibold mb-8">Dibawa (Kurir / Driver)</p>
                      <p className="font-bold text-slate-800 border-t border-slate-300 pt-1">( {selectedOrder.driver_name || '................................'} )</p>
                    </div>
                    <div className="p-2 border border-slate-200 rounded">
                      <p className="text-slate-500 font-semibold mb-8">Diterima (Toko Retail)</p>
                      <p className="font-bold text-slate-800 border-t border-slate-300 pt-1">( {selectedOrder.recipient_name} )</p>
                    </div>
                  </div>
                </div>

                <div className="pt-2 text-[9px] text-slate-400 text-center italic border-t border-slate-100">
                  Barang resmi dikirimkan langsung oleh jaringan gudang distributor terverifikasi Syupeo. Harap diperiksa kelengkapannya saat barang tiba di toko.
                </div>
              </div>

              <div className="pt-2 flex items-center justify-end gap-2">
                <button
                  onClick={() => setIsPrintLabelOpen(false)}
                  className="px-4 py-2 rounded-[8px] bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs"
                >
                  Tutup
                </button>
                <button
                  onClick={() => window.print()}
                  className="px-4 py-2 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold text-xs flex items-center gap-1.5"
                >
                  <Printer className="w-4 h-4" />
                  <span>Cetak Surat Jalan & Label</span>
                </button>
              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
}

