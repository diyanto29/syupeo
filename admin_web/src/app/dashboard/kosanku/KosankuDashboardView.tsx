'use client';

import { useState, useMemo, useTransition, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Navbar from '@/components/Navbar';
import {
  Home,
  Building,
  BedDouble,
  Users,
  Cloud,
  Zap,
  CreditCard,
  KeyRound,
  Search,
  CheckCircle2,
  AlertCircle,
  Copy,
  Check,
  Phone,
  Calendar,
  Layers,
  ArrowUpRight,
  ShieldCheck,
  RefreshCw,
  Clock,
  Sparkles,
  Package,
  Edit3,
  Plus,
  Trash2,
  Tag,
  Percent,
  CheckSquare,
  X,
  ExternalLink,
  Wrench,
  DoorOpen,
  DoorClosed,
  TrendingUp,
  MapPin,
  Eye,
  Crown,
  Coins,
  MessageSquare,
  Share2,
  Send,
  UserCheck,
} from 'lucide-react';
import {
  updateSubscriptionPackageAction,
  createOrActivateLicenseAction,
  toggleLicenseStatusAction,
  extendLicenseExpiryAction,
  deleteLicenseAction,
  setJuraganSubscriptionAction,
  toggleCommissionStatusAction,
  markAllReferrerCommissionsPaidAction,
  generateKosankuSerialKey,
  SubscriptionPackageInput,
} from './actions';

export interface KosankuProperty {
  id: string;
  user_id?: string;
  property_name?: string;
  name?: string;
  tagline?: string | null;
  owner_name?: string | null;
  owner_phone?: string | null;
  phone?: string | null;
  address?: string | null;
  bank_name?: string | null;
  account_number?: string | null;
  account_holder?: string | null;
  rules?: string | null;
  created_at?: string;
}

export interface KosankuRoom {
  id: string;
  property_id?: string;
  room_number: string;
  floor?: number | string | null;
  room_type?: string | null;
  monthly_price?: number;
  monthly_rate?: number;
  status: 'VACANT' | 'OCCUPIED' | 'MAINTENANCE' | 'SERVICE' | string;
  facilities?: string | null;
  electricity_type?: string | null;
  notes?: string | null;
  created_at?: string;
  property_name?: string;
}

export interface KosankuTenant {
  id: string;
  property_id?: string;
  name?: string;
  full_name?: string;
  phone?: string | null;
  nik?: string | null;
  occupation?: string | null;
  emergency_name?: string | null;
  emergency_phone?: string | null;
  is_active: boolean;
  created_at?: string;
}

export interface KosankuBill {
  id: string;
  property_id?: string;
  room_id?: string;
  tenant_id?: string;
  period_month: string;
  total_amount: number;
  paid_amount: number;
  status: 'PAID' | 'UNPAID' | 'PARTIAL' | string;
  due_date?: string | null;
  created_at?: string;
}

export interface KosankuLicense {
  id: string;
  user_id?: string | null;
  hardware_id: string;
  serial_key: string;
  plan_code: string;
  is_active: boolean;
  expires_at?: string | null;
  created_at: string;
  notes?: string | null;
}

export interface KosankuPackage {
  id: string;
  name: string;
  badge: string;
  sub_badge?: string | null;
  tagline: string;
  price: number;
  price_display: string;
  original_price_display?: string | null;
  period_display: string;
  secondary_price_display?: string | null;
  discount_badge?: string | null;
  suitable_for?: string | null;
  features?: string[] | any;
  button_text: string;
  sort_order: number;
  is_best_seller: boolean;
  is_active: boolean;
}

interface KosankuDashboardViewProps {
  properties: KosankuProperty[];
  rooms: KosankuRoom[];
  tenants: KosankuTenant[];
  bills: KosankuBill[];
  licenses: KosankuLicense[];
  packages: KosankuPackage[];
  authUsers?: { id: string; email: string }[];
  dbConnected: boolean;
  dbError?: string | null;
}

export default function KosankuDashboardView({
  properties,
  rooms,
  tenants,
  bills,
  licenses,
  packages,
  authUsers,
  dbConnected,
  dbError,
}: KosankuDashboardViewProps) {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<'dashboard' | 'commissions' | 'packages' | 'licenses' | 'rooms' | 'tenants'>('dashboard');
  const [searchQuery, setSearchQuery] = useState('');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Local state for instant optimistic updates
  const [packagesList, setPackagesList] = useState<KosankuPackage[]>(packages);
  useEffect(() => {
    setPackagesList(packages);
  }, [packages]);

  // Selected Juragan Modal Detail
  const [selectedJuragan, setSelectedJuragan] = useState<KosankuProperty | null>(null);

  // Notification Banner
  const [alertMessage, setAlertMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // Package Editor Modal State
  // Modal Atur Paket Juragan Kost
  const [selectedJuraganForPlan, setSelectedJuraganForPlan] = useState<any | null>(null);
  const [juraganTargetUserId, setJuraganTargetUserId] = useState<string>('');
  const [juraganSelectedPlan, setJuraganSelectedPlan] = useState<'starter' | 'mandiri_lifetime' | 'cloud_yearly' | 'cloud_monthly' | 'cloud_custom'>('cloud_yearly');
  const [juraganDurationYears, setJuraganDurationYears] = useState<number>(1);
  const [juraganCustomExpiry, setJuraganCustomExpiry] = useState<string>('');
  const [juraganReferrerName, setJuraganReferrerName] = useState<string>('');
  const [juraganCommissionAmount, setJuraganCommissionAmount] = useState<number>(0);


  const handleOpenJuraganPlanModal = (juragan: any) => {
    setSelectedJuraganForPlan(juragan);
    setJuraganTargetUserId(juragan.user_id || '');
    setJuraganSelectedPlan(juragan.planType === 'mandiri' ? 'mandiri_lifetime' : juragan.planType === 'cloud' ? 'cloud_yearly' : 'cloud_yearly');
    setJuraganDurationYears(1);
    setJuraganCustomExpiry('');
    setJuraganReferrerName(juragan.activeLicense?.referrer_name || '');
    setJuraganCommissionAmount(juragan.activeLicense?.commission_amount || 0);
  };

  const handleSaveJuraganPlan = () => {
    if (!selectedJuraganForPlan) return;
    const targetUserId = juraganTargetUserId || selectedJuraganForPlan.user_id;

    if (!targetUserId) {
      showAlert('error', 'User ID / Akun Juragan Kost belum terhubung ke Supabase!');
      return;
    }

    startTransition(async () => {
      const res = await setJuraganSubscriptionAction({
        userId: targetUserId,
        planCode: juraganSelectedPlan,
        durationYears: juraganDurationYears,
        customExpiresAt: juraganCustomExpiry ? new Date(juraganCustomExpiry).toISOString() : null,
        buyerName: selectedJuraganForPlan.owner_name || selectedJuraganForPlan.name,
        referrerName: juraganReferrerName || undefined,
        commissionAmount: Number(juraganCommissionAmount) || 0,
        propertyId: selectedJuraganForPlan.id,
      });

      if (res.success) {
        showAlert('success', res.message);
        setSelectedJuraganForPlan(null);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };


  const [editingPackage, setEditingPackage] = useState<KosankuPackage | null>(null);
  const [pkgFormData, setPkgFormData] = useState<SubscriptionPackageInput | null>(null);

  // New License Modal State (With Commission)
  const [isLicenseModalOpen, setIsLicenseModalOpen] = useState(false);
  const [licenseHwId, setLicenseHwId] = useState('');
  const [licensePlan, setLicensePlan] = useState<'mandiri_lifetime' | 'cloud_monthly' | 'cloud_yearly' | 'cloud_lifetime'>('mandiri_lifetime');
  const [buyerName, setBuyerName] = useState('');
  const [licensePrice, setLicensePrice] = useState<number | ''>(149000);
  const [platform, setPlatform] = useState<string>('WhatsApp');
  const [hasReferral, setHasReferral] = useState(false);
  const [referrerName, setReferrerName] = useState('');
  const [commissionAmount, setCommissionAmount] = useState<number | ''>(50000);
  const [commissionStatus, setCommissionStatus] = useState<'unpaid' | 'paid'>('unpaid');
  const [licenseNotes, setLicenseNotes] = useState('');
  const [previewSerialKey, setPreviewSerialKey] = useState('');

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(id);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const showAlert = (type: 'success' | 'error', text: string) => {
    setAlertMessage({ type, text });
    setTimeout(() => setAlertMessage(null), 4000);
  };

  const formatIDR = (val: number | undefined | null) => {
    const num = Number(val) || 0;
    return `Rp ${num.toLocaleString('id-ID')}`;
  };

  // =========================================================================
  // METRICS COMPUTATIONS (GLOBAL KPI)
  // =========================================================================
  const totalJuragan = properties.length;
  const totalRooms = rooms.length;
  const occupiedRooms = rooms.filter((r) => r.status?.toUpperCase() === 'OCCUPIED').length;
  const vacantRooms = rooms.filter((r) => r.status?.toUpperCase() === 'VACANT').length;
  const serviceRooms = rooms.filter((r) => {
    const s = r.status?.toUpperCase();
    return s === 'MAINTENANCE' || s === 'SERVICE';
  }).length;
  const totalTenants = tenants.filter((t) => t.is_active).length;
  const activeLicenses = licenses.filter((l) => l.is_active).length;
  const occupancyRate = totalRooms > 0 ? Math.round((occupiedRooms / totalRooms) * 100) : 0;

  // =========================================================================
  // PARSE METADATA KOMISI LISENSI
  // =========================================================================
  const parsedLicenses = useMemo(() => {
    return licenses.map((lic) => {
      let meta: any = {};
      try {
        meta = JSON.parse(lic.notes || '{}');
      } catch {
        meta = { note_text: lic.notes || '' };
      }

      return {
        ...lic,
        buyer_name: meta.buyer_name || null,
        license_price: Number(meta.license_price) || (lic.plan_code.includes('mandiri') ? 149000 : 29000),
        referrer_name: meta.referrer_name || null,
        commission_amount: Number(meta.commission_amount) || 0,
        commission_status: (meta.commission_status as 'unpaid' | 'paid' | 'none') || (meta.referrer_name ? 'unpaid' : 'none'),
        platform: meta.platform || 'Direct',
        history: Array.isArray(meta.history) ? meta.history : [],
        display_notes: meta.note_text || (typeof meta === 'string' ? meta : lic.notes),
      };
    });
  }, [licenses]);

  // Statistik Komisi Global
  const commissionStats = useMemo(() => {
    let pending = 0;
    let paid = 0;
    const referrersMap = new Map<string, { total: number; pending: number; paid: number; count: number }>();

    for (const lic of parsedLicenses) {
      if (lic.referrer_name) {
        const refName = lic.referrer_name.trim();
        const amt = lic.commission_amount || 0;

        if (lic.commission_status === 'paid') {
          paid += amt;
        } else {
          pending += amt;
        }

        const curr = referrersMap.get(refName) || { total: 0, pending: 0, paid: 0, count: 0 };
        curr.total += amt;
        curr.count += 1;
        if (lic.commission_status === 'paid') {
          curr.paid += amt;
        } else {
          curr.pending += amt;
        }
        referrersMap.set(refName, curr);
      }
    }

    return {
      pendingCommission: pending,
      paidCommission: paid,
      totalCommission: pending + paid,
      referrersMap,
    };
  }, [parsedLicenses]);

  // List Mitra dengan Statistik Komisi
  const referrersList = useMemo(() => {
    const list: Array<{ name: string; total: number; pending: number; paid: number; count: number }> = [];
    commissionStats.referrersMap.forEach((val, name) => {
      list.push({ name, ...val });
    });
    return list.sort((a, b) => b.total - a.total);
  }, [commissionStats]);

  // Filtered Juragan List
  const juraganListWithMetrics = useMemo(() => {
    return properties.map((prop) => {
      const propRooms = rooms.filter((r) => r.property_id === prop.id);
      const pTotal = propRooms.length;
      const pOccupied = propRooms.filter((r) => r.status?.toUpperCase() === 'OCCUPIED').length;
      const pVacant = propRooms.filter((r) => r.status?.toUpperCase() === 'VACANT').length;
      const pService = propRooms.filter((r) => {
        const s = r.status?.toUpperCase();
        return s === 'MAINTENANCE' || s === 'SERVICE';
      }).length;
      const pTenants = tenants.filter((t) => t.property_id === prop.id && t.is_active).length;
      const pRate = pTotal > 0 ? Math.round((pOccupied / pTotal) * 100) : 0;

      // Cari email dan lisensi aktif akun juragan
      const userEmail = authUsers?.find((u) => u.id === prop.user_id)?.email || null;
      const activeLicense = parsedLicenses.find(
        (l) => l.is_active && l.user_id && l.user_id === prop.user_id
      ) || parsedLicenses.find(
        (l) => l.is_active && (
          (prop.owner_name && l.buyer_name?.toLowerCase().includes(prop.owner_name.toLowerCase())) ||
          (prop.property_name && l.notes?.includes(prop.property_name))
        )
      );

      let planType: 'starter' | 'mandiri' | 'cloud' = 'starter';
      let planBadge = 'Starter (Free)';
      let planSubtitle = 'Maks. 5 Kamar';
      let expiresAt: string | null = null;
      let isExpired = false;

      if (activeLicense) {
        expiresAt = activeLicense.expires_at || null;
        const code = (activeLicense.plan_code || '').toLowerCase();
        if (code.includes('cloud')) {
          if (expiresAt && new Date(expiresAt).getTime() < Date.now()) {
            isExpired = true;
            planType = 'cloud';
            planBadge = 'Cloud (Kedaluwarsa)';
            planSubtitle = `Habis ${new Date(expiresAt).toLocaleDateString('id-ID')}`;
          } else {
            planType = 'cloud';
            planBadge = 'Juragan Cloud';
            planSubtitle = expiresAt
              ? `s/d ${new Date(expiresAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}`
              : 'Aktif Selamanya';
          }
        } else if (code.includes('mandiri')) {
          planType = 'mandiri';
          planBadge = 'Juragan Mandiri';
          planSubtitle = 'Lifetime (1x Beli)';
        }
      }

      return {
        ...prop,
        userEmail,
        activeLicense,
        activeLicenseHistory: activeLicense?.history || [],
        planType,
        planBadge,
        planSubtitle,
        isExpired,
        roomsCount: pTotal,
        occupiedCount: pOccupied,
        vacantCount: pVacant,
        serviceCount: pService,
        tenantsCount: pTenants,
        occupancyRate: pRate,
        roomsList: propRooms,
      };
    });
  }, [properties, rooms, tenants, authUsers, parsedLicenses]);

  const cloudCount = useMemo(() => juraganListWithMetrics.filter(j => j.planType === 'cloud' && !j.isExpired).length, [juraganListWithMetrics]);
  const mandiriCount = useMemo(() => juraganListWithMetrics.filter(j => j.planType === 'mandiri').length, [juraganListWithMetrics]);
  const starterCount = useMemo(() => juraganListWithMetrics.filter(j => j.planType === 'starter' || j.isExpired).length, [juraganListWithMetrics]);

  const filteredJuraganList = useMemo(() => {
    if (!searchQuery) return juraganListWithMetrics;
    const q = searchQuery.toLowerCase();
    return juraganListWithMetrics.filter(
      (j) =>
        (j.property_name || j.name)?.toLowerCase().includes(q) ||
        j.owner_name?.toLowerCase().includes(q) ||
        (j.owner_phone || j.phone)?.toLowerCase().includes(q) ||
        j.address?.toLowerCase().includes(q)
    );
  }, [juraganListWithMetrics, searchQuery]);

  // Filtered Licenses
  const filteredLicenses = useMemo(() => {
    if (!searchQuery) return parsedLicenses;
    const q = searchQuery.toLowerCase();
    return parsedLicenses.filter(
      (l) =>
        l.hardware_id?.toLowerCase().includes(q) ||
        l.serial_key?.toLowerCase().includes(q) ||
        l.plan_code?.toLowerCase().includes(q) ||
        l.referrer_name?.toLowerCase().includes(q) ||
        l.buyer_name?.toLowerCase().includes(q)
    );
  }, [parsedLicenses, searchQuery]);

  // Handle Edit Package
  const handleOpenEditPackage = (pkg: KosankuPackage) => {
    setEditingPackage(pkg);
    setPkgFormData({
      id: pkg.id,
      name: pkg.name,
      badge: pkg.badge,
      sub_badge: pkg.sub_badge || '',
      tagline: pkg.tagline,
      price: pkg.price,
      price_display: pkg.price_display,
      original_price_display: pkg.original_price_display || '',
      period_display: pkg.period_display,
      secondary_price_display: pkg.secondary_price_display || '',
      discount_badge: pkg.discount_badge || '',
      suitable_for: pkg.suitable_for || '',
      button_text: pkg.button_text,
      is_best_seller: pkg.is_best_seller,
      is_active: pkg.is_active,
      features: Array.isArray(pkg.features) ? pkg.features : [],
    });
  };

  const handleSavePackage = () => {
    if (!pkgFormData) return;
    startTransition(async () => {
      const res = await updateSubscriptionPackageAction(pkgFormData);
      if (res.success) {
        showAlert('success', res.message);
        setPackagesList((prev) =>
          prev.map((p) => (p.id === pkgFormData.id ? { ...p, ...pkgFormData } : p))
        );
        setEditingPackage(null);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  // Handle Serial Key Generation
  const handleHardwareIdChange = async (val: string) => {
    setLicenseHwId(val);
    if (val.trim().length >= 8) {
      const key = await generateKosankuSerialKey(val);
      setPreviewSerialKey(key);
    } else {
      setPreviewSerialKey('');
    }
  };

  const handleCreateLicense = () => {
    if (!licenseHwId.trim()) {
      showAlert('error', 'Hardware ID wajib diisi!');
      return;
    }
    startTransition(async () => {
      const res = await createOrActivateLicenseAction({
        hardware_id: licenseHwId,
        plan_code: licensePlan,
        buyer_name: buyerName,
        license_price: Number(licensePrice) || 0,
        platform,
        referrer_name: hasReferral ? referrerName : undefined,
        commission_amount: hasReferral ? Number(commissionAmount) || 0 : 0,
        commission_status: hasReferral ? commissionStatus : 'none',
        notes: licenseNotes,
      });
      if (res.success) {
        showAlert('success', `${res.message} Serial Key: ${res.serialKey}`);
        setIsLicenseModalOpen(false);
        setLicenseHwId('');
        setBuyerName('');
        setReferrerName('');
        setLicenseNotes('');
        setPreviewSerialKey('');
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  const handleToggleCommission = (licenseId: string, currentStatus: 'unpaid' | 'paid' | 'none') => {
    const nextStatus = currentStatus === 'paid' ? 'unpaid' : 'paid';
    startTransition(async () => {
      const res = await toggleCommissionStatusAction(licenseId, nextStatus);
      if (res.success) {
        showAlert('success', res.message);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  const handleMarkReferrerPaid = (refName: string) => {
    if (!confirm(`Tandai semua komisi pending untuk "${refName}" sebagai SUDAH DITRANSFER (LUNAS)?`)) return;
    startTransition(async () => {
      const res = await markAllReferrerCommissionsPaidAction(refName);
      if (res.success) {
        showAlert('success', res.message);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  const handleSendWhatsAppToReferrer = (refName: string, pendingAmt: number, totalAmt: number) => {
    const text = encodeURIComponent(
      `Halo Kak *${refName}*,\n\nTerima kasih banyak atas rekomendasi pembeli aplikasi *KosanKu*! 🙏\n\nBerikut rekap komisi Kakak:\n• Komisi Siap Cair : *${formatIDR(pendingAmt)}*\n• Total Komisi Akumulasi : *${formatIDR(totalAmt)}*\n\nMohon kirimkan nomor rekening / e-wallet untuk pencairan komisi ya kak. Terima kasih! 🏢✨`
    );
    window.open(`https://wa.me/?text=${text}`, '_blank');
  };

  const handleToggleLicense = (id: string, currentStatus: boolean) => {
    startTransition(async () => {
      const res = await toggleLicenseStatusAction(id, currentStatus);
      if (res.success) {
        showAlert('success', res.message);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  const handleExtendExpiry = (id: string, days: number) => {
    startTransition(async () => {
      const res = await extendLicenseExpiryAction(id, days);
      if (res.success) {
        showAlert('success', res.message);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  const handleDeleteLicense = (id: string) => {
    if (!confirm('Yakin ingin menghapus lisensi ini dari Supabase?')) return;
    startTransition(async () => {
      const res = await deleteLicenseAction(id);
      if (res.success) {
        showAlert('success', res.message);
        router.refresh();
      } else {
        showAlert('error', res.message);
      }
    });
  };

  return (
    <div className="space-y-8">
      {/* Navbar Header */}
      <Navbar
        title="Ringkasan Sistem KosanKu"
        description="Pantau pertumbuhan juragan kost, kamar, sistem bagi komisi mitra affiliate, dan konfigurasi paket harga"
      />

      {/* Alert Banner */}
      {alertMessage && (
        <div
          className={`p-4 rounded-xl border flex items-center justify-between text-sm font-semibold transition-all ${
            alertMessage.type === 'success'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
              : 'bg-rose-50 border-rose-200 text-rose-800'
          }`}
        >
          <div className="flex items-center gap-2">
            {alertMessage.type === 'success' ? (
              <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
            ) : (
              <AlertCircle className="w-5 h-5 text-rose-600 flex-shrink-0" />
            )}
            <span>{alertMessage.text}</span>
          </div>
          <button onClick={() => setAlertMessage(null)} className="text-slate-400 hover:text-slate-600">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 1. WELCOME HERO BANNER (Persis Mangga POS, Deep Contrast)                */}
      {/* ========================================================================= */}
      <div
        className="relative overflow-hidden rounded-3xl p-8 text-white shadow-2xl transition-all"
        style={{
          background: 'linear-gradient(135deg, #1e1b4b 0%, #312e81 40%, #4338ca 80%, #581c87 100%)',
          color: '#ffffff',
          boxShadow: '0 20px 25px -5px rgba(49, 46, 129, 0.35), 0 8px 10px -6px rgba(49, 46, 129, 0.25)',
        }}
      >
        <div
          className="absolute -top-12 -right-12 w-80 h-80 rounded-full blur-3xl pointer-events-none"
          style={{ background: 'rgba(255, 255, 255, 0.12)' }}
        />
        <div
          className="absolute -bottom-16 -left-16 w-64 h-64 rounded-full blur-2xl pointer-events-none"
          style={{ background: 'rgba(129, 140, 248, 0.18)' }}
        />
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2.5">
            <div
              className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border backdrop-blur-sm"
              style={{
                backgroundColor: 'rgba(255, 255, 255, 0.16)',
                borderColor: 'rgba(255, 255, 255, 0.3)',
                color: '#ffffff',
              }}
            >
              <Sparkles className="w-3.5 h-3.5 text-amber-300" />
              Super Admin KosanKu Cloud
            </div>
            <h2 className="text-2xl md:text-3xl font-black tracking-tight" style={{ color: '#ffffff' }}>
              Monitoring Juragan KosanKu & Sistem Komisi Mitra
            </h2>
            <p className="text-sm max-w-2xl leading-relaxed" style={{ color: '#e0e7ff' }}>
              Pantau seluruh bisnis kost terdaftar, status kamar terisi, kosong, service, serta kelola
              paket harga dan bagi hasil komisi mitra referral secara langsung.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={() => setActiveTab('packages')}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-sm shadow-lg transition-all hover:scale-102 hover:shadow-xl active:scale-98 cursor-pointer"
              style={{
                backgroundColor: '#ffffff',
                color: '#312e81',
              }}
            >
              <Crown className="w-4 h-4 text-amber-500" />
              Atur Harga Paket
            </button>
            <button
              onClick={() => {
                setActiveTab('licenses');
                setIsLicenseModalOpen(true);
              }}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-sm transition-all hover:bg-white/25 active:scale-98 cursor-pointer"
              style={{
                backgroundColor: 'rgba(255, 255, 255, 0.16)',
                color: '#ffffff',
                border: '1px solid rgba(255, 255, 255, 0.35)',
                backdropFilter: 'blur(8px)',
              }}
            >
              <KeyRound className="w-4 h-4 text-amber-300" />
              + Terbitkan Lisensi & Komisi
            </button>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* 2. STATS GRID (4 KOLOM UTAMA PERSIS MANGGA POS)                           */}
      {/* ========================================================================= */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* Card 1: Total Juragan Kost */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="w-12 h-12 rounded-xl bg-indigo-50 border border-indigo-200 flex items-center justify-center text-indigo-600">
              <Building className="w-6 h-6" />
            </div>
            <button
              onClick={() => setActiveTab('dashboard')}
              className="text-xs text-indigo-600 hover:text-indigo-700 flex items-center gap-1 font-bold"
            >
              Lihat <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>
          <div className="mt-4">
            <div className="text-3xl font-extrabold text-slate-900 tracking-tight">
              {totalJuragan}
            </div>
            <p className="text-xs font-semibold text-slate-500 mt-1">Total Juragan Kost Terdaftar</p>
          </div>
        </div>

        {/* Card 2: Total Kamar Kost */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="w-12 h-12 rounded-xl bg-purple-50 border border-purple-200 flex items-center justify-center text-purple-600">
              <BedDouble className="w-6 h-6" />
            </div>
            <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-purple-100 text-purple-800 border border-purple-200">
              KAPASITAS
            </span>
          </div>
          <div className="mt-4">
            <div className="text-3xl font-extrabold text-purple-700 tracking-tight">
              {totalRooms}
            </div>
            <p className="text-xs font-semibold text-slate-500 mt-1">Total Kamar di Semua Kost</p>
          </div>
        </div>

        {/* Card 3: Kamar Terisi (Occupancy) */}
        <div className="bg-white rounded-2xl p-6 border border-emerald-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="w-12 h-12 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600">
              <DoorClosed className="w-6 h-6" />
            </div>
            <span className="text-xs text-emerald-600 font-bold flex items-center gap-1">
              <TrendingUp className="w-3.5 h-3.5" /> {occupancyRate}% Terisi
            </span>
          </div>
          <div className="mt-4">
            <div className="text-3xl font-extrabold text-emerald-700 tracking-tight">
              {occupiedRooms}
            </div>
            <p className="text-xs font-semibold text-slate-500 mt-1">Kamar Terisi ({totalTenants} Penghuni)</p>
          </div>
        </div>

        {/* Card 4: Kamar Kosong & Service */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm relative overflow-hidden group hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="w-12 h-12 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
              <DoorOpen className="w-6 h-6" />
            </div>
            <div className="flex items-center gap-1.5">
              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800">
                {vacantRooms} Kosong
              </span>
              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-rose-100 text-rose-800">
                {serviceRooms} Service
              </span>
            </div>
          </div>
          <div className="mt-4">
            <div className="text-3xl font-extrabold text-slate-900 tracking-tight">
              {vacantRooms + serviceRooms}
            </div>
            <p className="text-xs font-semibold text-slate-500 mt-1">Kamar Siap Sewa & Perbaikan</p>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* 3. ROW KOMISI MITRA SUMMARY (Persis Mangga POS)                           */}
      {/* ========================================================================= */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
        {/* Pending Payout */}
        <div className="bg-gradient-to-br from-amber-50 to-orange-50/60 border border-amber-200 rounded-2xl p-5 shadow-xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-amber-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-amber-800">
                Komisi Belum Ditransfer (Pending)
              </span>
            </div>
            <span className="px-2 py-0.5 bg-amber-200/60 text-amber-900 rounded text-[10px] font-bold">
              Harus Ditransfer
            </span>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-amber-900 leading-tight">
              {formatIDR(commissionStats.pendingCommission)}
            </div>
            <p className="text-xs text-amber-700/80 mt-1">
              Hak komisi teman yang menunggu pencairan
            </p>
          </div>
        </div>

        {/* Paid Payout */}
        <div className="bg-gradient-to-br from-emerald-50 to-teal-50/60 border border-emerald-200 rounded-2xl p-5 shadow-xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-emerald-800">
                Komisi Sudah Ditransfer (Lunas)
              </span>
            </div>
            <span className="px-2 py-0.5 bg-emerald-200/60 text-emerald-900 rounded text-[10px] font-bold">
              Selesai Cair
            </span>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-emerald-900 leading-tight">
              {formatIDR(commissionStats.paidCommission)}
            </div>
            <p className="text-xs text-emerald-700/80 mt-1">
              Total komisi yang telah sukses dibayarkan
            </p>
          </div>
        </div>

        {/* Total Komisi & Mitra */}
        <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Users className="w-4 h-4 text-indigo-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Mitra & Teman Affiliate
              </span>
            </div>
            <button
              onClick={() => setActiveTab('commissions')}
              className="text-xs text-indigo-600 hover:text-indigo-700 font-bold"
            >
              Lihat Rekap →
            </button>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-black text-indigo-900 leading-tight">
              {referrersList.length} Mitra
            </div>
            <p className="text-xs text-slate-500 mt-1">
              Akumulasi {formatIDR(commissionStats.totalCommission)} total bagi hasil
            </p>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* 4. MAIN TABBED CONTAINER                                                  */}
      {/* ========================================================================= */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        {/* Navigation Tabs Header */}
        <div className="p-4 border-b border-slate-100 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
            <button
              onClick={() => setActiveTab('dashboard')}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                activeTab === 'dashboard'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Building className="w-3.5 h-3.5" />
              <span>Daftar Juragan Kost ({properties.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('commissions')}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                activeTab === 'commissions'
                  ? 'bg-amber-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Coins className="w-3.5 h-3.5" />
              <span>🤝 Rekap Komisi Mitra ({referrersList.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('packages')}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                activeTab === 'packages'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Package className="w-3.5 h-3.5" />
              <span>Paket & Harga Langganan ({packagesList.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('licenses')}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                activeTab === 'licenses'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <KeyRound className="w-3.5 h-3.5" />
              <span>Lisensi Pengguna ({licenses.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('rooms')}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                activeTab === 'rooms'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <BedDouble className="w-3.5 h-3.5" />
              <span>Semua Kamar ({rooms.length})</span>
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsLicenseModalOpen(true)}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm transition-colors whitespace-nowrap"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>+ Terbitkan Lisensi & Komisi</span>
            </button>

            {activeTab !== 'packages' && (
              <div className="relative w-full md:w-56">
                <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Cari data..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-9 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            )}
          </div>
        </div>

        {/* ========================================================================= */}
        {/* TAB 1: DAFTAR JURAGAN KOST                                                */}
        {/* ========================================================================= */}
        {activeTab === 'dashboard' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-500 font-bold uppercase tracking-wider border-b border-slate-100">
                <tr>
                  <th className="p-4">Nama Kosan & Alamat</th>
                  <th className="p-4">Juragan (Owner)</th>
                  <th className="p-4">Status Paket & Lisensi</th>
                  <th className="p-4">Total Kamar</th>
                  <th className="p-4">Status Kamar (Terisi / Kosong / Service)</th>
                  <th className="p-4">Tingkat Hunian</th>
                  <th className="p-4">Penghuni Aktif</th>
                  <th className="p-4 text-right">Rincian & Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredJuraganList.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center py-16 text-slate-400">
                      <Building className="w-10 h-10 mx-auto text-slate-300 mb-2" />
                      <p className="font-semibold text-slate-600">Belum Ada Juragan Kost Terdaftar di Cloud</p>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Data akan otomatis muncul begitu pengguna melakukan sinkronisasi cloud dari HP.
                      </p>
                    </td>
                  </tr>
                ) : (
                  filteredJuraganList.map((juragan) => {
                    const name = juragan.property_name || juragan.name || 'Kosan Tanpa Nama';
                    const owner = juragan.owner_name || 'Juragan Kos';
                    const phone = juragan.owner_phone || juragan.phone;

                    return (
                      <tr key={juragan.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="p-4">
                          <div className="flex items-start gap-3">
                            <div className="w-9 h-9 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center text-indigo-600 font-bold flex-shrink-0">
                              {name.substring(0, 1).toUpperCase()}
                            </div>
                            <div>
                              <p className="font-bold text-slate-900 text-sm">{name}</p>
                              <p className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5">
                                <MapPin className="w-3 h-3 text-slate-400 flex-shrink-0" />
                                <span className="truncate max-w-xs">{juragan.address || 'Alamat belum diatur'}</span>
                              </p>
                            </div>
                          </div>
                        </td>

                        <td className="p-4">
                          <p className="font-semibold text-slate-800">{owner}</p>
                          {phone && (
                            <a
                              href={`https://wa.me/${phone.replace(/[^0-9]/g, '')}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-[11px] text-emerald-600 hover:text-emerald-700 flex items-center gap-1 font-semibold mt-0.5"
                            >
                              <Phone className="w-3 h-3" />
                              <span>{phone}</span>
                            </a>
                          )}
                          {juragan.userEmail && (
                            <span className="text-[10.5px] text-indigo-600 font-mono block mt-0.5 truncate max-w-[150px]" title={juragan.userEmail}>
                              📧 {juragan.userEmail}
                            </span>
                          )}
                        </td>

                        {/* STATUS PAKET & LISENSI */}
                        <td className="p-4">
                          <div className="flex flex-col gap-0.5">
                            {juragan.planType === 'cloud' ? (
                              <span
                                className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold w-fit ${
                                  juragan.isExpired
                                    ? 'bg-rose-50 text-rose-700 border border-rose-200'
                                    : 'bg-teal-50 text-teal-700 border border-teal-200'
                                }`}
                              >
                                <Cloud className="w-3 h-3 text-teal-600" />
                                <span>{juragan.isExpired ? 'Cloud Kedaluwarsa' : 'Juragan Cloud'}</span>
                              </span>
                            ) : juragan.planType === 'mandiri' ? (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-purple-50 text-purple-700 border border-purple-200 w-fit">
                                <Crown className="w-3 h-3 text-purple-600" />
                                <span>Juragan Mandiri</span>
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-slate-100 text-slate-700 border border-slate-200 w-fit">
                                <ShieldCheck className="w-3 h-3 text-slate-500" />
                                <span>Starter (Free)</span>
                              </span>
                            )}
                            <span className="text-[11px] text-slate-500 font-medium pl-1">
                              {juragan.planSubtitle}
                            </span>
                          </div>
                        </td>

                        <td className="p-4">
                          <span className="font-bold text-slate-900 text-sm">{juragan.roomsCount}</span>
                          <span className="text-[11px] text-slate-400 ml-1">Kamar</span>
                        </td>

                        <td className="p-4">
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10.5px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                              {juragan.occupiedCount} Terisi
                            </span>
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10.5px] font-bold bg-slate-100 text-slate-600 border border-slate-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-slate-400" />
                              {juragan.vacantCount} Kosong
                            </span>
                            {juragan.serviceCount > 0 && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10.5px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                                <Wrench className="w-3 h-3" />
                                {juragan.serviceCount} Service
                              </span>
                            )}
                          </div>
                        </td>

                        <td className="p-4">
                          <div className="w-32">
                            <div className="flex items-center justify-between text-[11px] font-bold mb-1">
                              <span className={juragan.occupancyRate > 70 ? 'text-emerald-600' : 'text-slate-600'}>
                                {juragan.occupancyRate}%
                              </span>
                            </div>
                            <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                              <div
                                className={`h-full rounded-full transition-all ${
                                  juragan.occupancyRate > 80
                                    ? 'bg-emerald-500'
                                    : juragan.occupancyRate > 40
                                    ? 'bg-indigo-500'
                                    : 'bg-amber-500'
                                }`}
                                style={{ width: `${juragan.occupancyRate}%` }}
                              />
                            </div>
                          </div>
                        </td>

                        <td className="p-4">
                          <span className="inline-flex items-center gap-1 text-slate-700 font-bold">
                            <Users className="w-3.5 h-3.5 text-blue-500" />
                            {juragan.tenantsCount} Anak Kos
                          </span>
                        </td>

                        <td className="p-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => handleOpenJuraganPlanModal(juragan)}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-200 transition-all cursor-pointer shadow-xs"
                              title="Atur status langganan cloud/mandiri juragan ini"
                            >
                              <Zap className="w-3.5 h-3.5 text-amber-600" />
                              <span>Atur Paket</span>
                            </button>
                            <button
                              onClick={() => setSelectedJuragan(juragan)}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-indigo-50 hover:bg-indigo-100 text-indigo-700 transition-colors cursor-pointer"
                            >
                              <Eye className="w-3.5 h-3.5" />
                              <span>Lihat Kamar</span>
                            </button>
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

        {/* ========================================================================= */}
        {/* TAB 2: REKAP KOMISI MITRA (PERSIS MANGGA POS)                             */}
        {/* ========================================================================= */}
        {activeTab === 'commissions' && (
          <div className="p-6 space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h3 className="text-base font-bold text-slate-900">Bagi Komisi Teman & Mitra KosanKu</h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Pantau komisi per teman perekomendasi, cairkan saldo komisi, dan kirim rincian via WhatsApp.
                </p>
              </div>
            </div>

            <div className="overflow-x-auto rounded-xl border border-slate-200">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 text-slate-500 font-bold uppercase tracking-wider border-b border-slate-100">
                  <tr>
                    <th className="p-4">Nama Teman / Mitra</th>
                    <th className="p-4">Klien Binaan</th>
                    <th className="p-4">Total Komisi Masuk</th>
                    <th className="p-4">Komisi Pending (Siap Transfer)</th>
                    <th className="p-4">Komisi Selesai (Lunas)</th>
                    <th className="p-4 text-right">Aksi Bagi Hasil</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {referrersList.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="text-center py-16 text-slate-400">
                        <Coins className="w-10 h-10 mx-auto text-slate-300 mb-2" />
                        <p className="font-semibold text-slate-600">Belum Ada Catatan Komisi Mitra</p>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          Saat menerbitkan lisensi baru, centang "Ada Teman / Mitra Perekomendasi?" untuk membagi komisi.
                        </p>
                      </td>
                    </tr>
                  ) : (
                    referrersList.map((ref) => (
                      <tr key={ref.name} className="hover:bg-slate-50/70 transition-colors">
                        <td className="p-4 font-bold text-slate-900 text-sm">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-lg bg-amber-100 text-amber-800 font-bold flex items-center justify-center">
                              {ref.name.substring(0, 1).toUpperCase()}
                            </div>
                            <span>{ref.name}</span>
                          </div>
                        </td>
                        <td className="p-4 font-semibold text-slate-700">
                          {ref.count} Lisensi Terjual
                        </td>
                        <td className="p-4 font-black text-slate-900">
                          {formatIDR(ref.total)}
                        </td>
                        <td className="p-4">
                          {ref.pending > 0 ? (
                            <span className="font-bold text-amber-700 bg-amber-50 px-2 py-1 rounded border border-amber-200">
                              {formatIDR(ref.pending)}
                            </span>
                          ) : (
                            <span className="text-slate-400">Rp 0 (Nihil)</span>
                          )}
                        </td>
                        <td className="p-4 font-bold text-emerald-700">
                          {formatIDR(ref.paid)}
                        </td>
                        <td className="p-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {ref.pending > 0 && (
                              <button
                                onClick={() => handleMarkReferrerPaid(ref.name)}
                                disabled={isPending}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs transition-colors"
                              >
                                <Check className="w-3.5 h-3.5" />
                                <span>Tandai Lunas</span>
                              </button>
                            )}
                            <button
                              onClick={() => handleSendWhatsAppToReferrer(ref.name, ref.pending, ref.total)}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition-colors"
                              title="Kirim Rekap WhatsApp"
                            >
                              <Share2 className="w-3.5 h-3.5 text-emerald-600" />
                              <span>Kirim WA</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 3: PAKET & HARGA LANGGANAN                                            */}
        {/* ========================================================================= */}
        {activeTab === 'packages' && (
          <div className="p-6 space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h3 className="text-base font-bold text-slate-900">Kelola Paket Langganan KosanKu</h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Ubah harga, promo diskon, dan badge di sini. Harga di aplikasi HP pengguna langsung terupdate otomatis!
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {packagesList.map((pkg) => (
                <div
                  key={pkg.id}
                  className={`relative rounded-2xl border p-6 flex flex-col justify-between transition-all ${
                    pkg.is_best_seller
                      ? 'border-indigo-400 bg-gradient-to-b from-indigo-50/40 to-white shadow-md ring-2 ring-indigo-500/20'
                      : 'border-slate-200 bg-white hover:border-slate-300'
                  }`}
                >
                  <div className="flex items-center justify-between mb-3">
                    <span
                      className={`text-[10px] font-extrabold uppercase px-2.5 py-0.5 rounded-full ${
                        pkg.is_best_seller
                          ? 'bg-amber-100 text-amber-800 border border-amber-300'
                          : 'bg-indigo-50 text-indigo-700 border border-indigo-200'
                      }`}
                    >
                      {pkg.badge}
                    </span>
                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        pkg.is_active ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-500'
                      }`}
                    >
                      {pkg.is_active ? '● Aktif di Aplikasi' : '○ Nonaktif'}
                    </span>
                  </div>

                  <div>
                    <h4 className="text-lg font-black text-slate-900">{pkg.name}</h4>
                    <p className="text-xs text-slate-500 mt-1 min-h-[36px]">{pkg.tagline}</p>
                  </div>

                  <div className="my-4 p-4 rounded-xl bg-slate-50 border border-slate-100">
                    <div className="flex items-baseline gap-2">
                      <span className="text-2xl font-black text-slate-900">{pkg.price_display}</span>
                      <span className="text-xs font-semibold text-slate-500">{pkg.period_display}</span>
                    </div>

                    {pkg.original_price_display && (
                      <div className="flex items-center gap-2 mt-1">
                        <span className="text-xs text-slate-400 line-through">{pkg.original_price_display}</span>
                        {pkg.discount_badge && (
                          <span className="text-[10px] font-extrabold text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">
                            {pkg.discount_badge}
                          </span>
                        )}
                      </div>
                    )}

                    {pkg.secondary_price_display && (
                      <p className="text-[11px] font-bold text-indigo-600 mt-2">
                        {pkg.secondary_price_display}
                      </p>
                    )}
                  </div>

                  <div className="space-y-1.5 mb-6 text-xs text-slate-600 flex-1">
                    <p className="font-bold text-[11px] text-slate-400 uppercase tracking-wider mb-2">Fitur Unggulan:</p>
                    {Array.isArray(pkg.features) &&
                      pkg.features.slice(0, 4).map((f: string, idx: number) => (
                        <div key={idx} className="flex items-start gap-2">
                          <Check className="w-3.5 h-3.5 text-emerald-600 flex-shrink-0 mt-0.5" />
                          <span className="text-[11.5px] leading-tight text-slate-700">{f}</span>
                        </div>
                      ))}
                    {Array.isArray(pkg.features) && pkg.features.length > 4 && (
                      <p className="text-[10.5px] text-slate-400 font-semibold pl-5">
                        +{pkg.features.length - 4} fitur lainnya
                      </p>
                    )}
                  </div>

                  <button
                    onClick={() => handleOpenEditPackage(pkg)}
                    className={`w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl text-xs font-bold transition-all ${
                      pkg.is_best_seller
                        ? 'bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm'
                        : 'bg-slate-100 hover:bg-slate-200 text-slate-800'
                    }`}
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    <span>Ubah Harga & Detail</span>
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 4: LISENSI PENGGUNA (DILENGKAPI STATUS KOMISI & MITRA)                 */}
        {/* ========================================================================= */}
        {activeTab === 'licenses' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-500 font-bold uppercase tracking-wider border-b border-slate-100">
                <tr>
                  <th className="p-4">Hardware ID</th>
                  <th className="p-4">Paket</th>
                  <th className="p-4">Pembeli / Catatan</th>
                  <th className="p-4">Mitra & Komisi (Bagi Hasil)</th>
                  <th className="p-4">Serial Key</th>
                  <th className="p-4">Masa Berlaku</th>
                  <th className="p-4">Status Lisensi</th>
                  <th className="p-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredLicenses.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center py-12 text-slate-400">
                      Tidak ada lisensi yang cocok.
                    </td>
                  </tr>
                ) : (
                  filteredLicenses.map((lic) => {
                    const isLifetime = !lic.expires_at || lic.plan_code.includes('lifetime');
                    const isExpired = lic.expires_at ? new Date(lic.expires_at) < new Date() : false;

                    return (
                      <tr key={lic.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="p-4 font-mono font-bold text-slate-800">{lic.hardware_id}</td>
                        <td className="p-4">
                          <span
                            className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-bold ${
                              lic.plan_code.includes('cloud')
                                ? 'bg-indigo-50 text-indigo-700 border border-indigo-200'
                                : 'bg-purple-50 text-purple-700 border border-purple-200'
                            }`}
                          >
                            {lic.plan_code.toUpperCase()}
                          </span>
                        </td>

                        {/* Pembeli */}
                        <td className="p-4">
                          <p className="font-bold text-slate-800">{lic.buyer_name || 'Pembeli Langsung'}</p>
                          <p className="text-[10px] text-slate-400">{lic.platform} • {formatIDR(lic.license_price)}</p>
                        </td>

                        {/* Mitra & Komisi */}
                        <td className="p-4">
                          {lic.referrer_name ? (
                            <div>
                              <p className="font-bold text-slate-800 flex items-center gap-1">
                                <Users className="w-3 h-3 text-indigo-500" />
                                <span>{lic.referrer_name}</span>
                              </p>
                              <div className="flex items-center gap-2 mt-1">
                                <span className="font-mono font-bold text-slate-900">
                                  {formatIDR(lic.commission_amount)}
                                </span>
                                <button
                                  onClick={() => handleToggleCommission(lic.id, lic.commission_status)}
                                  className={`px-1.5 py-0.5 rounded text-[9.5px] font-bold transition-colors ${
                                    lic.commission_status === 'paid'
                                      ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200'
                                      : 'bg-amber-100 text-amber-900 hover:bg-amber-200'
                                  }`}
                                  title="Klik untuk ubah status komisi"
                                >
                                  {lic.commission_status === 'paid' ? '● LUNAS' : '○ PENDING'}
                                </button>
                              </div>
                            </div>
                          ) : (
                            <span className="text-slate-400 text-[11px]">Tanpa Mitra</span>
                          )}
                        </td>

                        <td className="p-4">
                          <div className="flex items-center gap-1.5 font-mono text-slate-700 bg-slate-100 px-2 py-1 rounded max-w-fit">
                            <span>{lic.serial_key}</span>
                            <button
                              onClick={() => copyToClipboard(lic.serial_key, lic.id)}
                              className="text-slate-400 hover:text-slate-600 ml-1"
                              title="Salin Serial Key"
                            >
                              {copiedKey === lic.id ? (
                                <Check className="w-3.5 h-3.5 text-emerald-600" />
                              ) : (
                                <Copy className="w-3.5 h-3.5" />
                              )}
                            </button>
                          </div>
                        </td>

                        <td className="p-4">
                          {isLifetime ? (
                            <span className="text-emerald-600 font-bold">♾️ Lifetime</span>
                          ) : (
                            <div>
                              <span className={isExpired ? 'text-rose-600 font-bold' : 'text-slate-700'}>
                                {new Date(lic.expires_at!).toLocaleDateString('id-ID', {
                                  day: 'numeric',
                                  month: 'short',
                                  year: 'numeric',
                                })}
                              </span>
                              {isExpired && (
                                <span className="ml-1 text-[10px] text-rose-500 font-bold">(Exp)</span>
                              )}
                            </div>
                          )}
                        </td>

                        <td className="p-4">
                          <button
                            onClick={() => handleToggleLicense(lic.id, lic.is_active)}
                            disabled={isPending}
                            className={`px-2 py-0.5 rounded text-[10.5px] font-bold transition-colors ${
                              lic.is_active
                                ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200'
                                : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                            }`}
                          >
                            {lic.is_active ? '● Aktif' : '○ Nonaktif'}
                          </button>
                        </td>

                        <td className="p-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            {!isLifetime && (
                              <>
                                <button
                                  onClick={() => handleExtendExpiry(lic.id, 30)}
                                  disabled={isPending}
                                  className="px-2 py-1 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 rounded text-[10px] font-bold"
                                  title="Perpanjang 30 Hari"
                                >
                                  +30h
                                </button>
                                <button
                                  onClick={() => handleExtendExpiry(lic.id, 365)}
                                  disabled={isPending}
                                  className="px-2 py-1 bg-purple-50 text-purple-700 hover:bg-purple-100 rounded text-[10px] font-bold"
                                  title="Perpanjang 1 Tahun"
                                >
                                  +1th
                                </button>
                              </>
                            )}
                            <button
                              onClick={() => handleDeleteLicense(lic.id)}
                              disabled={isPending}
                              className="p-1 text-slate-400 hover:text-rose-600 rounded"
                              title="Hapus Lisensi"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
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

        {/* ========================================================================= */}
        {/* TAB 5: SEMUA KAMAR                                                        */}
        {/* ========================================================================= */}
        {activeTab === 'rooms' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-500 font-bold uppercase tracking-wider border-b border-slate-100">
                <tr>
                  <th className="p-4">Nomor Kamar</th>
                  <th className="p-4">Lantai</th>
                  <th className="p-4">Tipe Kamar</th>
                  <th className="p-4">Tarif Bulanan</th>
                  <th className="p-4">Status Kamar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rooms.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="text-center py-12 text-slate-400">
                      Belum ada kamar tersinkron di cloud.
                    </td>
                  </tr>
                ) : (
                  rooms.map((r) => (
                    <tr key={r.id} className="hover:bg-slate-50/70">
                      <td className="p-4 font-bold text-slate-800">Kamar {r.room_number}</td>
                      <td className="p-4 text-slate-600">Lantai {r.floor || '1'}</td>
                      <td className="p-4 text-slate-600">{r.room_type || 'Standard'}</td>
                      <td className="p-4 font-semibold text-slate-800">
                        {formatIDR(r.monthly_price || r.monthly_rate || 0)}
                      </td>
                      <td className="p-4">
                        <span
                          className={`px-2 py-0.5 rounded text-[10.5px] font-bold ${
                            r.status?.toUpperCase() === 'OCCUPIED'
                              ? 'bg-emerald-50 text-emerald-700'
                              : r.status?.toUpperCase() === 'MAINTENANCE' || r.status?.toUpperCase() === 'SERVICE'
                              ? 'bg-amber-50 text-amber-700'
                              : 'bg-slate-100 text-slate-700'
                          }`}
                        >
                          {r.status}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ========================================================================= */}
      {/* MODAL: RINCIAN KAMAR JURAGAN KOST                                         */}
      {/* ========================================================================= */}
      {selectedJuragan && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[85vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between">
              <div>
                <h3 className="text-base font-bold text-slate-900">
                  🏢 {selectedJuragan.property_name || selectedJuragan.name}
                </h3>
                <p className="text-xs text-slate-500">
                  Pemilik: <span className="font-semibold text-slate-700">{selectedJuragan.owner_name}</span> •{' '}
                  {selectedJuragan.owner_phone || selectedJuragan.phone}
                </p>
              </div>
              <button
                onClick={() => setSelectedJuragan(null)}
                className="p-1 text-slate-400 hover:text-slate-600 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              <div className="grid grid-cols-3 gap-3">
                <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-center">
                  <span className="text-[10px] font-bold text-emerald-700 uppercase">TERISI</span>
                  <p className="text-xl font-black text-emerald-800 mt-0.5">
                    {rooms.filter((r) => r.property_id === selectedJuragan.id && r.status?.toUpperCase() === 'OCCUPIED').length}
                  </p>
                </div>
                <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 text-center">
                  <span className="text-[10px] font-bold text-slate-500 uppercase">KOSONG</span>
                  <p className="text-xl font-black text-slate-800 mt-0.5">
                    {rooms.filter((r) => r.property_id === selectedJuragan.id && r.status?.toUpperCase() === 'VACANT').length}
                  </p>
                </div>
                <div className="p-3 rounded-xl bg-amber-50 border border-amber-200 text-center">
                  <span className="text-[10px] font-bold text-amber-700 uppercase">SERVICE</span>
                  <p className="text-xl font-black text-amber-800 mt-0.5">
                    {rooms.filter((r) => {
                      const s = r.status?.toUpperCase();
                      return r.property_id === selectedJuragan.id && (s === 'MAINTENANCE' || s === 'SERVICE');
                    }).length}
                  </p>
                </div>
              </div>

              <div>
                <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-3">
                  Daftar Kamar ({rooms.filter((r) => r.property_id === selectedJuragan.id).length}):
                </h4>
                {rooms.filter((r) => r.property_id === selectedJuragan.id).length === 0 ? (
                  <p className="text-xs text-slate-400 italic text-center py-6">
                    Belum ada data kamar yang disinkronkan oleh juragan ini.
                  </p>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {rooms
                      .filter((r) => r.property_id === selectedJuragan.id)
                      .map((room) => {
                        const isOccupied = room.status?.toUpperCase() === 'OCCUPIED';
                        const isService = room.status?.toUpperCase() === 'MAINTENANCE' || room.status?.toUpperCase() === 'SERVICE';

                        return (
                          <div
                            key={room.id}
                            className={`p-3 rounded-xl border flex items-center justify-between text-xs ${
                              isOccupied
                                ? 'bg-emerald-50/50 border-emerald-200'
                                : isService
                                ? 'bg-amber-50/50 border-amber-200'
                                : 'bg-slate-50/50 border-slate-200'
                            }`}
                          >
                            <div>
                              <p className="font-bold text-slate-900">Kamar {room.room_number}</p>
                              <p className="text-[11px] text-slate-500">
                                Lt. {room.floor || '1'} • {room.room_type || 'Standard'}
                              </p>
                              <p className="text-[11px] font-bold text-indigo-600 mt-0.5">
                                {formatIDR(room.monthly_price || room.monthly_rate || 0)} / bln
                              </p>
                            </div>
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                                isOccupied
                                  ? 'bg-emerald-100 text-emerald-800'
                                  : isService
                                  ? 'bg-amber-100 text-amber-800'
                                  : 'bg-slate-200 text-slate-700'
                              }`}
                            >
                              {isOccupied ? 'Terisi' : isService ? 'Service' : 'Kosong'}
                            </span>
                          </div>
                        );
                      })}
                  </div>
                )}
              </div>
            </div>

            <div className="p-4 border-t border-slate-100 flex justify-end bg-slate-50/50">
              <button
                onClick={() => setSelectedJuragan(null)}
                className="px-4 py-2 rounded-xl text-xs font-bold bg-slate-200 hover:bg-slate-300 text-slate-700 transition-colors"
              >
                Tutup
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: EDIT PAKET LANGGANAN & HARGA                                       */}
      {/* ========================================================================= */}
      {editingPackage && pkgFormData && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full max-h-[90vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between">
              <div>
                <h3 className="text-base font-bold text-slate-900">Ubah Paket: {editingPackage.name}</h3>
                <p className="text-xs text-slate-500">Ubah harga dan detail paket yang tampil di aplikasi</p>
              </div>
              <button
                onClick={() => setEditingPackage(null)}
                className="p-1 text-slate-400 hover:text-slate-600 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Nama Paket</label>
                  <input
                    type="text"
                    value={pkgFormData.name}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, name: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Badge Tag</label>
                  <input
                    type="text"
                    value={pkgFormData.badge}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, badge: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                    placeholder="Contoh: BEST SELLER 👑"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Tagline Singkat</label>
                <textarea
                  rows={2}
                  value={pkgFormData.tagline}
                  onChange={(e) => setPkgFormData({ ...pkgFormData, tagline: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Nominal Harga (Angka)</label>
                  <input
                    type="number"
                    value={pkgFormData.price}
                    onChange={(e) => {
                      const num = Number(e.target.value) || 0;
                      setPkgFormData({
                        ...pkgFormData,
                        price: num,
                        price_display: num === 0 ? 'Rp 0' : `Rp ${num.toLocaleString('id-ID')}`,
                      });
                    }}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none font-mono"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Teks Harga (Format)</label>
                  <input
                    type="text"
                    value={pkgFormData.price_display}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, price_display: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                    placeholder="Contoh: Rp 149.000"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Harga Coret (Opsional)</label>
                  <input
                    type="text"
                    value={pkgFormData.original_price_display || ''}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, original_price_display: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                    placeholder="Contoh: Rp 299.000"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Badge Diskon</label>
                  <input
                    type="text"
                    value={pkgFormData.discount_badge || ''}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, discount_badge: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                    placeholder="Contoh: Hemat 50%"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Periode Durasi</label>
                  <input
                    type="text"
                    value={pkgFormData.period_display}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, period_display: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                    placeholder="Contoh: / bulan"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Opsi Harga Kedua (Opsional / Tahunan)</label>
                <input
                  type="text"
                  value={pkgFormData.secondary_price_display || ''}
                  onChange={(e) => setPkgFormData({ ...pkgFormData, secondary_price_display: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  placeholder="Contoh: Rp 199.000 / thn (Coret Rp 348rb)"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Teks Tombol Aksi</label>
                  <input
                    type="text"
                    value={pkgFormData.button_text}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, button_text: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Cocok Untuk</label>
                  <input
                    type="text"
                    value={pkgFormData.suitable_for || ''}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, suitable_for: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                </div>
              </div>

              <div className="pt-2 flex items-center gap-6">
                <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={pkgFormData.is_best_seller}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, is_best_seller: e.target.checked })}
                    className="w-4 h-4 text-indigo-600 rounded"
                  />
                  <span>Tandai Paling Populer (Best Seller)</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={pkgFormData.is_active}
                    onChange={(e) => setPkgFormData({ ...pkgFormData, is_active: e.target.checked })}
                    className="w-4 h-4 text-indigo-600 rounded"
                  />
                  <span>Tampilkan di Aplikasi (Aktif)</span>
                </label>
              </div>
            </div>

            <div className="p-5 border-t border-slate-100 flex items-center justify-end gap-3 bg-slate-50/50">
              <button
                onClick={() => setEditingPackage(null)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 transition-colors"
              >
                Batal
              </button>
              <button
                onClick={handleSavePackage}
                disabled={isPending}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm transition-colors flex items-center gap-2"
              >
                {isPending && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                <span>Simpan ke Supabase</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: AKTIVASI LISENSI BARU + SISTEM KOMISI MITRA (PERSIS MANGGA POS)    */}
      {/* ========================================================================= */}
      {isLicenseModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between">
              <div>
                <h3 className="text-base font-bold text-slate-900">Aktivasi Lisensi & Catat Komisi Mitra</h3>
                <p className="text-xs text-slate-500">Terbitkan serial key resmi KosanKu & catat bagi hasil teman</p>
              </div>
              <button
                onClick={() => setIsLicenseModalOpen(false)}
                className="p-1 text-slate-400 hover:text-slate-600 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">
                  Hardware ID Perangkat Pengguna <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  placeholder="Contoh: KSN-751A-93F2-0C14"
                  value={licenseHwId}
                  onChange={(e) => handleHardwareIdChange(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono text-xs focus:ring-2 focus:ring-indigo-500 outline-none font-bold"
                />
                <p className="text-[11px] text-slate-400 mt-1">
                  Minta pengguna melihat Hardware ID di menu Akun / Pengaturan KosanKu mereka.
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Pilih Paket Lisensi</label>
                  <select
                    value={licensePlan}
                    onChange={(e: any) => {
                      const val = e.target.value;
                      setLicensePlan(val);
                      if (val.includes('mandiri')) {
                        setLicensePrice(149000);
                        setCommissionAmount(50000);
                      } else {
                        setLicensePrice(29000);
                        setCommissionAmount(10000);
                      }
                    }}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  >
                    <option value="mandiri_lifetime">Paket Mandiri (Lifetime • Rp 149rb)</option>
                    <option value="cloud_monthly">Paket Cloud (Bulanan • Rp 29rb)</option>
                    <option value="cloud_yearly">Paket Cloud (Tahunan • Rp 199rb)</option>
                    <option value="cloud_lifetime">Paket Cloud (Lifetime Multi-HP)</option>
                  </select>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Platform Penjualan</label>
                  <select
                    value={platform}
                    onChange={(e) => setPlatform(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  >
                    <option value="WhatsApp">WhatsApp (Direct)</option>
                    <option value="Shopee">Shopee</option>
                    <option value="Tokopedia">Tokopedia</option>
                    <option value="TikTok Shop">TikTok Shop</option>
                    <option value="Mitra Affiliate">Mitra Affiliate / Teman</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Nama Pembeli / Juragan Kos</label>
                  <input
                    type="text"
                    placeholder="Contoh: Bu Hajah Siti - Kos Mawar"
                    value={buyerName}
                    onChange={(e) => setBuyerName(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Harga Jual Lisensi (IDR)</label>
                  <input
                    type="number"
                    value={licensePrice}
                    onChange={(e) => setLicensePrice(e.target.value === '' ? '' : Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium font-mono focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                </div>
              </div>

              {previewSerialKey && (
                <div className="p-3.5 bg-indigo-50/70 border border-indigo-200 rounded-xl">
                  <p className="text-[10px] font-bold text-indigo-700 uppercase tracking-wider">
                    SERIAL KEY RESMI TER-GENERATE:
                  </p>
                  <div className="flex items-center justify-between mt-1">
                    <span className="font-mono text-sm font-black text-indigo-900 tracking-wider">
                      {previewSerialKey}
                    </span>
                    <button
                      onClick={() => copyToClipboard(previewSerialKey, 'modal')}
                      className="px-2 py-1 bg-white rounded border border-indigo-200 text-indigo-700 text-[10px] font-bold hover:bg-indigo-50"
                    >
                      {copiedKey === 'modal' ? 'Tersalin!' : 'Salin'}
                    </button>
                  </div>
                </div>
              )}

              {/* ========================================================================= */}
              {/* SECTION REFERRAL & KOMISI MITRA                                           */}
              {/* ========================================================================= */}
              <div className="pt-2 border-t border-slate-100">
                <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-800 mb-2">
                  <input
                    type="checkbox"
                    checked={hasReferral}
                    onChange={(e) => setHasReferral(e.target.checked)}
                    className="w-4 h-4 text-amber-600 rounded"
                  />
                  <span className="text-xs">🤝 Ada Teman / Mitra Perekomendasi? (Bagi Komisi)</span>
                </label>

                {hasReferral && (
                  <div className="p-3.5 bg-amber-50/70 border border-amber-200 rounded-xl space-y-3 mt-2">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="font-bold text-amber-900 block mb-1">
                          Nama Teman / Mitra *
                        </label>
                        <input
                          type="text"
                          placeholder="Contoh: Budi Santoso"
                          value={referrerName}
                          onChange={(e) => setReferrerName(e.target.value)}
                          className="w-full px-3 py-2 bg-white border border-amber-300 rounded-xl font-medium text-xs focus:ring-2 focus:ring-amber-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="font-bold text-amber-900 block mb-1">
                          Nominal Komisi (IDR) *
                        </label>
                        <input
                          type="number"
                          value={commissionAmount}
                          onChange={(e) => setCommissionAmount(e.target.value === '' ? '' : Number(e.target.value))}
                          className="w-full px-3 py-2 bg-white border border-amber-300 rounded-xl font-medium font-mono text-xs focus:ring-2 focus:ring-amber-500 outline-none"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="font-bold text-amber-900 block mb-1">Status Pembayaran Komisi:</label>
                      <div className="flex items-center gap-4">
                        <label className="flex items-center gap-1.5 cursor-pointer">
                          <input
                            type="radio"
                            name="comm_status"
                            value="unpaid"
                            checked={commissionStatus === 'unpaid'}
                            onChange={() => setCommissionStatus('unpaid')}
                            className="text-amber-600"
                          />
                          <span className="text-amber-900 font-semibold text-xs">🟡 Belum Ditransfer (Pending)</span>
                        </label>
                        <label className="flex items-center gap-1.5 cursor-pointer">
                          <input
                            type="radio"
                            name="comm_status"
                            value="paid"
                            checked={commissionStatus === 'paid'}
                            onChange={() => setCommissionStatus('paid')}
                            className="text-emerald-600"
                          />
                          <span className="text-emerald-900 font-semibold text-xs">🟢 Sudah Ditransfer (Lunas)</span>
                        </label>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Catatan Tambahan (Opsional)</label>
                <input
                  type="text"
                  placeholder="Contoh: Order Shopee #982312, kirim serial key via chat"
                  value={licenseNotes}
                  onChange={(e) => setLicenseNotes(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:ring-2 focus:ring-indigo-500 outline-none"
                />
              </div>
            </div>

            <div className="p-5 border-t border-slate-100 flex items-center justify-end gap-3 bg-slate-50/50">
              <button
                onClick={() => setIsLicenseModalOpen(false)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 transition-colors"
              >
                Batal
              </button>
              <button
                onClick={handleCreateLicense}
                disabled={isPending || !licenseHwId.trim()}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50"
              >
                {isPending && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                <span>Terbitkan & Simpan Komisi</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: ATUR PAKET & LANGGANAN JURAGAN KOST (DIRECT ACCOUNT CLOUD/MANDIRI) */}
      {/* ========================================================================= */}
      {selectedJuraganForPlan && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full max-h-[92vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between sticky top-0 bg-white z-10">
              <div>
                <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Zap className="w-4 h-4 text-amber-500" />
                  Atur Paket & Langganan Juragan Kost
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Aktifkan langganan Cloud atau Mandiri langsung ke akun Juragan (tanpa perlu ID Perangkat)
                </p>
              </div>
              <button
                onClick={() => setSelectedJuraganForPlan(null)}
                className="p-1 text-slate-400 hover:text-slate-600 rounded-lg cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              {/* Rincian Akun Juragan */}
              <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 space-y-2">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="font-bold text-slate-900 text-sm">
                      {selectedJuraganForPlan.property_name || selectedJuraganForPlan.name}
                    </p>
                    <p className="text-[11px] text-slate-600 mt-0.5">
                      Pemilik: <b>{selectedJuraganForPlan.owner_name || 'Juragan Kos'}</b>
                      {selectedJuraganForPlan.owner_phone && ` • ${selectedJuraganForPlan.owner_phone}`}
                    </p>
                  </div>
                  <span className="text-[11px] px-2 py-0.5 rounded font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
                    {selectedJuraganForPlan.roomsCount} Kamar
                  </span>
                </div>

                {/* Akun Email / User ID */}
                <div className="pt-2 border-t border-slate-200/60">
                  <label className="text-[11px] font-bold text-slate-700 block mb-1">
                    Akun Cloud (Email Terdaftar):
                  </label>
                  {selectedJuraganForPlan.userEmail ? (
                    <div className="flex items-center gap-2 text-indigo-700 bg-indigo-50/70 px-2.5 py-1.5 rounded-lg border border-indigo-200 font-mono text-[11px]">
                      <span>📧</span>
                      <span className="font-bold">{selectedJuraganForPlan.userEmail}</span>
                    </div>
                  ) : authUsers && authUsers.length > 0 ? (
                    <select
                      value={juraganTargetUserId}
                      onChange={(e) => setJuraganTargetUserId(e.target.value)}
                      className="w-full px-2.5 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-medium"
                    >
                      <option value="">-- Pilih Akun Email Juragan --</option>
                      {authUsers.map((u) => (
                        <option key={u.id} value={u.id}>
                          {u.email} ({u.id.slice(0, 8)})
                        </option>
                      ))}
                    </select>
                  ) : (
                    <input
                      type="text"
                      placeholder="Masukkan User ID akun Supabase juragan"
                      value={juraganTargetUserId}
                      onChange={(e) => setJuraganTargetUserId(e.target.value)}
                      className="w-full px-2.5 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-mono"
                    />
                  )}
                </div>

                <div className="text-[11px] text-slate-500 pt-1 flex items-center gap-1.5 flex-wrap">
                  <span>Status Saat Ini:</span>
                  <b className="text-slate-800">{selectedJuraganForPlan.planBadge}</b>
                  <span>({selectedJuraganForPlan.planSubtitle})</span>
                </div>
              </div>

              {/* Pilihan Paket Baru */}
              <div>
                <label className="font-bold text-slate-700 block mb-2">
                  Pilih Paket Baru untuk Akun Ini:
                </label>
                <div className="grid grid-cols-1 gap-2.5">
                  {/* Card 1: Cloud Multi-HP */}
                  <div
                    onClick={() => setJuraganSelectedPlan('cloud_yearly')}
                    className={`p-3.5 rounded-xl border cursor-pointer transition-all ${
                      juraganSelectedPlan.startsWith('cloud')
                        ? 'border-teal-500 bg-teal-50/50 ring-2 ring-teal-500/20'
                        : 'border-slate-200 hover:border-slate-300 bg-white'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-teal-100 text-teal-700 flex items-center justify-center font-bold">
                          <Cloud className="w-4 h-4" />
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 text-sm">☁️ Juragan Cloud (Multi-HP)</p>
                          <p className="text-[11px] text-slate-500">
                            Bisa login di HP Pemilik, HP Pengelola, & tablet secara bersamaan
                          </p>
                        </div>
                      </div>
                      <input
                        type="radio"
                        checked={juraganSelectedPlan.startsWith('cloud')}
                        onChange={() => setJuraganSelectedPlan('cloud_yearly')}
                        className="text-teal-600 focus:ring-teal-500"
                      />
                    </div>
                  </div>

                  {/* Card 2: Mandiri Lifetime */}
                  <div
                    onClick={() => setJuraganSelectedPlan('mandiri_lifetime')}
                    className={`p-3.5 rounded-xl border cursor-pointer transition-all ${
                      juraganSelectedPlan === 'mandiri_lifetime'
                        ? 'border-purple-500 bg-purple-50/50 ring-2 ring-purple-500/20'
                        : 'border-slate-200 hover:border-slate-300 bg-white'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-purple-100 text-purple-700 flex items-center justify-center font-bold">
                          <Crown className="w-4 h-4" />
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 text-sm">👑 Juragan Mandiri (Lifetime)</p>
                          <p className="text-[11px] text-slate-500">
                            1x Beli selamanya, tanpa kuota kamar, pembukuan mandiri
                          </p>
                        </div>
                      </div>
                      <input
                        type="radio"
                        checked={juraganSelectedPlan === 'mandiri_lifetime'}
                        onChange={() => setJuraganSelectedPlan('mandiri_lifetime')}
                        className="text-purple-600 focus:ring-purple-500"
                      />
                    </div>
                  </div>

                  {/* Card 3: Starter Free */}
                  <div
                    onClick={() => setJuraganSelectedPlan('starter')}
                    className={`p-3.5 rounded-xl border cursor-pointer transition-all ${
                      juraganSelectedPlan === 'starter'
                        ? 'border-slate-500 bg-slate-100 ring-2 ring-slate-400/20'
                        : 'border-slate-200 hover:border-slate-300 bg-white'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-slate-200 text-slate-700 flex items-center justify-center font-bold">
                          <ShieldCheck className="w-4 h-4" />
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 text-sm">🆓 Starter (Free)</p>
                          <p className="text-[11px] text-slate-500">
                            Kembalikan ke paket gratis standar (maksimal 5 kamar)
                          </p>
                        </div>
                      </div>
                      <input
                        type="radio"
                        checked={juraganSelectedPlan === 'starter'}
                        onChange={() => setJuraganSelectedPlan('starter')}
                        className="text-slate-600 focus:ring-slate-500"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Pengaturan Durasi Jika Memilih Cloud */}
              {juraganSelectedPlan.startsWith('cloud') && (
                <div className="p-4 bg-teal-50/60 rounded-xl border border-teal-200 space-y-3">
                  <label className="font-bold text-teal-900 block">
                    Tentukan Durasi Langganan Cloud:
                  </label>
                  <div className="grid grid-cols-4 gap-2">
                    {[
                      { label: '1 Tahun', years: 1 },
                      { label: '2 Tahun', years: 2 },
                      { label: '3 Tahun', years: 3 },
                      { label: '1 Bulan', years: 0 },
                    ].map((opt) => {
                      const isSelected = juraganDurationYears === opt.years && !juraganCustomExpiry;
                      return (
                        <button
                          key={opt.label}
                          type="button"
                          onClick={() => {
                            setJuraganDurationYears(opt.years);
                            setJuraganCustomExpiry('');
                          }}
                          className={`py-2 px-2.5 rounded-lg font-bold text-xs border text-center transition-all cursor-pointer ${
                            isSelected
                              ? 'bg-teal-600 text-white border-teal-600 shadow-sm'
                              : 'bg-white text-teal-800 border-teal-200 hover:bg-teal-50'
                          }`}
                        >
                          {opt.label}
                        </button>
                      );
                    })}
                  </div>

                  {/* Kalkulasi Preview Masa Aktif */}
                  <div className="p-2.5 bg-white rounded-lg border border-teal-200 flex items-center justify-between text-[11px]">
                    <span className="text-slate-600">Perkiraan Masa Aktif:</span>
                    <span className="font-bold text-teal-700">
                      {(() => {
                        const now = new Date();
                        if (juraganCustomExpiry) {
                          const d = new Date(juraganCustomExpiry);
                          return `Hingga ${d.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}`;
                        }
                        if (juraganDurationYears === 0) {
                          now.setDate(now.getDate() + 30);
                          return `Hingga ${now.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })} (30 Hari)`;
                        }
                        now.setFullYear(now.getFullYear() + juraganDurationYears);
                        return `Hingga ${now.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })} (${juraganDurationYears} Tahun)`;
                      })()}
                    </span>
                  </div>
                </div>
              )}

              {/* Riwayat Langganan & Perpanjangan */}
              {selectedJuraganForPlan.activeLicenseHistory && selectedJuraganForPlan.activeLicenseHistory.length > 0 && (
                <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-slate-800 flex items-center gap-1.5 text-xs">
                      <Clock className="w-3.5 h-3.5 text-indigo-600" />
                      📜 Riwayat Langganan & Perpanjangan ({selectedJuraganForPlan.activeLicenseHistory.length})
                    </span>
                  </div>
                  <div className="space-y-1.5 max-h-36 overflow-y-auto pr-1">
                    {selectedJuraganForPlan.activeLicenseHistory.map((h: any, idx: number) => (
                      <div key={idx} className="p-2.5 bg-white rounded-lg border border-slate-200 text-[11px] flex items-center justify-between gap-2 shadow-2xs">
                        <div>
                          <p className="font-bold text-slate-900 flex items-center gap-1">
                            <span>{h.action === 'RENEWAL' ? '🔄 Perpanjangan' : (h.action === 'DEMOTE_TO_STARTER' ? '⚠️ Turun ke Free' : '✨ Aktivasi')}</span>
                            <span className="text-indigo-700">({h.duration_text || h.plan_name})</span>
                          </p>
                          <p className="text-[10px] text-slate-500 mt-0.5">
                            {new Date(h.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                            {h.referrer_name && ` • Mitra: ${h.referrer_name} (Rp ${Number(h.commission_amount).toLocaleString('id-ID')})`}
                          </p>
                        </div>
                        <span className="text-[10.5px] font-mono font-semibold text-teal-800 bg-teal-50 px-2 py-0.5 rounded border border-teal-200 flex-shrink-0">
                          {h.new_expiry ? `s/d ${new Date(h.new_expiry).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}` : 'Lifetime'}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Komisi Teman / Mitra Referral (Opsional) */}
              <div className="p-3.5 bg-amber-50/50 rounded-xl border border-amber-200 space-y-2">
                <label className="font-bold text-amber-900 block">
                  🤝 Catat Komisi Mitra / Teman (Opsional):
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-[11px] text-slate-600 block mb-1">Nama Mitra / Teman</label>
                    <input
                      type="text"
                      placeholder="Contoh: Rian / Agi"
                      value={juraganReferrerName}
                      onChange={(e) => setJuraganReferrerName(e.target.value)}
                      className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs"
                    />
                  </div>
                  <div>
                    <label className="text-[11px] text-slate-600 block mb-1">Bagi Hasil Komisi (Rp)</label>
                    <input
                      type="number"
                      placeholder="50000"
                      value={juraganCommissionAmount || ''}
                      onChange={(e) => setJuraganCommissionAmount(Number(e.target.value))}
                      className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="p-5 border-t border-slate-100 flex items-center justify-end gap-3 bg-slate-50/50">
              <button
                type="button"
                onClick={() => setSelectedJuraganForPlan(null)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={isPending}
                onClick={handleSaveJuraganPlan}
                className="inline-flex items-center gap-2 px-5 py-2 rounded-xl text-xs font-bold bg-teal-600 hover:bg-teal-700 text-white shadow-sm transition-colors cursor-pointer disabled:opacity-50"
              >
                {isPending && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                <Zap className="w-3.5 h-3.5 text-amber-300" />
                <span>Simpan & Aktifkan Paket</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
