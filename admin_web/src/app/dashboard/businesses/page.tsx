'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Business, BusinessTypeTemplate, SubscriptionPlan } from '@/types/database';
import Link from 'next/link';
import {
  Building2,
  Search,
  Filter,
  CheckCircle,
  X,
  AlertCircle,
  Sliders,
  Sparkles,
  Store,
  Layers,
  Crown,
  Calendar,
  Zap,
  Clock,
  ShieldCheck,
  Check,
  Eye,
  BarChart3,
  Trash2,
} from 'lucide-react';

export default function BusinessesPage() {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [templates, setTemplates] = useState<BusinessTypeTemplate[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTypeFilter, setSelectedTypeFilter] = useState('ALL');
  const [selectedPlanFilter, setSelectedPlanFilter] = useState('ALL'); // 'ALL' | 'pro' | 'free'

  // Change Template Modal state
  const [templateModalBusiness, setTemplateModalBusiness] = useState<Business | null>(null);
  const [selectedTemplateCode, setSelectedTemplateCode] = useState<string>('');

  // Subscription Plan (Free/Pro) Modal state
  const [planModalBusiness, setPlanModalBusiness] = useState<Business | null>(null);
  const [selectedPlanId, setSelectedPlanId] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('active');
  const [durationMonths, setDurationMonths] = useState<number>(1);
  const [isLifetime, setIsLifetime] = useState<boolean>(false);

  // Custom Limits Modal state
  const [limitsModalBusiness, setLimitsModalBusiness] = useState<Business | null>(null);
  const [customLimitsData, setCustomLimitsData] = useState({
    max_outlets: 1,
    max_products: 50,
    max_transactions: 100,
  });

  const [isUpdating, setIsUpdating] = useState(false);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    const [bizRes, tplRes, planRes] = await Promise.all([
      supabase
        .from('businesses')
        .select('*, profiles(id, full_name, email, phone), subscription_plans(*), partners(*)')
        .order('created_at', { ascending: false }),
      supabase.from('business_type_templates').select('*').order('name'),
      supabase.from('subscription_plans').select('*').order('price_monthly', { ascending: true }),
    ]);

    if (!bizRes.error && bizRes.data) {
      setBusinesses(bizRes.data as Business[]);
    }
    if (!tplRes.error && tplRes.data) {
      setTemplates(tplRes.data as BusinessTypeTemplate[]);
    }
    if (!planRes.error && planRes.data) {
      setPlans(planRes.data as SubscriptionPlan[]);
    }
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  // --- Handlers for Subscription Plan (Free vs Pro) ---
  const openPlanModal = (biz: Business) => {
    setPlanModalBusiness(biz);
    // Cari plan id saat ini atau default
    const currentPlanId = biz.plan_id || plans.find((p) => p.code === 'free')?.id || '';
    setSelectedPlanId(currentPlanId);
    setSelectedStatus(biz.subscription_status || 'active');
    setDurationMonths(1);
    setIsLifetime(!biz.subscription_end_at && biz.subscription_status === 'active' && biz.subscription_plans?.code === 'pro');
    setErrorMsg(null);
  };

  const handleSavePlan = async () => {
    if (!planModalBusiness || !selectedPlanId) return;
    setIsUpdating(true);
    setErrorMsg(null);

    try {
      const chosenPlan = plans.find((p) => p.id === selectedPlanId);
      const isProChosen = chosenPlan?.code === 'pro';

      let endAt: string | null = null;
      if (isProChosen) {
        if (isLifetime) {
          endAt = null; // null end_at = lifetime active
        } else {
          const date = new Date();
          date.setMonth(date.getMonth() + durationMonths);
          endAt = date.toISOString();
        }
      }

      // Update business subscription & sync limits if upgrading/downgrading
      const updatePayload: any = {
        plan_id: selectedPlanId,
        subscription_status: selectedStatus,
        subscription_end_at: endAt,
        updated_at: new Date().toISOString(),
      };

      // Jika diubah ke PRO, berikan limit PRO (misal 5 outlet, unlimited transaksi)
      if (isProChosen && chosenPlan) {
        updatePayload.max_transactions = chosenPlan.max_transactions_month;
        updatePayload.max_products = chosenPlan.max_products;
        updatePayload.max_outlets = chosenPlan.max_outlets;
      } else if (chosenPlan && chosenPlan.code === 'free') {
        // Jika ke Free
        updatePayload.max_transactions = chosenPlan.max_transactions_month || 150;
        updatePayload.max_products = chosenPlan.max_products || 50;
        updatePayload.max_outlets = chosenPlan.max_outlets || 1;
      }

      const { error } = await supabase
        .from('businesses')
        .update(updatePayload)
        .eq('id', planModalBusiness.id);

      if (error) throw error;

      setSuccessMsg(
        `Status langganan "${planModalBusiness.name}" berhasil diubah menjadi ${chosenPlan?.name || 'Paket Baru'}.`
      );
      setPlanModalBusiness(null);
      await loadData();
    } catch (err: any) {
      setErrorMsg(err?.message || 'Gagal mengubah status langganan.');
    } finally {
      setIsUpdating(false);
    }
  };

  // Quick toggle Free <-> Pro in 1-click
  const handleQuickTogglePro = async (biz: Business) => {
    const isCurrentlyPro = biz.subscription_plans?.code === 'pro';
    const targetPlanCode = isCurrentlyPro ? 'free' : 'pro';
    const targetPlan = plans.find((p) => p.code === targetPlanCode);

    if (!targetPlan) {
      alert(`Paket ${targetPlanCode} tidak ditemukan di database.`);
      return;
    }

    const confirmText = isCurrentlyPro
      ? `Turunkan status bisnis "${biz.name}" ke FREE Plan?`
      : `Upgrade status bisnis "${biz.name}" ke PRO Plan (Aktif Lifetime / 1 Tahun)?`;

    if (!confirm(confirmText)) return;

    try {
      let endAt: string | null = null;
      if (!isCurrentlyPro) {
        // Beri 1 tahun aktif untuk PRO
        const date = new Date();
        date.setFullYear(date.getFullYear() + 1);
        endAt = date.toISOString();
      }

      const { error } = await supabase
        .from('businesses')
        .update({
          plan_id: targetPlan.id,
          subscription_status: 'active',
          subscription_end_at: endAt,
          max_transactions: targetPlan.max_transactions_month,
          max_products: targetPlan.max_products,
          max_outlets: targetPlan.max_outlets,
          updated_at: new Date().toISOString(),
        })
        .eq('id', biz.id);

      if (error) throw error;

      setSuccessMsg(
        `Berhasil mengubah status "${biz.name}" menjadi ${isCurrentlyPro ? 'FREE' : 'PRO'}.`
      );
      await loadData();
    } catch (err: any) {
      alert(`Gagal toggle plan: ${err.message}`);
    }
  };

  // --- Handlers for Business Template ---
  const openTemplateModal = (biz: Business) => {
    setTemplateModalBusiness(biz);
    setSelectedTemplateCode(biz.business_type || (templates[0]?.code ?? 'general'));
    setErrorMsg(null);
  };

  const handleApplyTemplate = async () => {
    if (!templateModalBusiness || !selectedTemplateCode) return;
    setIsUpdating(true);
    setErrorMsg(null);

    try {
      const targetTpl = templates.find((t) => t.code === selectedTemplateCode);
      if (!targetTpl) throw new Error('Template tidak ditemukan.');

      const { error } = await supabase
        .from('businesses')
        .update({
          business_type: targetTpl.code,
          enabled_features: targetTpl.default_enabled_features,
          max_transactions: targetTpl.max_transactions ?? 100,
          max_products: targetTpl.max_products ?? 50,
          max_outlets: targetTpl.max_outlets ?? 1,
          features_config: targetTpl.features_config || {},
          limits_config: targetTpl.limits_config || {},
          role_labels: targetTpl.role_labels || {},
          updated_at: new Date().toISOString(),
        })
        .eq('id', templateModalBusiness.id);

      if (error) throw error;

      setSuccessMsg(
        `Tipe template "${templateModalBusiness.name}" berhasil diubah menjadi "${targetTpl.name}".`
      );
      setTemplateModalBusiness(null);
      await loadData();
    } catch (err: any) {
      setErrorMsg(err?.message || 'Gagal mengubah tipe template bisnis.');
    } finally {
      setIsUpdating(false);
    }
  };

  // --- Handlers for Custom Limits ---
  const openLimitsModal = (biz: Business) => {
    setLimitsModalBusiness(biz);
    setCustomLimitsData({
      max_outlets: biz.max_outlets ?? 1,
      max_products: biz.max_products ?? 50,
      max_transactions: biz.max_transactions ?? 100,
    });
  };

  const handleSaveCustomLimits = async () => {
    if (!limitsModalBusiness) return;
    setIsUpdating(true);
    try {
      const { error } = await supabase
        .from('businesses')
        .update({
          max_outlets: Number(customLimitsData.max_outlets),
          max_products: Number(customLimitsData.max_products),
          max_transactions: Number(customLimitsData.max_transactions),
          updated_at: new Date().toISOString(),
        })
        .eq('id', limitsModalBusiness.id);

      if (error) throw error;
      setSuccessMsg(`Limit kustom untuk "${limitsModalBusiness.name}" berhasil disimpan.`);
      setLimitsModalBusiness(null);
      await loadData();
    } catch (err: any) {
      alert(`Gagal menyimpan limit: ${err?.message}`);
    } finally {
      setIsUpdating(false);
    }
  };

  // Filtered List
  const filteredBusinesses = businesses.filter((b) => {
    const isPro = b.subscription_plans?.code === 'pro';

    const matchesSearch =
      b.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.id?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.profiles?.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.profiles?.full_name?.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesType =
      selectedTypeFilter === 'ALL' || b.business_type === selectedTypeFilter;

    const matchesPlan =
      selectedPlanFilter === 'ALL' ||
      (selectedPlanFilter === 'pro' && isPro) ||
      (selectedPlanFilter === 'free' && !isPro);

    return matchesSearch && matchesType && matchesPlan;
  });

  // --- Handler for Delete Business ---
  const handleDeleteBusiness = async (biz: Business) => {
    if (!confirm(`Hapus permanen toko "${biz.name}"? Data toko dan outlet yang berkaitan akan dibersihkan.`)) {
      return;
    }
    try {
      // 1. Coba panggil RPC aman jika sudah dibuat di Supabase
      const { error: rpcErr } = await supabase.rpc('delete_business_by_admin', {
        p_business_id: biz.id,
      });

      if (rpcErr) {
        // Fallback jika RPC belum dieksekusi di console: hapus outlets lalu hapus business
        const { data: outlets } = await supabase.from('outlets').select('id').eq('business_id', biz.id);
        if (outlets && outlets.length > 0) {
          const outletIds = outlets.map((o) => o.id);
          await supabase.from('outlet_members').delete().in('outlet_id', outletIds);
          await supabase.from('outlets').delete().in('id', outletIds);
        }
        await supabase.from('business_members').delete().eq('business_id', biz.id);
        const { error: delErr } = await supabase.from('businesses').delete().eq('id', biz.id);
        if (delErr) throw delErr;
      }

      setSuccessMsg(`Toko "${biz.name}" berhasil dihapus.`);
      await loadData();
    } catch (err: any) {
      alert(`Gagal menghapus toko: ${err?.message || 'Pastikan migration SQL delete sudah dijalankan di Supabase'}`);
    }
  };

  return (
    <div>
      <Navbar
        title="Manajemen Akun Bisnis"
        description="Kelola status langganan PRO / FREE, template jenis usaha, dan batasan kuota seluruh mitra DPOS"
      />

      <div className="space-y-6 mt-6">
        {/* Toast Alert */}
        {successMsg && (
          <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <CheckCircle className="w-5 h-5 text-emerald-400" />
              <span>{successMsg}</span>
            </div>
            <button onClick={() => setSuccessMsg(null)}>
              <X className="w-4 h-4 text-emerald-400 hover:text-white" />
            </button>
          </div>
        )}

        {/* Filter & Search Bar */}
        <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari nama bisnis, owner, atau email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm focus:outline-none focus:border-orange-500 shadow-xs"
            />
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Filter Plan (Free / Pro) */}
            <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl border border-slate-200 text-xs">
              <button
                onClick={() => setSelectedPlanFilter('ALL')}
                className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                  selectedPlanFilter === 'ALL'
                    ? 'bg-white text-slate-900 shadow-xs border border-slate-200'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Semua Plan
              </button>
              <button
                onClick={() => setSelectedPlanFilter('pro')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg font-bold transition-all ${
                  selectedPlanFilter === 'pro'
                    ? 'bg-amber-500 text-white shadow-xs'
                    : 'text-slate-600 hover:text-amber-700'
                }`}
              >
                <Crown className="w-3.5 h-3.5" />
                Hanya PRO
              </button>
              <button
                onClick={() => setSelectedPlanFilter('free')}
                className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                  selectedPlanFilter === 'free'
                    ? 'bg-white text-slate-900 shadow-xs border border-slate-200'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Hanya FREE
              </button>
            </div>

            {/* Filter Template */}
            <div className="flex items-center gap-2">
              <select
                value={selectedTypeFilter}
                onChange={(e) => setSelectedTypeFilter(e.target.value)}
                className="px-3.5 py-2.5 rounded-xl bg-white border border-slate-300 text-slate-800 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
              >
                <option value="ALL">Semua Tipe Template</option>
                {templates.map((t) => (
                  <option key={t.code} value={t.code}>
                    {t.name} ({t.code})
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* Table of Businesses */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          {loading ? (
            <div className="text-center py-20">
              <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
              <p className="text-sm text-slate-500">Memuat data akun bisnis...</p>
            </div>
          ) : filteredBusinesses.length === 0 ? (
            <div className="p-12 text-center text-slate-400 text-sm">
              Tidak ada akun bisnis yang cocok dengan kriteria pencarian.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200 text-slate-500 text-xs uppercase tracking-wider font-bold">
                    <th className="py-3.5 px-6">Nama Bisnis & Owner</th>
                    <th className="py-3.5 px-6">Status Paket</th>
                    <th className="py-3.5 px-6">Tipe Bisnis</th>
                    <th className="py-3.5 px-6">Limit Kuota</th>
                    <th className="py-3.5 px-6 text-right">Kelola Status / Plan</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredBusinesses.map((b) => {
                    const isPro = b.subscription_plans?.code === 'pro';
                    const hasEndAt = !!b.subscription_end_at;
                    const endAtFormatted = hasEndAt
                      ? new Date(b.subscription_end_at!).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })
                      : 'Lifetime';

                    return (
                      <tr key={b.id} className="hover:bg-slate-50 transition-colors">
                        {/* Bisnis & Owner */}
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-orange-50 text-orange-700 border border-orange-200 flex items-center justify-center font-bold text-sm flex-shrink-0">
                              {b.name?.charAt(0)?.toUpperCase() || 'B'}
                            </div>
                            <div className="min-w-0">
                              <Link
                                href={`/dashboard/businesses/${b.id}`}
                                className="font-bold text-slate-900 hover:text-orange-600 transition-colors flex items-center gap-2 text-left group"
                                title="Buka Halaman Profil Bisnis & Analitik Penjualan Lengkap"
                              >
                                <span className="truncate group-hover:underline">{b.name}</span>
                                {isPro && (
                                  <span className="px-1.5 py-0.5 rounded text-[10px] font-extrabold bg-amber-100 text-amber-800 border border-amber-200 flex items-center gap-1">
                                    <Crown className="w-3 h-3 text-amber-600" /> PRO
                                  </span>
                                )}
                              </Link>
                              <div className="text-xs text-slate-500 truncate">
                                {b.profiles?.full_name || 'Owner'} •{' '}
                                <span className="text-slate-400">{b.profiles?.email || '-'}</span>
                              </div>
                            </div>
                          </div>
                        </td>

                        {/* Status Paket (Free / Pro) */}
                        <td className="py-4 px-6">
                          <div className="space-y-1">
                            {isPro ? (
                              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200">
                                <Crown className="w-3.5 h-3.5 text-amber-600" />
                                <span>PRO PLAN</span>
                              </div>
                            ) : (
                              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-600 border border-slate-200">
                                <Store className="w-3.5 h-3.5 text-slate-500" />
                                <span>FREE PLAN</span>
                              </div>
                            )}

                            <div className="text-[11px] text-slate-500 flex items-center gap-1">
                              <Clock className="w-3 h-3 text-slate-400" />
                              <span>
                                {isPro
                                  ? hasEndAt
                                    ? `Hingga ${endAtFormatted}`
                                    : 'Akses Permanen (Lifetime)'
                                  : 'Gratis Selamanya'}
                              </span>
                            </div>

                            {b.partners && (
                              <div className="pt-0.5">
                                <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 px-1.5 py-0.5 rounded">
                                  Mitra: {b.partners.name} ({b.partners.commission_rate}%)
                                </span>
                              </div>
                            )}
                          </div>
                        </td>

                        {/* Tipe Template */}
                        <td className="py-4 px-6">
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                            <Layers className="w-3.5 h-3.5 text-slate-500" />
                            {b.business_type || 'default'}
                          </span>
                        </td>

                        {/* Limit Kuota */}
                        <td className="py-4 px-6 text-xs text-slate-600">
                          <div>
                            <span className="font-bold text-slate-900">{b.max_outlets ?? 1}</span>{' '}
                            Outlet
                          </div>
                          <div className="text-slate-400">
                            {b.max_products && b.max_products > 10000 ? 'Unlimited' : b.max_products ?? 50}{' '}
                            Produk •{' '}
                            {b.max_transactions && b.max_transactions > 10000
                              ? 'Unlimited'
                              : b.max_transactions ?? 100}{' '}
                            Tx
                          </div>
                        </td>

                        {/* Aksi */}
                        <td className="py-4 px-6 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {/* Tombol Utama: Buka Halaman Profil & Penjualan (Full Page) */}
                            <Link
                              href={`/dashboard/businesses/${b.id}`}
                              className="px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-700 transition-all flex items-center gap-1.5 shadow-2xs"
                              title="Buka Halaman Profil Bisnis, Produk Terlaris & Katalog Lengkap"
                            >
                              <Eye className="w-3.5 h-3.5 text-slate-600" />
                              <span>Detail & Penjualan</span>
                            </Link>

                            {/* Tombol Status Langganan Free/Pro */}
                            <button
                              onClick={() => openPlanModal(b)}
                              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 shadow-xs ${
                                isPro
                                  ? 'bg-amber-100 hover:bg-amber-200 text-amber-800 border border-amber-200'
                                  : 'bg-orange-600 hover:bg-orange-500 text-white'
                              }`}
                              title="Ubah paket Free / Pro & masa aktif"
                            >
                              <Crown className="w-3.5 h-3.5" />
                              {isPro ? 'Atur PRO' : 'Upgrade ke PRO'}
                            </button>

                            {/* Tombol Ganti Template */}
                            <button
                              onClick={() => openTemplateModal(b)}
                              className="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 transition-colors"
                              title="Ganti Template Bisnis"
                            >
                              <Layers className="w-4 h-4" />
                            </button>

                            {/* Tombol Override Limit */}
                            <button
                              onClick={() => openLimitsModal(b)}
                              className="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 transition-colors"
                              title="Override Limit Kuota"
                            >
                              <Sliders className="w-4 h-4" />
                            </button>

                            {/* Tombol Hapus Bisnis */}
                            <button
                              onClick={() => handleDeleteBusiness(b)}
                              className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 transition-colors"
                              title="Hapus Toko"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ======================================================== */}
        {/* MODAL 1: UBAH STATUS LANGGANAN (FREE vs PRO)            */}
        {/* ======================================================== */}
        {planModalBusiness && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
            <div className="bg-white w-full max-w-lg rounded-2xl p-6 border border-slate-200 shadow-2xl relative">
              <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="w-9 h-9 rounded-xl bg-amber-50 text-amber-600 border border-amber-200 flex items-center justify-center font-bold">
                    <Crown className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Ubah Status Langganan</h3>
                    <p className="text-xs text-slate-500">{planModalBusiness.name}</p>
                  </div>
                </div>
                <button
                  onClick={() => setPlanModalBusiness(null)}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {errorMsg && (
                <div className="mt-4 p-3 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div className="mt-5 space-y-4">
                {/* Pilihan Paket: FREE vs PRO */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">
                    Pilih Paket Langganan:
                  </label>
                  <div className="grid grid-cols-2 gap-3">
                    {plans.map((p) => {
                      const isPro = p.code === 'pro';
                      const isSelected = selectedPlanId === p.id;
                      return (
                        <div
                          key={p.id}
                          onClick={() => setSelectedPlanId(p.id)}
                          className={`p-4 rounded-xl border-2 cursor-pointer transition-all flex flex-col justify-between ${
                            isSelected
                              ? isPro
                                ? 'bg-amber-50 border-amber-400 shadow-xs'
                                : 'bg-slate-50 border-slate-400'
                              : 'bg-white border-slate-200 hover:border-slate-300'
                          }`}
                        >
                          <div>
                            <div className="flex items-center justify-between">
                              <span
                                className={`text-xs font-bold uppercase tracking-wider ${
                                  isPro ? 'text-amber-800' : 'text-slate-700'
                                }`}
                              >
                                {p.name}
                              </span>
                              {isSelected && (
                                <span
                                  className={`w-4 h-4 rounded-full flex items-center justify-center text-[10px] text-white ${
                                    isPro ? 'bg-amber-600' : 'bg-slate-800'
                                  }`}
                                >
                                  ✓
                                </span>
                              )}
                            </div>
                            <div className="text-lg font-black text-slate-900 mt-1">
                              {p.price_monthly > 0
                                ? `Rp ${Math.round(Number(p.price_monthly) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`
                                : 'Gratis'}
                            </div>
                            <div className="text-[11px] text-slate-500 mt-2 space-y-1">
                              <div>• {p.max_outlets} Maks Outlet</div>
                              <div>
                                • {p.max_products > 10000 ? 'Unlimited' : p.max_products} Produk
                              </div>
                              <div>
                                •{' '}
                                {p.max_transactions_month > 10000
                                  ? 'Unlimited'
                                  : p.max_transactions_month}{' '}
                                Transaksi
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Status Aktif */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5">
                    Status Akun:
                  </label>
                  <select
                    value={selectedStatus}
                    onChange={(e) => setSelectedStatus(e.target.value)}
                    className="w-full px-3.5 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                  >
                    <option value="active">Active (Aktif Normal)</option>
                    <option value="trial">Trial (Masa Uji Coba)</option>
                    <option value="expired">Expired (Berakhir / Ditangguhkan)</option>
                  </select>
                </div>

                {/* Pengaturan Durasi PRO (hanya jika memilih PRO) */}
                {plans.find((p) => p.id === selectedPlanId)?.code === 'pro' && (
                  <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-3">
                    <div className="flex items-center justify-between">
                      <label className="text-xs font-bold text-slate-700">
                        Masa Aktif Paket PRO:
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-amber-800">
                        <input
                          type="checkbox"
                          checked={isLifetime}
                          onChange={(e) => setIsLifetime(e.target.checked)}
                          className="rounded border-slate-300 text-amber-600 focus:ring-0"
                        />
                        <span>Aktif Permanen (Lifetime)</span>
                      </label>
                    </div>

                    {!isLifetime && (
                      <div className="grid grid-cols-4 gap-2 pt-1">
                        {[
                          { label: '1 Bulan', months: 1 },
                          { label: '3 Bulan', months: 3 },
                          { label: '6 Bulan', months: 6 },
                          { label: '1 Tahun', months: 12 },
                        ].map((dur) => (
                          <button
                            key={dur.months}
                            type="button"
                            onClick={() => setDurationMonths(dur.months)}
                            className={`py-2 rounded-lg text-xs font-bold border transition-all ${
                              durationMonths === dur.months
                                ? 'bg-orange-500 border-orange-500 text-white shadow-xs'
                                : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
                            }`}
                          >
                            {dur.label}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                  <button
                    onClick={() => setPlanModalBusiness(null)}
                    className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold"
                  >
                    Batal
                  </button>
                  <button
                    onClick={handleSavePlan}
                    disabled={isUpdating}
                    className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold shadow-md shadow-orange-500/20 disabled:opacity-50 flex items-center gap-1.5"
                  >
                    <Crown className="w-3.5 h-3.5" />
                    {isUpdating ? 'Menyimpan...' : 'Simpan Status Langganan'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ======================================================== */}
        {/* MODAL 2: GANTI TEMPLATE BISNIS                          */}
        {/* ======================================================== */}
        {templateModalBusiness && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
            <div className="bg-white w-full max-w-lg rounded-2xl p-6 border border-slate-200 shadow-2xl relative">
              <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-orange-50 text-orange-600 flex items-center justify-center font-bold">
                    <Layers className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Ganti Template Bisnis</h3>
                    <p className="text-xs text-slate-500">{templateModalBusiness.name}</p>
                  </div>
                </div>
                <button
                  onClick={() => setTemplateModalBusiness(null)}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="mt-5 space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">
                    Pilih Template Baru:
                  </label>
                  <div className="space-y-2 max-h-60 overflow-y-auto pr-1">
                    {templates.map((tpl) => (
                      <label
                        key={tpl.code}
                        className={`flex items-center justify-between p-3.5 rounded-xl border-2 cursor-pointer transition-all ${
                          selectedTemplateCode === tpl.code
                            ? 'bg-orange-50 border-orange-400 text-slate-900'
                            : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <input
                            type="radio"
                            name="template_code"
                            value={tpl.code}
                            checked={selectedTemplateCode === tpl.code}
                            onChange={(e) => setSelectedTemplateCode(e.target.value)}
                            className="text-orange-600 focus:ring-orange-500"
                          />
                          <div>
                            <div className="text-sm font-bold">{tpl.name}</div>
                            <div className="text-xs text-slate-500">
                              {tpl.max_outlets} Outlet • {tpl.max_products} Produk •{' '}
                              {tpl.default_enabled_features?.length || 0} Modul
                            </div>
                          </div>
                        </div>
                        <span className="font-mono text-xs text-orange-700 bg-orange-100 px-2 py-0.5 rounded border border-orange-200 font-semibold">
                          {tpl.code}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>

                <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                  <button
                    onClick={() => setTemplateModalBusiness(null)}
                    className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold"
                  >
                    Batal
                  </button>
                  <button
                    onClick={handleApplyTemplate}
                    disabled={isUpdating}
                    className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold shadow-md shadow-orange-500/20 disabled:opacity-50"
                  >
                    {isUpdating ? 'Menerapkan...' : 'Terapkan Template'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ======================================================== */}
        {/* MODAL 3: OVERRIDE CUSTOM LIMITS                         */}
        {/* ======================================================== */}
        {limitsModalBusiness && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
            <div className="bg-white w-full max-w-md rounded-2xl p-6 border border-slate-200 shadow-2xl relative">
              <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-orange-50 text-orange-600 flex items-center justify-center font-bold">
                    <Sliders className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Override Limit Kuota</h3>
                    <p className="text-xs text-slate-500">{limitsModalBusiness.name}</p>
                  </div>
                </div>
                <button
                  onClick={() => setLimitsModalBusiness(null)}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="mt-5 space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Maksimum Outlet
                  </label>
                  <input
                    type="number"
                    min={1}
                    value={customLimitsData.max_outlets}
                    onChange={(e) =>
                      setCustomLimitsData({
                        ...customLimitsData,
                        max_outlets: parseInt(e.target.value) || 1,
                      })
                    }
                    className="w-full px-3.5 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Maksimum Produk / Menu
                  </label>
                  <input
                    type="number"
                    min={1}
                    value={customLimitsData.max_products}
                    onChange={(e) =>
                      setCustomLimitsData({
                        ...customLimitsData,
                        max_products: parseInt(e.target.value) || 50,
                      })
                    }
                    className="w-full px-3.5 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Maksimum Transaksi / Bulan
                  </label>
                  <input
                    type="number"
                    min={1}
                    value={customLimitsData.max_transactions}
                    onChange={(e) =>
                      setCustomLimitsData({
                        ...customLimitsData,
                        max_transactions: parseInt(e.target.value) || 100,
                      })
                    }
                    className="w-full px-3.5 py-2 rounded-xl bg-white border border-slate-300 text-slate-900 text-sm font-semibold focus:outline-none focus:border-orange-500 shadow-xs"
                  />
                </div>

                <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                  <button
                    onClick={() => setLimitsModalBusiness(null)}
                    className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold"
                  >
                    Batal
                  </button>
                  <button
                    onClick={handleSaveCustomLimits}
                    disabled={isUpdating}
                    className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold shadow-md shadow-orange-500/20 disabled:opacity-50"
                  >
                    {isUpdating ? 'Menyimpan...' : 'Simpan Batasan'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
