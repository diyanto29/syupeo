'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { BusinessTypeTemplate } from '@/types/database';
import {
  Layers,
  Plus,
  Pencil,
  Trash2,
  CheckCircle,
  Settings2,
  X,
  AlertCircle,
  Boxes,
  Store,
  Utensils,
  ShoppingBag,
  Wrench,
  LayoutGrid,
  Bike,
  Shirt,
  Briefcase,
  Crown,
  Users,
  SlidersHorizontal,
  Sparkles,
  Receipt,
  ClipboardList,
  Package,
  BookOpen,
  CookingPot,
  Warehouse,
  Tag,
  Wallet,
  QrCode,
  BarChart3,
  Edit3,
} from 'lucide-react';

export const AVAILABLE_FEATURES = [
  {
    id: 'transaction',
    label: 'Transaksi POS',
    desc: 'Penjualan kasir & cetak struk belanja',
    icon: Receipt,
  },
  {
    id: 'order_mgmt',
    label: 'Pesanan & Draft',
    desc: 'Dine-in, take away, dan status pesanan antrian',
    icon: ClipboardList,
  },
  {
    id: 'menu_mgmt',
    label: 'Manajemen Produk & Diskon',
    desc: 'Kelola katalog produk, varian, dan promo diskon',
    icon: Package,
  },
  {
    id: 'master_catalog',
    label: 'Master Catalog (Sampel Produk)',
    desc: 'Database master produk siap pakai per jenis usaha',
    icon: BookOpen,
  },
  {
    id: 'table_mgmt',
    label: 'Manajemen Meja',
    desc: 'Layout denah meja resto & status okupansi tamu',
    icon: LayoutGrid,
  },
  {
    id: 'kitchen_kds',
    label: 'Antrian Dapur (KDS)',
    desc: 'Layar pantau pesanan untuk koki dan barista',
    icon: CookingPot,
  },
  {
    id: 'inventory',
    label: 'Inventori / Stok',
    desc: 'Manajemen stok bahan baku & produk jadi',
    icon: Warehouse,
  },
  {
    id: 'tiered_pricing',
    label: 'Harga Bertingkat / Grosir',
    desc: 'Dukungan harga grosir & tier kuantitas pembelian',
    icon: Tag,
  },
  {
    id: 'cash_flow',
    label: 'Manajemen Kas & Shift',
    desc: 'Kas modal awal, kas keluar, dan buka/tutup shift kasir',
    icon: Wallet,
  },
  {
    id: 'qr_order',
    label: 'QR Self-Order',
    desc: 'Customer pesan mandiri lewat scan QR meja',
    icon: QrCode,
  },
  {
    id: 'reports',
    label: 'Laporan Analitik',
    desc: 'Rekap omzet, arus kas, margin, dan laba bersih',
    icon: BarChart3,
  },
  {
    id: 'editable_price',
    label: 'Bisa Edit Harga Jual (Nego)',
    desc: 'Kasir dapat merubah nominal harga jual saat checkout',
    icon: Edit3,
  },
  {
    id: 'subscription',
    label: 'Menu Paket Langganan',
    desc: 'Akses menu upgrade paket langganan di aplikasi',
    icon: Crown,
  },
];

const AVAILABLE_ICONS = [
  { id: 'restaurant_rounded', label: 'Resto & Kafe', icon: Utensils },
  { id: 'shopping_bag_rounded', label: 'Retail & Toko', icon: ShoppingBag },
  { id: 'handyman_rounded', label: 'Bengkel & Servis', icon: Wrench },
  { id: 'apps_rounded', label: 'Umum & Lainnya', icon: LayoutGrid },
  { id: 'motorcycle_rounded', label: 'Otomotif & Kurir', icon: Bike },
  { id: 'local_laundry_service_rounded', label: 'Laundry & Jasa', icon: Shirt },
  { id: 'business_center_rounded', label: 'Showroom & Kantor', icon: Briefcase },
  { id: 'store', label: 'UMKM & Warung', icon: Store },
];

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<BusinessTypeTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<BusinessTypeTemplate | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Form states
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    description: '',
    icon_name: 'restaurant_rounded',
    free_max_transactions: 100,
    free_max_products: 50,
    free_max_outlets: 1,
    pro_max_transactions: 99999,
    pro_max_products: 99999,
    pro_max_outlets: 5,
    show_ads: false,
    role_waiter: '',
    role_kitchen: '',
    role_cashier: '',
    role_admin: '',
    features_config: {} as Record<string, 'off' | 'free' | 'pro'>,
  });

  const supabase = createClient();

  const fetchTemplates = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('business_type_templates')
      .select('*')
      .order('created_at', { ascending: true });

    if (!error && data) {
      setTemplates(data as BusinessTypeTemplate[]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchTemplates();
  }, []);

  const openCreateModal = () => {
    setEditingTemplate(null);
    const initialConfig: Record<string, 'off' | 'free' | 'pro'> = {};
    AVAILABLE_FEATURES.forEach((f) => {
      if (['transaction', 'order_mgmt', 'menu_mgmt', 'reports'].includes(f.id)) {
        initialConfig[f.id] = 'free';
      } else if (f.id === 'cash_flow') {
        initialConfig[f.id] = 'pro';
      } else {
        initialConfig[f.id] = 'off';
      }
    });

    setFormData({
      name: '',
      code: '',
      description: '',
      icon_name: 'restaurant_rounded',
      free_max_transactions: 100,
      free_max_products: 50,
      free_max_outlets: 1,
      pro_max_transactions: 99999,
      pro_max_products: 99999,
      pro_max_outlets: 5,
      show_ads: false,
      role_waiter: '',
      role_kitchen: '',
      role_cashier: '',
      role_admin: '',
      features_config: initialConfig,
    });
    setErrorMsg(null);
    setModalOpen(true);
  };

  const openEditModal = (tpl: BusinessTypeTemplate) => {
    setEditingTemplate(tpl);
    const limits = tpl.limits_config || {};
    const free = limits.free || {};
    const pro = limits.pro || {};
    const roles = tpl.role_labels || {};

    const initialConfig: Record<string, 'off' | 'free' | 'pro'> = {};
    AVAILABLE_FEATURES.forEach((f) => {
      if (tpl.features_config && tpl.features_config[f.id]) {
        const val = tpl.features_config[f.id];
        initialConfig[f.id] = val === 'free' || val === 'pro' || val === 'off' ? val : 'off';
      } else if (f.id === 'cash_flow') {
        initialConfig[f.id] = 'pro';
      } else if (tpl.default_enabled_features?.includes(f.id)) {
        initialConfig[f.id] = 'free';
      } else {
        initialConfig[f.id] = 'off';
      }
    });

    setFormData({
      name: tpl.name,
      code: tpl.code,
      description: tpl.description || '',
      icon_name: tpl.icon_name || 'restaurant_rounded',
      free_max_transactions: free.max_transactions ?? tpl.max_transactions ?? 100,
      free_max_products: free.max_products ?? tpl.max_products ?? 50,
      free_max_outlets: free.max_outlets ?? tpl.max_outlets ?? 1,
      pro_max_transactions: pro.max_transactions ?? 99999,
      pro_max_products: pro.max_products ?? 99999,
      pro_max_outlets: pro.max_outlets ?? 5,
      show_ads: tpl.show_ads ?? false,
      role_waiter: roles.waiter || '',
      role_kitchen: roles.kitchen || '',
      role_cashier: roles.cashier || '',
      role_admin: roles.admin || '',
      features_config: initialConfig,
    });
    setErrorMsg(null);
    setModalOpen(true);
  };

  const setFeatureTier = (featId: string, tier: 'off' | 'free' | 'pro') => {
    setFormData((prev) => ({
      ...prev,
      features_config: {
        ...prev.features_config,
        [featId]: tier,
      },
    }));
  };

  const setAllFeatures = (tier: 'off' | 'free' | 'pro') => {
    const updated: Record<string, 'off' | 'free' | 'pro'> = {};
    AVAILABLE_FEATURES.forEach((f) => {
      updated[f.id] = tier;
    });
    setFormData((prev) => ({
      ...prev,
      features_config: updated,
    }));
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setErrorMsg(null);

    try {
      const limits_config = {
        free: {
          max_transactions: Number(formData.free_max_transactions) || 100,
          max_products: Number(formData.free_max_products) || 50,
          max_outlets: Number(formData.free_max_outlets) || 1,
        },
        pro: {
          max_transactions: Number(formData.pro_max_transactions) || 99999,
          max_products: Number(formData.pro_max_products) || 99999,
          max_outlets: Number(formData.pro_max_outlets) || 5,
        },
      };

      const role_labels: Record<string, string> = {};
      if (formData.role_waiter.trim()) role_labels.waiter = formData.role_waiter.trim();
      if (formData.role_kitchen.trim()) role_labels.kitchen = formData.role_kitchen.trim();
      if (formData.role_cashier.trim()) role_labels.cashier = formData.role_cashier.trim();
      if (formData.role_admin.trim()) role_labels.admin = formData.role_admin.trim();

      const default_enabled_features = Object.entries(formData.features_config)
        .filter(([_, tier]) => tier !== 'off')
        .map(([featId]) => featId);

      const payload = {
        name: formData.name,
        code: formData.code.toLowerCase().trim(),
        description: formData.description,
        icon_name: formData.icon_name,
        features_config: formData.features_config,
        default_enabled_features,
        limits_config,
        role_labels,
        max_transactions: limits_config.free.max_transactions,
        max_products: limits_config.free.max_products,
        max_outlets: limits_config.free.max_outlets,
        show_ads: formData.show_ads,
        updated_at: new Date().toISOString(),
      };

      if (editingTemplate) {
        // UPDATE
        const { error, data } = await supabase
          .from('business_type_templates')
          .update(payload)
          .eq('id', editingTemplate.id)
          .select();

        if (error) throw error;
        if (!data || data.length === 0) {
          throw new Error('Gagal memperbarui: Izin ditolak oleh database (RLS). Pastikan akun Anda terdaftar sebagai Admin aktif di sistem.');
        }

        const updated = data[0] as BusinessTypeTemplate;
        setTemplates((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
        setSuccessMsg(`Template "${formData.name}" berhasil diperbarui.`);
      } else {
        // INSERT
        const { error, data } = await supabase
          .from('business_type_templates')
          .insert(payload)
          .select();

        if (error) throw error;
        if (!data || data.length === 0) {
          throw new Error('Gagal membuat: Izin ditolak oleh database (RLS). Pastikan akun Anda terdaftar sebagai Admin aktif di sistem.');
        }

        const created = data[0] as BusinessTypeTemplate;
        setTemplates((prev) => [...prev, created]);
        setSuccessMsg(`Template "${formData.name}" berhasil dibuat.`);
      }

      setModalOpen(false);
      await fetchTemplates();
    } catch (err: any) {
      setErrorMsg(err.message || 'Terjadi kesalahan saat menyimpan template.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (tpl: BusinessTypeTemplate) => {
    if (!confirm(`Yakin ingin menghapus template "${tpl.name}" (${tpl.code})?`)) return;

    const { error, data } = await supabase
      .from('business_type_templates')
      .delete()
      .eq('id', tpl.id)
      .select();

    if (!error && data && data.length > 0) {
      setSuccessMsg(`Template "${tpl.name}" telah dihapus.`);
      setTemplates((prev) => prev.filter((t) => t.id !== tpl.id));
    } else {
      alert(`Gagal menghapus: ${error?.message || 'Izin ditolak oleh database (RLS). Pastikan akun Anda terdaftar sebagai Admin aktif di sistem.'}`);
    }
  };

  const getTemplateIcon = (iconName?: string | null) => {
    const found = AVAILABLE_ICONS.find((item) => item.id === iconName);
    return found ? found.icon : Boxes;
  };

  return (
    <div>
      <Navbar
        title="Kelola Template Bisnis"
        description="Atur jenis usaha Mangga POS, custom role labels, konfigurasi fitur & tiering (Free vs Pro), serta batas kuota"
      />

      <div className="space-y-6 mt-6">
        {/* Toast Alerts */}
        {successMsg && (
          <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <CheckCircle className="w-5 h-5 text-emerald-600" />
              <span className="font-semibold">{successMsg}</span>
            </div>
            <button onClick={() => setSuccessMsg(null)}>
              <X className="w-4 h-4 text-emerald-600 hover:text-emerald-800" />
            </button>
          </div>
        )}

        {/* Action Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-xl font-bold text-slate-900 tracking-tight">Daftar Template</h2>
            <p className="text-xs text-slate-500 mt-0.5">
              Setiap template menentukan tampilan menu, modul, custom roles, dan kuota saat bisnis mendaftar
            </p>
          </div>

          <button
            onClick={openCreateModal}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-500 text-white font-bold text-sm shadow-md shadow-orange-500/20 transition-all"
          >
            <Plus className="w-4 h-4" />
            Tambah Template Baru
          </button>
        </div>

        {/* Templates Grid */}
        {loading ? (
          <div className="text-center py-20">
            <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-sm text-slate-500">Memuat data template bisnis...</p>
          </div>
        ) : templates.length === 0 ? (
          <div className="bg-white rounded-2xl p-12 text-center border border-slate-200 shadow-sm">
            <Layers className="w-12 h-12 text-slate-400 mx-auto mb-3" />
            <h3 className="text-lg font-bold text-slate-800">Belum Ada Template</h3>
            <p className="text-sm text-slate-500 mt-1 max-w-sm mx-auto">
              Silakan buat template pertama (misal: Cafe & Resto, Retail Modern, atau Bengkel / Servis)
            </p>
            <button
              onClick={openCreateModal}
              className="mt-4 px-4 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-sm font-bold shadow-xs"
            >
              Tambah Template Sekarang
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {templates.map((tpl) => {
              const IconComponent = getTemplateIcon(tpl.icon_name);
              const freeLimits = tpl.limits_config?.free || {
                max_outlets: tpl.max_outlets ?? 1,
                max_products: tpl.max_products ?? 50,
                max_transactions: tpl.max_transactions ?? 100,
              };
              const proLimits = tpl.limits_config?.pro || {
                max_outlets: 5,
                max_products: 99999,
                max_transactions: 99999,
              };
              const roleLabels = tpl.role_labels || {};
              const hasCustomRoles = Object.values(roleLabels).some((val) => !!val?.trim());

              // Feature counts
              const featConfig = tpl.features_config || {};
              const freeFeatures: string[] = [];
              const proFeatures: string[] = [];

              AVAILABLE_FEATURES.forEach((f) => {
                const tier = featConfig[f.id] || (f.id === 'cash_flow' ? 'pro' : tpl.default_enabled_features?.includes(f.id) ? 'free' : 'off');
                if (tier === 'free') freeFeatures.push(f.label);
                if (tier === 'pro') proFeatures.push(f.label);
              });

              return (
                <div
                  key={tpl.id}
                  className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm hover:border-slate-300 transition-all flex flex-col justify-between"
                >
                  <div className="space-y-4">
                    {/* Top: Icon + Code + Actions */}
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-orange-50 border border-orange-200 text-orange-600 flex items-center justify-center font-bold">
                          <IconComponent className="w-6 h-6" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <h3 className="font-bold text-slate-900 text-base">{tpl.name}</h3>
                            <span className="font-mono text-[11px] font-semibold text-orange-700 bg-orange-100 border border-orange-200 px-2 py-0.5 rounded-full">
                              {tpl.code}
                            </span>
                          </div>
                          <p className="text-xs text-slate-500 mt-1 line-clamp-2">
                            {tpl.description || 'Tidak ada deskripsi.'}
                          </p>
                        </div>
                      </div>

                      <div className="flex items-center gap-1.5 flex-shrink-0">
                        <button
                          onClick={() => openEditModal(tpl)}
                          className="p-2 rounded-lg bg-slate-100 hover:bg-orange-50 hover:text-orange-600 text-slate-600 transition-colors"
                          title="Edit Template"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(tpl)}
                          className="p-2 rounded-lg bg-slate-100 hover:bg-red-50 hover:text-red-600 text-slate-600 transition-colors"
                          title="Hapus Template"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    {/* Custom Role Labels Chip */}
                    {hasCustomRoles && (
                      <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs">
                        <div className="flex items-center gap-1.5 font-bold text-slate-700 mb-1.5">
                          <Users className="w-3.5 h-3.5 text-orange-600" />
                          <span>Custom Role Labels:</span>
                        </div>
                        <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[11px] text-slate-600">
                          {roleLabels.waiter && (
                            <div>
                              <span className="text-slate-400">Waiter:</span>{' '}
                              <strong className="text-slate-900">{roleLabels.waiter}</strong>
                            </div>
                          )}
                          {roleLabels.kitchen && (
                            <div>
                              <span className="text-slate-400">Kitchen:</span>{' '}
                              <strong className="text-slate-900">{roleLabels.kitchen}</strong>
                            </div>
                          )}
                          {roleLabels.cashier && (
                            <div>
                              <span className="text-slate-400">Cashier:</span>{' '}
                              <strong className="text-slate-900">{roleLabels.cashier}</strong>
                            </div>
                          )}
                          {roleLabels.admin && (
                            <div>
                              <span className="text-slate-400">Admin:</span>{' '}
                              <strong className="text-slate-900">{roleLabels.admin}</strong>
                            </div>
                          )}
                        </div>
                      </div>
                    )}

                    {/* Limits Dual-Grid (Free vs Pro) */}
                    <div className="grid grid-cols-2 gap-3 text-xs">
                      <div className="p-3 rounded-xl bg-blue-50/70 border border-blue-100">
                        <div className="flex items-center gap-1.5 font-bold text-blue-900 text-[11px] mb-1">
                          <span className="w-1.5 h-1.5 rounded-full bg-blue-600"></span>
                          LIMIT FREE
                        </div>
                        <div className="text-[11px] text-blue-800 space-y-0.5 font-medium">
                          <div>Outlet: <strong>{freeLimits.max_outlets ?? 1}</strong></div>
                          <div>Produk: <strong>{freeLimits.max_products ?? 50}</strong></div>
                          <div>Tx/bln: <strong>{freeLimits.max_transactions ?? 100}</strong></div>
                        </div>
                      </div>

                      <div className="p-3 rounded-xl bg-amber-50/70 border border-amber-100">
                        <div className="flex items-center gap-1.5 font-bold text-amber-900 text-[11px] mb-1">
                          <Crown className="w-3 h-3 text-amber-600" />
                          LIMIT PRO
                        </div>
                        <div className="text-[11px] text-amber-800 space-y-0.5 font-medium">
                          <div>Outlet: <strong>{proLimits.max_outlets ?? 5}</strong></div>
                          <div>Produk: <strong>{proLimits.max_products ?? 99999}</strong></div>
                          <div>Tx/bln: <strong>{proLimits.max_transactions ?? 99999}</strong></div>
                        </div>
                      </div>
                    </div>

                    {/* Features Badges (FREE vs PRO) */}
                    <div className="space-y-2">
                      <div className="text-xs font-bold text-slate-500 flex items-center justify-between">
                        <span>Modul Terkonfigurasi:</span>
                        <span className="text-[11px]">
                          {freeFeatures.length} Free • {proFeatures.length} Pro
                        </span>
                      </div>

                      <div className="flex flex-wrap gap-1.5">
                        {freeFeatures.map((name) => (
                          <span
                            key={name}
                            className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-semibold bg-emerald-50 border border-emerald-200 text-emerald-800"
                          >
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                            {name}
                          </span>
                        ))}
                        {proFeatures.map((name) => (
                          <span
                            key={name}
                            className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-semibold bg-amber-50 border border-amber-200 text-amber-800"
                          >
                            <Crown className="w-2.5 h-2.5 text-amber-600" />
                            {name}
                          </span>
                        ))}
                        {freeFeatures.length === 0 && proFeatures.length === 0 && (
                          <span className="text-xs text-slate-400 italic">
                            Semua fitur dalam posisi OFF.
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="mt-5 pt-4 border-t border-slate-100 flex items-center justify-between text-xs text-slate-400">
                    <span>Icon: {tpl.icon_name || 'restaurant_rounded'}</span>
                    <span>{tpl.show_ads ? 'Iklan Aktif' : 'Bebas Iklan'}</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Modal Create / Edit */}
        {modalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs overflow-y-auto">
            <div className="bg-white w-full max-w-3xl rounded-2xl p-6 sm:p-8 border border-slate-200 shadow-2xl relative my-8 max-h-[90vh] flex flex-col">
              {/* Header */}
              <div className="flex items-center justify-between pb-4 border-b border-slate-100 flex-shrink-0">
                <div className="flex items-center gap-2.5">
                  <div className="w-10 h-10 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center font-bold">
                    <Settings2 className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base sm:text-lg">
                      {editingTemplate ? 'Edit Template Bisnis' : 'Tambah Template Bisnis Baru'}
                    </h3>
                    <p className="text-xs text-slate-500">
                      Konfigurasikan informasi dasar, custom roles, kuota limits, dan tiering fitur
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setModalOpen(false)}
                  className="p-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {errorMsg && (
                <div className="mt-4 p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 text-sm flex items-center gap-2 flex-shrink-0">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{errorMsg}</span>
                </div>
              )}

              {/* Scrollable Form Body */}
              <form onSubmit={handleSave} className="mt-5 space-y-6 overflow-y-auto pr-1 flex-1">
                {/* 1. Basic Info */}
                <div className="space-y-4">
                  <div className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-2">
                    <Boxes className="w-4 h-4 text-orange-600" />
                    Informasi Dasar
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-bold text-slate-700 mb-1.5">
                        Nama Template
                      </label>
                      <input
                        type="text"
                        required
                        placeholder="Contoh: Cafe & Resto, Retail Modern"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                      />
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-slate-700 mb-1.5">
                        Kode Unik (Slug)
                      </label>
                      <input
                        type="text"
                        required
                        placeholder="Contoh: cafe_resto"
                        value={formData.code}
                        onChange={(e) => setFormData({ ...formData, code: e.target.value })}
                        disabled={!!editingTemplate}
                        className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 disabled:bg-slate-100 disabled:text-slate-500 shadow-xs"
                      />
                      <span className="text-[10px] text-slate-400 mt-1 block">
                        Kebab-case atau snake-case unik untuk sistem
                      </span>
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1.5">
                      Deskripsi Singkat
                    </label>
                    <textarea
                      rows={2}
                      placeholder="Penjelasan sasaran bisnis untuk template ini..."
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      className="w-full px-3.5 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                    />
                  </div>
                </div>

                {/* 2. Visual Icon Selector */}
                <div className="space-y-3">
                  <div className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-orange-600" />
                    Pilihan Ikon Template (Onboarding Mobile)
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
                    {AVAILABLE_ICONS.map((item) => {
                      const ItemIcon = item.icon;
                      const isSelected = formData.icon_name === item.id;
                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => setFormData({ ...formData, icon_name: item.id })}
                          className={`p-3 rounded-xl border flex items-center gap-2.5 transition-all text-left ${
                            isSelected
                              ? 'bg-orange-50 border-orange-500 text-orange-700 ring-2 ring-orange-500/20'
                              : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                          }`}
                        >
                          <ItemIcon className="w-4 h-4 flex-shrink-0" />
                          <span className="text-xs font-bold truncate">{item.label}</span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* 3. Custom Role Labels (Matching User's Mobile Screen) */}
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                  <div className="flex items-center gap-2">
                    <Users className="w-4 h-4 text-orange-600" />
                    <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
                      Custom Role Labels
                    </span>
                  </div>
                  <p className="text-xs text-slate-500">
                    Ganti nama peran agar sesuai dengan bisnis jasa/showroom (misal: Waiter diubah menjadi Sales/Marketer, Kitchen diubah menjadi Teknisi/Mekanik).
                  </p>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Waiter (e.g. Sales / Marketer)
                      </label>
                      <input
                        type="text"
                        placeholder="Waiter"
                        value={formData.role_waiter}
                        onChange={(e) => setFormData({ ...formData, role_waiter: e.target.value })}
                        className="w-full px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Kitchen (e.g. Teknisi / Mekanik)
                      </label>
                      <input
                        type="text"
                        placeholder="Kitchen"
                        value={formData.role_kitchen}
                        onChange={(e) => setFormData({ ...formData, role_kitchen: e.target.value })}
                        className="w-full px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Cashier (e.g. Finance)
                      </label>
                      <input
                        type="text"
                        placeholder="Cashier"
                        value={formData.role_cashier}
                        onChange={(e) => setFormData({ ...formData, role_cashier: e.target.value })}
                        className="w-full px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Admin (e.g. Supervisor)
                      </label>
                      <input
                        type="text"
                        placeholder="Admin"
                        value={formData.role_admin}
                        onChange={(e) => setFormData({ ...formData, role_admin: e.target.value })}
                        className="w-full px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                      />
                    </div>
                  </div>
                </div>

                {/* 4. Limits Config (Free vs Pro) */}
                <div className="space-y-3">
                  <div className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-2">
                    <SlidersHorizontal className="w-4 h-4 text-orange-600" />
                    Batasan Sistem (Limits Free vs Pro)
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* FREE LIMITS */}
                    <div className="p-4 rounded-2xl bg-blue-50/60 border border-blue-200/80 space-y-3">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-blue-600"></span>
                        <span className="text-xs font-extrabold text-blue-900 uppercase tracking-wider">
                          Limit Paket Free
                        </span>
                      </div>
                      <div className="grid grid-cols-3 gap-2">
                        <div>
                          <label className="block text-[10px] font-bold text-blue-900 mb-1">Maks Outlet</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.free_max_outlets}
                            onChange={(e) =>
                              setFormData({ ...formData, free_max_outlets: parseInt(e.target.value) || 1 })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-blue-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-blue-900 mb-1">Maks Produk</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.free_max_products}
                            onChange={(e) =>
                              setFormData({ ...formData, free_max_products: parseInt(e.target.value) || 50 })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-blue-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-blue-900 mb-1">Maks Tx/Bln</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.free_max_transactions}
                            onChange={(e) =>
                              setFormData({
                                ...formData,
                                free_max_transactions: parseInt(e.target.value) || 100,
                              })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-blue-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                      </div>
                    </div>

                    {/* PRO LIMITS */}
                    <div className="p-4 rounded-2xl bg-amber-50/60 border border-amber-200/80 space-y-3">
                      <div className="flex items-center gap-2">
                        <Crown className="w-3.5 h-3.5 text-amber-600" />
                        <span className="text-xs font-extrabold text-amber-900 uppercase tracking-wider">
                          Limit Paket Pro
                        </span>
                      </div>
                      <div className="grid grid-cols-3 gap-2">
                        <div>
                          <label className="block text-[10px] font-bold text-amber-900 mb-1">Maks Outlet</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.pro_max_outlets}
                            onChange={(e) =>
                              setFormData({ ...formData, pro_max_outlets: parseInt(e.target.value) || 5 })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-amber-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-amber-900 mb-1">Maks Produk</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.pro_max_products}
                            onChange={(e) =>
                              setFormData({ ...formData, pro_max_products: parseInt(e.target.value) || 99999 })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-amber-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-amber-900 mb-1">Maks Tx/Bln</label>
                          <input
                            type="number"
                            min={1}
                            value={formData.pro_max_transactions}
                            onChange={(e) =>
                              setFormData({
                                ...formData,
                                pro_max_transactions: parseInt(e.target.value) || 99999,
                              })
                            }
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-amber-200 text-slate-900 text-xs font-bold shadow-xs"
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* 5. Konfigurasi Fitur & Tiering (Matching User's Mobile Screen) */}
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                    <div>
                      <div className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-2">
                        <Sparkles className="w-4 h-4 text-orange-600" />
                        Konfigurasi Fitur & Tiering
                      </div>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        Pilih status modul: nonaktif (OFF), gratis untuk semua (FREE), atau khusus PRO.
                      </p>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => setAllFeatures('free')}
                        className="px-2.5 py-1 text-[11px] font-bold rounded-lg bg-emerald-100 text-emerald-800 hover:bg-emerald-200 transition-colors"
                      >
                        Semua FREE
                      </button>
                      <button
                        type="button"
                        onClick={() => setAllFeatures('pro')}
                        className="px-2.5 py-1 text-[11px] font-bold rounded-lg bg-amber-100 text-amber-800 hover:bg-amber-200 transition-colors"
                      >
                        Semua PRO
                      </button>
                      <button
                        type="button"
                        onClick={() => setAllFeatures('off')}
                        className="px-2.5 py-1 text-[11px] font-bold rounded-lg bg-slate-200 text-slate-700 hover:bg-slate-300 transition-colors"
                      >
                        Reset OFF
                      </button>
                    </div>
                  </div>

                  <div className="divide-y divide-slate-200/80 bg-white rounded-xl border border-slate-200 max-h-80 overflow-y-auto">
                    {AVAILABLE_FEATURES.map((feat) => {
                      const currentVal = formData.features_config[feat.id] || 'off';
                      const FeatIcon = feat.icon;
                      return (
                        <div
                          key={feat.id}
                          className="p-3.5 flex items-center justify-between gap-3 hover:bg-slate-50/50 transition-colors"
                        >
                          <div className="flex items-center gap-3">
                            <div
                              className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-colors ${
                                currentVal === 'pro'
                                  ? 'bg-amber-50 text-amber-600 border border-amber-200'
                                  : currentVal === 'free'
                                  ? 'bg-emerald-50 text-emerald-600 border border-emerald-200'
                                  : 'bg-slate-100 text-slate-400'
                              }`}
                            >
                              <FeatIcon className="w-4 h-4" />
                            </div>
                            <div>
                              <div className="text-xs font-bold text-slate-900">{feat.label}</div>
                              <div className="text-[11px] text-slate-500">{feat.desc}</div>
                            </div>
                          </div>

                          <div className="inline-flex items-center p-1 rounded-xl bg-slate-100 border border-slate-200 flex-shrink-0">
                            <button
                              type="button"
                              onClick={() => setFeatureTier(feat.id, 'off')}
                              className={`px-3 py-1 rounded-lg text-[11px] font-bold transition-all ${
                                currentVal === 'off'
                                  ? 'bg-slate-700 text-white shadow-xs'
                                  : 'text-slate-500 hover:text-slate-900'
                              }`}
                            >
                              OFF
                            </button>
                            <button
                              type="button"
                              onClick={() => setFeatureTier(feat.id, 'free')}
                              className={`px-3 py-1 rounded-lg text-[11px] font-bold transition-all ${
                                currentVal === 'free'
                                  ? 'bg-emerald-600 text-white shadow-xs'
                                  : 'text-slate-500 hover:text-slate-900'
                              }`}
                            >
                              FREE
                            </button>
                            <button
                              type="button"
                              onClick={() => setFeatureTier(feat.id, 'pro')}
                              className={`px-3 py-1 rounded-lg text-[11px] font-bold transition-all ${
                                currentVal === 'pro'
                                  ? 'bg-amber-500 text-white shadow-xs'
                                  : 'text-slate-500 hover:text-slate-900'
                              }`}
                            >
                              PRO
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Footer Buttons */}
                <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3 flex-shrink-0">
                  <button
                    type="button"
                    onClick={() => setModalOpen(false)}
                    className="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    disabled={isSaving}
                    className="px-5 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold shadow-md shadow-orange-500/20 disabled:opacity-50"
                  >
                    {isSaving ? 'Menyimpan...' : editingTemplate ? 'Perbarui Template' : 'Simpan Template'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
