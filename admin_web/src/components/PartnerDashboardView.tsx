'use client';

import { useState } from 'react';
import Link from 'next/link';
import {
  Users,
  Award,
  Wallet,
  DollarSign,
  TrendingUp,
  ArrowUpRight,
  Target,
  FileText,
  Copy,
  Check,
  Building2,
  Calendar,
  CreditCard,
  PlusCircle,
  Clock,
  CheckCircle2,
  AlertCircle,
  HelpCircle,
  Sparkles,
} from 'lucide-react';
import { Partner, PartnerCommission, PartnerPayout, Lead } from '@/types/database';
import { createClient } from '@/lib/supabase/client';

interface PartnerDashboardViewProps {
  partner: Partner;
  commissions: PartnerCommission[];
  payouts: PartnerPayout[];
  leads: Lead[];
  activeClientsCount: number;
}

export default function PartnerDashboardView({
  partner,
  commissions: initialCommissions,
  payouts: initialPayouts,
  leads,
  activeClientsCount,
}: PartnerDashboardViewProps) {
  const [commissions, setCommissions] = useState<PartnerCommission[]>(initialCommissions);
  const [payouts, setPayouts] = useState<PartnerPayout[]>(initialPayouts);
  const [copiedCode, setCopiedCode] = useState(false);
  const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState(false);
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [withdrawNote, setWithdrawNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const supabase = createClient();

  // Financial calculations
  const totalEarned = commissions
    .filter((c) => c.status !== 'cancelled')
    .reduce((sum, c) => sum + Number(c.commission_amount || 0), 0);

  const totalWithdrawn = payouts
    .filter((p) => p.status === 'completed')
    .reduce((sum, p) => sum + Number(p.amount || 0), 0);

  const pendingWithdrawn = payouts
    .filter((p) => p.status === 'pending')
    .reduce((sum, p) => sum + Number(p.amount || 0), 0);

  const availableBalance = Math.max(0, totalEarned - totalWithdrawn - pendingWithdrawn);

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(val);
  };

  const copyReferralCode = () => {
    if (!partner.referral_code) return;
    navigator.clipboard.writeText(partner.referral_code);
    setCopiedCode(true);
    setTimeout(() => setCopiedCode(false), 2000);
  };

  const handleRequestPayout = async (e: React.FormEvent) => {
    e.preventDefault();
    setMsg(null);
    const amount = Number(withdrawAmount.replace(/[^0-9]/g, ''));

    if (amount <= 0) {
      setMsg({ type: 'error', text: 'Nominal penarikan harus lebih dari Rp 0.' });
      return;
    }

    if (amount > availableBalance) {
      setMsg({
        type: 'error',
        text: `Saldo komisi tersedia tidak mencukupi (${formatRupiah(availableBalance)}).`,
      });
      return;
    }

    if (amount < 50000) {
      setMsg({ type: 'error', text: 'Minimal penarikan saldo adalah Rp 50.000.' });
      return;
    }

    setIsSubmitting(true);
    try {
      const payload = {
        partner_id: partner.id,
        amount: amount,
        bank_name: partner.bank_name || 'BCA',
        bank_account_number: partner.bank_account_number || '-',
        bank_account_holder: partner.bank_account_holder || partner.name,
        status: 'pending',
        reference_note: withdrawNote.trim() || 'Pengajuan penarikan komisi mandiri via portal mitra',
        created_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from('partner_payouts')
        .insert(payload)
        .select()
        .single();

      if (error) throw error;

      if (data) {
        setPayouts([data as PartnerPayout, ...payouts]);
      }

      setMsg({
        type: 'success',
        text: 'Pengajuan penarikan dana berhasil dikirim ke Super Admin!',
      });
      setIsWithdrawModalOpen(false);
      setWithdrawAmount('');
      setWithdrawNote('');
    } catch (err: any) {
      setMsg({ type: 'error', text: err?.message || 'Gagal mengajukan penarikan.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Alert Notification */}
      {msg && (
        <div
          className={`p-4 rounded-2xl flex items-center justify-between text-sm ${
            msg.type === 'success'
              ? 'bg-emerald-50 text-emerald-800 border border-emerald-200'
              : 'bg-red-50 text-red-800 border border-red-200'
          }`}
        >
          <div className="flex items-center gap-2">
            {msg.type === 'success' ? (
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
            ) : (
              <AlertCircle className="w-5 h-5 text-red-600" />
            )}
            <span>{msg.text}</span>
          </div>
          <button
            onClick={() => setMsg(null)}
            className="text-xs font-semibold underline hover:opacity-80"
          >
            Tutup
          </button>
        </div>
      )}

      {/* Hero Banner */}
      <div className="relative overflow-hidden rounded-3xl p-6 sm:p-8 bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-700 text-white shadow-xl shadow-emerald-600/15">
        <div className="absolute -top-12 -right-12 w-64 h-64 bg-white/10 rounded-full blur-2xl pointer-events-none" />
        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-white/20 text-white border border-white/30 backdrop-blur-xs">
              <Sparkles className="w-3.5 h-3.5" />
              Portal Kemitraan & Marketer Resmi
            </div>
            <h2 className="text-2xl sm:text-3xl font-black tracking-tight">
              Halo, {partner.name}! 👋
            </h2>
            <p className="text-sm text-emerald-100 max-w-2xl leading-relaxed">
              Dapatkan bagi hasil sebesar{' '}
              <span className="font-extrabold text-white underline decoration-amber-300 decoration-2">
                {partner.commission_rate}%
              </span>{' '}
              dari setiap aktivasi paket usaha Starter Kit Syupeo untuk mitra toko retail rujukan Anda.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Referral Code Box */}
            {partner.referral_code && (
              <div className="bg-white/15 backdrop-blur-md border border-white/30 rounded-2xl px-4 py-2.5 flex items-center gap-3 shadow-inner">
                <div>
                  <div className="text-[10px] font-medium text-emerald-200 uppercase tracking-wider">
                    Kode Referral Anda
                  </div>
                  <div className="font-mono font-black text-base text-white tracking-wider">
                    {partner.referral_code}
                  </div>
                </div>
                <button
                  onClick={copyReferralCode}
                  className="p-2 rounded-xl bg-white text-emerald-700 hover:bg-emerald-50 active:scale-95 transition-all shadow-xs"
                  title="Salin Kode Referral"
                >
                  {copiedCode ? <Check className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
                </button>
              </div>
            )}

            <Link
              href="/dashboard/subscriptions"
              className="inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-white/20 hover:bg-white/30 text-white font-extrabold text-sm border border-white/30 backdrop-blur-xs transition-all active:scale-95 shadow-sm"
            >
              <CreditCard className="w-4 h-4 text-emerald-200" />
              <span>Beri PRO Trial Toko (7-60 Hari)</span>
            </Link>

            <button
              onClick={() => setIsWithdrawModalOpen(true)}
              className="inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-amber-400 hover:bg-amber-300 text-slate-900 font-extrabold text-sm shadow-md transition-all active:scale-95"
            >
              <Wallet className="w-4 h-4" />
              Tarik Saldo Komisi
            </button>
          </div>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Saldo Tersedia */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Saldo Siap Ditarik
            </span>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 border border-emerald-100 flex items-center justify-center">
              <Wallet className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-slate-900 tracking-tight">
              {formatRupiah(availableBalance)}
            </div>
            <div className="mt-1 text-xs text-slate-500 flex items-center gap-1">
              <span>Rekening: {partner.bank_name || 'BCA'} {partner.bank_account_number || '-'}</span>
            </div>
          </div>
        </div>

        {/* Card 2: Total Komisi Didapat */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Total Komisi Masuk
            </span>
            <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 border border-blue-100 flex items-center justify-center">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-slate-900 tracking-tight">
              {formatRupiah(totalEarned)}
            </div>
            <div className="mt-1 text-xs text-blue-600 font-semibold">
              Dari {commissions.length} transaksi langganan klien
            </div>
          </div>
        </div>

        {/* Card 3: Klien Berlangganan Aktif */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Klien Aktif Pro
            </span>
            <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 border border-amber-100 flex items-center justify-center">
              <Award className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-slate-900 tracking-tight">
              {activeClientsCount} Toko
            </div>
            <div className="mt-1 text-xs text-slate-500">
              Paket Pro aktif saat ini
            </div>
          </div>
        </div>

        {/* Card 4: Total Prospek CRM */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Total Prospek (CRM)
            </span>
            <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 border border-purple-100 flex items-center justify-center">
              <Target className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-slate-900 tracking-tight">
              {leads.length} Calon Klien
            </div>
            <div className="mt-1 text-xs text-purple-600 font-semibold">
              Di pipeline follow-up Anda
            </div>
          </div>
        </div>
      </div>

      {/* Main Section: Riwayat Komisi & Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column (2 Cols): Riwayat Komisi Masuk (Billing) */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-xs p-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <h3 className="text-lg font-black text-slate-900 tracking-tight">
                  Riwayat Komisi Masuk
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Komisi otomatis tercatat setiap kali Super Admin mengaktifkan atau memperpanjang paket klien Anda
                </p>
              </div>
              <span className="px-2.5 py-1 text-xs font-bold bg-slate-100 text-slate-700 rounded-lg border border-slate-200">
                {commissions.length} Transaksi
              </span>
            </div>

            {commissions.length === 0 ? (
              <div className="py-12 text-center text-slate-400">
                <DollarSign className="w-12 h-12 mx-auto stroke-1 text-slate-300 mb-2" />
                <p className="font-semibold text-slate-600">Belum ada komisi masuk</p>
                <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
                  Tambahkan prospek di CRM atau buat surat penawaran. Ketika klien Anda berlangganan, komisi otomatis masuk ke sini!
                </p>
              </div>
            ) : (
              <div className="divide-y divide-slate-100 mt-2">
                {commissions.map((comm) => (
                  <div key={comm.id} className="py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-100 flex items-center justify-center flex-shrink-0 font-bold">
                        <DollarSign className="w-5 h-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="font-bold text-sm text-slate-900 truncate">
                          {comm.businesses?.name || 'Toko Klien'}
                        </div>
                        <div className="text-xs text-slate-500 truncate mt-0.5">
                          {comm.description || 'Komisi perpanjangan paket'}
                        </div>
                        <div className="text-[11px] text-slate-400 mt-0.5 flex items-center gap-2">
                          <span>{new Date(comm.created_at).toLocaleDateString('id-ID', { dateStyle: 'medium' })}</span>
                          <span>•</span>
                          <span>Bagi Hasil: {comm.commission_rate}%</span>
                          <span>•</span>
                          <span>Tagihan: {formatRupiah(Number(comm.subscription_amount))}</span>
                        </div>
                      </div>
                    </div>

                    <div className="text-right flex-shrink-0">
                      <div className="text-base font-black text-emerald-600">
                        +{formatRupiah(Number(comm.commission_amount))}
                      </div>
                      <span className="inline-block mt-0.5 px-2 py-0.5 text-[10px] font-bold bg-emerald-50 text-emerald-700 rounded border border-emerald-200">
                        Earned
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Riwayat Penarikan Dana (Payouts) */}
          <div className="bg-white rounded-3xl border border-slate-200 shadow-xs p-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <h3 className="text-lg font-black text-slate-900 tracking-tight">
                  Riwayat Pencairan Dana
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Status transfer dana komisi ke rekening bank Anda
                </p>
              </div>
              <button
                onClick={() => setIsWithdrawModalOpen(true)}
                className="px-3 py-1.5 text-xs font-bold bg-slate-900 text-white rounded-xl hover:bg-slate-800 transition-colors"
              >
                + Ajukan Pencairan
              </button>
            </div>

            {payouts.length === 0 ? (
              <div className="py-8 text-center text-slate-400 text-xs">
                Belum ada riwayat penarikan dana.
              </div>
            ) : (
              <div className="divide-y divide-slate-100 mt-2">
                {payouts.map((pay) => (
                  <div key={pay.id} className="py-3 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
                      <div
                        className={`w-9 h-9 rounded-xl flex items-center justify-center font-bold text-xs ${
                          pay.status === 'completed'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : pay.status === 'pending'
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : 'bg-red-50 text-red-700 border border-red-200'
                        }`}
                      >
                        {pay.status === 'completed' ? (
                          <CheckCircle2 className="w-4 h-4" />
                        ) : (
                          <Clock className="w-4 h-4" />
                        )}
                      </div>
                      <div>
                        <div className="font-bold text-sm text-slate-800">
                          {formatRupiah(Number(pay.amount))}
                        </div>
                        <div className="text-[11px] text-slate-500 mt-0.5">
                          {pay.bank_name} {pay.bank_account_number} a.n {pay.bank_account_holder}
                        </div>
                        <div className="text-[10px] text-slate-400 mt-0.5">
                          {new Date(pay.created_at).toLocaleDateString('id-ID', {
                            dateStyle: 'medium',
                            timeStyle: 'short',
                          })}
                        </div>
                      </div>
                    </div>

                    <div className="text-right">
                      <span
                        className={`px-2 py-0.5 text-[10px] font-bold rounded border ${
                          pay.status === 'completed'
                            ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                            : pay.status === 'pending'
                            ? 'bg-amber-100 text-amber-800 border-amber-200'
                            : 'bg-red-100 text-red-800 border-red-200'
                        }`}
                      >
                        {pay.status === 'completed'
                          ? 'Selesai Ditransfer'
                          : pay.status === 'pending'
                          ? 'Menunggu Diproses'
                          : 'Ditolak'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Quick Links & Profil Rekening */}
        <div className="space-y-6">
          {/* Quick Actions Card */}
          <div className="bg-white rounded-3xl border border-slate-200 shadow-xs p-6">
            <h3 className="text-base font-black text-slate-900 tracking-tight mb-4">
              Aksi Cepat
            </h3>

            <div className="space-y-3">
              <Link
                href="/dashboard/crm"
                className="flex items-center justify-between p-3.5 rounded-2xl border border-slate-200 hover:border-orange-300 hover:bg-orange-50/50 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center">
                    <Target className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="font-bold text-sm text-slate-800 group-hover:text-orange-600 transition-colors">
                      Kelola CRM Prospek
                    </div>
                    <div className="text-[11px] text-slate-500">
                      Input & pantau calon klien baru
                    </div>
                  </div>
                </div>
                <ArrowUpRight className="w-4 h-4 text-slate-400 group-hover:text-orange-600" />
              </Link>

              <Link
                href="/dashboard/quotations"
                className="flex items-center justify-between p-3.5 rounded-2xl border border-slate-200 hover:border-blue-300 hover:bg-blue-50/50 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-blue-100 text-blue-600 flex items-center justify-center">
                    <FileText className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="font-bold text-sm text-slate-800 group-hover:text-blue-600 transition-colors">
                      Buat Surat Penawaran
                    </div>
                    <div className="text-[11px] text-slate-500">
                      Kirim quotation resmi ke WhatsApp
                    </div>
                  </div>
                </div>
                <ArrowUpRight className="w-4 h-4 text-slate-400 group-hover:text-blue-600" />
              </Link>

              <Link
                href="/dashboard/starter-kits"
                className="flex items-center justify-between p-3.5 rounded-2xl border border-slate-200 hover:border-blue-300 hover:bg-blue-50/50 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-purple-100 text-purple-600 flex items-center justify-center">
                    <CreditCard className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="font-bold text-sm text-slate-800 group-hover:text-purple-600 transition-colors">
                      Brosur Paket Kasir
                    </div>
                    <div className="text-[11px] text-slate-500">
                      Download PDF paket mesin kasir
                    </div>
                  </div>
                </div>
                <ArrowUpRight className="w-4 h-4 text-slate-400 group-hover:text-purple-600" />
              </Link>
            </div>
          </div>

          {/* Profil Rekening Bank Payout */}
          <div className="bg-white rounded-3xl border border-slate-200 shadow-xs p-6">
            <h3 className="text-base font-black text-slate-900 tracking-tight mb-2">
              Rekening Pencairan Dana
            </h3>
            <p className="text-xs text-slate-500 mb-4">
              Rekening yang digunakan Super Admin untuk mentransfer komisi Anda
            </p>

            <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-500">Nama Bank</span>
                <span className="font-bold text-slate-800">{partner.bank_name || 'BCA'}</span>
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-500">Nomor Rekening</span>
                <span className="font-mono font-bold text-slate-800">{partner.bank_account_number || '-'}</span>
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-500">Atas Nama</span>
                <span className="font-bold text-slate-800">{partner.bank_account_holder || partner.name}</span>
              </div>
            </div>

            <p className="text-[11px] text-slate-400 mt-3 leading-relaxed">
              *Jika ingin memperbarui nomor rekening bank, silakan hubungi Super Admin.
            </p>
          </div>
        </div>
      </div>

      {/* Modal: Ajukan Penarikan Komisi */}
      {isWithdrawModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-5 animate-in fade-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <h3 className="text-lg font-black text-slate-900 tracking-tight">
                Ajukan Pencairan Saldo
              </h3>
              <button
                onClick={() => setIsWithdrawModalOpen(false)}
                className="text-slate-400 hover:text-slate-600"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleRequestPayout} className="space-y-4">
              <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-200 text-xs text-emerald-800">
                <div className="font-semibold text-emerald-900">Saldo Tersedia:</div>
                <div className="text-xl font-black mt-0.5">{formatRupiah(availableBalance)}</div>
                <div className="mt-1 text-[11px] text-emerald-700">
                  Akan ditransfer ke: {partner.bank_name} {partner.bank_account_number} a.n {partner.bank_account_holder || partner.name}
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Nominal Penarikan (Rp)
                </label>
                <div className="relative">
                  <span className="absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-slate-400 text-sm">
                    Rp
                  </span>
                  <input
                    type="number"
                    min={50000}
                    max={availableBalance}
                    required
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                    placeholder="Contoh: 100000"
                    className="w-full pl-11 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-emerald-500 font-bold text-base text-slate-800"
                  />
                </div>
                <div className="flex justify-between items-center mt-1 text-[11px] text-slate-400">
                  <span>Minimal Rp 50.000</span>
                  <button
                    type="button"
                    onClick={() => setWithdrawAmount(availableBalance.toString())}
                    className="text-emerald-600 font-bold hover:underline"
                  >
                    Tarik Semua Saldo
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Catatan / Keterangan (Opsional)
                </label>
                <textarea
                  rows={2}
                  value={withdrawNote}
                  onChange={(e) => setWithdrawNote(e.target.value)}
                  placeholder="Catatan tambahan untuk Super Admin..."
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-emerald-500 text-sm text-slate-800"
                />
              </div>

              <div className="flex items-center gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setIsWithdrawModalOpen(false)}
                  className="flex-1 py-3 rounded-xl border border-slate-200 text-slate-700 font-bold text-sm hover:bg-slate-50 transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || availableBalance < 50000}
                  className="flex-1 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-extrabold text-sm shadow-md transition-all"
                >
                  {isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
