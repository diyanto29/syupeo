import { createClient } from '@/lib/supabase/server';
import Navbar from '@/components/Navbar';
import Link from 'next/link';
import {
  Building2,
  Layers,
  Crown,
  Users,
  ArrowUpRight,
  TrendingUp,
  Sparkles,
  CheckCircle2,
  Store,
} from 'lucide-react';
import PartnerDashboardView from '@/components/PartnerDashboardView';

export const revalidate = 0; // realtime stats

export default async function DashboardPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  const userEmail = user?.email?.toLowerCase();
  const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';

  let role: 'super_admin' | 'admin' | 'partner' = 'admin';
  let partnerId: string | null = null;

  if (userEmail === adminEmail.toLowerCase()) {
    role = 'super_admin';
  } else if (userEmail) {
    const { data: adminRecord } = await supabase
      .from('admin_users')
      .select('role, partner_id')
      .eq('email', userEmail)
      .eq('is_active', true)
      .maybeSingle();

    if (adminRecord) {
      role = adminRecord.role as 'super_admin' | 'admin' | 'partner';
      partnerId = adminRecord.partner_id || null;
    }
  }

  // If user is a partner, render dedicated Partner Dashboard
  if (role === 'partner' && partnerId) {
    const [
      { data: partnerData },
      { data: commissionsData },
      { data: payoutsData },
      { data: leadsData },
      { count: activeClientsCount },
    ] = await Promise.all([
      supabase.from('partners').select('*').eq('id', partnerId).maybeSingle(),
      supabase
        .from('partner_commissions')
        .select('*, businesses(id, name)')
        .eq('partner_id', partnerId)
        .order('created_at', { ascending: false }),
      supabase
        .from('partner_payouts')
        .select('*')
        .eq('partner_id', partnerId)
        .order('created_at', { ascending: false }),
      supabase
        .from('leads')
        .select('*')
        .eq('partner_id', partnerId)
        .order('created_at', { ascending: false }),
      supabase
        .from('businesses')
        .select('*', { count: 'exact', head: true })
        .eq('referred_by_partner_id', partnerId)
        .eq('subscription_status', 'active'),
    ]);

    if (partnerData) {
      return (
        <div>
          <Navbar
            title="Portal Mitra & Marketer"
            description="Pantau prospek klien, transaksi perpanjangan langganan, dan saldo komisi rujukan Anda"
          />
          <div className="mt-6">
            <PartnerDashboardView
              partner={partnerData}
              commissions={commissionsData || []}
              payouts={payoutsData || []}
              leads={leadsData || []}
              activeClientsCount={activeClientsCount ?? 0}
            />
          </div>
        </div>
      );
    }
  }

  // Load metrics concurrently
  const [
    { count: businessesCount },
    { count: templatesCount },
    { count: proBusinessesCount },
    { data: businessOwnerRows },
    { data: recentBusinesses },
    { data: templates },
  ] = await Promise.all([
    supabase.from('businesses').select('*', { count: 'exact', head: true }),
    supabase.from('business_type_templates').select('*', { count: 'exact', head: true }),
    supabase
      .from('businesses')
      .select('id, subscription_plans!inner(code)', { count: 'exact', head: true })
      .eq('subscription_plans.code', 'pro')
      .eq('subscription_status', 'active'),
    supabase.from('businesses').select('owner_user_id'),
    supabase
      .from('businesses')
      .select('id, name, business_type, created_at, max_outlets, max_products, subscription_plans(name, code)')
      .order('created_at', { ascending: false })
      .limit(6),
    supabase
      .from('business_type_templates')
      .select('*')
      .order('created_at', { ascending: true })
      .limit(5),
  ]);

  
  // Hitung pemilik bisnis aktif terdaftar
  const uniqueOwnersCount = new Set((businessOwnerRows || []).map((b: any) => b.owner_user_id).filter(Boolean)).size;
  const displayOwnersCount = uniqueOwnersCount > 0 ? uniqueOwnersCount : (businessesCount ?? 0);

  return (
    <div>
      <Navbar
        title="Ringkasan Sistem"
        description="Pantau pertumbuhan bisnis terdaftar, akun PRO, konfigurasi template aktif, dan kesehatan ekosistem Mangga POS"
      />

      <div className="space-y-8 mt-6">
        {/* Welcome Banner in Mangga Orange */}
        <div className="relative overflow-hidden rounded-3xl p-8 bg-gradient-to-r from-orange-500 via-amber-500 to-orange-600 text-white shadow-lg shadow-orange-500/15">
          <div className="absolute -top-12 -right-12 w-64 h-64 bg-white/10 rounded-full blur-2xl pointer-events-none" />
          <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-white/20 text-white border border-white/30 backdrop-blur-xs">
                <Sparkles className="w-3.5 h-3.5" />
                Super Admin Access
              </div>
              <h2 className="text-2xl font-black tracking-tight">
                Selamat Datang, Diyanto
              </h2>
              <p className="text-sm text-white/90 max-w-2xl leading-relaxed">
                Panel kontrol penuh untuk mengatur harga paket langganan (PRO / FREE), modul template bisnis,
                dan batasan kuota fitur POS secara langsung.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Link
                href="/merchant"
                className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-sm shadow-md transition-all group"
              >
                <Store className="w-4 h-4 text-orange-400 group-hover:scale-110 transition-transform" />
                <span>Buka Portal Toko</span>
              </Link>
              <Link
                href="/dashboard/pricing"
                className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white hover:bg-slate-50 text-orange-600 font-bold text-sm shadow-md transition-all"
              >
                <Crown className="w-4 h-4 text-orange-600" />
                Atur Harga Paket
              </Link>
              <Link
                href="/dashboard/businesses"
                className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-700/60 hover:bg-orange-700/80 border border-white/20 text-white font-semibold text-sm transition-all"
              >
                <Building2 className="w-4 h-4" />
                Kelola Mitra
              </Link>
            </div>
          </div>
        </div>

        {/* Stats Grid - 4 Columns */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Card 1: Total Bisnis */}
          <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-xl bg-orange-50 border border-orange-200 flex items-center justify-center text-orange-600">
                <Building2 className="w-6 h-6" />
              </div>
              <Link
                href="/dashboard/businesses"
                className="text-xs text-orange-600 hover:text-orange-700 flex items-center gap-1 font-bold"
              >
                Lihat <ArrowUpRight className="w-3.5 h-3.5" />
              </Link>
            </div>
            <div className="mt-4">
              <div className="text-3xl font-extrabold text-slate-900 tracking-tight">
                {businessesCount ?? 0}
              </div>
              <p className="text-xs font-semibold text-slate-500 mt-1">Total Bisnis Terdaftar</p>
            </div>
          </div>

          {/* Card 2: Total Akun PRO */}
          <div className="bg-white rounded-2xl p-6 border border-amber-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
                <Crown className="w-6 h-6" />
              </div>
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800 border border-amber-200">
                PREMIUM
              </span>
            </div>
            <div className="mt-4">
              <div className="text-3xl font-extrabold text-amber-700 tracking-tight">
                {proBusinessesCount ?? 0}
              </div>
              <p className="text-xs font-semibold text-slate-500 mt-1">Akun PRO Aktif</p>
            </div>
          </div>

          {/* Card 3: Template Bisnis */}
          <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-700">
                <Layers className="w-6 h-6" />
              </div>
              <Link
                href="/dashboard/templates"
                className="text-xs text-slate-600 hover:text-slate-900 flex items-center gap-1 font-bold"
              >
                Lihat <ArrowUpRight className="w-3.5 h-3.5" />
              </Link>
            </div>
            <div className="mt-4">
              <div className="text-3xl font-extrabold text-slate-900 tracking-tight">
                {templatesCount ?? 0}
              </div>
              <p className="text-xs font-semibold text-slate-500 mt-1">Template Bisnis</p>
            </div>
          </div>

          {/* Card 4: Pengguna Owner */}
          <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600">
                <Users className="w-6 h-6" />
              </div>
              <span className="text-xs text-emerald-600 font-semibold flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> Cloud Sync
              </span>
            </div>
            <div className="mt-4">
              <div className="text-3xl font-extrabold text-slate-900 tracking-tight">
                {displayOwnersCount}
              </div>
              <p className="text-xs font-semibold text-slate-500 mt-1">Pemilik Bisnis Terdaftar</p>
            </div>
          </div>
        </div>

        {/* Two Column Layout: Recent Businesses & Templates Quick View */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column (2 cols): Recent Businesses */}
          <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-lg font-bold text-slate-900 tracking-tight">Bisnis Terbaru</h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Mitra bisnis yang baru saja terdaftar di platform
                </p>
              </div>
              <Link
                href="/dashboard/businesses"
                className="text-xs font-bold text-orange-600 hover:text-orange-700 flex items-center gap-1"
              >
                Lihat Semua <ArrowUpRight className="w-4 h-4" />
              </Link>
            </div>

            {recentBusinesses && recentBusinesses.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 text-slate-400 text-xs uppercase tracking-wider font-semibold bg-slate-50/60">
                      <th className="py-2.5 px-3 rounded-l-lg">Nama Bisnis</th>
                      <th className="py-2.5 px-3">Paket</th>
                      <th className="py-2.5 px-3">Tipe / Template</th>
                      <th className="py-2.5 px-3">Outlet</th>
                      <th className="py-2.5 px-3 text-right rounded-r-lg">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {recentBusinesses.map((b: any) => {
                      const isPro = b.subscription_plans?.code === 'pro';
                      return (
                        <tr key={b.id} className="hover:bg-slate-50 transition-colors">
                          <td className="py-3 px-3 font-semibold text-slate-900">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-lg bg-orange-100 text-orange-700 flex items-center justify-center font-bold text-xs">
                                {b.name?.charAt(0)?.toUpperCase() || 'B'}
                              </div>
                              <span>{b.name || 'Tanpa Nama'}</span>
                            </div>
                          </td>
                          <td className="py-3 px-3">
                            {isPro ? (
                              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-100 text-amber-800 border border-amber-200">
                                <Crown className="w-3 h-3 text-amber-600" /> PRO
                              </span>
                            ) : (
                              <span className="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold bg-slate-100 text-slate-600">
                                FREE
                              </span>
                            )}
                          </td>
                          <td className="py-3 px-3">
                            <span className="px-2 py-0.5 rounded-md text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                              {b.business_type || 'default'}
                            </span>
                          </td>
                          <td className="py-3 px-3 text-slate-600">{b.max_outlets ?? 1} Outlet</td>
                          <td className="py-3 px-3 text-right">
                            <Link
                              href="/dashboard/businesses"
                              className="text-xs font-bold text-orange-600 hover:text-orange-700"
                            >
                              Kelola
                            </Link>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-center py-12 text-slate-400 text-sm">
                Belum ada data bisnis yang ditemukan.
              </div>
            )}
          </div>

          {/* Right Column (1 col): Template Bisnis List */}
          <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-bold text-slate-900 tracking-tight">Template Tersedia</h3>
                <p className="text-xs text-slate-500 mt-0.5">Preset modul untuk jenis usaha</p>
              </div>
              <Link
                href="/dashboard/templates"
                className="text-xs font-bold text-orange-600 hover:text-orange-700"
              >
                Kelola
              </Link>
            </div>

            <div className="space-y-3 pt-2">
              {templates && templates.length > 0 ? (
                templates.map((tpl) => (
                  <div
                    key={tpl.id}
                    className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 hover:border-orange-300 transition-all flex items-center justify-between"
                  >
                    <div>
                      <div className="font-bold text-sm text-slate-900">{tpl.name}</div>
                      <div className="text-xs text-slate-500 flex items-center gap-2 mt-1">
                        <span className="font-mono text-[11px] text-orange-700 bg-orange-100 px-1.5 py-0.5 rounded border border-orange-200">
                          {tpl.code}
                        </span>
                        <span>{tpl.default_enabled_features?.length ?? 0} Modul</span>
                      </div>
                    </div>
                    <Link
                      href="/dashboard/templates"
                      className="p-1.5 rounded-lg text-slate-400 hover:text-orange-600 hover:bg-orange-50 transition-colors"
                    >
                      <ArrowUpRight className="w-4 h-4" />
                    </Link>
                  </div>
                ))
              ) : (
                <div className="text-center py-8 text-slate-400 text-xs">
                  Belum ada template bisnis yang dibuat.
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
