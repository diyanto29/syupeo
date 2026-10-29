'use client';

import { useState, useEffect, useMemo } from 'react';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Partner, PartnerCommission, PartnerPayout, AdminUser } from '@/types/database';
import {
  Users,
  UserPlus,
  DollarSign,
  Wallet,
  ArrowUpRight,
  TrendingUp,
  Search,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  Building2,
  ChevronRight,
  Phone,
  CreditCard,
  X,
  PlusCircle,
  Clock,
  Sparkles,
  KeyRound,
  UserCheck,
  Shield,
} from 'lucide-react';

export default function PartnersPage() {
  const [partners, setPartners] = useState<Partner[]>([]);
  const [commissions, setCommissions] = useState<PartnerCommission[]>([]);
  const [payouts, setPayouts] = useState<PartnerPayout[]>([]);
  const [businessCounts, setBusinessCounts] = useState<Record<string, number>>({});
  const [partnerAdmins, setPartnerAdmins] = useState<Record<string, AdminUser>>({});
  const [loading, setLoading] = useState(true);

  // Search
  const [searchQuery, setSearchQuery] = useState('');

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [selectedPartnerForPayout, setSelectedPartnerForPayout] = useState<Partner | null>(null);

  // Modal Login Account
  const [isAccountModalOpen, setIsAccountModalOpen] = useState(false);
  const [selectedPartnerForAccount, setSelectedPartnerForAccount] = useState<Partner | null>(null);
  const [accountEmail, setAccountEmail] = useState('');

  // Form States (Add/Edit Partner)
  const [partnerForm, setPartnerForm] = useState({
    id: '',
    name: '',
    phone: '',
    email: '',
    referral_code: '',
    commission_rate: 20,
    bank_name: 'BCA',
    bank_account_number: '',
    bank_account_holder: '',
    notes: '',
  });

  // Form States (Payout)
  const [payoutAmount, setPayoutAmount] = useState<number>(0);
  const [payoutNote, setPayoutNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      // 1. Fetch partners
      const { data: partnerData, error: partnerErr } = await supabase
        .from('partners')
        .select('*')
        .order('created_at', { ascending: false });

      if (partnerErr) throw partnerErr;

      // 2. Fetch admin_users with role partner
      const { data: adminData } = await supabase
        .from('admin_users')
        .select('*')
        .eq('role', 'partner');

      const adminMap: Record<string, AdminUser> = {};
      if (adminData) {
        adminData.forEach((a: any) => {
          if (a.partner_id) {
            adminMap[a.partner_id] = a;
          }
        });
      }
      setPartnerAdmins(adminMap);

      // 2. Fetch commissions
      const { data: commData, error: commErr } = await supabase
        .from('partner_commissions')
        .select('*');

      if (commErr) {
        console.warn('Could not load commissions:', commErr.message);
      }

      // 3. Fetch payouts
      const { data: payoutData, error: payoutErr } = await supabase
        .from('partner_payouts')
        .select('*');

      if (payoutErr) {
        console.warn('Could not load payouts:', payoutErr.message);
      }

      // 4. Fetch business counts per partner
      const { data: bizData, error: bizErr } = await supabase
        .from('businesses')
        .select('id, referred_by_partner_id');

      const counts: Record<string, number> = {};
      if (bizData) {
        bizData.forEach((b: any) => {
          if (b.referred_by_partner_id) {
            counts[b.referred_by_partner_id] = (counts[b.referred_by_partner_id] || 0) + 1;
          }
        });
      }

      setPartners((partnerData as Partner[]) || []);
      setCommissions((commData as PartnerCommission[]) || []);
      setPayouts((payoutData as PartnerPayout[]) || []);
      setBusinessCounts(counts);
    } catch (err: any) {
      setErrorMsg(`Gagal memuat data mitra: ${err?.message || 'Terjadi kesalahan sistem'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Compute stats per partner
  const partnerStatsMap = useMemo(() => {
    const map: Record<string, { earned: number; withdrawn: number; balance: number }> = {};

    partners.forEach((p) => {
      map[p.id] = { earned: 0, withdrawn: 0, balance: 0 };
    });

    commissions.forEach((c) => {
      if (map[c.partner_id] && c.status === 'earned') {
        map[c.partner_id].earned += Number(c.commission_amount || 0);
      }
    });

    payouts.forEach((po) => {
      if (map[po.partner_id] && po.status === 'completed') {
        map[po.partner_id].withdrawn += Number(po.amount || 0);
      }
    });

    Object.keys(map).forEach((pId) => {
      map[pId].balance = map[pId].earned - map[pId].withdrawn;
    });

    return map;
  }, [partners, commissions, payouts]);

  // Overall Global Metrics
  const globalMetrics = useMemo(() => {
    let totalEarned = 0;
    let totalWithdrawn = 0;

    commissions.forEach((c) => {
      if (c.status === 'earned') totalEarned += Number(c.commission_amount || 0);
    });

    payouts.forEach((po) => {
      if (po.status === 'completed') totalWithdrawn += Number(po.amount || 0);
    });

    return {
      totalPartners: partners.length,
      totalEarned,
      totalWithdrawn,
      availableBalance: totalEarned - totalWithdrawn,
    };
  }, [partners, commissions, payouts]);

  // Open Payout Modal
  const openPayoutModal = (partner: Partner) => {
    const stats = partnerStatsMap[partner.id] || { balance: 0 };
    setSelectedPartnerForPayout(partner);
    setPayoutAmount(stats.balance > 0 ? stats.balance : 0);
    setPayoutNote('');
    setIsPayoutModalOpen(true);
  };

  // Submit Partner Save (Add / Edit)
  const handleSavePartner = async () => {
    if (!partnerForm.name.trim()) {
      setErrorMsg('Nama mitra wajib diisi.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const payload: any = {
        name: partnerForm.name.trim(),
        phone: partnerForm.phone.trim() || null,
        email: partnerForm.email.trim() || null,
        referral_code: partnerForm.referral_code.trim().toUpperCase() || null,
        commission_rate: Number(partnerForm.commission_rate) || 20,
        bank_name: partnerForm.bank_name || null,
        bank_account_number: partnerForm.bank_account_number.trim() || null,
        bank_account_holder: partnerForm.bank_account_holder.trim() || null,
        notes: partnerForm.notes.trim() || null,
        status: 'active',
        updated_at: new Date().toISOString(),
      };

      if (partnerForm.id) {
        // Edit existing
        const { error } = await supabase.from('partners').update(payload).eq('id', partnerForm.id);
        if (error) throw error;
        setSuccessMsg(`Data mitra "${payload.name}" berhasil diperbarui.`);
      } else {
        // Add new
        const { error } = await supabase.from('partners').insert(payload);
        if (error) throw error;
        setSuccessMsg(`Mitra baru "${payload.name}" berhasil didaftarkan!`);
      }

      setIsAddModalOpen(false);
      setPartnerForm({
        id: '',
        name: '',
        phone: '',
        email: '',
        referral_code: '',
        commission_rate: 20,
        bank_name: 'BCA',
        bank_account_number: '',
        bank_account_holder: '',
        notes: '',
      });
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan mitra: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Submit Create Account for Partner
  const handleCreateAccountForPartner = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedPartnerForAccount || !accountEmail.trim()) return;

    setIsSubmitting(true);
    setErrorMsg(null);
    try {
      const cleanEmail = accountEmail.trim().toLowerCase();
      const { error } = await supabase.from('admin_users').insert({
        email: cleanEmail,
        name: selectedPartnerForAccount.name,
        role: 'partner',
        partner_id: selectedPartnerForAccount.id,
        is_active: true,
        can_manage_licenses: false,
      });

      if (error) {
        if (error.code === '23505') {
          throw new Error(`Email ${cleanEmail} sudah terdaftar sebagai akun pengguna.`);
        }
        throw error;
      }

      setSuccessMsg(`Akun login mitra berhasil dibuat untuk "${selectedPartnerForAccount.name}" (${cleanEmail})!`);
      setIsAccountModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(err?.message || 'Gagal membuat akun login mitra.');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Submit Payout
  const handleProcessPayout = async () => {
    if (!selectedPartnerForPayout) return;
    if (payoutAmount <= 0) {
      setErrorMsg('Nominal penarikan harus lebih dari 0.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const payoutPayload = {
        partner_id: selectedPartnerForPayout.id,
        amount: payoutAmount,
        bank_name: selectedPartnerForPayout.bank_name,
        bank_account_number: selectedPartnerForPayout.bank_account_number,
        bank_account_holder: selectedPartnerForPayout.bank_account_holder,
        status: 'completed',
        reference_note: payoutNote || 'Pencairan komisi langganan',
        processed_by: 'Admin Console',
        processed_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
      };

      const { error } = await supabase.from('partner_payouts').insert(payoutPayload);
      if (error) throw error;

      setSuccessMsg(
        `Penarikan saldo Rp ${payoutAmount.toLocaleString('id-ID')} untuk ${selectedPartnerForPayout.name} berhasil dicatat!`
      );
      setIsPayoutModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal memproses penarikan: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Filtered partners
  const filteredPartners = useMemo(() => {
    if (!searchQuery) return partners;
    const q = searchQuery.toLowerCase();
    return partners.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        (p.referral_code || '').toLowerCase().includes(q) ||
        (p.phone || '').toLowerCase().includes(q)
    );
  }, [partners, searchQuery]);

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Mitra & Komisi (Bagi Hasil)"
        description="Kelola teman & sales affiliate, pantau komisi berulang (recurring), dan riwayat pencairan saldo"
      />

      {/* Top Banner Alert / Success */}
      {successMsg && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600" />
            <span className="text-sm font-medium">{successMsg}</span>
          </div>
          <button onClick={() => setSuccessMsg(null)} className="text-emerald-700 hover:text-emerald-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {errorMsg && (
        <div className="p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-rose-600" />
            <span className="text-sm font-medium">{errorMsg}</span>
          </div>
          <button onClick={() => setErrorMsg(null)} className="text-rose-700 hover:text-rose-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* 4 Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-emerald-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Mitra</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-emerald-600">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{globalMetrics.totalPartners}</span>
            <span className="text-xs text-slate-500 ml-2">teman / partner</span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <Sparkles className="w-3.5 h-3.5 text-emerald-500" /> Penyalur langganan toko
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-amber-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Komisi Masuk</span>
            <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 flex items-center justify-center text-amber-600">
              <TrendingUp className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rp {globalMetrics.totalEarned.toLocaleString('id-ID')}
            </span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <ArrowUpRight className="w-3.5 h-3.5 text-amber-500" /> Total komisi yang pernah dicatat
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-indigo-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Sudah Dicairkan</span>
            <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center text-indigo-600">
              <CreditCard className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rp {globalMetrics.totalWithdrawn.toLocaleString('id-ID')}
            </span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5 text-indigo-500" /> Dana berhasil ditransfer ke teman
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-emerald-400 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Saldo Siap Tarik</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-500 text-white flex items-center justify-center shadow-xs">
              <Wallet className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-extrabold text-emerald-700 tracking-tight">
              Rp {globalMetrics.availableBalance.toLocaleString('id-ID')}
            </span>
          </div>
          <p className="mt-2 text-xs text-emerald-600 font-medium flex items-center gap-1">
            <Clock className="w-3.5 h-3.5" /> Total kewajiban komisi saat ini
          </p>
        </div>
      </div>

      {/* Main Container */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden">
        {/* Header Bar */}
        <div className="p-6 border-b border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-base font-extrabold text-slate-900">Daftar Mitra & Teman Bisnis</h2>
            <p className="text-xs text-slate-500 mt-0.5">
              Setiap perpanjangan langganan dari toko binaan mitra otomatis membagi hasil komisi
            </p>
          </div>

          <div className="flex items-center gap-3 w-full sm:w-auto">
            <button
              onClick={() => loadData()}
              disabled={loading}
              className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>

            <button
              onClick={() => {
                setPartnerForm({
                  id: '',
                  name: '',
                  phone: '',
                  email: '',
                  referral_code: '',
                  commission_rate: 20,
                  bank_name: 'BCA',
                  bank_account_number: '',
                  bank_account_holder: '',
                  notes: '',
                });
                setIsAddModalOpen(true);
              }}
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="flex-1 sm:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95"
            >
              <UserPlus className="w-4 h-4 text-white" />
              <span className="text-white">+ Tambah Mitra Baru</span>
            </button>
          </div>
        </div>

        {/* Filter and Search Bar */}
        <div className="p-4 bg-slate-50/60 border-b border-slate-100 flex items-center justify-between">
          <div className="relative w-full sm:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari nama mitra, kode referral, atau telepon..."
              value={searchQuery}
              onInput={(e) => setSearchQuery((e.target as HTMLInputElement).value)}
              className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all"
            />
          </div>
        </div>

        {/* Partners Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                <th className="py-3.5 px-6">Nama Mitra & Kode</th>
                <th className="py-3.5 px-4">Kontak & Rekening</th>
                <th className="py-3.5 px-4 text-center">Rate Komisi</th>
                <th className="py-3.5 px-4 text-center">Klien Binaan</th>
                <th className="py-3.5 px-4">Akun Login</th>
                <th className="py-3.5 px-4">Total Komisi Masuk</th>
                <th className="py-3.5 px-4">Saldo Siap Tarik</th>
                <th className="py-3.5 px-6 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-xs">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-slate-400" />
                    Memuat data mitra...
                  </td>
                </tr>
              ) : filteredPartners.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    Belum ada mitra terdaftar. Klik "+ Tambah Mitra Baru" untuk mulai.
                  </td>
                </tr>
              ) : (
                filteredPartners.map((p) => {
                  const stats = partnerStatsMap[p.id] || { earned: 0, withdrawn: 0, balance: 0 };
                  const clientCount = businessCounts[p.id] || 0;

                  return (
                    <tr key={p.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-700 font-bold shrink-0">
                            {p.name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <Link
                              href={`/dashboard/partners/${p.id}`}
                              className="font-bold text-slate-900 hover:text-emerald-600 transition-colors"
                            >
                              {p.name}
                            </Link>
                            {p.referral_code && (
                              <div className="text-[11px] font-mono text-emerald-700 bg-emerald-50 px-1.5 py-0.5 rounded-md inline-block mt-0.5 border border-emerald-100">
                                {p.referral_code}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>

                      <td className="py-4 px-4">
                        <div className="text-slate-800 font-semibold">{p.phone || '-'}</div>
                        <div className="text-[11px] text-slate-500">
                          {p.bank_name ? `${p.bank_name} - ${p.bank_account_number || ''}` : 'Belum isi rekening'}
                        </div>
                      </td>

                      <td className="py-4 px-4 text-center">
                        <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-extrabold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          {p.commission_rate}%
                        </span>
                      </td>

                      <td className="py-4 px-4 text-center">
                        <span className="font-bold text-slate-900 text-sm">{clientCount}</span>
                        <span className="text-[11px] text-slate-400 block">toko</span>
                      </td>

                      <td className="py-4 px-4">
                        {partnerAdmins[p.id] ? (
                          <div className="flex items-center gap-1.5">
                            <span className="w-2 h-2 rounded-full bg-emerald-500 shrink-0"></span>
                            <span
                              className="font-mono text-[11px] font-semibold text-slate-700 truncate max-w-[130px]"
                              title={partnerAdmins[p.id].email}
                            >
                              {partnerAdmins[p.id].email}
                            </span>
                          </div>
                        ) : (
                          <button
                            onClick={() => {
                              setSelectedPartnerForAccount(p);
                              setAccountEmail(p.email || '');
                              setIsAccountModalOpen(true);
                            }}
                            className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-50 hover:bg-emerald-600 hover:text-white text-emerald-800 text-[11px] font-bold transition-all border border-emerald-200"
                          >
                            <KeyRound className="w-3 h-3" />
                            <span>+ Buat Akun</span>
                          </button>
                        )}
                      </td>

                      <td className="py-4 px-4">
                        <div className="font-bold text-slate-900">
                          Rp {stats.earned.toLocaleString('id-ID')}
                        </div>
                        <div className="text-[10px] text-slate-400">
                          Ditarik: Rp {stats.withdrawn.toLocaleString('id-ID')}
                        </div>
                      </td>

                      <td className="py-4 px-4">
                        <span
                          className={`font-extrabold text-sm ${
                            stats.balance > 0 ? 'text-emerald-600' : 'text-slate-400'
                          }`}
                        >
                          Rp {stats.balance.toLocaleString('id-ID')}
                        </span>
                      </td>

                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => openPayoutModal(p)}
                            disabled={stats.balance <= 0}
                            className="px-2.5 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-600 hover:text-white text-emerald-700 text-xs font-semibold transition-all disabled:opacity-40 disabled:hover:bg-emerald-50 disabled:hover:text-emerald-700"
                            title="Tarik / Cairkan Saldo"
                          >
                            Cairkan
                          </button>

                          <Link
                            href={`/dashboard/partners/${p.id}`}
                            className="p-1.5 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-100 transition-colors"
                            title="Lihat Detail & Ledger"
                          >
                            <ChevronRight className="w-4 h-4" />
                          </Link>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL: TAMBAH / EDIT MITRA */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="p-6 bg-emerald-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <UserPlus className="w-5 h-5 text-emerald-200" />
                  <span className="text-white">{partnerForm.id ? 'Edit Data Mitra' : 'Daftarkan Mitra / Teman Baru'}</span>
                </h3>
                <p className="text-xs text-emerald-100 mt-0.5">
                  Mitra akan menerima komisi recurring setiap kali kliennya memperpanjang langganan
                </p>
              </div>
              <button
                onClick={() => setIsAddModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[75vh] overflow-y-auto text-xs">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Nama Mitra / Teman *</label>
                <input
                  type="text"
                  placeholder="Contoh: Budi Santoso"
                  value={partnerForm.name}
                  onInput={(e) => setPartnerForm({ ...partnerForm, name: (e.target as HTMLInputElement).value })}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-emerald-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">No. WhatsApp / HP</label>
                  <input
                    type="text"
                    placeholder="08123456789"
                    value={partnerForm.phone}
                    onInput={(e) => setPartnerForm({ ...partnerForm, phone: (e.target as HTMLInputElement).value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-emerald-500"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Kode Referral Unik</label>
                  <input
                    type="text"
                    placeholder="BUDI20"
                    value={partnerForm.referral_code}
                    onInput={(e) =>
                      setPartnerForm({ ...partnerForm, referral_code: (e.target as HTMLInputElement).value })
                    }
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-mono uppercase focus:outline-hidden focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  Persentase Komisi Default (%):
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="number"
                    min="1"
                    max="100"
                    value={partnerForm.commission_rate}
                    onInput={(e) =>
                      setPartnerForm({
                        ...partnerForm,
                        commission_rate: Number((e.target as HTMLInputElement).value),
                      })
                    }
                    className="w-32 px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold"
                  />
                  <span className="text-slate-500 text-[11px]">
                    Contoh: 20% dari setiap perpanjangan Pro (Rp 49.000 = Rp 9.800)
                  </span>
                </div>
              </div>

              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <span className="font-bold text-slate-800 block">Informasi Rekening Pencairan:</span>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block font-medium text-slate-600 mb-1">Bank / E-Wallet</label>
                    <input
                      type="text"
                      placeholder="BCA / Mandiri / GoPay"
                      value={partnerForm.bank_name}
                      onInput={(e) =>
                        setPartnerForm({ ...partnerForm, bank_name: (e.target as HTMLInputElement).value })
                      }
                      className="w-full px-3 py-1.5 rounded-lg border border-slate-200 text-slate-900 bg-white"
                    />
                  </div>
                  <div>
                    <label className="block font-medium text-slate-600 mb-1">Nomor Rekening</label>
                    <input
                      type="text"
                      placeholder="1234567890"
                      value={partnerForm.bank_account_number}
                      onInput={(e) =>
                        setPartnerForm({
                          ...partnerForm,
                          bank_account_number: (e.target as HTMLInputElement).value,
                        })
                      }
                      className="w-full px-3 py-1.5 rounded-lg border border-slate-200 text-slate-900 bg-white"
                    />
                  </div>
                </div>
                <div>
                  <label className="block font-medium text-slate-600 mb-1">Nama Pemilik Rekening</label>
                  <input
                    type="text"
                    placeholder="Budi Santoso"
                    value={partnerForm.bank_account_holder}
                    onInput={(e) =>
                      setPartnerForm({
                        ...partnerForm,
                        bank_account_holder: (e.target as HTMLInputElement).value,
                      })
                    }
                    className="w-full px-3 py-1.5 rounded-lg border border-slate-200 text-slate-900 bg-white"
                  />
                </div>
              </div>
            </div>

            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setIsAddModalOpen(false)}
                className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleSavePartner}
                disabled={isSubmitting}
                style={{ backgroundColor: '#059669', color: '#ffffff' }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    <span className="text-white">Menyimpan...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-white" />
                    <span className="text-white">Simpan Mitra</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: CAIRKAN SALDO (PAYOUT) */}
      {isPayoutModalOpen && selectedPartnerForPayout && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="p-6 bg-emerald-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <Wallet className="w-5 h-5 text-emerald-200" />
                  <span className="text-white">Cairkan Saldo Komisi</span>
                </h3>
                <p className="text-xs text-emerald-100 mt-0.5">{selectedPartnerForPayout.name}</p>
              </div>
              <button
                onClick={() => setIsPayoutModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-100">
                <span className="text-slate-600 block">Saldo Siap Tarik Saat Ini:</span>
                <span className="text-2xl font-extrabold text-emerald-800">
                  Rp {(partnerStatsMap[selectedPartnerForPayout.id]?.balance || 0).toLocaleString('id-ID')}
                </span>
                <div className="mt-2 pt-2 border-t border-emerald-200/60 text-[11px] text-slate-600">
                  Rekening Tujuan: <br />
                  <strong className="text-slate-900">
                    {selectedPartnerForPayout.bank_name || 'Bank'} -{' '}
                    {selectedPartnerForPayout.bank_account_number || '-'}{' '}
                    (a.n {selectedPartnerForPayout.bank_account_holder || selectedPartnerForPayout.name})
                  </strong>
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Nominal yang Dicairkan (Rp) *</label>
                <input
                  type="number"
                  value={payoutAmount}
                  onInput={(e) => setPayoutAmount(Number((e.target as HTMLInputElement).value))}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold text-base focus:outline-hidden focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Catatan / Bukti Referensi Transfer</label>
                <input
                  type="text"
                  placeholder="Contoh: No Ref Transfer BCA 9812448 / TF Manual"
                  value={payoutNote}
                  onInput={(e) => setPayoutNote((e.target as HTMLInputElement).value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900"
                />
              </div>
            </div>

            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setIsPayoutModalOpen(false)}
                className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleProcessPayout}
                disabled={isSubmitting || payoutAmount <= 0}
                style={{ backgroundColor: '#059669', color: '#ffffff' }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    <span className="text-white">Memproses...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-white" />
                    <span className="text-white">Konfirmasi Pencairan</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: BUAT AKUN LOGIN MITRA */}
      {isAccountModalOpen && selectedPartnerForAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="p-6 bg-emerald-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <KeyRound className="w-5 h-5 text-emerald-200" />
                  <span className="text-white">Buat Akun Login Mitra</span>
                </h3>
                <p className="text-xs text-emerald-100 mt-0.5">
                  Berikan akses login khusus Mitra untuk {selectedPartnerForAccount.name}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsAccountModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>
            </div>

            <form onSubmit={handleCreateAccountForPartner} className="p-6 space-y-4">
              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs space-y-1">
                <div className="font-bold text-slate-800">Profil Mitra:</div>
                <div className="text-slate-600">
                  Nama: <strong className="text-slate-900">{selectedPartnerForAccount.name}</strong>
                </div>
                <div className="text-slate-600">
                  Komisi: <strong className="text-emerald-700">{selectedPartnerForAccount.commission_rate}%</strong>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Email Akun Google Mitra *
                </label>
                <input
                  type="email"
                  required
                  placeholder="mitra@gmail.com"
                  value={accountEmail}
                  onChange={(e) => setAccountEmail(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-slate-900 font-semibold text-xs focus:outline-hidden focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                />
                <p className="text-[11px] text-slate-400 mt-1">
                  Mitra dapat login ke Admin Web menggunakan Google SSO dengan email ini.
                </p>
              </div>

              <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-[11px] text-emerald-900 leading-relaxed">
                💡 Mitra hanya memiliki akses ke <strong>Dashboard Mitra</strong>, <strong>Mini CRM</strong>, dan <strong>Surat Penawaran</strong> milik mereka sendiri.
              </div>

              <div className="p-5 -mx-6 -mb-6 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3 mt-6">
                <button
                  type="button"
                  onClick={() => setIsAccountModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || !accountEmail.trim()}
                  style={{ backgroundColor: '#059669', color: '#ffffff' }}
                  className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50"
                >
                  {isSubmitting ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin text-white" />
                      <span className="text-white">Menyimpan...</span>
                    </>
                  ) : (
                    <>
                      <UserCheck className="w-4 h-4 text-white" />
                      <span className="text-white">Buat Akun Login</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
