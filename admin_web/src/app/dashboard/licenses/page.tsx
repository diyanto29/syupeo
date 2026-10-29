'use client';

import { useState, useEffect, useMemo } from 'react';
import Link from "next/link";
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { generateAppSerialKeyAction } from './actions';
import {
  KeyRound,
  Copy,
  Check,
  Search,
  Download,
  Trash2,
  MessageSquare,
  Sparkles,
  ShoppingBag,
  Building,
  Store,
  Layers,
  RotateCcw,
  Info,
  Users,
  Coins,
  CheckCircle2,
  Clock,
  ChevronDown,
  UserCheck,
  Lock,
  ShieldAlert,
} from 'lucide-react';

export interface AppLicenseRecord {
  id: string;
  app_code: 'BATIKU' | 'KOSANKU' | 'MANGGOPOS' | 'CUSTOM';
  app_name: string;
  device_id: string;
  serial_key: string;
  buyer_name?: string | null;
  platform: 'Shopee' | 'Tokopedia' | 'WhatsApp' | 'Direct' | string;
  notes?: string | null;
  // Referral & Komisi Mitra
  license_price?: number;
  referrer_name?: string | null;
  commission_amount?: number;
  commission_status?: 'unpaid' | 'paid' | 'none';
  created_at: string;
}

const APP_CONFIGS = {
  BATIKU: {
    code: 'BATIKU' as const,
    name: 'BatiKu',
    fullName: 'BatiKu (Sistem PO & Keuangan Usaha)',
    placeholder: 'Contoh: BTK-8F2A-99B1-4E6C',
    prefix: 'BTK',
    badgeColor: 'bg-teal-50 text-teal-700 border-teal-200',
    icon: ShoppingBag,
  },
  KOSANKU: {
    code: 'KOSANKU' as const,
    name: 'KosanKu',
    fullName: 'KosanKu (Sistem Manajemen Kost & Properti)',
    placeholder: 'Contoh: KSN-8F2A-99B1-4E6C',
    prefix: 'KSN',
    badgeColor: 'bg-indigo-50 text-indigo-700 border-indigo-200',
    icon: Building,
  },
  MANGGOPOS: {
    code: 'MANGGOPOS' as const,
    name: 'ManggoPOS',
    fullName: 'ManggoPOS (Sistem Kasir POS & Manajemen Toko)',
    placeholder: 'Contoh: MGP-8F2A-99B1-4E6C',
    prefix: 'MGP',
    badgeColor: 'bg-amber-50 text-amber-700 border-amber-200',
    icon: Store,
  },
  CUSTOM: {
    code: 'CUSTOM' as const,
    name: 'Kustom',
    fullName: 'Aplikasi Kustom',
    placeholder: 'Masukkan Device ID pembeli',
    prefix: 'CST',
    badgeColor: 'bg-slate-50 text-slate-700 border-slate-200',
    icon: Layers,
  },
};

const LOCAL_STORAGE_KEY = 'manggapos_app_licenses_cache';

const formatIDR = (val: number | undefined | null) => {
  const num = Number(val) || 0;
  return `Rp ${num.toLocaleString('id-ID')}`;
};

export default function LicenseGeneratorPage() {
  const [selectedApp, setSelectedApp] = useState<'BATIKU' | 'KOSANKU' | 'MANGGOPOS' | 'CUSTOM'>('BATIKU');
  const [deviceId, setDeviceId] = useState('');
  const [buyerName, setBuyerName] = useState('');
  const [platform, setPlatform] = useState<'Shopee' | 'Tokopedia' | 'WhatsApp' | 'Direct'>('Shopee');
  const [licensePrice, setLicensePrice] = useState<number | ''>(180000);
  const [notes, setNotes] = useState('');
  const [customSecret, setCustomSecret] = useState('');
  const [customSalt, setCustomSalt] = useState('CUSTOM_HARDWARE_LOCK_SALT');

  // Referral / Komisi Form State
  const [hasReferral, setHasReferral] = useState(false);
  const [referrerName, setReferrerName] = useState('');
  const [commissionAmount, setCommissionAmount] = useState<number | ''>(50000);
  const [commissionStatus, setCommissionStatus] = useState<'unpaid' | 'paid'>('unpaid');

  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const [chatTemplate, setChatTemplate] = useState<string | null>(null);
  const [referrerChatTemplate, setReferrerChatTemplate] = useState<string | null>(null);

  const [licenses, setLicenses] = useState<AppLicenseRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [appFilter, setAppFilter] = useState<'ALL' | 'BATIKU' | 'KOSANKU' | 'MANGGOPOS'>('ALL');
  const [commissionFilter, setCommissionFilter] = useState<'ALL' | 'UNPAID' | 'PAID'>('ALL');

  const [copiedKey, setCopiedKey] = useState(false);
  const [copiedChat, setCopiedChat] = useState(false);
  const [copiedReferrerChat, setCopiedReferrerChat] = useState(false);
  const [copyRowId, setCopyRowId] = useState<string | null>(null);

  // Tab View: 'LICENSES' vs 'REFERRAL_RECAP'
  
  const [accessChecked, setAccessChecked] = useState(false);
  const [hasLicenseAccess, setHasLicenseAccess] = useState(false);
  const [currentUserEmail, setCurrentUserEmail] = useState("");
  const [currentUserRole, setCurrentUserRole] = useState("Admin");

  const [activeViewTab, setActiveViewTab] = useState<'LICENSES' | 'REFERRALS'>('LICENSES');

  const supabase = createClient();

  useEffect(() => {
    checkPermissionAndLoad();
  }, []);

  const checkPermissionAndLoad = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user || !user.email) {
        setHasLicenseAccess(false);
        setAccessChecked(true);
        return;
      }

      const email = user.email.toLowerCase();
      setCurrentUserEmail(email);
      const masterEmail = (process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || "diyanto2911@gmail.com").toLowerCase();

      // Master account always has access
      if (email === masterEmail) {
        setHasLicenseAccess(true);
        setCurrentUserRole("Super Admin (Master)");
        setAccessChecked(true);
        loadLicenses();
        return;
      }

      // Check admin_users record
      const { data: adminRecord } = await supabase
        .from("admin_users")
        .select("role, is_active, can_manage_licenses")
        .eq("email", email)
        .eq("is_active", true)
        .maybeSingle();

      if (adminRecord) {
        setCurrentUserRole(adminRecord.role === "super_admin" ? "Super Admin" : "Admin");
        const allowed = adminRecord.role === "super_admin" || Boolean(adminRecord.can_manage_licenses);
        setHasLicenseAccess(allowed);
        if (allowed) {
          loadLicenses();
        }
      } else {
        setHasLicenseAccess(false);
      }
    } catch (e) {
      console.warn("Error checking permission:", e);
      setHasLicenseAccess(true);
      loadLicenses();
    } finally {
      setAccessChecked(true);
    }
  };

  const loadLicenses = async () => {
    setLoading(true);
    let loaded: AppLicenseRecord[] = [];

    try {
      const { data, error } = await supabase
        .from('app_licenses')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && data && data.length > 0) {
        loaded = data as AppLicenseRecord[];
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(data));
      } else {
        const cached = localStorage.getItem(LOCAL_STORAGE_KEY);
        if (cached) {
          loaded = JSON.parse(cached);
        }
      }
    } catch {
      const cached = localStorage.getItem(LOCAL_STORAGE_KEY);
      if (cached) {
        loaded = JSON.parse(cached);
      }
    } finally {
      setLicenses(loaded);
      setLoading(false);
    }
  };

  const handleGenerateAndSave = async (e: React.FormEvent) => {
    e.preventDefault();

    const config = APP_CONFIGS[selectedApp];

    if (!deviceId.trim()) {
      alert('Harap masukkan Device ID pembeli terlebih dahulu!');
      return;
    }

    if (selectedApp === 'CUSTOM' && !customSecret.trim()) {
      alert('Master secret key untuk aplikasi Kustom belum diisi!');
      return;
    }

    const cleanDeviceIdInput = deviceId.trim().toUpperCase();

    // Generate Serial Key secara aman via Server Action (Secret HMAC tidak bocor ke browser)
    const result = await generateAppSerialKeyAction({
      appCode: selectedApp,
      deviceId: cleanDeviceIdInput,
      customSecret: selectedApp === 'CUSTOM' ? customSecret.trim() : undefined,
      customSalt: selectedApp === 'CUSTOM' ? customSalt.trim() : undefined,
    });

    if (!result.success || !result.serialKey) {
      alert(result.message || 'Gagal menghasilkan Serial Key!');
      return;
    }

    const key = result.serialKey;
    const finalBuyerName = buyerName.trim() || 'Kak';

    // Format pesan untuk pembeli
    const chatMsg = `Halo ${finalBuyerName}! Terima kasih sudah berbelanja lisensi aplikasi ${config.name} di toko kami. 🚀

Berikut adalah Serial Key resmi untuk perangkat Anda:
• Aplikasi     : ${config.name}
• ID Perangkat : ${cleanDeviceIdInput}
• Serial Key   : ${key}

Petunjuk Aktivasi Cepat:
1. Buka aplikasi ${config.name} di HP Anda.
2. Buka menu Aktivasi Lisensi Pro.
3. Tempel Serial Key di atas, lalu klik tombol "Aktivasi Sekarang".

Lisensi ini aktif permanen (Lifetime) untuk 1 perangkat tersebut.
Jika ada kendala saat aktivasi, jangan ragu hubungi kami ya kak. Selamat menggunakan aplikasi ${config.name}! 😊`;

    // Format konfirmasi untuk perekomendasi (teman)
    let refChatMsg = null;
    if (hasReferral && referrerName.trim()) {
      refChatMsg = `Halo Kak ${referrerName.trim()}! 🙏
Terima kasih atas rekomendasinya. Lisensi aplikasi ${config.name} untuk ${finalBuyerName} sudah aktif.

Detail Bagi Komisi:
• Pembeli       : ${finalBuyerName}
• Aplikasi      : ${config.name}
• Komisi Anda   : ${formatIDR(Number(commissionAmount) || 0)}
• Status        : ${commissionStatus === 'paid' ? 'Sudah Ditransfer ✅' : 'Tercatat / Pending ⏳'}

Terima kasih banyak atas support-nya ya kak! Salam sukses selalu. 🚀`;
    }

    setGeneratedKey(key);
    setChatTemplate(chatMsg);
    setReferrerChatTemplate(refChatMsg);

    const newRecord: AppLicenseRecord = {
      id: crypto.randomUUID(),
      app_code: selectedApp,
      app_name: config.name,
      device_id: cleanDeviceIdInput,
      serial_key: key,
      buyer_name: buyerName.trim() || null,
      platform,
      license_price: Number(licensePrice) || 0,
      referrer_name: hasReferral && referrerName.trim() ? referrerName.trim() : null,
      commission_amount: hasReferral && referrerName.trim() ? Number(commissionAmount) || 0 : 0,
      commission_status: hasReferral && referrerName.trim() ? commissionStatus : 'none',
      notes: notes.trim() || null,
      created_at: new Date().toISOString(),
    };

    const updated = [newRecord, ...licenses];
    setLicenses(updated);
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(updated));

    try {
      await supabase.from('app_licenses').insert({
        id: newRecord.id,
        app_code: newRecord.app_code,
        app_name: newRecord.app_name,
        device_id: newRecord.device_id,
        serial_key: newRecord.serial_key,
        buyer_name: newRecord.buyer_name,
        platform: newRecord.platform,
        license_price: newRecord.license_price,
        referrer_name: newRecord.referrer_name,
        commission_amount: newRecord.commission_amount,
        commission_status: newRecord.commission_status,
        notes: newRecord.notes,
        created_at: newRecord.created_at,
      });
    } catch (err) {
      console.warn('Supabase insert warning, saved locally in cache:', err);
    }
  };

  // Toggle Status Komisi (Pending <-> Lunas) langsung dari tabel
  const handleToggleCommissionStatus = async (item: AppLicenseRecord) => {
    if (!item.referrer_name || item.commission_status === 'none') return;

    const newStatus: 'unpaid' | 'paid' = item.commission_status === 'paid' ? 'unpaid' : 'paid';
    const updated = licenses.map((l) => (l.id === item.id ? { ...l, commission_status: newStatus } : l));

    setLicenses(updated);
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(updated));

    try {
      await supabase.from('app_licenses').update({ commission_status: newStatus }).eq('id', item.id);
    } catch (err) {
      console.warn('Supabase update status warning:', err);
    }
  };

  // Tandai semua komisi untuk 1 mitra tertentu menjadi lunas
  const handleMarkAllReferrerPaid = async (refName: string) => {
    if (!confirm(`Tandai semua komisi pending untuk "${refName}" sebagai SUDAH DITRANSFER (LUNAS)?`)) return;

    const updated = licenses.map((l) =>
      l.referrer_name?.toLowerCase() === refName.toLowerCase() && l.commission_status === 'unpaid'
        ? { ...l, commission_status: 'paid' as const }
        : l
    );

    setLicenses(updated);
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(updated));

    try {
      await supabase
        .from('app_licenses')
        .update({ commission_status: 'paid' })
        .eq('referrer_name', refName)
        .eq('commission_status', 'unpaid');
    } catch (err) {
      console.warn('Supabase batch update warning:', err);
    }
  };

  const handleDeleteLicense = async (id: string) => {
    if (!confirm('Hapus riwayat lisensi ini?')) return;

    const filtered = licenses.filter((item) => item.id !== id);
    setLicenses(filtered);
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(filtered));

    try {
      await supabase.from('app_licenses').delete().eq('id', id);
    } catch (err) {
      console.warn('Supabase delete warning:', err);
    }
  };

  const handleCopyKey = () => {
    if (!generatedKey) return;
    navigator.clipboard.writeText(generatedKey);
    setCopiedKey(true);
    setTimeout(() => setCopiedKey(false), 2000);
  };

  const handleCopyChat = () => {
    if (!chatTemplate) return;
    navigator.clipboard.writeText(chatTemplate);
    setCopiedChat(true);
    setTimeout(() => setCopiedChat(false), 2000);
  };

  const handleCopyReferrerChat = () => {
    if (!referrerChatTemplate) return;
    navigator.clipboard.writeText(referrerChatTemplate);
    setCopiedReferrerChat(true);
    setTimeout(() => setCopiedReferrerChat(false), 2000);
  };

  const handleCopyRowKey = (rowId: string, keyText: string) => {
    navigator.clipboard.writeText(keyText);
    setCopyRowId(rowId);
    setTimeout(() => setCopyRowId(null), 2000);
  };

  const handleExportCSV = () => {
    if (licenses.length === 0) {
      alert('Belum ada data lisensi untuk diekspor.');
      return;
    }

    const headers = [
      'Tanggal',
      'Aplikasi',
      'Nama Pembeli',
      'Platform',
      'Device ID',
      'Serial Key',
      'Harga Lisensi',
      'Perekomendasi',
      'Nominal Komisi',
      'Status Komisi',
      'Catatan',
    ];
    const rows = licenses.map((l) => [
      new Date(l.created_at).toLocaleString('id-ID'),
      l.app_name,
      l.buyer_name || '-',
      l.platform,
      l.device_id,
      l.serial_key,
      l.license_price || 0,
      l.referrer_name || '-',
      l.commission_amount || 0,
      l.commission_status === 'paid' ? 'Lunas' : l.commission_status === 'unpaid' ? 'Pending' : '-',
      l.notes || '-',
    ]);

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.map((x) => `"${x}"`).join(','))].join('\n');

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Rekap_Lisensi_dan_Komisi_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // General App Counts
  const counts = useMemo(() => {
    const batiku = licenses.filter((l) => l.app_code === 'BATIKU').length;
    const kosanku = licenses.filter((l) => l.app_code === 'KOSANKU').length;
    const manggopos = licenses.filter((l) => l.app_code === 'MANGGOPOS').length;
    const total = licenses.length;
    return { batiku, kosanku, manggopos, total };
  }, [licenses]);

  // Commission Calculations
  const commissionStats = useMemo(() => {
    let totalCommission = 0;
    let pendingCommission = 0;
    let paidCommission = 0;
    const referrersMap = new Map<string, { count: number; total: number; pending: number; paid: number }>();

    licenses.forEach((l) => {
      if (l.referrer_name && (l.commission_amount || 0) > 0) {
        const amt = l.commission_amount || 0;
        totalCommission += amt;
        if (l.commission_status === 'unpaid') {
          pendingCommission += amt;
        } else if (l.commission_status === 'paid') {
          paidCommission += amt;
        }

        const refKey = l.referrer_name.trim();
        const existing = referrersMap.get(refKey) || { count: 0, total: 0, pending: 0, paid: 0 };
        existing.count += 1;
        existing.total += amt;
        if (l.commission_status === 'unpaid') existing.pending += amt;
        if (l.commission_status === 'paid') existing.paid += amt;
        referrersMap.set(refKey, existing);
      }
    });

    const referrersList = Array.from(referrersMap.entries()).map(([name, data]) => ({
      name,
      ...data,
    }));

    return {
      totalCommission,
      pendingCommission,
      paidCommission,
      referrerCount: referrersMap.size,
      referrersList,
    };
  }, [licenses]);

  // Autocomplete list of recent referrers
  const uniqueReferrerSuggestions = useMemo(() => {
    const set = new Set<string>();
    licenses.forEach((l) => {
      if (l.referrer_name) set.add(l.referrer_name);
    });
    return Array.from(set);
  }, [licenses]);

  // Filtered List
  const filteredLicenses = useMemo(() => {
    return licenses.filter((item) => {
      const matchApp = appFilter === 'ALL' || item.app_code === appFilter;
      const matchCommission =
        commissionFilter === 'ALL' ||
        (commissionFilter === 'UNPAID' && item.commission_status === 'unpaid') ||
        (commissionFilter === 'PAID' && item.commission_status === 'paid');

      const q = searchQuery.toLowerCase().trim();
      const matchQuery =
        !q ||
        item.device_id.toLowerCase().includes(q) ||
        item.serial_key.toLowerCase().includes(q) ||
        (item.buyer_name && item.buyer_name.toLowerCase().includes(q)) ||
        (item.referrer_name && item.referrer_name.toLowerCase().includes(q)) ||
        (item.notes && item.notes.toLowerCase().includes(q));

      return matchApp && matchCommission && matchQuery;
    });
  }, [licenses, appFilter, commissionFilter, searchQuery]);

  
  if (!accessChecked) {
    return (
      <div className="space-y-6 max-w-6xl pb-16">
        <Navbar
          title="Generator & Rekap Lisensi"
          description="Memverifikasi hak akses pengguna..."
        />
        <div className="p-12 text-center">
          <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-xs text-slate-500">Memeriksa izin akses admin...</p>
        </div>
      </div>
    );
  }

  if (accessChecked && !hasLicenseAccess) {
    return (
      <div className="space-y-6 max-w-4xl pb-16">
        <Navbar
          title="Generator & Rekap Lisensi"
          description="Akses fitur terbatas untuk pengguna yang berwenang."
        />

        <div className="bg-white border border-slate-200 rounded-2xl p-8 sm:p-12 text-center shadow-xs">
          <div className="w-16 h-16 rounded-2xl bg-amber-50 text-amber-600 border border-amber-200 mx-auto flex items-center justify-center mb-4">
            <Lock className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-extrabold text-slate-900 mb-2">
            Akses Menu Lisensi & Serial Key Dibatasi
          </h2>
          <p className="text-sm text-slate-600 max-w-lg mx-auto leading-relaxed mb-6">
            Fitur pembuatan Serial Key, penerbitan lisensi resmi, dan rekap bagi komisi ini hanya dapat diakses oleh <strong className="text-slate-900">Super Admin</strong> atau pengguna Admin yang telah <strong className="text-amber-700">diberikan izin khusus oleh Super Admin</strong>.
          </p>

          <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl text-left max-w-md mx-auto text-xs space-y-2 mb-6 text-slate-600">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-slate-500">Akun Anda:</span>
              <span className="font-mono text-slate-900">{currentUserEmail}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="font-semibold text-slate-500">Peran Akun:</span>
              <span className="font-bold text-slate-800">{currentUserRole || "Admin"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="font-semibold text-slate-500">Status Izin Lisensi:</span>
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
                Belum Diizinkan
              </span>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Link
              href="/dashboard"
              className="px-5 py-2.5 bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs rounded-xl shadow-xs transition-all"
            >
              Kembali ke Dashboard Overview
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-6xl pb-16">
      <Navbar
        title="Generator & Rekap Lisensi"
        description="Pusat penerbitan Serial Key, rekap transaksi lisensi, dan catatan bagi komisi referral teman."
      />

      {/* Info Banner in Mangga Palette */}
      <div className="p-4 rounded-2xl bg-orange-50 border border-orange-200 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-orange-100 text-orange-700 flex items-center justify-center font-bold">
            <KeyRound className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-sm font-bold text-slate-900">Pusat Lisensi & Bagi Komisi Mitra</h4>
            <p className="text-xs text-slate-600">
              Terbitkan lisensi offline 1-Device resmi dan pantau komisi untuk teman yang berhasil merekomendasikan pembeli.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleExportCSV}
            className="px-3.5 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 hover:text-slate-900 text-xs font-bold flex items-center gap-2 transition-colors shadow-xs"
          >
            <Download className="w-3.5 h-3.5 text-slate-500" />
            Ekspor CSV
          </button>
          <button
            type="button"
            onClick={loadLicenses}
            disabled={loading}
            className="px-3.5 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 hover:text-slate-900 text-xs font-bold flex items-center gap-2 transition-colors disabled:opacity-50 shadow-xs"
            title="Muat Ulang"
          >
            <RotateCcw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Muat Ulang
          </button>
        </div>
      </div>

      {/* Stat Cards Row 1: App Counts */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {/* BatiKu Card */}
        <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-teal-700 bg-teal-50 px-2.5 py-0.5 rounded-full border border-teal-200">
              BatiKu
            </span>
            <div className="w-7 h-7 rounded-lg bg-teal-50 text-teal-600 flex items-center justify-center">
              <ShoppingBag className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2.5">
            <div className="text-2xl font-extrabold text-slate-900 leading-tight">{counts.batiku}</div>
            <p className="text-xs text-slate-500 mt-0.5">Lisensi PO Kuliner</p>
          </div>
        </div>

        {/* KosanKu Card */}
        <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-indigo-700 bg-indigo-50 px-2.5 py-0.5 rounded-full border border-indigo-200">
              KosanKu
            </span>
            <div className="w-7 h-7 rounded-lg bg-indigo-50 text-indigo-600 flex items-center justify-center">
              <Building className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2.5">
            <div className="text-2xl font-extrabold text-slate-900 leading-tight">{counts.kosanku}</div>
            <p className="text-xs text-slate-500 mt-0.5">Lisensi Kost</p>
          </div>
        </div>

        {/* ManggoPOS Card */}
        <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-amber-700 bg-amber-50 px-2.5 py-0.5 rounded-full border border-amber-200">
              ManggoPOS
            </span>
            <div className="w-7 h-7 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center">
              <Store className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2.5">
            <div className="text-2xl font-extrabold text-slate-900 leading-tight">{counts.manggopos}</div>
            <p className="text-xs text-slate-500 mt-0.5">Lisensi Kasir POS</p>
          </div>
        </div>

        {/* Total All Card */}
        <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider bg-white/20 text-white px-2.5 py-0.5 rounded-full">
              Total Terbit
            </span>
            <div className="w-7 h-7 rounded-lg bg-white/10 text-amber-400 flex items-center justify-center">
              <Sparkles className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2.5">
            <div className="text-2xl font-extrabold text-white leading-tight">{counts.total}</div>
            <p className="text-xs text-slate-300 mt-0.5">Total Semua Aplikasi</p>
          </div>
        </div>
      </div>

      {/* Stat Cards Row 2: Referral Commission Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Pending Payout */}
        <div className="bg-gradient-to-br from-amber-50 to-orange-50/60 border border-amber-200 rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-amber-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-amber-800">
                Komisi Belum Ditransfer (Pending)
              </span>
            </div>
            <span className="px-2 py-0.5 bg-amber-200/60 text-amber-900 rounded text-[10px] font-bold">
              Harus Dibayar
            </span>
          </div>
          <div className="mt-2">
            <div className="text-2xl font-extrabold text-amber-900 leading-tight">
              {formatIDR(commissionStats.pendingCommission)}
            </div>
            <p className="text-xs text-amber-700/80 mt-0.5">
              Siap ditransfer ke teman perekomendasi
            </p>
          </div>
        </div>

        {/* Paid Payout */}
        <div className="bg-gradient-to-br from-emerald-50 to-teal-50/60 border border-emerald-200 rounded-2xl p-4 shadow-xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-emerald-800">
                Komisi Sudah Cair (Lunas)
              </span>
            </div>
            <span className="px-2 py-0.5 bg-emerald-200/60 text-emerald-900 rounded text-[10px] font-bold">
              Selesai
            </span>
          </div>
          <div className="mt-2">
            <div className="text-2xl font-extrabold text-emerald-900 leading-tight">
              {formatIDR(commissionStats.paidCommission)}
            </div>
            <p className="text-xs text-emerald-700/80 mt-0.5">
              Total komisi yang telah sukses dibayarkan
            </p>
          </div>
        </div>

        {/* Active Referrers */}
        <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Users className="w-4 h-4 text-indigo-600" />
              <span className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Teman & Mitra Aktif
              </span>
            </div>
            <button
              onClick={() => setActiveViewTab('REFERRALS')}
              className="text-[11px] font-bold text-orange-600 hover:text-orange-700 underline"
            >
              Lihat Rekap
            </button>
          </div>
          <div className="mt-2">
            <div className="text-2xl font-extrabold text-slate-900 leading-tight">
              {commissionStats.referrerCount} <span className="text-sm font-normal text-slate-500">orang</span>
            </div>
            <p className="text-xs text-slate-500 mt-0.5">
              Total {formatIDR(commissionStats.totalCommission)} komisi keseluruhan
            </p>
          </div>
        </div>
      </div>

      {/* Generator Form & Result Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Form Generator */}
        <div className="lg:col-span-7 bg-white border border-slate-200 rounded-2xl p-6 shadow-xs">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100 mb-4">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center font-bold">
                <KeyRound className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Form Buat Serial Key & Catat Komisi</h3>
                <p className="text-xs text-slate-500">Terbitkan lisensi resmi 1-Device dan rekam bagi hasil</p>
              </div>
            </div>
          </div>

          <form onSubmit={handleGenerateAndSave} className="space-y-4">
            {/* App Select Tabs */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                Pilih Aplikasi yang Dipesan *
              </label>
              <div className="grid grid-cols-3 gap-2.5">
                {(['BATIKU', 'KOSANKU', 'MANGGOPOS'] as const).map((appKey) => {
                  const cfg = APP_CONFIGS[appKey];
                  const isSelected = selectedApp === appKey;
                  return (
                    <button
                      key={appKey}
                      type="button"
                      onClick={() => setSelectedApp(appKey)}
                      className={`p-2.5 rounded-xl border text-left transition-all ${
                        isSelected
                          ? 'border-orange-500 bg-orange-50/60 shadow-xs ring-1 ring-orange-500'
                          : 'border-slate-200 bg-white hover:bg-slate-50'
                      }`}
                    >
                      <div className="text-xs font-bold text-slate-900 truncate">{cfg.name}</div>
                      <div className="text-[10px] text-slate-400 mt-0.5">Prefix: {cfg.prefix}-</div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Device ID Input */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                ID Perangkat Pembeli (Device ID) *
              </label>
              <input
                type="text"
                required
                value={deviceId}
                onChange={(e) => setDeviceId(e.target.value.toUpperCase())}
                placeholder={APP_CONFIGS[selectedApp].placeholder}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 font-mono text-xs uppercase tracking-wider focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
              />
            </div>

            {/* Buyer Name & Platform */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                  Nama Pembeli / Toko (Opsional)
                </label>
                <input
                  type="text"
                  value={buyerName}
                  onChange={(e) => setBuyerName(e.target.value)}
                  placeholder="Contoh: Bu Dewi / Dapur Berkah"
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-xs focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                  Channel Penjualan
                </label>
                <select
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value as any)}
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-xs focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="Shopee">🟠 Shopee</option>
                  <option value="Tokopedia">🟢 Tokopedia</option>
                  <option value="WhatsApp">💬 WhatsApp</option>
                  <option value="Direct">⚡ Langsung / Direct</option>
                </select>
              </div>
            </div>

            {/* Referral / Komisi Toggle Section */}
            <div className="p-3.5 rounded-xl border border-orange-200/80 bg-orange-50/40 space-y-3">
              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={hasReferral}
                    onChange={(e) => setHasReferral(e.target.checked)}
                    className="w-4 h-4 rounded text-orange-600 focus:ring-orange-500 border-slate-300"
                  />
                  <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                    <Users className="w-3.5 h-3.5 text-orange-600" />
                    Ada Teman / Mitra Perekomendasi? (Bagi Komisi)
                  </span>
                </label>
                <span className="text-[10px] font-semibold text-orange-700 bg-orange-100/70 px-2 py-0.5 rounded-full">
                  Sistem Referral
                </span>
              </div>

              {hasReferral && (
                <div className="pt-2 border-t border-orange-100 space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {/* Referrer Name with autocomplete suggestion */}
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Nama Teman Perekomendasi *
                      </label>
                      <input
                        type="text"
                        required={hasReferral}
                        value={referrerName}
                        onChange={(e) => setReferrerName(e.target.value)}
                        placeholder="Contoh: Budi Santoso / Agus"
                        list="referrer-suggestions"
                        className="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-orange-500"
                      />
                      <datalist id="referrer-suggestions">
                        {uniqueReferrerSuggestions.map((name) => (
                          <option key={name} value={name} />
                        ))}
                      </datalist>
                    </div>

                    {/* Commission Amount */}
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Nominal Komisi (IDR) *
                      </label>
                      <div className="relative">
                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                          Rp
                        </span>
                        <input
                          type="number"
                          step={5000}
                          value={commissionAmount}
                          onChange={(e) => setCommissionAmount(e.target.value === '' ? '' : Number(e.target.value))}
                          placeholder="50000"
                          className="w-full pl-9 pr-3 py-2 bg-white border border-slate-200 rounded-lg text-slate-900 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-orange-500"
                        />
                      </div>
                    </div>
                  </div>

                  {/* Commission Status */}
                  <div className="flex items-center justify-between pt-1">
                    <span className="text-[11px] text-slate-600 font-medium">Status Pembayaran Komisi:</span>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setCommissionStatus('unpaid')}
                        className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                          commissionStatus === 'unpaid'
                            ? 'bg-amber-500 text-white shadow-xs'
                            : 'bg-white text-slate-600 border border-slate-200'
                        }`}
                      >
                        ⏳ Pending (Belum Ditransfer)
                      </button>
                      <button
                        type="button"
                        onClick={() => setCommissionStatus('paid')}
                        className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                          commissionStatus === 'paid'
                            ? 'bg-emerald-600 text-white shadow-xs'
                            : 'bg-white text-slate-600 border border-slate-200'
                        }`}
                      >
                        ✓ Lunas (Sudah Ditransfer)
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Notes */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                Catatan Transaksi (Opsional)
              </label>
              <input
                type="text"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Misal: No pesanan Shopee 241007..."
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-xs focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
              />
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              className="w-full py-3 bg-orange-500 hover:bg-orange-600 text-white font-bold text-xs rounded-xl shadow-xs hover:shadow transition-all flex items-center justify-center gap-2 mt-2"
            >
              <KeyRound className="w-4 h-4" />
              Terbitkan Serial Key & Catat Komisi
            </button>
          </form>
        </div>

        {/* Result Card */}
        <div className="lg:col-span-5 space-y-4">
          {generatedKey ? (
            <div className="bg-white border-2 border-dashed border-orange-500 rounded-2xl p-5 shadow-xs space-y-3">
              <div className="text-center">
                <span className="inline-block px-2.5 py-0.5 bg-orange-50 text-orange-700 border border-orange-200 text-[10px] font-bold rounded-full mb-1">
                  ✓ SERIAL KEY BERHASIL DIBUAT
                </span>
                <div className="text-xs text-slate-500 font-semibold uppercase tracking-wider">
                  {APP_CONFIGS[selectedApp].name} • 1-DEVICE
                </div>
                <div className="text-xl font-extrabold font-mono text-slate-900 tracking-wider my-2.5 p-3 bg-slate-50 rounded-xl border border-slate-200 select-all">
                  {generatedKey}
                </div>
                <button
                  onClick={handleCopyKey}
                  className="w-full py-2 bg-orange-500 hover:bg-orange-600 text-white font-semibold text-xs rounded-xl flex items-center justify-center gap-2 transition-colors"
                >
                  {copiedKey ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                  {copiedKey ? 'Serial Key Disalin!' : 'Salin Serial Key'}
                </button>
              </div>

              {/* Chat for Buyer */}
              {chatTemplate && (
                <div className="border-t border-slate-100 pt-3">
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5 flex items-center gap-1.5">
                    <MessageSquare className="w-3.5 h-3.5 text-slate-400" />
                    Pesan Siap Kirim ke Pembeli:
                  </label>
                  <textarea
                    readOnly
                    rows={6}
                    value={chatTemplate}
                    className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono text-slate-800 leading-relaxed resize-none focus:outline-none"
                  />
                  <button
                    onClick={handleCopyChat}
                    className="w-full mt-2 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs rounded-xl flex items-center justify-center gap-2 transition-colors shadow-xs"
                  >
                    {copiedChat ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                    {copiedChat ? 'Pesan Pembeli Disalin!' : 'Salin Pesan untuk Pembeli'}
                  </button>
                </div>
              )}

              {/* Chat for Referrer Friend */}
              {referrerChatTemplate && (
                <div className="border-t border-slate-100 pt-3">
                  <label className="block text-xs font-bold uppercase tracking-wider text-amber-700 mb-1.5 flex items-center gap-1.5">
                    <UserCheck className="w-3.5 h-3.5 text-amber-600" />
                    Pesan Konfirmasi untuk Teman ({referrerName}):
                  </label>
                  <textarea
                    readOnly
                    rows={5}
                    value={referrerChatTemplate}
                    className="w-full p-3 bg-amber-50/50 border border-amber-200 rounded-xl text-xs font-mono text-slate-800 leading-relaxed resize-none focus:outline-none"
                  />
                  <button
                    onClick={handleCopyReferrerChat}
                    className="w-full mt-2 py-2 bg-amber-600 hover:bg-amber-700 text-white font-semibold text-xs rounded-xl flex items-center justify-center gap-2 transition-colors shadow-xs"
                  >
                    {copiedReferrerChat ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                    {copiedReferrerChat ? 'Pesan Konfirmasi Teman Disalin!' : 'Salin Pesan untuk Teman (Perekomendasi)'}
                  </button>
                </div>
              )}
            </div>
          ) : (
            <div className="bg-white border border-slate-200 rounded-2xl p-6 text-center shadow-xs">
              <div className="w-10 h-10 rounded-xl bg-orange-50 text-orange-500 mx-auto flex items-center justify-center mb-2.5">
                <KeyRound className="w-5 h-5" />
              </div>
              <h3 className="text-sm font-bold text-slate-800">Menunggu Pembuatan Kunci</h3>
              <p className="text-xs text-slate-500 mt-1">
                Isi Device ID di form samping untuk menerbitkan Serial Key & pesan chat siap kirim.
              </p>
              <div className="mt-4 p-3 bg-blue-50/80 border border-blue-100 rounded-xl text-left text-xs text-blue-700 flex items-start gap-2">
                <Info className="w-4 h-4 flex-shrink-0 mt-0.5 text-blue-500" />
                <span>
                  Kunci dan komisi teman otomatis tersimpan di tabel riwayat bawah dan bisa dicari atau difilter status bayarnya.
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Main Tabs: Riwayat Transaksi vs Rekap per Teman */}
      <div className="flex border-b border-slate-200 gap-6">
        <button
          onClick={() => setActiveViewTab('LICENSES')}
          className={`pb-3 text-sm font-bold flex items-center gap-2 border-b-2 transition-all ${
            activeViewTab === 'LICENSES'
              ? 'border-orange-500 text-orange-600'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <KeyRound className="w-4 h-4" />
          Riwayat Semua Lisensi & Komisi ({filteredLicenses.length})
        </button>

        <button
          onClick={() => setActiveViewTab('REFERRALS')}
          className={`pb-3 text-sm font-bold flex items-center gap-2 border-b-2 transition-all ${
            activeViewTab === 'REFERRALS'
              ? 'border-orange-500 text-orange-600'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Users className="w-4 h-4" />
          Rekap Komisi per Teman / Mitra ({commissionStats.referrerCount})
        </button>
      </div>

      {activeViewTab === 'LICENSES' ? (
        /* History Table Section */
        <div className="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
          {/* Table Header Controls */}
          <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex flex-wrap items-center gap-2">
              {/* App Filter Tabs */}
              <div className="flex p-0.5 bg-slate-100 rounded-xl border border-slate-200 text-xs font-semibold">
                {(['ALL', 'BATIKU', 'KOSANKU', 'MANGGOPOS'] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setAppFilter(tab)}
                    className={`px-3 py-1 rounded-lg transition-all ${
                      appFilter === tab
                        ? 'bg-white text-slate-900 shadow-xs font-bold'
                        : 'text-slate-500 hover:text-slate-800'
                    }`}
                  >
                    {tab === 'ALL' ? 'Semua App' : APP_CONFIGS[tab].name}
                  </button>
                ))}
              </div>

              {/* Commission Filter */}
              <select
                value={commissionFilter}
                onChange={(e) => setCommissionFilter(e.target.value as any)}
                className="px-2.5 py-1 bg-slate-50 border border-slate-200 rounded-lg text-xs font-semibold text-slate-700 focus:outline-none"
              >
                <option value="ALL">Semua Komisi</option>
                <option value="UNPAID">⏳ Pending Saja</option>
                <option value="PAID">✓ Lunas Saja</option>
              </select>
            </div>

            {/* Search Box */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari pembeli, teman, device..."
                className="pl-8 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-900 focus:bg-white focus:outline-none focus:ring-1 focus:ring-orange-500 w-52"
              />
            </div>
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            {loading ? (
              <div className="p-8 text-center text-slate-400 text-xs">Memuat data riwayat lisensi...</div>
            ) : filteredLicenses.length === 0 ? (
              <div className="p-8 text-center text-slate-400 text-xs">
                Belum ada riwayat lisensi yang sesuai dengan filter.
              </div>
            ) : (
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50/80 border-b border-slate-200 text-slate-500 uppercase tracking-wider font-bold text-[10px]">
                  <tr>
                    <th className="py-3 px-4">Tanggal</th>
                    <th className="py-3 px-4">Aplikasi</th>
                    <th className="py-3 px-4">Pembeli / Channel</th>
                    <th className="py-3 px-4 font-mono">Device ID & Serial Key</th>
                    <th className="py-3 px-4">Perekomendasi & Komisi</th>
                    <th className="py-3 px-4">Status Komisi</th>
                    <th className="py-3 px-4 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredLicenses.map((item) => {
                    const cfg = APP_CONFIGS[item.app_code] || APP_CONFIGS.CUSTOM;
                    const dateFormatted = new Date(item.created_at).toLocaleDateString('id-ID', {
                      day: 'numeric',
                      month: 'short',
                      hour: '2-digit',
                      minute: '2-digit',
                    });

                    const hasRef = Boolean(item.referrer_name);

                    return (
                      <tr key={item.id} className="hover:bg-slate-50/60 transition-colors">
                        <td className="py-3 px-4 text-slate-500 whitespace-nowrap text-xs">{dateFormatted}</td>
                        <td className="py-3 px-4 whitespace-nowrap">
                          <span
                            className={`inline-block px-2.5 py-0.5 rounded-full border text-[10px] font-bold ${cfg.badgeColor}`}
                          >
                            {cfg.name}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                          <div className="font-semibold text-slate-900">{item.buyer_name || '-'}</div>
                          <span className="text-[10px] text-slate-400">{item.platform}</span>
                        </td>
                        <td className="py-3 px-4">
                          <div className="font-mono text-slate-600 text-[11px]">{item.device_id}</div>
                          <div className="flex items-center gap-1.5 font-mono font-bold text-slate-900 text-xs mt-0.5">
                            <span>{item.serial_key}</span>
                            <button
                              onClick={() => handleCopyRowKey(item.id, item.serial_key)}
                              className="p-0.5 hover:bg-slate-200 rounded text-slate-400 hover:text-slate-700 transition-colors"
                              title="Salin Kunci"
                            >
                              {copyRowId === item.id ? (
                                <Check className="w-3 h-3 text-emerald-600" />
                              ) : (
                                <Copy className="w-3 h-3" />
                              )}
                            </button>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          {hasRef ? (
                            <div>
                              <div className="font-bold text-slate-900 flex items-center gap-1">
                                <Users className="w-3 h-3 text-orange-600" />
                                {item.referrer_name}
                              </div>
                              <div className="text-[11px] font-extrabold text-orange-700 mt-0.5">
                                {formatIDR(item.commission_amount)}
                              </div>
                            </div>
                          ) : (
                            <span className="text-slate-400">-</span>
                          )}
                        </td>
                        <td className="py-3 px-4 whitespace-nowrap">
                          {hasRef ? (
                            <button
                              onClick={() => handleToggleCommissionStatus(item)}
                              title="Klik untuk ubah status pembayaran komisi"
                              className={`px-2.5 py-1 rounded-lg text-[10px] font-bold flex items-center gap-1 border transition-all ${
                                item.commission_status === 'paid'
                                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                                  : 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                              }`}
                            >
                              {item.commission_status === 'paid' ? (
                                <>
                                  <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                                  Sudah Ditransfer
                                </>
                              ) : (
                                <>
                                  <Clock className="w-3 h-3 text-amber-600" />
                                  Pending Transfer
                                </>
                              )}
                            </button>
                          ) : (
                            <span className="text-slate-400 text-[11px]">-</span>
                          )}
                        </td>
                        <td className="py-3 px-4 text-right whitespace-nowrap">
                          <button
                            onClick={() => handleDeleteLicense(item.id)}
                            className="p-1.5 hover:bg-rose-50 text-slate-400 hover:text-rose-600 rounded-lg transition-colors"
                            title="Hapus Catatan"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </div>
      ) : (
        /* Referral Mitra Recap View */
        <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="font-bold text-slate-900 text-sm">Daftar Akumulasi Komisi per Teman / Mitra</h3>
              <p className="text-xs text-slate-500">
                Ringkasan total bagi hasil yang harus dibayarkan ke masing-masing perekomendasi
              </p>
            </div>
          </div>

          {commissionStats.referrersList.length === 0 ? (
            <div className="p-8 text-center text-slate-400 text-xs">
              Belum ada data komisi referral yang tercatat.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {commissionStats.referrersList.map((ref) => (
                <div
                  key={ref.name}
                  className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 flex flex-col justify-between space-y-3"
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-bold text-slate-900 text-sm flex items-center gap-1.5">
                        <Users className="w-4 h-4 text-orange-600" />
                        {ref.name}
                      </h4>
                      <p className="text-xs text-slate-500 mt-0.5">
                        Berhasil merekomendasikan {ref.count} pembeli
                      </p>
                    </div>
                    <span className="text-xs font-bold text-slate-900 bg-white border border-slate-200 px-2.5 py-1 rounded-lg">
                      Total: {formatIDR(ref.total)}
                    </span>
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-xs pt-2 border-t border-slate-200">
                    <div className="p-2 bg-amber-50 rounded-lg border border-amber-200/60">
                      <span className="text-[10px] font-bold text-amber-700 uppercase">Pending</span>
                      <div className="font-extrabold text-amber-900">{formatIDR(ref.pending)}</div>
                    </div>
                    <div className="p-2 bg-emerald-50 rounded-lg border border-emerald-200/60">
                      <span className="text-[10px] font-bold text-emerald-700 uppercase">Sudah Ditransfer</span>
                      <div className="font-extrabold text-emerald-900">{formatIDR(ref.paid)}</div>
                    </div>
                  </div>

                  {ref.pending > 0 && (
                    <button
                      onClick={() => handleMarkAllReferrerPaid(ref.name)}
                      className="w-full py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs rounded-lg transition-colors flex items-center justify-center gap-1.5 shadow-xs"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Tandai Semua Komisi {ref.name} Sudah Ditransfer (Lunas)
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
