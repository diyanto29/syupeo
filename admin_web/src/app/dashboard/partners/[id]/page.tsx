'use client';

import { useState, useEffect, useMemo } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Business, Partner, PartnerCommission, PartnerPayout } from '@/types/database';
import {
  Users,
  ArrowLeft,
  Wallet,
  DollarSign,
  TrendingUp,
  CreditCard,
  Building2,
  Phone,
  Calendar,
  Clock,
  CheckCircle2,
  AlertTriangle,
  History,
  Sparkles,
  ExternalLink,
  Crown,
  Gift,
  RefreshCw,
  PlusCircle,
  X,
} from 'lucide-react';

export default function PartnerDetailPage() {
  const params = useParams();
  const partnerId = params?.id as string;
  const router = useRouter();

  const [partner, setPartner] = useState<Partner | null>(null);
  const [referredBusinesses, setReferredBusinesses] = useState<Business[]>([]);
  const [commissions, setCommissions] = useState<PartnerCommission[]>([]);
  const [payouts, setPayouts] = useState<PartnerPayout[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'clients' | 'commissions' | 'payouts'>('clients');

  // Payout Modal
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [payoutAmount, setPayoutAmount] = useState<number>(0);
  const [payoutNote, setPayoutNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadPartnerData = async () => {
    if (!partnerId) return;
    setLoading(true);
    setErrorMsg(null);

    try {
      // 1. Fetch partner detail
      const { data: pData, error: pErr } = await supabase
        .from('partners')
        .select('*')
        .eq('id', partnerId)
        .single();

      if (pErr) throw pErr;

      // 2. Fetch referred businesses
      const { data: bData, error: bErr } = await supabase
        .from('businesses')
        .select('*, profiles(id, full_name, email, phone), subscription_plans(*)')
        .eq('referred_by_partner_id', partnerId)
        .order('created_at', { ascending: false });

      if (bErr) throw bErr;

      // 3. Fetch commissions ledger
      const { data: cData, error: cErr } = await supabase
        .from('partner_commissions')
        .select('*, businesses(id, name)')
        .eq('partner_id', partnerId)
        .order('created_at', { ascending: false });

      if (cErr) console.warn('Commissions load warning:', cErr.message);

      // 4. Fetch payouts ledger
      const { data: poData, error: poErr } = await supabase
        .from('partner_payouts')
        .select('*')
        .eq('partner_id', partnerId)
        .order('created_at', { ascending: false });

      if (poErr) console.warn('Payouts load warning:', poErr.message);

      setPartner(pData as Partner);
      setReferredBusinesses((bData as Business[]) || []);
      setCommissions((cData as PartnerCommission[]) || []);
      setPayouts((poData as PartnerPayout[]) || []);
    } catch (err: any) {
      setErrorMsg(`Gagal memuat detail mitra: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPartnerData();
  }, [partnerId]);

  // Compute Balances
  const walletStats = useMemo(() => {
    let earned = 0;
    let withdrawn = 0;

    commissions.forEach((c) => {
      if (c.status === 'earned') earned += Number(c.commission_amount || 0);
    });

    payouts.forEach((po) => {
      if (po.status === 'completed') withdrawn += Number(po.amount || 0);
    });

    const balance = earned - withdrawn;

    return {
      earned,
      withdrawn,
      balance,
    };
  }, [commissions, payouts]);

  // Handle Payout
  const handleProcessPayout = async () => {
    if (!partner) return;
    if (payoutAmount <= 0) {
      setErrorMsg('Nominal penarikan harus lebih dari 0.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const payoutPayload = {
        partner_id: partner.id,
        amount: payoutAmount,
        bank_name: partner.bank_name,
        bank_account_number: partner.bank_account_number,
        bank_account_holder: partner.bank_account_holder,
        status: 'completed',
        reference_note: payoutNote || 'Pencairan komisi langganan',
        processed_by: 'Admin Console',
        processed_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
      };

      const { error } = await supabase.from('partner_payouts').insert(payoutPayload);
      if (error) throw error;

      setSuccessMsg(
        `Penarikan saldo Rp ${payoutAmount.toLocaleString('id-ID')} berhasil dicatat untuk ${partner.name}!`
      );
      setIsPayoutModalOpen(false);
      await loadPartnerData();
    } catch (err: any) {
      setErrorMsg(`Gagal mencatat penarikan: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading && !partner) {
    return (
      <div className="p-12 text-center text-slate-500">
        <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-3 text-emerald-600" />
        Memuat detail mitra...
      </div>
    );
  }

  if (!partner) {
    return (
      <div className="p-12 text-center text-slate-500">
        <p>Mitra tidak ditemukan.</p>
        <Link
          href="/dashboard/partners"
          className="inline-flex items-center gap-1.5 mt-4 text-xs font-bold text-emerald-600"
        >
          <ArrowLeft className="w-4 h-4" /> Kembali ke Daftar Mitra
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title={`Mitra: ${partner.name}`}
        description={`Buku kas komisi, saldo siap tarik, dan daftar klien langganan binaan ${partner.name}`}
      />

      {/* Back button */}
      <div>
        <Link
          href="/dashboard/partners"
          className="inline-flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-slate-900 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Kembali ke Daftar Mitra</span>
        </Link>
      </div>

      {/* Alerts */}
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

      {/* Profile & Wallet Banner */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Partner Info Card */}
        <div className="bg-white p-6 rounded-3xl border border-slate-200/80 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-2xl bg-emerald-600 bg-gradient-to-tr from-emerald-600 to-teal-500 text-white font-extrabold text-2xl flex items-center justify-center shadow-sm">
                {partner.name.charAt(0).toUpperCase()}
              </div>
              <div>
                <h2 className="text-lg font-extrabold text-slate-900">{partner.name}</h2>
                <div className="flex items-center gap-2 mt-0.5">
                  {partner.referral_code && (
                    <span className="text-xs font-mono font-bold bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-md border border-emerald-200">
                      {partner.referral_code}
                    </span>
                  )}
                  <span className="text-xs font-extrabold bg-amber-50 text-amber-700 px-2 py-0.5 rounded-md border border-amber-200">
                    Komisi {partner.commission_rate}%
                  </span>
                </div>
              </div>
            </div>

            <div className="mt-6 space-y-2 text-xs">
              <div className="flex items-center justify-between py-1 border-b border-slate-100">
                <span className="text-slate-500">Nomor Telepon / WhatsApp:</span>
                <span className="font-semibold text-slate-900">{partner.phone || '-'}</span>
              </div>
              <div className="flex items-center justify-between py-1 border-b border-slate-100">
                <span className="text-slate-500">Rekening Tujuan:</span>
                <span className="font-semibold text-slate-900">
                  {partner.bank_name || 'Bank'} - {partner.bank_account_number || '-'}
                </span>
              </div>
              <div className="flex items-center justify-between py-1">
                <span className="text-slate-500">Atas Nama Rekening:</span>
                <span className="font-semibold text-slate-900">
                  {partner.bank_account_holder || partner.name}
                </span>
              </div>
            </div>
          </div>

          {partner.phone && (
            <div className="mt-6 pt-4 border-t border-slate-100">
              <a
                href={`https://wa.me/${partner.phone.replace(/[^0-9]/g, '')}`}
                target="_blank"
                rel="noreferrer"
                className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs transition-colors"
              >
                <Phone className="w-4 h-4" />
                <span>Hubungi via WhatsApp</span>
              </a>
            </div>
          )}
        </div>

        {/* Wallet Stats Cards */}
        <div className="lg:col-span-2 grid grid-cols-1 sm:grid-cols-3 gap-5">
          {/* Card 1: Saldo Siap Tarik */}
          <div className="bg-emerald-600 bg-gradient-to-br from-emerald-600 to-teal-700 text-white p-6 rounded-3xl shadow-lg flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-emerald-100 uppercase tracking-wider">
                  Saldo Siap Tarik
                </span>
                <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center">
                  <Wallet className="w-5 h-5 text-white" />
                </div>
              </div>
              <div className="mt-4">
                <span className="text-3xl font-black tracking-tight">
                  Rp {walletStats.balance.toLocaleString('id-ID')}
                </span>
              </div>
              <p className="mt-2 text-xs text-emerald-100">
                Dapat langsung dicairkan / ditransfer ke teman
              </p>
            </div>

            <div className="mt-6">
              <button
                onClick={() => {
                  setPayoutAmount(walletStats.balance > 0 ? walletStats.balance : 0);
                  setPayoutNote('');
                  setIsPayoutModalOpen(true);
                }}
                disabled={walletStats.balance <= 0}
                style={{ backgroundColor: '#ffffff', color: '#047857' }}
                className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-white text-emerald-800 hover:bg-emerald-50 text-xs font-extrabold shadow-md transition-all disabled:opacity-40"
              >
                <CreditCard className="w-4 h-4 text-emerald-700" />
                <span className="text-emerald-800">Cairkan Saldo</span>
              </button>
            </div>
          </div>

          {/* Card 2: Total Komisi Masuk */}
          <div className="bg-white p-6 rounded-3xl border border-slate-200/80 shadow-xs flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Total Komisi Masuk
                </span>
                <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5" />
                </div>
              </div>
              <div className="mt-4">
                <span className="text-2xl font-black text-slate-900 tracking-tight">
                  Rp {walletStats.earned.toLocaleString('id-ID')}
                </span>
              </div>
              <p className="mt-2 text-xs text-slate-500">
                Dari {commissions.length} kali transaksi langganan
              </p>
            </div>
            <div className="mt-6 pt-3 border-t border-slate-100 text-[11px] text-emerald-600 font-semibold flex items-center gap-1">
              <Sparkles className="w-3.5 h-3.5" /> Recurring otomatis
            </div>
          </div>

          {/* Card 3: Total Sudah Dicairkan */}
          <div className="bg-white p-6 rounded-3xl border border-slate-200/80 shadow-xs flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Sudah Dicairkan
                </span>
                <div className="w-10 h-10 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center">
                  <CheckCircle2 className="w-5 h-5" />
                </div>
              </div>
              <div className="mt-4">
                <span className="text-2xl font-black text-slate-900 tracking-tight">
                  Rp {walletStats.withdrawn.toLocaleString('id-ID')}
                </span>
              </div>
              <p className="mt-2 text-xs text-slate-500">
                Dalam {payouts.length} kali penarikan dana
              </p>
            </div>
            <div className="mt-6 pt-3 border-t border-slate-100 text-[11px] text-slate-500">
              Riwayat transfer tercatat
            </div>
          </div>
        </div>
      </div>

      {/* Tabs & Ledgers */}
      <div className="bg-white rounded-3xl border border-slate-200/80 shadow-xs overflow-hidden">
        {/* Tab Navigation */}
        <div className="p-6 border-b border-slate-100 flex items-center gap-3 bg-slate-50/50">
          <button
            onClick={() => setActiveTab('clients')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'clients'
                ? 'bg-white text-slate-900 shadow-xs border border-slate-200'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Klien Binaan ({referredBusinesses.length})
          </button>

          <button
            onClick={() => setActiveTab('commissions')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'commissions'
                ? 'bg-white text-slate-900 shadow-xs border border-slate-200'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Buku Kas Komisi Masuk ({commissions.length})
          </button>

          <button
            onClick={() => setActiveTab('payouts')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'payouts'
                ? 'bg-white text-slate-900 shadow-xs border border-slate-200'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Riwayat Penarikan Dana ({payouts.length})
          </button>
        </div>

        {/* Tab 1: Klien Binaan */}
        {activeTab === 'clients' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-6">Toko / Client</th>
                  <th className="py-3.5 px-4">Status Paket</th>
                  <th className="py-3.5 px-4">Masa Berlaku</th>
                  <th className="py-3.5 px-6 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {referredBusinesses.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="py-12 text-center text-slate-400">
                      Belum ada toko yang didaftarkan melalui mitra ini.
                    </td>
                  </tr>
                ) : (
                  referredBusinesses.map((b) => {
                    const isPro = b.subscription_plans?.code === 'pro';
                    const isTrial = b.subscription_status === 'trial';
                    const hasEnd = !!b.subscription_end_at;
                    const endDate = hasEnd ? new Date(b.subscription_end_at!) : null;

                    return (
                      <tr key={b.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="py-4 px-6">
                          <div className="font-bold text-slate-900">{b.name}</div>
                          <div className="text-[11px] text-slate-500">
                            {b.profiles?.full_name || 'Owner'} • {b.profiles?.phone || '-'}
                          </div>
                        </td>

                        <td className="py-4 px-4">
                          {isTrial ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-indigo-50 border border-indigo-200 text-indigo-700">
                              <Gift className="w-3 h-3" /> Trial
                            </span>
                          ) : isPro ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-50 border border-amber-200 text-amber-700">
                              <Crown className="w-3 h-3" /> Paket PRO
                            </span>
                          ) : (
                            <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold bg-slate-100 text-slate-600">
                              Free
                            </span>
                          )}
                        </td>

                        <td className="py-4 px-4">
                          <div className="font-semibold text-slate-800">
                            {hasEnd ? (
                              endDate!.toLocaleDateString('id-ID', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                              })
                            ) : isPro ? (
                              'Lifetime'
                            ) : (
                              '-'
                            )}
                          </div>
                        </td>

                        <td className="py-4 px-6 text-right">
                          <Link
                            href="/dashboard/subscriptions"
                            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-amber-500 hover:text-white text-slate-700 font-semibold transition-all"
                          >
                            <span>Perpanjang</span>
                          </Link>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}

        {/* Tab 2: Buku Kas Komisi Masuk (Ledger) */}
        {activeTab === 'commissions' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-6">Waktu Transaksi</th>
                  <th className="py-3.5 px-4">Dari Toko Klien</th>
                  <th className="py-3.5 px-4">Nominal Langganan</th>
                  <th className="py-3.5 px-4">Persentase</th>
                  <th className="py-3.5 px-4">Komisi Diterima</th>
                  <th className="py-3.5 px-6">Keterangan</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {commissions.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-slate-400">
                      Belum ada komisi masuk dari perpanjangan klien.
                    </td>
                  </tr>
                ) : (
                  commissions.map((c) => (
                    <tr key={c.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-4 px-6 text-slate-500 whitespace-nowrap">
                        {new Date(c.created_at).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>

                      <td className="py-4 px-4 font-bold text-slate-900">
                        {c.businesses?.name || 'Toko Klien'}
                      </td>

                      <td className="py-4 px-4 font-semibold text-slate-700">
                        Rp {Number(c.subscription_amount).toLocaleString('id-ID')}
                      </td>

                      <td className="py-4 px-4">
                        <span className="font-extrabold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 text-[11px] border border-emerald-200">
                          {c.commission_rate}%
                        </span>
                      </td>

                      <td className="py-4 px-4 font-extrabold text-emerald-700 text-sm">
                        + Rp {Number(c.commission_amount).toLocaleString('id-ID')}
                      </td>

                      <td className="py-4 px-6 text-slate-500 max-w-xs truncate">
                        {c.description || 'Komisi langganan'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}

        {/* Tab 3: Riwayat Penarikan Dana (Payouts) */}
        {activeTab === 'payouts' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-6">Waktu Penarikan</th>
                  <th className="py-3.5 px-4">Nominal Ditarik</th>
                  <th className="py-3.5 px-4">Rekening Tujuan</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-6">Catatan Transfer & Admin</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {payouts.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      Belum pernah ada riwayat penarikan dana.
                    </td>
                  </tr>
                ) : (
                  payouts.map((po) => (
                    <tr key={po.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-4 px-6 text-slate-500 whitespace-nowrap">
                        {new Date(po.created_at).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>

                      <td className="py-4 px-4 font-extrabold text-slate-900 text-sm">
                        Rp {Number(po.amount).toLocaleString('id-ID')}
                      </td>

                      <td className="py-4 px-4">
                        <div className="font-semibold text-slate-800">
                          {po.bank_name || 'Bank'} - {po.bank_account_number || '-'}
                        </div>
                        <div className="text-[11px] text-slate-400">
                          a.n {po.bank_account_holder || '-'}
                        </div>
                      </td>

                      <td className="py-4 px-4">
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <CheckCircle2 className="w-3 h-3" /> Berhasil
                        </span>
                      </td>

                      <td className="py-4 px-6 text-slate-500">
                        <div>{po.reference_note || '-'}</div>
                        <div className="text-[10px] text-slate-400">Oleh: {po.processed_by || 'Admin'}</div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* MODAL: CAIRKAN SALDO */}
      {isPayoutModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="p-6 bg-emerald-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <CreditCard className="w-5 h-5 text-emerald-200" />
                  <span className="text-white">Cairkan Saldo Mitra</span>
                </h3>
                <p className="text-xs text-emerald-100 mt-0.5">{partner.name}</p>
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
                <span className="text-slate-600 block">Saldo Tersedia:</span>
                <span className="text-2xl font-extrabold text-emerald-800">
                  Rp {walletStats.balance.toLocaleString('id-ID')}
                </span>
                <div className="mt-2 pt-2 border-t border-emerald-200/60 text-[11px] text-slate-600">
                  Rekening Tujuan: <br />
                  <strong className="text-slate-900">
                    {partner.bank_name || 'Bank'} - {partner.bank_account_number || '-'}{' '}
                    (a.n {partner.bank_account_holder || partner.name})
                  </strong>
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Nominal yang Dicairkan (Rp) *</label>
                <input
                  type="number"
                  value={payoutAmount}
                  onInput={(e) => setPayoutAmount(Number((e.target as HTMLInputElement).value))}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold text-base"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Catatan / No Referensi Transfer</label>
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
    </div>
  );
}
