'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { SubscriptionPlan } from '@/types/database';
import {
  Crown,
  CheckCircle2,
  AlertCircle,
  Save,
  RotateCcw,
  Sparkles,
  Smartphone,
  Store,
  Flame,
  Plus,
  Trash2,
  Eye,
  EyeOff,
  Tag,
  Clock,
  X,
  HelpCircle,
} from 'lucide-react';

export interface PricingTierItem {
  id: string;
  code: string;
  name: string;
  months: number;
  is_lifetime: boolean;
  price: number;
  original_price?: number | null; // Harga Asli / Coret (Anchor Pricing)
  is_active: boolean; // TRUE = Tampil di Aplikasi, FALSE = Disembunyikan (Hide)
  badge?: string | null;
  subtitle?: string | null;
}

const DEFAULT_TIERS: PricingTierItem[] = [
  {
    id: '1_month',
    code: '1_month',
    name: '1 Bulan (Bulanan Dasar)',
    months: 1,
    is_lifetime: false,
    price: 49000,
    original_price: null,
    is_active: true,
    subtitle: '/bulan',
  },
  {
    id: '3_months',
    code: '3_months',
    name: '3 Bulan',
    months: 3,
    is_lifetime: false,
    price: 129000,
    original_price: 147000,
    is_active: true,
    subtitle: '/3 bulan',
  },
  {
    id: '6_months',
    code: '6_months',
    name: '6 Bulan',
    months: 6,
    is_lifetime: false,
    price: 239000,
    original_price: 294000,
    is_active: true,
    subtitle: '/6 bulan',
  },
  {
    id: '12_months',
    code: '12_months',
    name: '1 Tahun (12 Bulan)',
    months: 12,
    is_lifetime: false,
    price: 399000,
    original_price: 588000,
    is_active: true,
    subtitle: '/tahun',
  },
  {
    id: 'lifetime',
    code: 'lifetime',
    name: 'Paket Pro Lifetime (Seumur Hidup)',
    months: 0,
    is_lifetime: true,
    price: 799000,
    original_price: 1499000,
    is_active: true,
    badge: 'BEST VALUE 👑',
    subtitle: 'sekali bayar selamanya',
  },
];

export default function PricingPage() {
  const [loading, setLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Daftar Paket Durasi Pro (Dinamis & bisa di-Hide/Show)
  const [tiers, setTiers] = useState<PricingTierItem[]>(DEFAULT_TIERS);

  // Kuota Standar Paket Pro
  const [proMaxOutlets, setProMaxOutlets] = useState(5);
  const [proMaxProducts, setProMaxProducts] = useState(999999);
  const [proMaxTransactions, setProMaxTransactions] = useState(999999);

  // Kuota Standar Paket Free
  const [freeMaxOutlets, setFreeMaxOutlets] = useState(1);
  const [freeMaxProducts, setFreeMaxProducts] = useState(50);
  const [freeMaxTransactions, setFreeMaxTransactions] = useState(150);

  // Modal Tambah Paket Baru
  const [showAddModal, setShowAddModal] = useState(false);
  const [newTierName, setNewTierName] = useState('');
  const [newTierMonths, setNewTierMonths] = useState(2);
  const [newTierIsLifetime, setNewTierIsLifetime] = useState(false);
  const [newTierPrice, setNewTierPrice] = useState(89000);
  const [newTierOriginalPrice, setNewTierOriginalPrice] = useState<number | null>(null);
  const [newTierBadge, setNewTierBadge] = useState('');

  const supabase = createClient();

  const loadPlans = async () => {
    setLoading(true);
    setErrorMsg(null);

    const { data, error } = await supabase
      .from('subscription_plans')
      .select('*')
      .order('price_monthly', { ascending: true });

    if (error) {
      setErrorMsg(`Gagal memuat paket: ${error.message}`);
    } else if (data && data.length > 0) {
      const proPlan = data.find((p) => p.code === 'pro');
      const freePlan = data.find((p) => p.code === 'free');

      const rawTiersObj = proPlan?.pricing_tiers || {};

      // 1. Cek apakah ada list 'tiers' dinamis di JSONB
      if (Array.isArray(rawTiersObj.tiers) && rawTiersObj.tiers.length > 0) {
        setTiers(
          (rawTiersObj.tiers as any[]).map((t) => {
            let origPrice = t.original_price != null ? Number(t.original_price) : null;
            if (origPrice === null) {
              if (t.months === 3) origPrice = 147000;
              else if (t.months === 6) origPrice = 294000;
              else if (t.months === 12) origPrice = 588000;
              else if (t.is_lifetime || t.code === 'lifetime') origPrice = 1499000;
            }
            return {
              ...t,
              price: Number(t.price) || 0,
              original_price: origPrice,
            } as PricingTierItem;
          })
        );
      } else {
        // Fallback untuk backward compatibility jika masih format flat lama
        const visibility = (rawTiersObj.visibility as Record<string, boolean>) || {};
        const isLifetimeActive =
          visibility['lifetime'] ?? (rawTiersObj['lifetime_active'] !== false);

        setTiers([
          {
            id: '1_month',
            code: '1_month',
            name: '1 Bulan (Bulanan Dasar)',
            months: 1,
            is_lifetime: false,
            price: Number(rawTiersObj['1_month'] ?? proPlan?.price_monthly ?? 49000),
            original_price: null,
            is_active: visibility['1_month'] ?? true,
            subtitle: '/bulan',
          },
          {
            id: '3_months',
            code: '3_months',
            name: '3 Bulan',
            months: 3,
            is_lifetime: false,
            price: Number(rawTiersObj['3_months'] ?? 129000),
            original_price: 147000,
            is_active: visibility['3_months'] ?? true,
            subtitle: '/3 bulan',
          },
          {
            id: '6_months',
            code: '6_months',
            name: '6 Bulan',
            months: 6,
            is_lifetime: false,
            price: Number(rawTiersObj['6_months'] ?? 239000),
            original_price: 294000,
            is_active: visibility['6_months'] ?? true,
            subtitle: '/6 bulan',
          },
          {
            id: '12_months',
            code: '12_months',
            name: '1 Tahun (12 Bulan)',
            months: 12,
            is_lifetime: false,
            price: Number(rawTiersObj['12_months'] ?? 399000),
            original_price: 588000,
            is_active: visibility['12_months'] ?? true,
            subtitle: '/tahun',
          },
          {
            id: 'lifetime',
            code: 'lifetime',
            name: 'Paket Pro Lifetime (Seumur Hidup)',
            months: 0,
            is_lifetime: true,
            price: Number(rawTiersObj['lifetime'] ?? 799000),
            original_price: 1499000,
            is_active: isLifetimeActive,
            badge: 'BEST VALUE 👑',
            subtitle: 'sekali bayar selamanya',
          },
        ]);
      }

      // Set Kuota
      setProMaxOutlets(proPlan?.max_outlets ?? 5);
      setProMaxProducts(proPlan?.max_products ?? 999999);
      setProMaxTransactions(proPlan?.max_transactions_month ?? 999999);

      setFreeMaxOutlets(freePlan?.max_outlets ?? 1);
      setFreeMaxProducts(freePlan?.max_products ?? 50);
      setFreeMaxTransactions(freePlan?.max_transactions_month ?? 150);
    }
    setLoading(false);
  };

  useEffect(() => {
    loadPlans();
  }, []);

  const formatIDR = (val: number) => {
    const num = Math.round(Number(val) || 0);
    return `Rp ${num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
  };

  const formatPriceInput = (val: number | null | undefined) => {
    if (!val || val === 0) return '';
    return val.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  };

  // Toggle Tampilkan / Sembunyikan Paket
  const handleToggleTierActive = (id: string) => {
    setTiers((prev) =>
      prev.map((t) => (t.id === id ? { ...t, is_active: !t.is_active } : t))
    );
  };

  // Update Harga Tier
  const handleTierPriceChange = (id: string, rawValue: string) => {
    const cleanDigits = rawValue.replace(/\D/g, '');
    const trimmed = cleanDigits.replace(/^0+/, '');
    const num = trimmed === '' ? 0 : parseInt(trimmed, 10);

    setTiers((prev) =>
      prev.map((t) => (t.id === id ? { ...t, price: num } : t))
    );
  };

  // Update Harga Coret / Asli (Anchor IDR)
  const handleTierOriginalPriceChange = (id: string, rawValue: string) => {
    const cleanDigits = rawValue.replace(/\D/g, '');
    const trimmed = cleanDigits.replace(/^0+/, '');
    const num = trimmed === '' ? null : parseInt(trimmed, 10);

    setTiers((prev) =>
      prev.map((t) => (t.id === id ? { ...t, original_price: num } : t))
    );
  };

  // Update Badge Kustom Tier
  const handleTierBadgeChange = (id: string, badge: string) => {
    setTiers((prev) =>
      prev.map((t) => (t.id === id ? { ...t, badge: badge.trim() === '' ? null : badge } : t))
    );
  };

  // Hapus Tier Kustom
  const handleDeleteTier = (id: string) => {
    if (confirm('Yakin ingin menghapus paket durasi ini?')) {
      setTiers((prev) => prev.filter((t) => t.id !== id));
    }
  };

  // Tambah Tier Baru
  const handleCreateNewTier = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTierName.trim()) {
      alert('Nama paket wajib diisi.');
      return;
    }

    const code = newTierIsLifetime
      ? `lifetime_${Date.now()}`
      : `${newTierMonths}_months_${Date.now().toString().slice(-4)}`;

    const newTier: PricingTierItem = {
      id: `custom_${Date.now()}`,
      code: code,
      name: newTierName.trim(),
      months: newTierIsLifetime ? 0 : Number(newTierMonths),
      is_lifetime: newTierIsLifetime,
      price: Number(newTierPrice) || 0,
      original_price:
        newTierOriginalPrice && newTierOriginalPrice > 0
          ? Number(newTierOriginalPrice)
          : null,
      is_active: true,
      badge: newTierBadge.trim() ? newTierBadge.trim() : null,
      subtitle: newTierIsLifetime ? 'sekali bayar selamanya' : `/${newTierMonths} bulan`,
    };

    setTiers((prev) => [...prev, newTier]);
    setShowAddModal(false);
    setNewTierName('');
    setNewTierMonths(2);
    setNewTierIsLifetime(false);
    setNewTierPrice(89000);
    setNewTierOriginalPrice(null);
    setNewTierBadge('');
  };

  // Hitung hemat persen dibanding harga 1 bulan
  const baseMonthlyTier = tiers.find((t) => t.code === '1_month' || t.months === 1);
  const basePrice = baseMonthlyTier?.price || 49000;

  const calcSavings = (price: number, months: number) => {
    if (!basePrice || basePrice <= 0 || !months || months <= 1) return 0;
    const standardCost = basePrice * months;
    const savings = Math.round(((standardCost - price) / standardCost) * 100);
    return savings > 0 ? savings : 0;
  };

  const handleQuotaChange = (
    setter: React.Dispatch<React.SetStateAction<number>>,
    rawValue: string
  ) => {
    const cleanDigits = rawValue.replace(/\D/g, '');
    const trimmed = cleanDigits.replace(/^0+/, '');
    const num = trimmed === '' ? 0 : parseInt(trimmed, 10);
    setter(num);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setErrorMsg(null);
    setSuccessMsg(null);

    try {
      // 1. Susun payload pricing_tiers yang kaya dan backward-compatible
      const visibilityMap: Record<string, boolean> = {};
      const flatPricesMap: Record<string, number> = {};

      tiers.forEach((t) => {
        visibilityMap[t.code] = t.is_active;
        flatPricesMap[t.code] = Number(t.price);
      });

      // Cek status khusus lifetime untuk helper query
      const lifetimeTier = tiers.find((t) => t.is_lifetime || t.code === 'lifetime');
      const isLifetimeActive = lifetimeTier ? lifetimeTier.is_active : false;

      const pricingTiersPayload = {
        tiers: tiers,
        visibility: visibilityMap,
        lifetime_active: isLifetimeActive,
        ...flatPricesMap,
      };

      const proFeatures = {
        cash_flow: true,
        tiered_pricing: true,
        qr_ordering: true,
        kds: true,
        table_management: true,
        advanced_reports: true,
        inventory_management: true,
        barcode_scanner: true,
        realtime_notifications: true,
      };

      const freeFeatures = {
        cash_flow: false,
        tiered_pricing: false,
        qr_ordering: false,
        kds: false,
        table_management: false,
        advanced_reports: false,
        inventory_management: false,
        barcode_scanner: true,
        realtime_notifications: false,
      };

      // 2. Simpan Paket Free
      const { error: freeError } = await supabase.from('subscription_plans').upsert(
        {
          name: 'Free Plan',
          code: 'free',
          price_monthly: 0,
          pricing_tiers: {},
          max_outlets: Number(freeMaxOutlets),
          max_products: Number(freeMaxProducts),
          max_transactions_month: Number(freeMaxTransactions),
          features: freeFeatures,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'code' }
      );

      if (freeError) throw freeError;

      // 3. Simpan Paket Pro
      const primaryMonthlyPrice = basePrice > 0 ? basePrice : 49000;

      const { error: proError } = await supabase.from('subscription_plans').upsert(
        {
          name: 'Pro Plan',
          code: 'pro',
          price_monthly: primaryMonthlyPrice,
          pricing_tiers: pricingTiersPayload,
          max_outlets: Number(proMaxOutlets),
          max_products: Number(proMaxProducts),
          max_transactions_month: Number(proMaxTransactions),
          features: proFeatures,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'code' }
      );

      if (proError) throw proError;

      setSuccessMsg(
        'Pengaturan paket, harga, dan visibilitas berhasil disimpan! Perubahan langsung aktif di aplikasi Android & Web.'
      );
      await loadPlans();
    } catch (err: any) {
      console.error(err);
      setErrorMsg(err.message || 'Terjadi kesalahan saat menyimpan data paket.');
    } finally {
      setIsSaving(false);
    }
  };

  // Daftar paket aktif untuk live mobile preview
  const activeTiers = tiers.filter((t) => t.is_active);
  const activeLifetime = activeTiers.find((t) => t.is_lifetime || t.code === 'lifetime');
  const previewHeadlineTier = activeLifetime || activeTiers[activeTiers.length - 1] || tiers[0];

  return (
    <div className="space-y-6 max-w-6xl pb-16">
      <Navbar
        title="Paket & Harga Langganan"
        description="Atur harga paket Pro, kelola visibilitas (tampilkan atau sembunyikan paket seperti Lifetime), serta tambah/kurang paket langganan secara dinamis."
      />

      {/* Alert Messages */}
      {successMsg && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 flex items-center gap-3">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0 text-emerald-600" />
          <div className="text-sm font-semibold">{successMsg}</div>
        </div>
      )}

      {errorMsg && (
        <div className="p-4 rounded-xl bg-red-50 border border-red-200 text-red-800 flex items-center gap-3">
          <AlertCircle className="w-5 h-5 flex-shrink-0 text-red-600" />
          <div className="text-sm font-semibold">{errorMsg}</div>
        </div>
      )}

      {/* Info Banner in Syupeo Palette */}
      <div className="p-4 rounded-[12px] bg-[#eff6ff] border border-[#bfdbfe] flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-[8px] bg-[#0070fc] text-white flex items-center justify-center font-bold">
            <Crown className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-sm font-bold text-slate-900">Kendali Penuh Visibilitas & Harga</h4>
            <p className="text-xs text-slate-600">
              Paket yang Anda sembunyikan (toggle OFF) otomatis tidak akan muncul di layar langganan aplikasi kasir Android.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={loadPlans}
            disabled={loading}
            className="px-3.5 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 hover:text-slate-900 text-xs font-bold flex items-center gap-2 transition-colors disabled:opacity-50 shadow-xs"
          >
            <RotateCcw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Muat Ulang
          </button>
        </div>
      </div>

      <form onSubmit={handleSave} className="space-y-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Kolom Kiri & Tengah: Form Setting Harga & Paket Dinamis */}
          <div className="lg:col-span-2 space-y-6">
            {/* CARD 1: PAKET PRO & DAFTAR DURASI */}
            <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden">
              <div className="flex items-center justify-between pb-5 border-b border-slate-100">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-500 to-amber-400 p-0.5 shadow-md shadow-orange-500/20 flex items-center justify-center">
                    <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center">
                      <Crown className="w-5 h-5 text-orange-600" />
                    </div>
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base flex items-center gap-2">
                      Paket Pro (Pilihan Durasi & Harga)
                      <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800 border border-amber-200">
                        PREMIUM
                      </span>
                    </h3>
                    <p className="text-xs text-slate-500">
                      Atur harga, sembunyikan/tampilkan paket, atau tambah paket baru
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => setShowAddModal(true)}
                  className="px-3 py-1.5 rounded-xl bg-orange-50 border border-orange-200 text-orange-700 hover:bg-orange-100 text-xs font-bold flex items-center gap-1.5 transition-colors shadow-2xs"
                >
                  <Plus className="w-3.5 h-3.5" />
                  Tambah Paket Baru
                </button>
              </div>

              {/* List Paket Durasi */}
              <div className="mt-6 space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5 text-orange-500" />
                    Daftar Tingkatan Durasi Langganan ({tiers.length} Paket)
                  </h4>
                  <span className="text-[11px] text-slate-500">
                    🟢 {activeTiers.length} Aktif di App • ⚪ {tiers.length - activeTiers.length} Disembunyikan
                  </span>
                </div>

                <div className="space-y-3">
                  {tiers.map((tier) => {
                    const isBaseTier = tier.code === '1_month';
                    const isLifetime = tier.is_lifetime || tier.code === 'lifetime';
                    const savings = calcSavings(tier.price, tier.months);
                    const hasDiscount =
                      tier.original_price != null && tier.original_price > tier.price;
                    const discountPct = hasDiscount
                      ? Math.round(
                          ((tier.original_price! - tier.price) / tier.original_price!) * 100
                        )
                      : 0;

                    return (
                      <div
                        key={tier.id}
                        className={`p-4 rounded-xl border transition-all ${
                          !tier.is_active
                            ? 'bg-slate-50/80 border-slate-200 opacity-70'
                            : isLifetime
                            ? 'bg-gradient-to-r from-amber-50/70 to-orange-50/50 border-amber-300 shadow-2xs'
                            : 'bg-white border-slate-200 shadow-2xs'
                        }`}
                      >
                        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
                          <div className="flex items-center flex-wrap gap-2">
                            {isLifetime ? (
                              <Crown className="w-4 h-4 text-amber-600 flex-shrink-0" />
                            ) : (
                              <Clock className="w-4 h-4 text-slate-400 flex-shrink-0" />
                            )}
                            <span className="text-xs font-bold text-slate-900">
                              {tier.name}
                            </span>
                            {tier.is_lifetime && (
                              <span className="px-1.5 py-0.5 rounded text-[9px] font-black bg-amber-500 text-white uppercase shadow-2xs">
                                SEUMUR HIDUP
                              </span>
                            )}
                            {hasDiscount && (
                              <span className="px-1.5 py-0.5 rounded text-[10px] font-black bg-rose-100 text-rose-700 border border-rose-200">
                                Diskon {discountPct}% (Harga Coret Aktif)
                              </span>
                            )}
                            {!isLifetime && !hasDiscount && savings > 0 && (
                              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-100 text-emerald-800 border border-emerald-200">
                                Hemat {savings}%
                              </span>
                            )}
                          </div>

                          {/* Toggle Sakelar Tampilkan / Sembunyikan */}
                          <div className="flex items-center gap-2">
                            <button
                              type="button"
                              onClick={() => handleToggleTierActive(tier.id)}
                              className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold transition-all shadow-2xs ${
                                tier.is_active
                                  ? 'bg-emerald-100 text-emerald-800 border border-emerald-300 hover:bg-emerald-200'
                                  : 'bg-slate-200 text-slate-600 border border-slate-300 hover:bg-slate-300'
                              }`}
                            >
                              {tier.is_active ? (
                                <>
                                  <Eye className="w-3.5 h-3.5 text-emerald-700" />
                                  <span>Tampil di App</span>
                                </>
                              ) : (
                                <>
                                  <EyeOff className="w-3.5 h-3.5 text-slate-500" />
                                  <span>Disembunyikan (Hide)</span>
                                </>
                              )}
                            </button>

                            {/* Tombol Hapus untuk paket kustom */}
                            {!isBaseTier && tier.code !== 'lifetime' && (
                              <button
                                type="button"
                                onClick={() => handleDeleteTier(tier.id)}
                                className="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                                title="Hapus Paket"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            )}
                          </div>
                        </div>

                        {/* Input Harga, Harga Coret & Badge */}
                        <div className="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3 items-start">
                          <div>
                            <label className="block text-[10px] font-bold text-slate-500 mb-1">
                              Harga Langganan (IDR)
                            </label>
                            <div className="relative">
                              <span className="absolute left-3 top-2 text-xs text-slate-400 font-bold">
                                Rp
                              </span>
                              <input
                                type="text"
                                inputMode="numeric"
                                required
                                placeholder="0"
                                value={formatPriceInput(tier.price)}
                                onChange={(e) => handleTierPriceChange(tier.id, e.target.value)}
                                className="w-full pl-9 pr-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold focus:outline-none focus:border-orange-500 font-mono shadow-2xs"
                              />
                            </div>
                            <div className="mt-1 text-[10px] text-orange-600 font-bold">
                              {formatIDR(tier.price)}{' '}
                              <span className="text-slate-400 font-normal">{tier.subtitle}</span>
                            </div>
                          </div>

                          <div>
                            <label className="block text-[10px] font-bold text-slate-500 mb-1">
                              Harga Asli / Coret (Anchor IDR)
                            </label>
                            <div className="relative">
                              <span className="absolute left-3 top-2 text-xs text-slate-400 font-bold">
                                Rp
                              </span>
                              <input
                                type="text"
                                inputMode="numeric"
                                placeholder="Opsional (cth: 147.000)"
                                value={formatPriceInput(tier.original_price)}
                                onChange={(e) =>
                                  handleTierOriginalPriceChange(tier.id, e.target.value)
                                }
                                className="w-full pl-9 pr-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold focus:outline-none focus:border-orange-500 font-mono shadow-2xs"
                              />
                            </div>
                            <div className="mt-1 text-[10px]">
                              {tier.original_price && tier.original_price > tier.price ? (
                                <span className="text-rose-600 font-bold">
                                  Dicoret: <span className="line-through">{formatIDR(tier.original_price)}</span> (Hemat {discountPct}%)
                                </span>
                              ) : (
                                <span className="text-slate-400">Kosongkan jika tanpa harga coret</span>
                              )}
                            </div>
                          </div>

                          <div>
                            <label className="block text-[10px] font-bold text-slate-500 mb-1">
                              Badge Promosi (Opsional)
                            </label>
                            <div className="relative">
                              <span className="absolute left-3 top-2 text-xs text-slate-400">
                                <Tag className="w-3.5 h-3.5" />
                              </span>
                              <input
                                type="text"
                                placeholder="Misal: BEST VALUE 👑, PROMO"
                                value={tier.badge || ''}
                                onChange={(e) => handleTierBadgeChange(tier.id, e.target.value)}
                                className="w-full pl-8 pr-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs focus:outline-none focus:border-orange-500 shadow-2xs"
                              />
                            </div>
                            <div className="mt-1 text-[10px] text-slate-400">
                              Muncul di samping nama paket di HP kasir
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Quota Pro Standar */}
                <div className="pt-5 border-t border-slate-100">
                  <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-3">
                    Batas Kuota Standar Toko Paket Pro
                  </h4>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">
                        Maks. Cabang Outlet
                      </label>
                      <input
                        type="text"
                        inputMode="numeric"
                        placeholder="0"
                        value={proMaxOutlets === 0 ? '' : proMaxOutlets}
                        onChange={(e) => handleQuotaChange(setProMaxOutlets, e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">
                        Maks. Produk
                      </label>
                      <input
                        type="text"
                        inputMode="numeric"
                        placeholder="0"
                        value={proMaxProducts === 0 ? '' : proMaxProducts}
                        onChange={(e) => handleQuotaChange(setProMaxProducts, e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                      />
                      <span className="text-[10px] text-slate-500">999999 = Tanpa Batas</span>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">
                        Maks. Transaksi/Bln
                      </label>
                      <input
                        type="text"
                        inputMode="numeric"
                        placeholder="0"
                        value={proMaxTransactions === 0 ? '' : proMaxTransactions}
                        onChange={(e) => handleQuotaChange(setProMaxTransactions, e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                      />
                      <span className="text-[10px] text-slate-500">999999 = Tanpa Batas</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* CARD 2: PAKET FREE (GRATIS) */}
            <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
              <div className="flex items-center gap-3 pb-5 border-b border-slate-100">
                <div className="w-10 h-10 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-bold">
                  <Store className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-slate-900 text-base">Paket Free (Gratis Selamanya)</h3>
                  <p className="text-xs text-slate-500">
                    Harga selalu Rp 0. Anda dapat menyesuaikan batas kuota dasar pengguna baru.
                  </p>
                </div>
              </div>

              <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">
                    Maks. Cabang Outlet
                  </label>
                  <input
                    type="text"
                    inputMode="numeric"
                    placeholder="0"
                    value={freeMaxOutlets === 0 ? '' : freeMaxOutlets}
                    onChange={(e) => handleQuotaChange(setFreeMaxOutlets, e.target.value)}
                    className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">
                    Maks. Produk Katalog
                  </label>
                  <input
                    type="text"
                    inputMode="numeric"
                    placeholder="0"
                    value={freeMaxProducts === 0 ? '' : freeMaxProducts}
                    onChange={(e) => handleQuotaChange(setFreeMaxProducts, e.target.value)}
                    className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">
                    Maks. Transaksi/Bulan
                  </label>
                  <input
                    type="text"
                    inputMode="numeric"
                    placeholder="0"
                    value={freeMaxTransactions === 0 ? '' : freeMaxTransactions}
                    onChange={(e) => handleQuotaChange(setFreeMaxTransactions, e.target.value)}
                    className="w-full px-3 py-1.5 rounded-lg bg-white border border-slate-300 text-slate-900 text-xs font-bold shadow-xs"
                  />
                </div>
              </div>
            </div>

            {/* Submit Action */}
            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="submit"
                disabled={isSaving}
                className="px-6 py-3 rounded-xl bg-orange-600 hover:bg-orange-500 text-white font-bold text-sm shadow-md shadow-orange-500/20 flex items-center gap-2 transition-all disabled:opacity-50"
              >
                <Save className="w-4 h-4" />
                {isSaving ? 'Menyimpan ke Database...' : 'Simpan Semua Perubahan Paket & Harga'}
              </button>
            </div>
          </div>

          {/* Kolom Kanan: Live Mobile Preview Card */}
          <div className="space-y-6">
            <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-sm sticky top-6">
              <div className="flex items-center gap-2.5 pb-4 border-b border-slate-100">
                <Smartphone className="w-4 h-4 text-orange-600" />
                <h4 className="text-xs font-bold text-slate-900 uppercase tracking-wider">
                  Live Preview Mobile (Android)
                </h4>
              </div>

              <div className="mt-4 space-y-3">
                <p className="text-[11px] text-slate-500">
                  Berikut tampilan real-time apa yang dilihat kasir di layar Android berdasarkan pengaturan di sebelah kiri:
                </p>

                {/* Preview Chips */}
                <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
                  <div className="text-[10px] font-bold text-slate-400 uppercase">
                    Pilihan Durasi Aktif ({activeTiers.length}):
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {activeTiers.length === 0 ? (
                      <span className="text-xs text-red-500 italic">
                        Semua paket disembunyikan. Harap aktifkan minimal 1 paket.
                      </span>
                    ) : (
                      activeTiers.map((t) => (
                        <span
                          key={t.id}
                          className={`px-2 py-1 rounded-md text-[10px] font-semibold ${
                            t.is_lifetime
                              ? 'bg-orange-500 text-white font-bold shadow-xs'
                              : 'bg-white border border-slate-200 text-slate-700'
                          }`}
                        >
                          {t.name.split(' (')[0]}
                          {t.badge && ` (${t.badge})`}
                        </span>
                      ))
                    )}
                  </div>
                </div>

                {/* Preview Price Card */}
                {previewHeadlineTier && (
                  <div className="p-4 rounded-xl bg-white border-2 border-orange-200 shadow-sm">
                    <div className="flex items-center justify-between mb-1">
                      <div className="text-xs font-bold text-orange-600">
                        {previewHeadlineTier.name}
                      </div>
                      {previewHeadlineTier.badge && (
                        <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-amber-100 text-amber-800">
                          {previewHeadlineTier.badge}
                        </span>
                      )}
                    </div>
                    {previewHeadlineTier.original_price &&
                      previewHeadlineTier.original_price > previewHeadlineTier.price && (
                        <div className="flex items-center gap-1.5 mb-1">
                          <span className="text-xs font-bold text-slate-400 line-through font-mono">
                            {formatIDR(previewHeadlineTier.original_price)}
                          </span>
                          <span className="px-1.5 py-0.2 rounded text-[9px] font-black bg-rose-50 text-rose-600 border border-rose-200">
                            HEMAT{' '}
                            {Math.round(
                              ((previewHeadlineTier.original_price -
                                previewHeadlineTier.price) /
                                previewHeadlineTier.original_price) *
                                100
                            )}
                            %
                          </span>
                        </div>
                      )}
                    <div className="text-xl font-black text-slate-900 font-mono">
                      {formatIDR(previewHeadlineTier.price)}
                    </div>
                    <div className="text-[10px] text-slate-500 mb-2">
                      {previewHeadlineTier.subtitle || (previewHeadlineTier.is_lifetime ? 'sekali bayar selamanya' : `/${previewHeadlineTier.name}`)}
                    </div>
                    <div className="text-[11px] text-slate-600 line-clamp-2">
                      {previewHeadlineTier.is_lifetime
                        ? 'Akses selamanya tanpa perpanjangan berkala. Fitur dapur pintar (KDS), self-order QR meja resto, dan manajemen stok.'
                        : 'Luncurkan efisiensi maksimal dengan fitur dapur pintar, multi-cabang, dan sistem pemesanan mandiri.'}
                    </div>
                    <div className="mt-3 pt-2 border-t border-slate-100 flex items-center justify-between text-[10px] text-slate-500 font-medium">
                      <span>Maks. {proMaxOutlets} Outlet</span>
                      <span>Produk Unlimited</span>
                    </div>
                  </div>
                )}

                {/* WhatsApp Chat Preview */}
                <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-[11px] text-emerald-800 space-y-1">
                  <div className="font-bold flex items-center gap-1 text-emerald-700">
                    <Flame className="w-3.5 h-3.5 text-emerald-600" />
                    Pesan Otomatis WhatsApp:
                  </div>
                  <div className="font-mono text-[10px] bg-white p-2 rounded border border-emerald-200 text-slate-700 shadow-2xs">
                    "Halo Tim Syupeo, saya ingin konsultasi aktivasi paket retail ({previewHeadlineTier?.name || 'Paket'} - {formatIDR(previewHeadlineTier?.price || 0)})..."
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </form>

      {/* MODAL: TAMBAH PAKET BARU */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Plus className="w-5 h-5 text-orange-600" />
                <h3 className="font-bold text-slate-900 text-base">Tambah Paket Durasi Baru</h3>
              </div>
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateNewTier} className="p-5 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Nama Paket Durasi
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: 2 Tahun, 90 Hari Hemat, Promo Merdeka"
                  value={newTierName}
                  onChange={(e) => setNewTierName(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-sm font-semibold focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="flex items-center gap-2 p-3 rounded-xl bg-amber-50 border border-amber-200">
                <input
                  type="checkbox"
                  id="newTierIsLifetime"
                  checked={newTierIsLifetime}
                  onChange={(e) => setNewTierIsLifetime(e.target.checked)}
                  className="w-4 h-4 text-orange-600 rounded border-slate-300 focus:ring-orange-500"
                />
                <label htmlFor="newTierIsLifetime" className="text-xs font-bold text-slate-800 cursor-pointer">
                  Paket Bersifat Lifetime (Sekali Bayar Selamanya)
                </label>
              </div>

              {!newTierIsLifetime && (
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Durasi dalam Satuan Bulan
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="60"
                    required
                    value={newTierMonths}
                    onChange={(e) => setNewTierMonths(Number(e.target.value))}
                    className="w-full px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-sm font-semibold focus:outline-none focus:border-orange-500"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    Contoh: ketik 24 untuk durasi 2 tahun (24 bulan)
                  </p>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Harga Langganan (IDR)
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-xs text-slate-400 font-bold">Rp</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    required
                    placeholder="0"
                    value={formatPriceInput(newTierPrice)}
                    onChange={(e) => {
                      const cleanDigits = e.target.value.replace(/\D/g, '').replace(/^0+/, '');
                      setNewTierPrice(cleanDigits === '' ? 0 : parseInt(cleanDigits, 10));
                    }}
                    className="w-full pl-9 pr-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-sm font-bold font-mono focus:outline-none focus:border-orange-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Harga Asli / Coret (Anchor IDR) - Opsional
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-xs text-slate-400 font-bold">Rp</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    placeholder="Misal: 147.000 (akan dicoret di HP kasir)"
                    value={formatPriceInput(newTierOriginalPrice)}
                    onChange={(e) => {
                      const cleanDigits = e.target.value.replace(/\D/g, '').replace(/^0+/, '');
                      setNewTierOriginalPrice(cleanDigits === '' ? null : parseInt(cleanDigits, 10));
                    }}
                    className="w-full pl-9 pr-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-sm font-bold font-mono focus:outline-none focus:border-orange-500"
                  />
                </div>
                <p className="text-[10px] text-slate-500 mt-1">
                  Jika diisi lebih besar dari harga langganan, aplikasi otomatis menampilkan harga dicoret dan badge hemat %.
                </p>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Badge Promosi (Opsional)
                </label>
                <input
                  type="text"
                  placeholder="Misal: PROMO SPESIAL, HEMAT 25%"
                  value={newTierBadge}
                  onChange={(e) => setNewTierBadge(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-xs focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-100 text-slate-700 text-xs font-bold hover:bg-slate-200 transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold shadow-md shadow-orange-500/20 transition-all"
                >
                  Tambahkan ke Daftar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
