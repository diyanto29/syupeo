'use client';

import { useState, useEffect, useMemo } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Business, Partner, SubscriptionHistory, SubscriptionPlan, Lead, Quotation } from '@/types/database';
import {
  CreditCard,
  Gift,
  Crown,
  Search,
  Filter,
  CheckCircle2,
  Clock,
  AlertTriangle,
  History,
  Store,
  Calendar,
  DollarSign,
  UserCheck,
  ChevronRight,
  Sparkles,
  Zap,
  Info,
  X,
  RefreshCw,
  PlusCircle,
  Building2,
  User,
  ArrowRight,
  FileText,
  Target,
} from 'lucide-react';

export default function SubscriptionsPage() {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [histories, setHistories] = useState<SubscriptionHistory[]>([]);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [quotations, setQuotations] = useState<Quotation[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'businesses' | 'history'>('businesses');

  // Search & Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pro' | 'trial' | 'expiring' | 'free'>('all');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedBusiness, setSelectedBusiness] = useState<Business | null>(null);
  const [autoDetectedMitra, setAutoDetectedMitra] = useState<{
    partner: Partner;
    source: string;
    matchedLead?: Lead;
  } | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // User Role & Partner Scoping
  const [currentUserRole, setCurrentUserRole] = useState<'super_admin' | 'admin' | 'partner'>('admin');
  const [currentPartnerId, setCurrentPartnerId] = useState<string | null>(null);
  const [currentPartnerName, setCurrentPartnerName] = useState<string>('');

  // Modal Form Inputs
  const [modalMode, setModalMode] = useState<'pro' | 'trial'>('pro');
  const [trialDays, setTrialDays] = useState<number>(14);
  const [isTrialLifetime, setIsTrialLifetime] = useState(false);
  const [trialShowAds, setTrialShowAds] = useState<boolean>(true);
  const [customTrialDaysInput, setCustomTrialDaysInput] = useState<string>('');
  const [proDurationMonths, setProDurationMonths] = useState<number>(1);
  const [isLifetime, setIsLifetime] = useState(false);
  const [pricePaid, setPricePaid] = useState<number>(49000);
  const [selectedPartnerId, setSelectedPartnerId] = useState<string>('');
  const [customCommissionRate, setCustomCommissionRate] = useState<number>(20);
  const [commissionAmount, setCommissionAmount] = useState<number>(0);
  const [notes, setNotes] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('Transfer Bank');

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      // 0. Identify user role & partner
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
          if (userRole === 'partner' && !userPartnerId) {
            const { data: pMatch } = await supabase
              .from('partners')
              .select('id, name')
              .eq('email', userEmail)
              .maybeSingle();
            if (pMatch) {
              userPartnerId = pMatch.id;
              userPartnerName = pMatch.name;
              try {
                await supabase.from('admin_users').update({ partner_id: pMatch.id }).eq('id', adminRecord.id);
              } catch (_) {}
            }
          }
          setCurrentUserRole(userRole);
          setCurrentPartnerId(userPartnerId);
          setCurrentPartnerName(userPartnerName);
        } else {
          const { data: pMatch } = await supabase
            .from('partners')
            .select('id, name')
            .eq('email', userEmail)
            .maybeSingle();
          if (pMatch) {
            userRole = 'partner';
            userPartnerId = pMatch.id;
            userPartnerName = pMatch.name;
            setCurrentUserRole('partner');
            setCurrentPartnerId(pMatch.id);
            setCurrentPartnerName(pMatch.name);
          }
        }
      }

      // 1. Fetch businesses with profiles, subscription_plans, and partners
      const { data: bizData, error: bizErr } = await supabase
        .from('businesses')
        .select('*, profiles(id, full_name, email, phone), subscription_plans(*), partners(*)')
        .order('created_at', { ascending: false });

      if (bizErr) throw bizErr;

      // 2. Fetch partners
      const { data: partnerData, error: partnerErr } = await supabase
        .from('partners')
        .select('*')
        .order('name', { ascending: true });

      if (partnerErr) throw partnerErr;

      // 3. Fetch plans
      const { data: planData, error: planErr } = await supabase
        .from('subscription_plans')
        .select('*')
        .order('price_monthly', { ascending: true });

      if (planErr) throw planErr;

      // 4. Fetch subscription histories with joins
      const { data: histData, error: histErr } = await supabase
        .from('subscription_histories')
        .select('*, businesses(id, name, subscription_status, profiles(full_name, email, phone)), subscription_plans(*), partners(*)')
        .order('created_at', { ascending: false })
        .limit(100);

      if (histErr) {
        console.warn('Could not load histories:', histErr.message);
      }

      // 5. Fetch leads for auto-detection
      const { data: leadData } = await supabase
        .from('leads')
        .select('*, partners(*)');

      // 6. Fetch quotations for auto-detection
      const { data: quoteData } = await supabase
        .from('quotations')
        .select('*, partners(*)');

      let finalBizList = (bizData as Business[]) || [];
      let finalHistList = (histData as SubscriptionHistory[]) || [];

      // Scoping: If logged in as partner, only display partner's referred businesses and histories
      if (userRole === 'partner' && userPartnerId) {
        finalBizList = finalBizList.filter(
          (b) => b.referred_by_partner_id === userPartnerId
        );
        finalHistList = finalHistList.filter(
          (h) => h.partner_id === userPartnerId
        );
      }

      setBusinesses(finalBizList);
      setPartners((partnerData as Partner[]) || []);
      setPlans((planData as SubscriptionPlan[]) || []);
      setHistories(finalHistList);
      setLeads((leadData as Lead[]) || []);
      setQuotations((quoteData as Quotation[]) || []);
    } catch (err: any) {
      setErrorMsg(`Gagal memuat data: ${err?.message || 'Terjadi kesalahan sistem'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Update commission when price or partner changes
  useEffect(() => {
    if (!selectedPartnerId || modalMode === 'trial') {
      setCommissionAmount(0);
      return;
    }
    const partner = partners.find((p) => p.id === selectedPartnerId);
    const rate = partner ? partner.commission_rate : customCommissionRate;
    setCustomCommissionRate(rate);
    const calculated = Math.round((pricePaid * rate) / 100);
    setCommissionAmount(calculated);
  }, [selectedPartnerId, pricePaid, modalMode, partners, customCommissionRate]);

  // Dynamic Pricing Tiers from Master subscription_plans
  const proPlan = plans.find((p) => p.code === 'pro');
  const tiers = proPlan?.pricing_tiers || {};
  const price1Month = Number(tiers['1_month'] ?? proPlan?.price_monthly ?? 49000);
  const price3Months = Number(tiers['3_months'] ?? 129000);
  const price6Months = Number(tiers['6_months'] ?? 239000);
  const price1Year = Number(tiers['12_months'] ?? 399000);
  const priceLifetime = Number(tiers['lifetime'] ?? 799000);

  // Phone & string normalization helpers for partner detection
  const normalizePhone = (p?: string | null) => {
    if (!p) return '';
    let cleaned = p.replace(/\D/g, '');
    if (cleaned.startsWith('62')) cleaned = '0' + cleaned.slice(2);
    return cleaned;
  };

  const cleanText = (s?: string | null) => {
    return (s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  };

  // Smart Detection: Automatically detects which Mitra/Marketer referred this client
  const detectPartnerForBusiness = (
    biz: Business,
    partnerList: Partner[],
    leadList: Lead[],
    quoteList: Quotation[]
  ): { partner: Partner; source: string; matchedLead?: Lead } | null => {
    // 1. Direct link on business
    const directPartnerId = biz.referred_by_partner_id || biz.partners?.id;
    if (directPartnerId) {
      const p = partnerList.find((x) => x.id === directPartnerId) || (biz.partners as Partner);
      if (p) {
        return {
          partner: p,
          source: 'Terkait langsung di profil Toko',
        };
      }
    }

    const bizPhone = normalizePhone(biz.profiles?.phone);
    const bizEmail = (biz.profiles?.email || '').trim().toLowerCase();
    const bizName = cleanText(biz.name);

    // 2. Check CRM Leads
    for (const lead of leadList) {
      if (!lead.partner_id) continue;
      const p = partnerList.find((x) => x.id === lead.partner_id) || (lead.partners as Partner);
      if (!p) continue;

      // Match by converted_business_id
      if (lead.converted_business_id === biz.id) {
        return {
          partner: p,
          source: `CRM Leads: "${lead.business_name}" (ID Terkonversi)`,
          matchedLead: lead,
        };
      }

      // Match by phone / WhatsApp
      const leadPhone = normalizePhone(lead.phone);
      if (bizPhone && leadPhone && bizPhone === leadPhone) {
        return {
          partner: p,
          source: `CRM Leads: "${lead.business_name}" (No WhatsApp/HP cocok: ${lead.phone})`,
          matchedLead: lead,
        };
      }

      // Match by email
      if (bizEmail && lead.email && lead.email.trim().toLowerCase() === bizEmail) {
        return {
          partner: p,
          source: `CRM Leads: "${lead.business_name}" (Email cocok: ${lead.email})`,
          matchedLead: lead,
        };
      }

      // Match by business name
      const leadBizName = cleanText(lead.business_name);
      if (
        bizName &&
        leadBizName &&
        (bizName === leadBizName ||
          (bizName.length >= 5 && leadBizName.includes(bizName)) ||
          (leadBizName.length >= 5 && bizName.includes(leadBizName)))
      ) {
        return {
          partner: p,
          source: `CRM Leads: Nama Toko Cocok ("${lead.business_name}")`,
          matchedLead: lead,
        };
      }
    }

    // 3. Check Quotations (Surat Penawaran)
    for (const quote of quoteList) {
      if (!quote.partner_id) continue;
      const p = partnerList.find((x) => x.id === quote.partner_id) || (quote.partners as Partner);
      if (!p) continue;

      // Phone match
      const qPhone = normalizePhone(quote.client_phone);
      if (bizPhone && qPhone && bizPhone === qPhone) {
        return {
          partner: p,
          source: `Surat Penawaran #${quote.quote_number} (No HP: ${quote.client_phone})`,
        };
      }

      // Business name match
      const qBizName = cleanText(quote.client_business_name);
      if (
        bizName &&
        qBizName &&
        (bizName === qBizName ||
          (bizName.length >= 5 && qBizName.includes(bizName)) ||
          (qBizName.length >= 5 && bizName.includes(qBizName)))
      ) {
        return {
          partner: p,
          source: `Surat Penawaran #${quote.quote_number} ("${quote.client_business_name}")`,
        };
      }
    }

    return null;
  };

  // Open Modal for a specific business
  const openActionModal = (biz?: Business) => {
    setErrorMsg(null);
    setSuccessMsg(null);
    const targetBiz = biz || businesses[0] || null;
    setSelectedBusiness(targetBiz);

    if (targetBiz) {
      // Run automatic partner detection
      const detected = detectPartnerForBusiness(targetBiz, partners, leads, quotations);
      if (detected) {
        setAutoDetectedMitra(detected);
        setSelectedPartnerId(detected.partner.id);
        setCustomCommissionRate(detected.partner.commission_rate);
      } else {
        setAutoDetectedMitra(null);
        const existingPartnerId = targetBiz.referred_by_partner_id || targetBiz.partners?.id || '';
        setSelectedPartnerId(existingPartnerId);
      }
      const isAlreadyPro = targetBiz.subscription_plans?.code === 'pro';
      setModalMode(isAlreadyPro ? 'pro' : 'pro');
    } else {
      setAutoDetectedMitra(null);
      setSelectedPartnerId('');
      setModalMode('pro');
    }

    setTrialDays(14);
    setIsTrialLifetime(false);
    setTrialShowAds(targetBiz?.show_ads ?? true);
    setCustomTrialDaysInput('');
    setProDurationMonths(1);
    setIsLifetime(false);
    setPricePaid(price1Month);
    setNotes('');
    setPaymentMethod('Transfer Bank');

    // Partner-specific defaults: Strictly Trial mode, lock to partner
    if (currentUserRole === 'partner') {
      setModalMode('trial');
      setTrialDays(14);
      setIsTrialLifetime(false);
      setSelectedPartnerId(currentPartnerId || '');
    }

    setIsModalOpen(true);
  };

  // Helper to calculate target expiration date
  const calculatedEndDate = useMemo(() => {
    if (!selectedBusiness) return null;
    const now = new Date();
    let baseDate = now;

    // Smart extension: if current subscription is still active and in the future, extend from that future date!
    if (selectedBusiness.subscription_end_at) {
      const currentEnd = new Date(selectedBusiness.subscription_end_at);
      if (currentEnd > now) {
        baseDate = currentEnd;
      }
    }

    if (modalMode === 'trial') {
      if (isTrialLifetime) {
        return null; // Lifetime Trial = null end date
      }
      const target = new Date(baseDate);
      target.setDate(target.getDate() + trialDays);
      return target;
    }

    if (isLifetime) {
      return null; // Lifetime = null end date
    }

    const target = new Date(baseDate);
    target.setMonth(target.getMonth() + proDurationMonths);
    return target;
  }, [selectedBusiness, modalMode, trialDays, isTrialLifetime, proDurationMonths, isLifetime]);

  // Handle Pro Duration Select & Price Auto-Fill
  const handleSelectDuration = (months: number, price: number) => {
    setProDurationMonths(months);
    setIsLifetime(false);
    setPricePaid(price);
  };

  const handleSelectLifetime = (price: number) => {
    setIsLifetime(true);
    setPricePaid(price);
  };

  // Handle Submit Activation / Extension / Trial
  const handleSubmitSubscription = async () => {
    if (!selectedBusiness) {
      setErrorMsg('Pilih toko terlebih dahulu.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      // Partner validation guard
      if (currentUserRole === 'partner') {
        if (modalMode !== 'trial') {
          setErrorMsg('Akun Mitra hanya berwenang memberikan Masa Uji Coba PRO (Trial).');
          setIsSubmitting(false);
          return;
        }
        if (![7, 14, 30, 60].includes(trialDays)) {
          setErrorMsg('Pilihan durasi masa trial untuk Mitra dibatasi pada 7, 14, 30, atau 60 hari.');
          setIsSubmitting(false);
          return;
        }
        if (isTrialLifetime) {
          setErrorMsg('Akun Mitra tidak berwenang memberikan trial selamanya (Lifetime).');
          setIsSubmitting(false);
          return;
        }
      }

      const proPlan = plans.find((p) => p.code === 'pro');
      const freePlan = plans.find((p) => p.code === 'free');

      const isProAction = modalMode === 'pro';
      // Saat trial diberikan, targetPlan adalah proPlan (karena ini Trial PRO)
      const targetPlan = isProAction ? proPlan : (proPlan || selectedBusiness.subscription_plans || freePlan);
      const isLifetimeAction = modalMode === 'trial' ? isTrialLifetime : isLifetime;
      const endAtISO = isLifetimeAction ? null : (calculatedEndDate ? calculatedEndDate.toISOString() : null);
      const finalStatus = modalMode === 'trial' ? 'trial' : 'active';
      const actionType: 'trial' | 'new' | 'renewal' | 'upgrade' =
        modalMode === 'trial'
          ? 'trial'
          : selectedBusiness.subscription_plans?.code === 'pro'
          ? 'renewal'
          : 'upgrade';

      // 1. Update businesses table
      const bizUpdatePayload: any = {
        plan_id: targetPlan?.id,
        subscription_status: finalStatus,
        subscription_end_at: endAtISO,
        show_ads: modalMode === 'trial' ? trialShowAds : false, // Paid pro selalu bebas iklan
        updated_at: new Date().toISOString(),
      };

      if (selectedPartnerId) {
        bizUpdatePayload.referred_by_partner_id = selectedPartnerId;
      }

      // Upgrade limits if Pro or Trial Pro
      if (proPlan) {
        bizUpdatePayload.max_transactions = proPlan.max_transactions_month;
        bizUpdatePayload.max_products = proPlan.max_products;
        bizUpdatePayload.max_outlets = proPlan.max_outlets;
      }

      const { data: updatedBiz, error: bizErr } = await supabase
        .from('businesses')
        .update(bizUpdatePayload)
        .eq('id', selectedBusiness.id)
        .select();

      if (bizErr) throw bizErr;
      if (!updatedBiz || updatedBiz.length === 0) {
        throw new Error('Gagal memperbarui data toko ke database. Pastikan kebijakan RLS mengizinkan admin.');
      }

      // 2. Insert into subscription_histories
      const historyPayload = {
        business_id: selectedBusiness.id,
        plan_id: targetPlan?.id,
        action_type: actionType,
        duration_type: modalMode === 'trial' ? (isTrialLifetime ? 'lifetime' : 'days') : isLifetime ? 'lifetime' : 'months',
        duration_value: modalMode === 'trial' ? (isTrialLifetime ? 0 : trialDays) : isLifetime ? 0 : proDurationMonths,
        price_paid: modalMode === 'trial' ? 0 : pricePaid,
        started_at: new Date().toISOString(),
        ended_at: endAtISO,
        partner_id: selectedPartnerId || null,
        commission_rate: selectedPartnerId ? customCommissionRate : 0,
        commission_amount: selectedPartnerId ? commissionAmount : 0,
        payment_status: modalMode === 'trial' ? 'free_trial' : 'paid',
        payment_method: modalMode === 'trial' ? 'free' : paymentMethod,
        notes: notes || null,
        created_by_admin: currentUserRole === 'partner' ? `Mitra (${currentPartnerName || 'Partner'})` : 'Admin Console',
        created_at: new Date().toISOString(),
      };

      const { data: histInserted, error: histErr } = await supabase
        .from('subscription_histories')
        .insert(historyPayload)
        .select()
        .single();

      if (histErr) {
        console.warn('Subscription history insert notice:', histErr.message);
      }

      // 3. If there is a partner commission, record into partner_commissions
      if (selectedPartnerId && commissionAmount > 0) {
        const partnerCommissionPayload = {
          partner_id: selectedPartnerId,
          business_id: selectedBusiness.id,
          subscription_history_id: histInserted?.id || null,
          subscription_amount: pricePaid,
          commission_rate: customCommissionRate,
          commission_amount: commissionAmount,
          description: `Komisi ${customCommissionRate}% (${modalMode.toUpperCase()}) dari ${selectedBusiness.name}`,
          status: 'earned',
          created_at: new Date().toISOString(),
        };

        const { error: commErr } = await supabase
          .from('partner_commissions')
          .insert(partnerCommissionPayload);

        if (commErr) {
          console.warn('Commission ledger insert notice:', commErr.message);
        }
      }

      // 4. If this business matches any lead in CRM, update that lead to 'won' and mark converted_business_id
      const leadToUpdate =
        autoDetectedMitra?.matchedLead ||
        leads.find(
          (l) =>
            l.partner_id === selectedPartnerId &&
            (normalizePhone(l.phone) === normalizePhone(selectedBusiness.profiles?.phone) ||
              (l.email &&
                l.email.trim().toLowerCase() === (selectedBusiness.profiles?.email || '').trim().toLowerCase()) ||
              cleanText(l.business_name) === cleanText(selectedBusiness.name))
        );

      if (leadToUpdate && leadToUpdate.status !== 'won') {
        const { error: leadUpdErr } = await supabase
          .from('leads')
          .update({
            status: 'won',
            converted_business_id: selectedBusiness.id,
            updated_at: new Date().toISOString(),
          })
          .eq('id', leadToUpdate.id);

        if (leadUpdErr) {
          console.warn('Notice updating lead to won:', leadUpdErr.message);
        }
      }

      setSuccessMsg(
        modalMode === 'trial'
          ? `Masa Trial ${isTrialLifetime ? 'Selamanya (Lifetime)' : `${trialDays} hari`} (${trialShowAds ? 'Dengan Iklan' : 'Bebas Iklan'}) berhasil diberikan untuk "${selectedBusiness.name}".`
          : `Langganan PRO untuk "${selectedBusiness.name}" berhasil diaktifkan / diperpanjang!`
      );

      setIsModalOpen(false);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal memproses langganan: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Metrics computation
  const metrics = useMemo(() => {
    const now = new Date();
    const sevenDaysFromNow = new Date();
    sevenDaysFromNow.setDate(now.getDate() + 7);

    let proActive = 0;
    let trialCount = 0;
    let expiringSoon = 0;

    businesses.forEach((b) => {
      const isPro = b.subscription_plans?.code === 'pro';
      const isTrial = b.subscription_status === 'trial';
      const hasEnd = !!b.subscription_end_at;
      const endDate = hasEnd ? new Date(b.subscription_end_at!) : null;

      if (isTrial) {
        trialCount++;
      } else if (isPro) {
        if (!hasEnd || (endDate && endDate > now)) {
          proActive++;
        }
      }

      if (hasEnd && endDate && endDate > now && endDate <= sevenDaysFromNow) {
        expiringSoon++;
      }
    });

    const totalRevenue = histories.reduce((sum, h) => sum + Number(h.price_paid || 0), 0);

    return {
      proActive,
      trialCount,
      expiringSoon,
      totalRevenue,
    };
  }, [businesses, histories]);

  // Filtered businesses
  const filteredBusinesses = useMemo(() => {
    const now = new Date();
    const sevenDaysFromNow = new Date();
    sevenDaysFromNow.setDate(now.getDate() + 7);

    return businesses.filter((b) => {
      const q = searchQuery.toLowerCase();
      const matchSearch =
        !searchQuery ||
        b.name.toLowerCase().includes(q) ||
        (b.profiles?.full_name || '').toLowerCase().includes(q) ||
        (b.profiles?.email || '').toLowerCase().includes(q) ||
        (b.partners?.name || '').toLowerCase().includes(q);

      if (!matchSearch) return false;

      const isPro = b.subscription_plans?.code === 'pro';
      const isTrial = b.subscription_status === 'trial';
      const hasEnd = !!b.subscription_end_at;
      const endDate = hasEnd ? new Date(b.subscription_end_at!) : null;

      if (statusFilter === 'pro') {
        return isPro && !isTrial && (!hasEnd || (endDate && endDate > now));
      }
      if (statusFilter === 'trial') {
        return isTrial;
      }
      if (statusFilter === 'expiring') {
        return hasEnd && endDate && endDate > now && endDate <= sevenDaysFromNow;
      }
      if (statusFilter === 'free') {
        return !isPro && !isTrial;
      }

      return true;
    });
  }, [businesses, searchQuery, statusFilter]);

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title={currentUserRole === 'partner' ? 'Langganan & Trial Klien' : 'Langganan & Billing'}
        description={
          currentUserRole === 'partner'
            ? 'Kelola pemberian Masa Uji Coba PRO resmi untuk klien rujukan Anda (Pilihan: 7, 14, 30, atau 60 hari)'
            : 'Kelola aktivasi paket PRO, perpanjangan masa aktif, pemberian trial, dan riwayat billing'
        }
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
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-amber-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">PRO Aktif</span>
            <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 flex items-center justify-center text-amber-600">
              <Crown className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{metrics.proActive}</span>
            <span className="text-xs text-slate-500 ml-2">toko berlangganan</span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <Sparkles className="w-3.5 h-3.5 text-amber-500" /> Toko aktif fitur premium
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-indigo-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Masa Trial</span>
            <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center text-indigo-600">
              <Gift className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{metrics.trialCount}</span>
            <span className="text-xs text-slate-500 ml-2">toko uji coba</span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <Clock className="w-3.5 h-3.5 text-indigo-500" /> Uji coba gratis (7-30 hari)
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-rose-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Segera Habis (&lt;7 Hari)</span>
            <div className="w-10 h-10 rounded-xl bg-rose-50 border border-rose-100 flex items-center justify-center text-rose-600">
              <AlertTriangle className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-3xl font-extrabold text-slate-900 tracking-tight">{metrics.expiringSoon}</span>
            <span className="text-xs text-slate-500 ml-2">perlu difollow-up</span>
          </div>
          <p className="mt-2 text-xs text-rose-600 flex items-center gap-1">
            <Clock className="w-3.5 h-3.5" /> Peluang perpanjangan langganan
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs relative overflow-hidden group hover:border-emerald-300 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Pemasukan</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-emerald-600">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rp {metrics.totalRevenue.toLocaleString('id-ID')}
            </span>
          </div>
          <p className="mt-2 text-xs text-slate-500 flex items-center gap-1">
            <History className="w-3.5 h-3.5 text-emerald-600" /> Akumulasi billing tercatat
          </p>
        </div>
      </div>

      {/* Main Container with Tabs */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden">
        {/* Header Bar */}
        <div className="p-6 border-b border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-center gap-2 bg-slate-100 p-1 rounded-xl">
            <button
              onClick={() => setActiveTab('businesses')}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all ${
                activeTab === 'businesses'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Status Langganan Toko ({businesses.length})
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all ${
                activeTab === 'history'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Riwayat Aktivasi & Billing ({histories.length})
            </button>
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
              onClick={() => openActionModal()}
              style={{ background: 'linear-gradient(135deg, #f59e0b 0%, #ea580c 100%)', color: '#ffffff' }}
              className="flex-1 sm:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95"
            >
              <PlusCircle className="w-4 h-4 text-white" />
              <span className="text-white">
                {currentUserRole === 'partner' ? '+ Beri Masa Trial PRO' : '+ Aktivasi / Perpanjang / Trial'}
              </span>
            </button>
          </div>
        </div>

        {/* Tab 1: Businesses Subscription Status */}
        {activeTab === 'businesses' && (
          <div>
            {/* Filter and Search Bar */}
            <div className="p-4 bg-slate-50/60 border-b border-slate-100 flex flex-col md:flex-row gap-3 items-center justify-between">
              <div className="relative w-full md:w-80">
                <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Cari toko, email, atau mitra..."
                  value={searchQuery}
                  onInput={(e) => setSearchQuery((e.target as HTMLInputElement).value)}
                  className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-amber-500 focus:ring-1 focus:ring-amber-500 transition-all"
                />
              </div>

              <div className="flex items-center gap-2 w-full md:w-auto overflow-x-auto pb-1 md:pb-0">
                <span className="text-xs text-slate-400 font-medium whitespace-nowrap">Filter:</span>
                {[
                  { id: 'all', label: 'Semua' },
                  { id: 'pro', label: 'PRO Aktif' },
                  { id: 'trial', label: 'Masa Trial' },
                  { id: 'expiring', label: 'Segera Habis' },
                  { id: 'free', label: 'Free' },
                ].map((f) => (
                  <button
                    key={f.id}
                    onClick={() => setStatusFilter(f.id as any)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
                      statusFilter === f.id
                        ? 'bg-amber-500 text-white shadow-xs'
                        : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                    <th className="py-3.5 px-6">Toko & Pemilik</th>
                    <th className="py-3.5 px-4">Status Paket</th>
                    <th className="py-3.5 px-4">Masa Berlaku</th>
                    <th className="py-3.5 px-4">Mitra Referral</th>
                    <th className="py-3.5 px-6 text-right">Aksi Cepat</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 text-xs">
                  {loading ? (
                    <tr>
                      <td colSpan={5} className="py-12 text-center text-slate-400">
                        <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-slate-400" />
                        Memuat data toko...
                      </td>
                    </tr>
                  ) : filteredBusinesses.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="py-12 text-center text-slate-400">
                        Tidak ada toko yang sesuai dengan filter.
                      </td>
                    </tr>
                  ) : (
                    filteredBusinesses.map((b) => {
                      const isPro = b.subscription_plans?.code === 'pro';
                      const isTrial = b.subscription_status === 'trial';
                      const hasEnd = !!b.subscription_end_at;
                      const now = new Date();
                      const endDate = hasEnd ? new Date(b.subscription_end_at!) : null;
                      const isExpired = endDate ? endDate < now : false;

                      // Remaining days calculation
                      let daysRemainingText = '';
                      if (!hasEnd && isPro && !isTrial) {
                        daysRemainingText = 'Aktif Permanen (Lifetime)';
                      } else if (endDate) {
                        const diffTime = endDate.getTime() - now.getTime();
                        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
                        if (diffDays > 0) {
                          daysRemainingText = `Sisa ${diffDays} hari`;
                        } else {
                          daysRemainingText = `Habis ${Math.abs(diffDays)} hari lalu`;
                        }
                      }

                      return (
                        <tr key={b.id} className="hover:bg-slate-50/70 transition-colors">
                          <td className="py-4 px-6">
                            <div className="flex items-center gap-3">
                              <div className="w-9 h-9 rounded-xl bg-orange-50 border border-orange-100 flex items-center justify-center text-orange-600 font-bold shrink-0">
                                {b.name.charAt(0).toUpperCase()}
                              </div>
                              <div>
                                <div className="font-bold text-slate-900">{b.name}</div>
                                <div className="text-[11px] text-slate-500">
                                  {b.profiles?.full_name || 'Owner'} • {b.profiles?.phone || b.profiles?.email || '-'}
                                </div>
                              </div>
                            </div>
                          </td>

                          <td className="py-4 px-4">
                            {isTrial ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-indigo-50 border border-indigo-200 text-indigo-700">
                                <Gift className="w-3 h-3" /> Masa Trial
                              </span>
                            ) : isPro ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-50 border border-amber-200 text-amber-700">
                                <Crown className="w-3 h-3" /> Paket PRO
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-slate-100 text-slate-600">
                                Paket Free
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
                                <span className="text-amber-600 font-bold">Lifetime</span>
                              ) : (
                                '-'
                              )}
                            </div>
                            <div
                              className={`text-[11px] font-medium ${
                                isExpired
                                  ? 'text-rose-500'
                                  : daysRemainingText.includes('Sisa') && daysRemainingText.includes('7')
                                  ? 'text-amber-600'
                                  : 'text-slate-400'
                              }`}
                            >
                              {daysRemainingText}
                            </div>
                          </td>

                          <td className="py-4 px-4">
                            {b.partners ? (
                              <div className="flex items-center gap-1.5">
                                <div className="w-6 h-6 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-[10px]">
                                  {b.partners.name.charAt(0)}
                                </div>
                                <div>
                                  <div className="font-semibold text-slate-800">{b.partners.name}</div>
                                  <div className="text-[10px] text-emerald-600 font-medium">
                                    Komisi {b.partners.commission_rate}%
                                  </div>
                                </div>
                              </div>
                            ) : (
                              <span className="text-slate-400 text-xs">Tanpa Mitra</span>
                            )}
                          </td>

                          <td className="py-4 px-6 text-right">
                            <button
                              onClick={() => openActionModal(b)}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-amber-500 hover:text-white text-slate-700 text-xs font-semibold transition-all group"
                            >
                              <span>{currentUserRole === 'partner' ? 'Beri Trial PRO' : 'Aktivasi / Perpanjang'}</span>
                              <ChevronRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform" />
                            </button>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 2: Subscription Activation & Billing History */}
        {activeTab === 'history' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-6">Waktu</th>
                  <th className="py-3.5 px-4">Toko / Client</th>
                  <th className="py-3.5 px-4">Aksi & Durasi</th>
                  <th className="py-3.5 px-4">Nominal Bayar</th>
                  <th className="py-3.5 px-4">Mitra & Komisi</th>
                  <th className="py-3.5 px-6">Catatan Admin</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {histories.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-slate-400">
                      Belum ada riwayat aktivasi atau perpanjangan tercatat.
                    </td>
                  </tr>
                ) : (
                  histories.map((h) => {
                    const actionBadge =
                      h.action_type === 'trial' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
                          <Gift className="w-2.5 h-2.5" /> TRIAL
                        </span>
                      ) : h.action_type === 'renewal' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <RefreshCw className="w-2.5 h-2.5" /> PERPANJANGAN
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                          <Crown className="w-2.5 h-2.5" /> PRO BARU
                        </span>
                      );

                    return (
                      <tr key={h.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="py-4 px-6 text-slate-500 whitespace-nowrap">
                          {new Date(h.created_at).toLocaleDateString('id-ID', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </td>

                        <td className="py-4 px-4">
                          <div className="font-bold text-slate-900">{h.businesses?.name || 'Toko Terhapus'}</div>
                          <div className="text-[11px] text-slate-500">
                            {h.businesses?.profiles?.full_name || '-'}
                          </div>
                        </td>

                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            {actionBadge}
                            <span className="font-semibold text-slate-700">
                              {h.duration_type === 'lifetime'
                                ? 'Lifetime'
                                : `${h.duration_value} ${h.duration_type === 'days' ? 'Hari' : 'Bulan'}`}
                            </span>
                          </div>
                          {h.ended_at && (
                            <div className="text-[10px] text-slate-400 mt-0.5">
                              s/d{' '}
                              {new Date(h.ended_at).toLocaleDateString('id-ID', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </div>
                          )}
                        </td>

                        <td className="py-4 px-4 font-bold text-slate-900">
                          {h.price_paid > 0 ? (
                            `Rp ${Number(h.price_paid).toLocaleString('id-ID')}`
                          ) : (
                            <span className="text-slate-400 font-normal">Rp 0 (Trial/Free)</span>
                          )}
                        </td>

                        <td className="py-4 px-4">
                          {h.partners ? (
                            <div>
                              <div className="font-semibold text-slate-800">{h.partners.name}</div>
                              <div className="text-[11px] text-emerald-600 font-bold">
                                + Rp {Number(h.commission_amount).toLocaleString('id-ID')} ({h.commission_rate}%)
                              </div>
                            </div>
                          ) : (
                            <span className="text-slate-400 text-[11px]">-</span>
                          )}
                        </td>

                        <td className="py-4 px-6 text-slate-500 max-w-xs truncate">
                          {h.notes || '-'}
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

      {/* MODAL: AKTIVASI / PERPANJANG / TRIAL */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div
              style={{ background: 'linear-gradient(135deg, #f59e0b 0%, #ea580c 100%)', color: '#ffffff' }}
              className="p-6 bg-amber-500 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <CreditCard className="w-5 h-5 text-amber-200" />
                  <span className="text-white">Aktivasi, Perpanjang & Trial</span>
                </h3>
                <p className="text-xs text-amber-100 mt-0.5">
                  Atur masa aktif paket PRO atau berikan masa uji coba gratis untuk toko
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-6 space-y-6 max-h-[75vh] overflow-y-auto">
              {/* Partner Banner Notice */}
              {currentUserRole === 'partner' && (
                <div className="p-3.5 rounded-2xl bg-indigo-50 border border-indigo-200 flex items-center justify-between text-indigo-950">
                  <div className="flex items-center gap-2.5">
                    <span className="text-xl">🔒</span>
                    <div>
                      <div className="text-xs font-black flex items-center gap-1.5">
                        <span>Mode Mitra: Pemberian Masa Uji Coba PRO</span>
                        <span className="text-[10px] bg-indigo-200 text-indigo-800 px-1.5 py-0.5 rounded font-extrabold">
                          Maksimal 60 Hari
                        </span>
                      </div>
                      <p className="text-[11px] text-indigo-700 mt-0.5">
                        Anda dapat mengaktifkan fitur PRO gratis untuk toko klien Anda dengan durasi resmi: <b>7, 14, 30, atau 60 hari</b>.
                      </p>
                    </div>
                  </div>
                </div>
              )}
              {/* Step 1: Pilih Toko */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                  1. Pilih Toko / Client
                </label>
                <select
                  value={selectedBusiness?.id || ''}
                  onChange={(e) => {
                    const b = businesses.find((item) => item.id === e.target.value);
                    if (b) {
                      setSelectedBusiness(b);
                      const detected = detectPartnerForBusiness(b, partners, leads, quotations);
                      if (detected) {
                        setAutoDetectedMitra(detected);
                        setSelectedPartnerId(detected.partner.id);
                        setCustomCommissionRate(detected.partner.commission_rate);
                      } else {
                        setAutoDetectedMitra(null);
                        setSelectedPartnerId(b.referred_by_partner_id || b.partners?.id || '');
                      }
                    }
                  }}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-800 focus:outline-hidden focus:border-amber-500 focus:ring-1 focus:ring-amber-500"
                >
                  {businesses.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name} ({b.subscription_plans?.name || 'Free'} - {b.subscription_status || 'aktif'})
                    </option>
                  ))}
                </select>
              </div>

              {/* Step 2: Pilih Mode (PRO vs Trial) */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                  2. Pilih Mode Layanan
                </label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => {
                      if (currentUserRole === 'partner') {
                        setErrorMsg(
                          'Aktivasi Langganan PRO berbayar divalidasi oleh Super Admin saat pembayaran diterima. Mitra berwenang memberikan Masa Uji Coba PRO (Maks 60 Hari).'
                        );
                        return;
                      }
                      setModalMode('pro');
                      setPricePaid(49000);
                      setProDurationMonths(1);
                    }}
                    className={`p-3.5 rounded-2xl border text-left flex items-start gap-3 transition-all ${
                      modalMode === 'pro'
                        ? 'border-amber-500 bg-amber-50/50 ring-2 ring-amber-500/20'
                        : 'border-slate-200 hover:border-slate-300'
                    } ${currentUserRole === 'partner' ? 'opacity-50 cursor-not-allowed' : ''}`}
                    title={currentUserRole === 'partner' ? 'Aktivasi berbayar divalidasi oleh Super Admin' : ''}
                  >
                    <div className="w-8 h-8 rounded-xl bg-amber-500 text-white flex items-center justify-center shrink-0">
                      <Crown className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="font-extrabold text-xs text-slate-900 flex items-center gap-1.5">
                        <span>Langganan PRO</span>
                        {currentUserRole === 'partner' && (
                          <span className="text-[9px] bg-amber-100 text-amber-800 px-1 rounded font-bold">
                            🔒 Admin
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] text-slate-500">Berbayar (1 bln s/d Lifetime)</div>
                    </div>
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setModalMode('trial');
                      setPricePaid(0);
                      setTrialDays(14);
                    }}
                    className={`p-3.5 rounded-2xl border text-left flex items-start gap-3 transition-all ${
                      modalMode === 'trial'
                        ? 'border-indigo-500 bg-indigo-50/50 ring-2 ring-indigo-500/20'
                        : 'border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="w-8 h-8 rounded-xl bg-indigo-500 text-white flex items-center justify-center shrink-0">
                      <Gift className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="font-extrabold text-xs text-slate-900">Beri Masa Trial PRO</div>
                      <div className="text-[11px] text-slate-500">
                        {currentUserRole === 'partner'
                          ? 'Pilihan: 7, 14, 30, atau 60 hari'
                          : 'Gratis (7 s/d 90 hari atau Selamanya)'}
                      </div>
                    </div>
                  </button>
                </div>
              </div>

              {/* Step 3: Durasi Pilihan */}
              {modalMode === 'trial' ? (
                <div className="space-y-4">
                  <div className="p-4 rounded-2xl bg-indigo-50/40 border border-indigo-100 space-y-3">
                    <div className="flex items-center justify-between">
                      <label className="block text-xs font-bold text-indigo-950">
                        Durasi Masa Trial:
                      </label>
                      {currentUserRole === 'partner' ? (
                        <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-800">
                          🔒 Pilihan Resmi: 7, 14, 30, atau 60 Hari
                        </span>
                      ) : isTrialLifetime ? (
                        <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-800">
                          👑 Trial Tanpa Batas Waktu
                        </span>
                      ) : null}
                    </div>

                    {currentUserRole === 'partner' ? (
                      /* Partner Mode: Strictly 7, 14, 30, 60 days */
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                        {[
                          { days: 7, label: '7 Hari' },
                          { days: 14, label: '14 Hari' },
                          { days: 30, label: '30 Hari (1 Bln)' },
                          { days: 60, label: '60 Hari (2 Bln)' },
                        ].map((item) => (
                          <button
                            key={item.days}
                            type="button"
                            onClick={() => {
                              setIsTrialLifetime(false);
                              setTrialDays(item.days);
                              setCustomTrialDaysInput('');
                            }}
                            className={`py-3 px-2 rounded-xl text-xs font-bold transition-all text-center ${
                              !isTrialLifetime && trialDays === item.days
                                ? 'bg-indigo-600 text-white shadow-md ring-2 ring-indigo-400/50'
                                : 'bg-white border border-indigo-200 text-indigo-700 hover:bg-indigo-50'
                            }`}
                          >
                            <div>{item.label}</div>
                            {item.days === 14 && (
                              <div className="text-[9px] font-normal opacity-80 mt-0.5">Rekomendasi</div>
                            )}
                          </button>
                        ))}
                      </div>
                    ) : (
                      /* Super Admin / Admin Mode: Full options */
                      <>
                        <div className="grid grid-cols-3 gap-2">
                          {[
                            { days: 7, label: '7 Hari' },
                            { days: 14, label: '14 Hari' },
                            { days: 30, label: '30 Hari (1 Bln)' },
                            { days: 60, label: '60 Hari (2 Bln)' },
                            { days: 90, label: '90 Hari (3 Bln)' },
                          ].map((item) => (
                            <button
                              key={item.days}
                              type="button"
                              onClick={() => {
                                setIsTrialLifetime(false);
                                setTrialDays(item.days);
                                setCustomTrialDaysInput('');
                              }}
                              className={`py-2 px-2 rounded-xl text-xs font-bold transition-all ${
                                !isTrialLifetime && trialDays === item.days
                                  ? 'bg-indigo-600 text-white shadow-xs'
                                  : 'bg-white border border-indigo-200 text-indigo-700 hover:bg-indigo-50'
                              }`}
                            >
                              {item.label}
                            </button>
                          ))}

                          <button
                            type="button"
                            onClick={() => {
                              setIsTrialLifetime(true);
                              setCustomTrialDaysInput('');
                            }}
                            className={`py-2 px-2 rounded-xl text-xs font-bold transition-all ${
                              isTrialLifetime
                                ? 'bg-indigo-600 text-white shadow-xs'
                                : 'bg-white border border-indigo-200 text-indigo-700 hover:bg-indigo-50'
                            }`}
                          >
                            👑 Selamanya
                          </button>
                        </div>

                        {/* Input Custom Hari */}
                        <div className="pt-2 border-t border-indigo-100/80 flex items-center gap-2">
                          <span className="text-[11px] font-semibold text-indigo-900 shrink-0">
                            Atau custom hari:
                          </span>
                          <input
                            type="number"
                            placeholder="Contoh: 45"
                            min="1"
                            value={customTrialDaysInput}
                            onChange={(e) => {
                              const val = e.target.value;
                              setCustomTrialDaysInput(val);
                              const parsed = parseInt(val, 10);
                              if (!isNaN(parsed) && parsed > 0) {
                                setIsTrialLifetime(false);
                                setTrialDays(parsed);
                              }
                            }}
                            className="w-24 px-2.5 py-1.5 rounded-lg border border-indigo-200 bg-white text-xs font-bold text-slate-800 focus:outline-hidden focus:ring-1 focus:ring-indigo-500"
                          />
                          <span className="text-[11px] text-indigo-700">Hari</span>
                        </div>
                      </>
                    )}
                  </div>

                  {/* Pengaturan Iklan Selama Trial */}
                  <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2.5">
                    <label className="block text-xs font-bold text-slate-800">
                      Pengaturan Iklan (AdMob):
                    </label>
                    <p className="text-[11px] text-slate-500">
                      Tentukan apakah toko tetap melihat banner iklan selama masa uji coba
                    </p>

                    <div className="grid grid-cols-2 gap-2 pt-1">
                      <button
                        type="button"
                        onClick={() => setTrialShowAds(true)}
                        className={`p-3 rounded-xl border text-left transition-all ${
                          trialShowAds
                            ? 'bg-amber-50 border-amber-400 text-amber-950 ring-1 ring-amber-400'
                            : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <div className="font-extrabold text-xs flex items-center gap-1.5 text-amber-900">
                          📢 Tetap Tampilkan Iklan
                        </div>
                        <div className="text-[10px] text-amber-800/80 mt-0.5">
                          Insentif upgrade ke Pro Berbayar
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => setTrialShowAds(false)}
                        className={`p-3 rounded-xl border text-left transition-all ${
                          !trialShowAds
                            ? 'bg-emerald-50 border-emerald-400 text-emerald-950 ring-1 ring-emerald-400'
                            : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <div className="font-extrabold text-xs flex items-center gap-1.5 text-emerald-900">
                          🛡️ Bebas Iklan (Tanpa Iklan)
                        </div>
                        <div className="text-[10px] text-emerald-800/80 mt-0.5">
                          100% bersih untuk client VIP / Demo
                        </div>
                      </button>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="p-4 rounded-2xl bg-amber-50/40 border border-amber-100 space-y-3">
                  <label className="block text-xs font-bold text-amber-950">Durasi Langganan PRO:</label>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    {[
                      { m: 1, price: price1Month, label: '1 Bulan' },
                      { m: 3, price: price3Months, label: '3 Bulan' },
                      { m: 6, price: price6Months, label: '6 Bulan' },
                      { m: 12, price: price1Year, label: '1 Tahun' },
                    ].map((tier) => (
                      <button
                        key={tier.m}
                        type="button"
                        onClick={() => handleSelectDuration(tier.m, tier.price)}
                        className={`p-2.5 rounded-xl text-left border transition-all ${
                          !isLifetime && proDurationMonths === tier.m
                            ? 'bg-amber-500 border-amber-600 text-white shadow-xs'
                            : 'bg-white border-slate-200 text-slate-700 hover:border-amber-300'
                        }`}
                      >
                        <div className="font-extrabold text-xs">{tier.label}</div>
                        <div
                          className={`text-[10px] ${
                            !isLifetime && proDurationMonths === tier.m ? 'text-amber-100' : 'text-slate-500'
                          }`}
                        >
                          Rp {tier.price.toLocaleString('id-ID')}
                        </div>
                      </button>
                    ))}

                    <button
                      type="button"
                      onClick={() => handleSelectLifetime(priceLifetime)}
                      className={`p-2.5 rounded-xl text-left border transition-all col-span-2 sm:col-span-1 ${
                        isLifetime
                          ? 'bg-amber-500 border-amber-600 text-white shadow-xs'
                          : 'bg-white border-slate-200 text-slate-700 hover:border-amber-300'
                      }`}
                    >
                      <div className="font-extrabold text-xs flex items-center gap-1">
                        <Sparkles className="w-3 h-3" /> Lifetime
                      </div>
                      <div className={`text-[10px] ${isLifetime ? 'text-amber-100' : 'text-slate-500'}`}>
                        Rp {priceLifetime.toLocaleString('id-ID')}
                      </div>
                    </button>
                  </div>

                  <div className="pt-2">
                    <label className="block text-[11px] font-bold text-slate-700 mb-1">
                      Nominal Pembayaran Diterima (Rp):
                    </label>
                    <input
                      type="number"
                      value={pricePaid}
                      onInput={(e) => setPricePaid(Number((e.target as HTMLInputElement).value))}
                      className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-white text-xs font-bold text-slate-900"
                    />
                  </div>
                </div>
              )}

              {/* Step 4: Mitra / Teman Referral Attribution */}
              <div className="p-4 rounded-2xl bg-emerald-50/40 border border-emerald-100 space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                    <UserCheck className="w-4 h-4 text-emerald-600" />
                    Teman / Mitra Referral (Bagi Hasil):
                  </label>
                  {selectedPartnerId && (
                    <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                      Komisi {customCommissionRate}%
                    </span>
                  )}
                </div>

                {/* Auto Detection Callout */}
                {autoDetectedMitra && (
                  <div className="p-3.5 rounded-xl bg-emerald-100/80 border border-emerald-300 text-emerald-950 flex items-start gap-2.5 shadow-xs">
                    <Sparkles className="w-4 h-4 text-emerald-700 shrink-0 mt-0.5" />
                    <div className="text-xs space-y-1">
                      <div className="font-extrabold flex flex-wrap items-center gap-1.5 text-emerald-950">
                        <span>✓ Terdeteksi Otomatis:</span>
                        <span className="px-2 py-0.5 bg-emerald-700 text-white rounded font-bold">
                          {autoDetectedMitra.partner.name}
                        </span>
                        {autoDetectedMitra.partner.referral_code && (
                          <span className="font-mono text-[10px] bg-white text-emerald-800 border border-emerald-300 px-1.5 py-0.5 rounded">
                            {autoDetectedMitra.partner.referral_code}
                          </span>
                        )}
                        <span className="text-[11px] text-emerald-700 font-semibold">
                          ({autoDetectedMitra.partner.commission_rate}% komisi)
                        </span>
                      </div>
                      <p className="text-[11px] text-emerald-800/90">
                        Sumber: <span className="font-bold">{autoDetectedMitra.source}</span>
                      </p>
                    </div>
                  </div>
                )}

                {currentUserRole === 'partner' ? (
                  <div className="p-3 rounded-xl bg-white border border-emerald-200 text-xs flex items-center justify-between">
                    <div>
                      <span className="text-slate-500 block text-[10px] font-semibold uppercase">Mitra Penanggung Jawab:</span>
                      <span className="font-extrabold text-emerald-800 text-xs">
                        {currentPartnerName || 'Akun Mitra Anda'} (Otomatis Ditautkan)
                      </span>
                    </div>
                    <span className="px-2 py-0.5 rounded bg-emerald-100 text-emerald-800 text-[10px] font-bold">
                      Terkunci
                    </span>
                  </div>
                ) : (
                  <select
                    value={selectedPartnerId}
                    onChange={(e) => {
                      setSelectedPartnerId(e.target.value);
                      if (!e.target.value) {
                        setAutoDetectedMitra(null);
                      }
                    }}
                    className="w-full px-3 py-2 rounded-xl border border-emerald-200 bg-white text-xs font-semibold text-slate-800"
                  >
                    <option value="">-- Tanpa Mitra / Milik Sendiri --</option>
                    {partners.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.commission_rate}% - {p.phone || p.bank_name || 'Mitra'})
                      </option>
                    ))}
                  </select>
                )}

                {selectedPartnerId && modalMode === 'pro' && (
                  <div className="bg-white p-3 rounded-xl border border-emerald-200 text-xs flex items-center justify-between">
                    <span className="text-slate-600">Komisi Otomatis Masuk ke Mitra:</span>
                    <span className="font-extrabold text-emerald-700 text-sm">
                      Rp {commissionAmount.toLocaleString('id-ID')}
                    </span>
                  </div>
                )}
              </div>

              {/* Smart Extension Preview */}
              <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs flex items-center gap-3">
                <Info className="w-4 h-4 text-slate-400 shrink-0" />
                <div className="text-slate-600">
                  Masa aktif baru:{' '}
                  <span className="font-bold text-slate-900">
                    {calculatedEndDate
                      ? calculatedEndDate.toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'long',
                          year: 'numeric',
                        })
                      : 'Lifetime (Selamanya)'}
                  </span>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Catatan Transaksi / Bukti Bayar:
                </label>
                <input
                  type="text"
                  placeholder="Contoh: Transfer BCA an Budi / Pembayaran Cash / Trial Pameran"
                  value={notes}
                  onInput={(e) => setNotes((e.target as HTMLInputElement).value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs text-slate-800"
                />
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setIsModalOpen(false)}
                className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
              >
                Batal
              </button>

              <button
                type="button"
                onClick={handleSubmitSubscription}
                disabled={isSubmitting}
                style={{ backgroundColor: '#f59e0b', color: '#ffffff' }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    <span className="text-white">Menyimpan...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-white" />
                    <span className="text-white">Simpan & Aktifkan</span>
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
