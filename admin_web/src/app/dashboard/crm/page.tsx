'use client';

import { useState, useEffect, useMemo } from 'react';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Lead, LeadStatus, Partner, Business, SubscriptionPlan } from '@/types/database';
import {
  Target,
  PlusCircle,
  Search,
  Filter,
  Phone,
  MessageCircle,
  Building2,
  DollarSign,
  TrendingUp,
  Award,
  ChevronRight,
  MoreVertical,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  X,
  FileText,
  UserCheck,
  Calendar,
  Layers,
  Sparkles,
  ArrowRight,
  Send,
  SlidersHorizontal,
  Kanban,
  List,
} from 'lucide-react';

const STATUS_COLUMNS: { id: LeadStatus; label: string; color: string; bg: string; border: string }[] = [
  { id: 'new', label: 'Prospek Baru', color: 'text-sky-700', bg: 'bg-sky-50', border: 'border-sky-200' },
  { id: 'contacted', label: 'Dihubungi', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
  { id: 'demo', label: 'Demo / Trial', color: 'text-indigo-700', bg: 'bg-indigo-50', border: 'border-indigo-200' },
  { id: 'quoted', label: 'Kirim Penawaran', color: 'text-purple-700', bg: 'bg-purple-50', border: 'border-purple-200' },
  { id: 'won', label: 'Closing (Won)', color: 'text-emerald-700', bg: 'bg-emerald-50', border: 'border-emerald-200' },
  { id: 'lost', label: 'Batal (Lost)', color: 'text-slate-600', bg: 'bg-slate-100', border: 'border-slate-200' },
];

export default function CrmPage() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewMode, setViewMode] = useState<'kanban' | 'list'>('kanban');

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [partnerFilter, setPartnerFilter] = useState('all');

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isConvertModalOpen, setIsConvertModalOpen] = useState(false);
  const [isActivityModalOpen, setIsActivityModalOpen] = useState(false);
  const [selectedLead, setSelectedLead] = useState<Lead | null>(null);

  // Add Lead Form State
  const [leadForm, setLeadForm] = useState({
    business_name: '',
    contact_name: '',
    phone: '',
    email: '',
    city: '',
    business_type: 'fnb',
    partner_id: '',
    estimated_deal_value: 399000,
    notes: '',
  });

  // Convert to Business Form State
  const [convertForm, setConvertForm] = useState({
    plan_mode: 'trial' as 'trial' | 'pro',
    duration_months: 12,
    trial_days: 14,
  });

  // Dynamic Pricing Tiers from Master subscription_plans
  const proPlan = plans.find((p) => p.code === 'pro');
  const tiers = proPlan?.pricing_tiers || {};
  const price1Month = Number(tiers['1_month'] ?? proPlan?.price_monthly ?? 49000);
  const price3Months = Number(tiers['3_months'] ?? 129000);
  const price6Months = Number(tiers['6_months'] ?? 239000);
  const price1Year = Number(tiers['12_months'] ?? 399000);
  const priceLifetime = Number(tiers['lifetime'] ?? 799000);

  const getPackagePrice = (months: number) => {
    if (months === 1) return price1Month;
    if (months === 3) return price3Months;
    if (months === 6) return price6Months;
    if (months === 12) return price1Year;
    if (months >= 999) return priceLifetime;
    return price1Month * months;
  };

  // Activity Form State
  const [activityNote, setActivityNote] = useState('');
  const [activityType, setActivityType] = useState<'whatsapp' | 'call' | 'meeting' | 'demo' | 'note'>('whatsapp');

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // User Role & Partner Identity
  const [currentUserRole, setCurrentUserRole] = useState<'super_admin' | 'admin' | 'partner'>('admin');
  const [currentPartnerId, setCurrentPartnerId] = useState<string | null>(null);
  const [currentPartnerName, setCurrentPartnerName] = useState<string>('');

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      // 0. Identify current user role and partner_id
      let userRole: 'super_admin' | 'admin' | 'partner' = 'admin';
      let userPartnerId: string | null = null;
      let userPartnerName: string = '';

      const { data: { user } } = await supabase.auth.getUser();
      if (user && user.email) {
        const userEmail = user.email.toLowerCase();
        const { data: adminRecord } = await supabase
          .from('admin_users')
          .select('*, partners(*)')
          .or(`email.ilike.${userEmail},user_id.eq.${user.id}`)
          .maybeSingle();

        if (adminRecord) {
          userRole = (adminRecord.role || 'admin') as 'super_admin' | 'admin' | 'partner';
          userPartnerId = adminRecord.partner_id || null;
          userPartnerName = adminRecord.partners?.name || '';
          setCurrentUserRole(userRole);
          setCurrentPartnerId(userPartnerId);
          setCurrentPartnerName(userPartnerName);
          if (userRole === 'partner' && userPartnerId) {
            setPartnerFilter(userPartnerId);
            setLeadForm((prev) => ({ ...prev, partner_id: userPartnerId! }));
          }

          // Auto-link user_id in admin_users if not set
          if (!adminRecord.user_id && user.id) {
            await supabase
              .from('admin_users')
              .update({ user_id: user.id })
              .eq('id', adminRecord.id);
          }
        }
      }

      // 1. Fetch leads with partners (filtered if partner)
      let leadQuery = supabase
        .from('leads')
        .select('*, partners(*)')
        .order('created_at', { ascending: false });

      if (userRole === 'partner' && userPartnerId) {
        leadQuery = leadQuery.eq('partner_id', userPartnerId);
      }

      const { data: leadData, error: leadErr } = await leadQuery;

      if (leadErr) {
        console.warn('Leads table load warning:', leadErr.message);
      }

      // 2. Fetch partners
      const { data: partnerData, error: partnerErr } = await supabase
        .from('partners')
        .select('*')
        .order('name', { ascending: true });

      if (partnerErr) throw partnerErr;

      // 3. Fetch plans
      const { data: planData } = await supabase.from('subscription_plans').select('*');

      setLeads((leadData as Lead[]) || []);
      setPartners((partnerData as Partner[]) || []);
      setPlans((planData as SubscriptionPlan[]) || []);
    } catch (err: any) {
      setErrorMsg(`Gagal memuat data CRM: ${err?.message || 'Terjadi kesalahan sistem'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Compute Metrics
  const metrics = useMemo(() => {
    // For partners, only compute metrics from their own leads
    const scopedLeads =
      currentUserRole === 'partner' && currentPartnerId
        ? leads.filter((l) => l.partner_id === currentPartnerId)
        : leads;

    const totalLeads = scopedLeads.length;
    const wonCount = scopedLeads.filter((l) => l.status === 'won').length;
    const activePipelineValue = scopedLeads
      .filter((l) => ['new', 'contacted', 'demo', 'quoted'].includes(l.status))
      .reduce((sum, l) => sum + Number(l.estimated_deal_value || 0), 0);
    const demoAndQuoted = scopedLeads.filter((l) => ['demo', 'quoted'].includes(l.status)).length;

    return {
      totalLeads,
      wonCount,
      activePipelineValue,
      demoAndQuoted,
    };
  }, [leads, currentUserRole, currentPartnerId]);

  // Filtered Leads
  const filteredLeads = useMemo(() => {
    return leads.filter((l) => {
      // Security safeguard: If partner, NEVER show other partner's leads
      if (currentUserRole === 'partner' && currentPartnerId) {
        if (l.partner_id !== currentPartnerId) return false;
      }

      const q = searchQuery.toLowerCase();
      const matchSearch =
        !searchQuery ||
        l.business_name.toLowerCase().includes(q) ||
        (l.contact_name || '').toLowerCase().includes(q) ||
        (l.phone || '').toLowerCase().includes(q) ||
        (l.city || '').toLowerCase().includes(q);

      if (!matchSearch) return false;

      if (partnerFilter !== 'all') {
        if (partnerFilter === 'unassigned') {
          if (l.partner_id) return false;
        } else if (l.partner_id !== partnerFilter) {
          return false;
        }
      }

      return true;
    });
  }, [leads, searchQuery, partnerFilter, currentUserRole, currentPartnerId]);

  // Quick Change Lead Status
  const handleUpdateStatus = async (leadId: string, newStatus: LeadStatus) => {
    try {
      const { error } = await supabase
        .from('leads')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', leadId);

      if (error) throw error;

      setLeads((prev) =>
        prev.map((item) => (item.id === leadId ? { ...item, status: newStatus } : item))
      );
    } catch (err: any) {
      setErrorMsg(`Gagal update status prospek: ${err?.message || 'Kesalahan sistem'}`);
    }
  };

  // Submit Add Lead
  const handleCreateLead = async () => {
    if (!leadForm.business_name.trim()) {
      setErrorMsg('Nama usaha / toko wajib diisi.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const payload: any = {
        business_name: leadForm.business_name.trim(),
        contact_name: leadForm.contact_name.trim() || null,
        phone: leadForm.phone.trim() || null,
        email: leadForm.email.trim() || null,
        city: leadForm.city.trim() || null,
        business_type: leadForm.business_type,
        partner_id: leadForm.partner_id || null,
        estimated_deal_value: Number(leadForm.estimated_deal_value) || 399000,
        status: 'new',
        notes: leadForm.notes.trim() || null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { error } = await supabase.from('leads').insert(payload);
      if (error) throw error;

      setSuccessMsg(`Prospek toko "${payload.business_name}" berhasil ditambahkan!`);
      setIsAddModalOpen(false);
      setLeadForm({
        business_name: '',
        contact_name: '',
        phone: '',
        email: '',
        city: '',
        business_type: 'fnb',
        partner_id: '',
        estimated_deal_value: 399000,
        notes: '',
      });
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan prospek: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Convert Lead to Business (Closing)
  const handleConvertLead = async () => {
    if (!selectedLead) return;

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      if (currentUserRole === 'partner') {
        if (convertForm.plan_mode !== 'trial') {
          throw new Error('Akun Mitra hanya berwenang memberikan Masa Uji Coba (PRO Trial).');
        }
        if (![7, 14, 30, 60].includes(convertForm.trial_days)) {
          throw new Error('Pilihan durasi trial mitra dibatasi pada 7, 14, 30, atau 60 hari.');
        }
      }

      const proPlan = plans.find((p) => p.code === 'pro');
      const freePlan = plans.find((p) => p.code === 'free');

      const isPro = convertForm.plan_mode === 'pro';
      const isLifetime = isPro && convertForm.duration_months >= 999;
      const targetPlan = isPro ? proPlan : freePlan;
      const actualPrice = convertForm.plan_mode === 'trial' ? 0 : getPackagePrice(convertForm.duration_months);

      // End date calculation
      const now = new Date();
      let endAtISO: string | null = null;
      if (convertForm.plan_mode === 'trial') {
        const d = new Date(now);
        d.setDate(d.getDate() + convertForm.trial_days);
        endAtISO = d.toISOString();
      } else if (isPro && !isLifetime) {
        const d = new Date(now);
        d.setMonth(d.getMonth() + convertForm.duration_months);
        endAtISO = d.toISOString();
      }

      // 1. Create Business
      const bizPayload: any = {
        name: selectedLead.business_name,
        business_type: selectedLead.business_type,
        plan_id: targetPlan?.id,
        subscription_status: convertForm.plan_mode === 'trial' ? 'trial' : 'active',
        subscription_end_at: endAtISO,
        phone: selectedLead.phone,
        email: selectedLead.email,
        address: selectedLead.city,
        referred_by_partner_id: selectedLead.partner_id || null,
        owner_user_id: '00000000-0000-0000-0000-000000000000', // temporary placeholder or unassigned
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      if (proPlan && (isPro || convertForm.plan_mode === 'trial')) {
        bizPayload.max_transactions = proPlan.max_transactions_month;
        bizPayload.max_products = proPlan.max_products;
        bizPayload.max_outlets = proPlan.max_outlets;
      }

      const { data: createdBiz, error: bizErr } = await supabase
        .from('businesses')
        .insert(bizPayload)
        .select()
        .single();

      if (bizErr) throw bizErr;

      // 2. Update Lead status to 'won' and link converted_business_id
      const { error: leadUpdateErr } = await supabase
        .from('leads')
        .update({
          status: 'won',
          converted_business_id: createdBiz.id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedLead.id);

      if (leadUpdateErr) console.warn('Lead link warning:', leadUpdateErr.message);

      // 3. Record in subscription_histories
      const partnerRate = selectedLead.partners?.commission_rate || 20;
      const commissionAmount =
        convertForm.plan_mode === 'trial'
          ? 0
          : Math.round((actualPrice * partnerRate) / 100);

      const histPayload = {
        business_id: createdBiz.id,
        plan_id: targetPlan?.id,
        action_type: convertForm.plan_mode === 'trial' ? 'trial' : 'new',
        duration_type: convertForm.plan_mode === 'trial' ? 'days' : isLifetime ? 'lifetime' : 'months',
        duration_value: convertForm.plan_mode === 'trial' ? convertForm.trial_days : convertForm.duration_months,
        price_paid: actualPrice,
        started_at: new Date().toISOString(),
        ended_at: endAtISO,
        partner_id: selectedLead.partner_id || null,
        commission_rate: partnerRate,
        commission_amount: commissionAmount,
        payment_status: convertForm.plan_mode === 'trial' ? 'free_trial' : 'paid',
        notes: `Converted from CRM Lead: ${selectedLead.business_name} (${
          convertForm.plan_mode === 'trial'
            ? `${convertForm.trial_days} Hari Trial`
            : isLifetime
            ? 'Lifetime PRO'
            : `${convertForm.duration_months} Bulan PRO`
        })`,
        created_by_admin: 'Admin Console CRM',
        created_at: new Date().toISOString(),
      };

      await supabase.from('subscription_histories').insert(histPayload);

      setSuccessMsg(
        `Selamat! Toko "${selectedLead.business_name}" resmi menjadi klien aktif Mangga POS (${convertForm.plan_mode.toUpperCase()})!`
      );
      setIsConvertModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal convert lead ke toko: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Add Activity / Note
  const handleAddActivity = async () => {
    if (!selectedLead || !activityNote.trim()) return;

    try {
      const { error } = await supabase.from('lead_activities').insert({
        lead_id: selectedLead.id,
        partner_id: selectedLead.partner_id || null,
        activity_type: activityType,
        notes: activityNote.trim(),
        created_at: new Date().toISOString(),
      });

      if (error) throw error;

      setSuccessMsg('Catatan interaksi berhasil disimpan.');
      setActivityNote('');
      setIsActivityModalOpen(false);
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan interaksi: ${err?.message}`);
    }
  };

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Mini CRM Prospek & Pipeline"
        description="Pantau prospek calon klien toko binaan mitra dari kontak awal, demo, penawaran, hingga closing"
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
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-sky-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Prospek</span>
            <div className="w-10 h-10 rounded-xl bg-sky-50 border border-sky-100 flex items-center justify-center text-sky-600">
              <Target className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{metrics.totalLeads}</span>
            <span className="text-xs text-slate-500 ml-2">calon klien</span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <Building2 className="w-3.5 h-3.5 text-sky-500" /> Toko/kafe dalam radar sales
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-amber-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Potensi Pipeline</span>
            <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 flex items-center justify-center text-amber-600">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rp {metrics.activePipelineValue.toLocaleString('id-ID')}
            </span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5 text-amber-500" /> Estimasi nilai deal aktif
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-purple-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Demo & Penawaran</span>
            <div className="w-10 h-10 rounded-xl bg-purple-50 border border-purple-100 flex items-center justify-center text-purple-600">
              <Sparkles className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{metrics.demoAndQuoted}</span>
            <span className="text-xs text-slate-500 ml-2">toko intensif</span>
          </div>
          <p className="mt-2 text-xs text-purple-600 flex items-center gap-1">
            <Send className="w-3.5 h-3.5" /> Peluang closing tertinggi
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-emerald-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Closing (Won)</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-emerald-600">
              <Award className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-emerald-700 tracking-tight">{metrics.wonCount}</span>
            <span className="text-xs text-slate-500 ml-2">toko berlangganan</span>
          </div>
          <p className="mt-2 text-xs text-emerald-600 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5" /> Berhasil dikonversi jadi klien
          </p>
        </div>
      </div>

      {/* Main Container */}
      <div className="bg-white rounded-3xl border border-slate-200/80 shadow-xs overflow-hidden">
        {/* Header Action Bar */}
        <div className="p-6 border-b border-slate-100 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-xl">
              <button
                onClick={() => setViewMode('kanban')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                  viewMode === 'kanban'
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <Kanban className="w-3.5 h-3.5" />
                <span>Pipeline (Kanban)</span>
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                  viewMode === 'list'
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <List className="w-3.5 h-3.5" />
                <span>Tabel List</span>
              </button>
            </div>
          </div>

          <div className="flex items-center gap-3 w-full md:w-auto">
            <button
              onClick={() => loadData()}
              disabled={loading}
              className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>

            <button
              onClick={() => setIsAddModalOpen(true)}
              style={{ background: 'linear-gradient(135deg, #0284c7 0%, #4338ca 100%)', color: '#ffffff' }}
              className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-sky-600 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95"
            >
              <PlusCircle className="w-4 h-4 text-white" />
              <span className="text-white">+ Tambah Prospek Baru</span>
            </button>
          </div>
        </div>

        {/* Filter and Search Bar */}
        <div className="p-4 bg-slate-50/60 border-b border-slate-100 flex flex-col md:flex-row gap-3 items-center justify-between">
          <div className="relative w-full md:max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari nama toko, kontak, atau kota..."
              value={searchQuery}
              onInput={(e) => setSearchQuery((e.target as HTMLInputElement).value)}
              className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition-all shadow-2xs"
            />
          </div>

          {currentUserRole === 'partner' ? (
            <div className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold shadow-2xs">
              <UserCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
              <span>Prospek Saya ({currentPartnerName || 'Mitra'}) • {leads.length} Toko</span>
            </div>
          ) : (
            <div className="flex items-center gap-2 w-full md:w-auto">
              <span className="text-xs text-slate-400 font-medium whitespace-nowrap">Filter Mitra:</span>
              <select
                value={partnerFilter}
                onChange={(e) => setPartnerFilter(e.target.value)}
                className="px-3.5 py-2 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-700 shadow-2xs focus:outline-hidden focus:ring-1 focus:ring-sky-500 cursor-pointer"
              >
                <option value="all">Semua Mitra / Sales ({leads.length})</option>
                <option value="unassigned">
                  Tanpa Mitra / Organik ({leads.filter((l) => !l.partner_id).length})
                </option>
                {partners.map((p) => {
                  const pCount = leads.filter((l) => l.partner_id === p.id).length;
                  return (
                    <option key={p.id} value={p.id}>
                      {p.name} ({pCount})
                    </option>
                  );
                })}
              </select>
            </div>
          )}
        </div>

        {/* VIEW 1: KANBAN PIPELINE */}
        {viewMode === 'kanban' && (
          <div className="p-6 overflow-x-auto">
            <div className="flex gap-4 min-w-[1400px] items-start">
              {STATUS_COLUMNS.map((col) => {
                const columnLeads = filteredLeads.filter((l) => l.status === col.id);

                return (
                  <div
                    key={col.id}
                    className="flex-1 bg-slate-50/70 border border-slate-200/80 rounded-2xl p-3 flex flex-col min-w-[270px] max-w-[320px]"
                  >
                    {/* Column Header */}
                    <div className="flex items-center justify-between pb-3 border-b border-slate-200/60 mb-3">
                      <div className="flex items-center gap-2">
                        <span className={`w-2.5 h-2.5 rounded-full ${col.bg} border ${col.border}`} />
                        <h4 className="text-xs font-extrabold text-slate-800">{col.label}</h4>
                      </div>
                      <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-white text-slate-600 border border-slate-200 shadow-2xs">
                        {columnLeads.length}
                      </span>
                    </div>

                    {/* Leads Cards */}
                    <div className="space-y-3 min-h-[350px]">
                      {columnLeads.length === 0 ? (
                        <div className="h-32 rounded-2xl border-2 border-dashed border-slate-200 flex flex-col items-center justify-center text-slate-400 gap-1 p-3 text-center">
                          <span className="text-xs font-semibold text-slate-400">Belum ada prospek</span>
                          <span className="text-[10px] text-slate-400">di tahapan ini</span>
                        </div>
                      ) : (
                        columnLeads.map((lead) => (
                          <div
                            key={lead.id}
                            className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs hover:shadow-md hover:border-slate-300 transition-all text-xs space-y-3 group"
                          >
                            {/* Title & Type */}
                            <div className="flex items-start justify-between gap-2">
                              <div>
                                <h5 className="font-extrabold text-slate-900 text-sm leading-snug group-hover:text-sky-600 transition-colors">
                                  {lead.business_name}
                                </h5>
                                <div className="text-[11px] text-slate-500 mt-0.5">
                                  {lead.contact_name || 'Owner'} {lead.city ? `• ${lead.city}` : ''}
                                </div>
                              </div>
                              <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-md bg-slate-100 text-slate-600 shrink-0">
                                {lead.business_type}
                              </span>
                            </div>

                            {/* Estimated Deal Value */}
                            <div className="flex items-center justify-between text-xs pt-2 border-t border-slate-100">
                              <span className="text-slate-400 text-[11px]">Potensi Deal:</span>
                              <span className="font-extrabold text-slate-900 bg-slate-50 px-2 py-0.5 rounded-md border border-slate-200/60">
                                Rp {Number(lead.estimated_deal_value).toLocaleString('id-ID')}
                              </span>
                            </div>

                            {/* Referring Partner Badge (Highlighted for Admin) */}
                            {currentUserRole !== 'partner' ? (
                              lead.partners ? (
                                <div className="flex items-center gap-1.5 text-[10px] text-emerald-800 bg-emerald-50 px-2.5 py-1 rounded-md border border-emerald-200">
                                  <UserCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                                  <span className="font-semibold">Mitra: {lead.partners.name}</span>
                                </div>
                              ) : (
                                <div className="flex items-center gap-1.5 text-[10px] text-slate-500 bg-slate-100 px-2.5 py-1 rounded-md">
                                  <span>Organik / Tanpa Mitra</span>
                                </div>
                              )
                            ) : null}

                            {/* Stage Selector Row (Full Width Clean Dropdown) */}
                            <div className="pt-2 border-t border-slate-100">
                              <select
                                value={lead.status}
                                onChange={(e) => handleUpdateStatus(lead.id, e.target.value as LeadStatus)}
                                className="w-full text-[11px] font-semibold rounded-xl border border-slate-200 bg-slate-50 hover:bg-white px-3 py-1.5 text-slate-700 focus:outline-hidden focus:ring-1 focus:ring-sky-500 cursor-pointer transition-all shadow-2xs"
                              >
                                {STATUS_COLUMNS.map((sc) => (
                                  <option key={sc.id} value={sc.id}>
                                    Tahap: {sc.label}
                                  </option>
                                ))}
                              </select>
                            </div>

                            {/* Action Buttons Row */}
                            <div className="pt-1 flex items-center justify-between gap-2">
                              <div className="flex items-center gap-1.5">
                                {/* WhatsApp Direct Chat */}
                                {lead.phone && (
                                  <a
                                    href={`https://wa.me/${lead.phone.replace(/[^0-9]/g, '')}?text=Halo%20${encodeURIComponent(
                                      lead.contact_name || lead.business_name
                                    )},%20saya%20dari%20Mangga%20POS...`}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="h-8 px-2.5 rounded-xl bg-emerald-50 hover:bg-emerald-600 text-emerald-700 hover:text-white flex items-center gap-1 font-bold text-xs transition-all shadow-2xs"
                                    title="Chat WhatsApp"
                                  >
                                    <MessageCircle className="w-3.5 h-3.5" />
                                    <span>WA</span>
                                  </a>
                                )}

                                {/* Create Quotation Link */}
                                <Link
                                  href={`/dashboard/quotations?leadId=${lead.id}&clientName=${encodeURIComponent(
                                    lead.contact_name || ''
                                  )}&bizName=${encodeURIComponent(lead.business_name)}&phone=${encodeURIComponent(
                                    lead.phone || ''
                                  )}`}
                                  className="h-8 px-2.5 rounded-xl bg-purple-50 hover:bg-purple-600 text-purple-700 hover:text-white flex items-center gap-1 font-bold text-xs transition-all shadow-2xs"
                                  title="Buat Surat Penawaran"
                                >
                                  <FileText className="w-3.5 h-3.5" />
                                  <span>Quote</span>
                                </Link>
                              </div>

                              {/* Convert to Business Button (If not won yet) */}
                              {lead.status !== 'won' ? (
                                <button
                                  onClick={() => {
                                    setSelectedLead(lead);
                                    setIsConvertModalOpen(true);
                                  }}
                                  className="h-8 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs flex items-center gap-1 shadow-xs hover:shadow-sm transition-all active:scale-95 shrink-0"
                                  title="Convert to Client (Closing)"
                                >
                                  <span>Closing</span>
                                  <ChevronRight className="w-3.5 h-3.5" />
                                </button>
                              ) : (
                                <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-xl border border-emerald-200">
                                  <CheckCircle2 className="w-3.5 h-3.5" />
                                  <span>Won</span>
                                </span>
                              )}
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* VIEW 2: LIST TABLE */}
        {viewMode === 'list' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-6">Usaha & Kontak</th>
                  <th className="py-3.5 px-4">Status Pipeline</th>
                  <th className="py-3.5 px-4">Potensi Nilai Deal</th>
                  <th className="py-3.5 px-4">Mitra Sales</th>
                  <th className="py-3.5 px-6 text-right">Aksi Cepat</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredLeads.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      Tidak ada data prospek yang sesuai filter.
                    </td>
                  </tr>
                ) : (
                  filteredLeads.map((lead) => {
                    const statusObj = STATUS_COLUMNS.find((sc) => sc.id === lead.status);

                    return (
                      <tr key={lead.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-slate-900 text-sm">{lead.business_name}</span>
                            <span className="text-[10px] uppercase font-bold px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">
                              {lead.business_type}
                            </span>
                          </div>
                          <div className="text-[11px] text-slate-500 mt-0.5">
                            {lead.contact_name || 'Owner'} • {lead.phone || '-'} • {lead.city || '-'}
                          </div>
                        </td>

                        <td className="py-4 px-4">
                          <select
                            value={lead.status}
                            onChange={(e) => handleUpdateStatus(lead.id, e.target.value as LeadStatus)}
                            className={`px-2.5 py-1 rounded-lg text-xs font-bold border cursor-pointer transition-all ${
                              statusObj?.bg || 'bg-slate-100'
                            } ${statusObj?.color || 'text-slate-700'} ${statusObj?.border || 'border-slate-200'}`}
                          >
                            {STATUS_COLUMNS.map((sc) => (
                              <option key={sc.id} value={sc.id} className="bg-white text-slate-800">
                                {sc.label}
                              </option>
                            ))}
                          </select>
                        </td>

                        <td className="py-4 px-4 font-bold text-slate-800">
                          Rp {Number(lead.estimated_deal_value).toLocaleString('id-ID')}
                        </td>

                        <td className="py-4 px-4">
                          {lead.partners ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-semibold bg-emerald-50 text-emerald-800 border border-emerald-200">
                              <UserCheck className="w-3.5 h-3.5 text-emerald-600" />
                              <span>{lead.partners.name}</span>
                            </span>
                          ) : (
                            <span className="text-slate-400 text-xs">Organik / Langsung</span>
                          )}
                        </td>

                        <td className="py-4 px-6 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {/* WhatsApp Direct Chat */}
                            {lead.phone && (
                              <a
                                href={`https://wa.me/${lead.phone.replace(/[^0-9]/g, '')}?text=Halo%20${encodeURIComponent(
                                  lead.contact_name || lead.business_name
                                )},%20saya%20dari%20Mangga%20POS...`}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 font-bold transition-colors"
                                title="Chat WhatsApp"
                              >
                                <MessageCircle className="w-3.5 h-3.5" />
                                <span>WA</span>
                              </a>
                            )}

                            {/* Create Quotation Link (Quick Surat Penawaran in Mode List) */}
                            <Link
                              href={`/dashboard/quotations?leadId=${lead.id}&clientName=${encodeURIComponent(
                                lead.contact_name || ''
                              )}&bizName=${encodeURIComponent(lead.business_name)}&phone=${encodeURIComponent(
                                lead.phone || ''
                              )}`}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-purple-50 text-purple-700 hover:bg-purple-100 font-bold transition-colors"
                              title="Buat Surat Penawaran"
                            >
                              <FileText className="w-3.5 h-3.5" />
                              <span>Penawaran</span>
                            </Link>

                            {/* Closing Button */}
                            {lead.status !== 'won' ? (
                              <button
                                onClick={() => {
                                  setSelectedLead(lead);
                                  setIsConvertModalOpen(true);
                                }}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs shadow-xs transition-colors"
                                title="Closing / Convert ke Toko Aktif"
                              >
                                <span>Closing</span>
                                <ChevronRight className="w-3.5 h-3.5" />
                              </button>
                            ) : (
                              <span className="text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-md border border-emerald-200">
                                ✓ Klien Aktif
                              </span>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* MODAL: TAMBAH PROSPEK BARU */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #0284c7 0%, #4338ca 100%)', color: '#ffffff' }}
              className="p-6 bg-sky-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <Target className="w-5 h-5 text-sky-200" />
                  <span className="text-white">Tambah Prospek Calon Klien</span>
                </h3>
                <p className="text-xs text-sky-100 mt-0.5">
                  Catat calon toko/kafe yang sedang diprospek oleh Anda atau mitra
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsAddModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[75vh] overflow-y-auto text-xs">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Nama Usaha / Toko / Kafe *</label>
                <input
                  type="text"
                  placeholder="Contoh: Kopi Kenangan Senja"
                  value={leadForm.business_name}
                  onInput={(e) => setLeadForm({ ...leadForm, business_name: (e.target as HTMLInputElement).value })}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold focus:outline-hidden focus:border-sky-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Nama Pemilik (Owner)</label>
                  <input
                    type="text"
                    placeholder="Contoh: Mas Ryan"
                    value={leadForm.contact_name}
                    onInput={(e) => setLeadForm({ ...leadForm, contact_name: (e.target as HTMLInputElement).value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-sky-500"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">No. WhatsApp / HP</label>
                  <input
                    type="text"
                    placeholder="08123456789"
                    value={leadForm.phone}
                    onInput={(e) => setLeadForm({ ...leadForm, phone: (e.target as HTMLInputElement).value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-sky-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Kota / Lokasi</label>
                  <input
                    type="text"
                    placeholder="Jakarta Barat"
                    value={leadForm.city}
                    onInput={(e) => setLeadForm({ ...leadForm, city: (e.target as HTMLInputElement).value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Jenis Usaha</label>
                  <select
                    value={leadForm.business_type}
                    onChange={(e) => setLeadForm({ ...leadForm, business_type: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                  >
                    <option value="fnb">Kuliner / Kafe / Resto (F&B)</option>
                    <option value="retail">Retail / Minimarket / Butik</option>
                    <option value="service">Jasa / Barbershop / Laundry</option>
                    <option value="other">Lainnya</option>
                  </select>
                </div>
              </div>

              {currentUserRole === 'partner' ? (
                <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200">
                  <span className="text-[11px] font-bold text-slate-700 block mb-0.5">Mitra Penanggung Jawab:</span>
                  <span className="text-xs font-extrabold text-emerald-800">
                    {currentPartnerName || 'Akun Mitra Anda'} (Otomatis Ditautkan)
                  </span>
                </div>
              ) : (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Mitra / Sales Penanggung Jawab:</label>
                  <select
                    value={leadForm.partner_id}
                    onChange={(e) => setLeadForm({ ...leadForm, partner_id: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                  >
                    <option value="">-- Prospek Langsung (Tanpa Mitra) --</option>
                    {partners.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.commission_rate}%)
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div>
                <label className="block font-bold text-slate-700 mb-1">Estimasi Potensi Penawaran (Rp):</label>
                <input
                  type="number"
                  value={leadForm.estimated_deal_value}
                  onInput={(e) =>
                    setLeadForm({ ...leadForm, estimated_deal_value: Number((e.target as HTMLInputElement).value) })
                  }
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Catatan Kebutuhan Calon Klien:</label>
                <textarea
                  rows={2}
                  placeholder="Contoh: Butuh cetak struk bluetooth, menu 50 item, dan manajemen meja"
                  value={leadForm.notes}
                  onInput={(e) => setLeadForm({ ...leadForm, notes: (e.target as HTMLTextAreaElement).value })}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900"
                />
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
                onClick={handleCreateLead}
                disabled={isSubmitting}
                style={{ backgroundColor: '#0284c7', color: '#ffffff' }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    <span className="text-white">Menyimpan...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-white" />
                    <span className="text-white">Simpan Prospek</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: CONVERT TO CLIENT (CLOSING) */}
      {isConvertModalOpen && selectedLead && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #059669 0%, #0d9488 100%)', color: '#ffffff' }}
              className="p-6 bg-emerald-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <Award className="w-5 h-5 text-emerald-200" />
                  <span className="text-white">Closing & Buatkan Toko</span>
                </h3>
                <p className="text-xs text-emerald-100 mt-0.5">
                  Ubah prospek &ldquo;{selectedLead.business_name}&rdquo; menjadi klien aktif
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsConvertModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-100 space-y-1">
                <div className="font-bold text-emerald-950 text-sm">{selectedLead.business_name}</div>
                <div className="text-slate-600">Kontak: {selectedLead.contact_name || '-'} ({selectedLead.phone || '-'})</div>
                {selectedLead.partners && (
                  <div className="text-emerald-700 font-semibold pt-1">
                    Mitra Terkunci: {selectedLead.partners.name} ({selectedLead.partners.commission_rate}%)
                  </div>
                )}
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-2">Pilih Paket Aktivasi Awal:</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setConvertForm({ ...convertForm, plan_mode: 'trial' })}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      convertForm.plan_mode === 'trial'
                        ? 'border-indigo-500 bg-indigo-50/50 ring-2 ring-indigo-500/20'
                        : 'border-slate-200'
                    }`}
                  >
                    <div className="font-bold text-indigo-950">Beri Masa Trial PRO</div>
                    <div className="text-[11px] text-slate-500">Uji coba 7, 14, 30, atau 60 hari</div>
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      if (currentUserRole === 'partner') {
                        setErrorMsg(
                          'Akun Mitra hanya berwenang memberikan Masa Uji Coba (PRO Trial Maksimal 60 Hari). Aktivasi PRO berbayar divalidasi oleh Super Admin.'
                        );
                        return;
                      }
                      setConvertForm({ ...convertForm, plan_mode: 'pro' });
                    }}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      convertForm.plan_mode === 'pro'
                        ? 'border-amber-500 bg-amber-50/50 ring-2 ring-amber-500/20'
                        : 'border-slate-200'
                    } ${currentUserRole === 'partner' ? 'opacity-60 cursor-not-allowed' : ''}`}
                    title={
                      currentUserRole === 'partner'
                        ? 'Aktivasi berbayar divalidasi oleh Super Admin'
                        : ''
                    }
                  >
                    <div className="font-bold text-amber-950 flex items-center justify-between">
                      <span>Langsung PRO</span>
                      {currentUserRole === 'partner' && (
                        <span className="text-[9px] font-extrabold bg-amber-100 text-amber-800 px-1 rounded">
                          🔒 Admin
                        </span>
                      )}
                    </div>
                    <div className="text-[11px] text-slate-500">1 Bulan s/d 1 Tahun</div>
                  </button>
                </div>
              </div>

              {convertForm.plan_mode === 'trial' ? (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Durasi Trial (Hari):</label>
                  <select
                    value={convertForm.trial_days}
                    onChange={(e) => setConvertForm({ ...convertForm, trial_days: Number(e.target.value) })}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                  >
                    <option value={7}>7 Hari Gratis</option>
                    <option value={14}>14 Hari Gratis (Rekomendasi)</option>
                    <option value={30}>30 Hari Gratis (1 Bulan)</option>
                    <option value={60}>60 Hari Gratis (2 Bulan)</option>
                  </select>
                </div>
              ) : (
                <div className="space-y-3">
                  <div>
                    <label className="block font-bold text-slate-700 mb-1">
                      Pilihan Paket Langganan PRO (Tersinkron Master Harga):
                    </label>
                    <select
                      value={convertForm.duration_months}
                      onChange={(e) => setConvertForm({ ...convertForm, duration_months: Number(e.target.value) })}
                      className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                    >
                      <option value={1}>1 Bulan — Rp {price1Month.toLocaleString('id-ID')}</option>
                      <option value={3}>3 Bulan — Rp {price3Months.toLocaleString('id-ID')}</option>
                      <option value={6}>6 Bulan — Rp {price6Months.toLocaleString('id-ID')}</option>
                      <option value={12}>1 Tahun (Rekomendasi) — Rp {price1Year.toLocaleString('id-ID')}</option>
                      <option value={999}>Lifetime / Permanen — Rp {priceLifetime.toLocaleString('id-ID')}</option>
                    </select>
                  </div>

                  {/* Live Synced Investment & Commission Box */}
                  <div className="p-3.5 rounded-2xl bg-amber-50/70 border border-amber-200/80 space-y-1.5">
                    <div className="flex items-center justify-between">
                      <span className="text-slate-600 font-medium">Nilai Investasi Klien:</span>
                      <span className="font-extrabold text-amber-950 text-sm">
                        Rp {getPackagePrice(convertForm.duration_months).toLocaleString('id-ID')}
                      </span>
                    </div>
                    {selectedLead.partners ? (
                      <div className="flex items-center justify-between pt-1.5 border-t border-amber-200/60 text-emerald-800">
                        <span className="font-semibold">
                          Komisi Masuk ke Mitra ({selectedLead.partners.commission_rate}%):
                        </span>
                        <span className="font-black text-sm">
                          Rp{' '}
                          {Math.round(
                            (getPackagePrice(convertForm.duration_months) * selectedLead.partners.commission_rate) /
                              100
                          ).toLocaleString('id-ID')}
                        </span>
                      </div>
                    ) : (
                      <div className="text-[11px] text-slate-500 pt-1 border-t border-amber-200/60">
                        Tanpa perantara mitra (100% pendapatan pusat)
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>

            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setIsConvertModalOpen(false)}
                className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleConvertLead}
                disabled={isSubmitting}
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
                    <span className="text-white">Konfirmasi Closing & Buat Toko</span>
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
