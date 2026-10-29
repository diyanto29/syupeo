'use client';

import { useState, useEffect, useMemo, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Quotation, QuotationItem, Partner, Lead, SubscriptionPlan } from '@/types/database';
import {
  FileText,
  PlusCircle,
  Search,
  MessageCircle,
  Printer,
  CheckCircle2,
  AlertTriangle,
  X,
  RefreshCw,
  DollarSign,
  Send,
  Trash2,
  Calendar,
  Building2,
  ChevronRight,
  Sparkles,
  Copy,
  Check,
  Crown,
  ShoppingBag,
  Layers,
} from 'lucide-react';

function QuotationsContent() {
  const searchParams = useSearchParams();
  const prefillLeadId = searchParams.get('leadId') || '';
  const prefillClientName = searchParams.get('clientName') || '';
  const prefillBizName = searchParams.get('bizName') || '';
  const prefillPhone = searchParams.get('phone') || '';

  const [quotations, setQuotations] = useState<Quotation[]>([]);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Modal States
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [previewQuotation, setPreviewQuotation] = useState<Quotation | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Sync Pricing Tiers with Master subscription_plans
  const proPlan = plans.find((p) => p.code === 'pro');
  const tiers = proPlan?.pricing_tiers || {};
  const price1Month = Number(tiers['1_month'] ?? proPlan?.price_monthly ?? 49000);
  const price3Months = Number(tiers['3_months'] ?? 129000);
  const price6Months = Number(tiers['6_months'] ?? 239000);
  const price1Year = Number(tiers['12_months'] ?? 399000);
  const priceLifetime = Number(tiers['lifetime'] ?? 799000);

  // 1. Software Licenses Presets (Live sync with subscription_plans)
  const softwarePresets = useMemo(
    () => [
      { description: 'Langganan Mangga POS PRO (1 Tahun)', unit_price: price1Year, tag: '1 Tahun' },
      { description: 'Langganan Mangga POS PRO (6 Bulan)', unit_price: price6Months, tag: '6 Bulan' },
      { description: 'Langganan Mangga POS PRO (3 Bulan)', unit_price: price3Months, tag: '3 Bulan' },
      { description: 'Langganan Mangga POS PRO (1 Bulan)', unit_price: price1Month, tag: '1 Bulan' },
      { description: 'Langganan Mangga POS PRO Lifetime (Permanen)', unit_price: priceLifetime, tag: 'Lifetime' },
    ],
    [price1Year, price6Months, price3Months, price1Month, priceLifetime]
  );

  // 2. Hardware Bundles Presets (Perangkat Kasir Lengkap + Bonus Free Lisensi PRO)
  const hardwareBundles = [
    {
      name: 'Paket Starter Mobile (Printer 58mm + Free PRO 6 Bulan)',
      description: 'Paket Starter Mobile: Printer Thermal Bluetooth 58mm + 5 Roll Kertas + Free Lisensi PRO 6 Bulan Penuh',
      unit_price: 499000,
      badge: 'Hemat',
    },
    {
      name: 'Paket Meja Kafe & Resto (Tablet + Stand + Printer + Laci + Free PRO 1 Tahun)',
      description: 'Paket Meja Kafe & Resto: Tablet Kasir Android + Stand Meja + Printer 58mm + Cash Drawer Logam RJ11 + BONUS FREE Lisensi PRO 1 Tahun Penuh',
      unit_price: 2499000,
      badge: 'Best Seller 👑',
    },
    {
      name: 'Paket Super Ritel & Minimarket (Tablet 10" + Scanner + Printer + Laci + Free PRO 1 Tahun)',
      description: 'Paket Super Ritel & Minimarket: Tablet 10" + Barcode Scanner Wireless 1D/2D + Printer Thermal + Cash Drawer + Master 10.000 Barcode + BONUS FREE Lisensi PRO 1 Tahun',
      unit_price: 3499000,
      badge: 'Super Lengkap',
    },
  ];

  // 3. Eceran Hardware & Layanan
  const extraHardwareItems = [
    { description: 'Printer Thermal Bluetooth 58mm Portable', unit_price: 250000 },
    { description: 'Printer Thermal Auto-Cutter 80mm (USB + Bluetooth)', unit_price: 650000 },
    { description: 'Laci Uang Kasir Logam (Cash Drawer RJ11)', unit_price: 350000 },
    { description: 'Barcode Scanner Wireless 1D/2D QR', unit_price: 290000 },
    { description: 'Kertas Struk Thermal 58x30mm (Isi 10 Roll)', unit_price: 50000 },
    { description: 'Jasa Setup Database Menu Awal & Training Kasir', unit_price: 100000 },
  ];

  // Create Form State
  const [formClientName, setFormClientName] = useState('');
  const [formBizName, setFormBizName] = useState('');
  const [formPhone, setFormPhone] = useState('');
  const [formPartnerId, setFormPartnerId] = useState('');
  const [formLeadId, setFormLeadId] = useState('');
  const [formItems, setFormItems] = useState<QuotationItem[]>([
    { description: 'Langganan Mangga POS PRO (1 Tahun)', qty: 1, unit_price: 399000, total_price: 399000 },
  ]);
  const [formDiscount, setFormDiscount] = useState<number>(0);
  const [formValidDays, setFormValidDays] = useState<number>(14);
  const [formNotes, setFormNotes] = useState('Garansi support teknis 7 hari seminggu. Hardware garansi 1 tahun.');

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // User Role & Partner Scoping
  const [currentUserRole, setCurrentUserRole] = useState<'super_admin' | 'admin' | 'partner'>('admin');
  const [currentPartnerId, setCurrentPartnerId] = useState<string | null>(null);
  const [currentPartnerName, setCurrentPartnerName] = useState<string>('');

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

          // Safety fallback: if role is partner but partner_id is missing, search partners table
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
              } catch (_) { }
            }
          }

          setCurrentUserRole(userRole);
          setCurrentPartnerId(userPartnerId);
          setCurrentPartnerName(userPartnerName);
          if (userRole === 'partner' && userPartnerId) {
            setFormPartnerId(userPartnerId);
          }
        } else {
          // If no admin_users row found, check if this email belongs to a registered partner
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
            setFormPartnerId(pMatch.id);
          }
        }
      }

      // 1. Fetch quotations (scoped if partner)
      let qQuery = supabase
        .from('quotations')
        .select('*, leads(*), partners(*)')
        .order('created_at', { ascending: false });

      if (userRole === 'partner' && userPartnerId) {
        qQuery = qQuery.eq('partner_id', userPartnerId);
      }

      const { data: qData, error: qErr } = await qQuery;

      if (qErr) console.warn('Quotations load warning:', qErr.message);

      // 2. Fetch leads (scoped if partner)
      let lQuery = supabase.from('leads').select('*').order('business_name');
      if (userRole === 'partner' && userPartnerId) {
        lQuery = lQuery.eq('partner_id', userPartnerId);
      }
      const { data: lData } = await lQuery;

      // 3. Fetch partners
      const { data: pData } = await supabase.from('partners').select('*').order('name');

      // 4. Fetch subscription_plans for real-time price synchronization
      const { data: planData } = await supabase.from('subscription_plans').select('*');

      setQuotations((qData as Quotation[]) || []);
      setLeads((lData as Lead[]) || []);
      setPartners((pData as Partner[]) || []);
      if (planData) setPlans(planData as SubscriptionPlan[]);
    } catch (err: any) {
      setErrorMsg(`Gagal memuat surat penawaran: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Handle URL query prefill
  useEffect(() => {
    if (prefillBizName || prefillClientName) {
      setFormBizName(prefillBizName);
      setFormClientName(prefillClientName);
      setFormPhone(prefillPhone);
      setFormLeadId(prefillLeadId);
      if (currentUserRole === 'partner' && currentPartnerId) {
        setFormPartnerId(currentPartnerId);
      }
      setIsCreateModalOpen(true);
    }
  }, [prefillBizName, prefillClientName, prefillPhone, prefillLeadId, currentUserRole, currentPartnerId]);

  // Compute Subtotal and Final
  const formSubtotal = useMemo(() => {
    return formItems.reduce((sum, item) => sum + Number(item.total_price || 0), 0);
  }, [formItems]);

  const formFinalAmount = useMemo(() => {
    const val = formSubtotal - formDiscount;
    return val > 0 ? val : 0;
  }, [formSubtotal, formDiscount]);

  // Add Item to Form
  const handleAddItem = (desc = '', price = 0) => {
    setFormItems((prev) => [
      ...prev,
      { description: desc, qty: 1, unit_price: price, total_price: price },
    ]);
  };

  // Update Item
  const handleUpdateItem = (index: number, field: keyof QuotationItem, value: any) => {
    setFormItems((prev) => {
      const copy = [...prev];
      const item = { ...copy[index], [field]: value };
      if (field === 'qty' || field === 'unit_price') {
        item.total_price = Number(item.qty || 0) * Number(item.unit_price || 0);
      }
      copy[index] = item;
      return copy;
    });
  }  // Remove Item
  const handleRemoveItem = (index: number) => {
    setFormItems((prev) => prev.filter((_, i) => i !== index));
  };

  // 1-Click Comparison Preset: Option A (Software Only) vs Option B (Hardware Bundle + Free License)
  const handleApplyComparisonPreset = () => {
    setFormItems([
      {
        description:
          '[PILIHAN A - HEMAT (SOFTWARE SAJA)] Langganan Mangga POS PRO 1 Tahun Penuh (Bisa pakai HP / Tablet sendiri)',
        qty: 1,
        unit_price: price1Year,
        total_price: price1Year,
      },
      {
        description:
          '[PILIHAN B - TERIMA BERES (PAKET MESIN KASIR)] Paket Meja Kafe & Resto (Tablet + Stand Meja + Printer 58mm + Cash Drawer RJ11) • BONUS: GRATIS Lisensi PRO 1 Tahun Penuh',
        qty: 1,
        unit_price: 2499000,
        total_price: 2499000,
      },
    ]);
    setFormDiscount(0);
    setFormNotes(
      'Klien dipersilakan memilih salah satu opsi di atas yang paling sesuai dengan kebutuhan usaha:\n' +
      '• Pilihan A: Investasi paling hemat, siap langsung dipakai di smartphone/tablet yang sudah dimiliki.\n' +
      '• Pilihan B: Perangkat kasir lengkap siap pakai di meja kasir toko/kafe Anda, garansi hardware resmi 1 tahun.\n' +
      '• Keduanya sudah termasuk gratis pendampingan input menu awal & panduan kasir sampai mahir.'
    );
  };

  const isFormComparison = useMemo(() => {
    return formItems.some((it) => /\[(PILIHAN|OPSI)\s*[A-Z]/i.test(it.description));
  }, [formItems]);

  // Submit Create Quotation
  const handleCreateQuotation = async () => {
    if (!formBizName.trim()) {
      setErrorMsg('Nama usaha / toko wajib diisi.');
      return;
    }
    if (formItems.length === 0) {
      setErrorMsg('Tambahkan minimal 1 item paket penawaran.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const now = new Date();
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const quoteNumber = `QUO-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}-${randomSuffix}`;

      const validUntilDate = new Date(now);
      validUntilDate.setDate(validUntilDate.getDate() + formValidDays);

      // Determine partner_id: If partner role, strictly use partner's ID
      let finalPartnerId = formPartnerId || null;
      if (currentUserRole === 'partner') {
        finalPartnerId = currentPartnerId || formPartnerId || null;
        if (!finalPartnerId) {
          // Last resort fallback
          const { data: { user } } = await supabase.auth.getUser();
          if (user?.email) {
            const { data: me } = await supabase
              .from('admin_users')
              .select('partner_id, role')
              .or(`email.ilike.${user.email.toLowerCase()},user_id.eq.${user.id}`)
              .maybeSingle();
            if (me?.partner_id) {
              finalPartnerId = me.partner_id;
              setCurrentPartnerId(me.partner_id);
            } else {
              const { data: pMatch } = await supabase
                .from('partners')
                .select('id')
                .eq('email', user.email.toLowerCase())
                .maybeSingle();
              if (pMatch?.id) {
                finalPartnerId = pMatch.id;
                setCurrentPartnerId(pMatch.id);
              }
            }
          }
        }

        if (!finalPartnerId) {
          setErrorMsg(
            'Akun Anda terdaftar sebagai Mitra tetapi profil belum ditautkan ke ID Mitra. Silakan hubungi Super Admin.'
          );
          setIsSubmitting(false);
          return;
        }
      }

      const finalDiscount = currentUserRole === 'partner' ? 0 : formDiscount;
      const finalAmount = currentUserRole === 'partner' ? formSubtotal : formFinalAmount;

      const payload = {
        quote_number: quoteNumber,
        client_name: formClientName.trim() || 'Pemilik Toko',
        client_business_name: formBizName.trim(),
        client_phone: formPhone.trim() || null,
        lead_id: formLeadId || null,
        partner_id: finalPartnerId,
        items: formItems,
        subtotal: formSubtotal,
        discount_amount: finalDiscount,
        final_amount: finalAmount,
        valid_until: validUntilDate.toISOString().split('T')[0],
        status: 'sent',
        notes: formNotes.trim() || null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { data: created, error: qErr } = await supabase
        .from('quotations')
        .insert(payload)
        .select('*, leads(*), partners(*)')
        .single();

      if (qErr) throw qErr;

      // If tied to lead, update lead status to 'quoted' safely
      if (formLeadId) {
        try {
          await supabase
            .from('leads')
            .update({ status: 'quoted', updated_at: new Date().toISOString() })
            .eq('id', formLeadId);
        } catch (leadErr) {
          console.warn('Could not auto-update lead status:', leadErr);
        }
      }

      setSuccessMsg(`Surat penawaran ${quoteNumber} untuk "${formBizName}" berhasil dibuat!`);
      setIsCreateModalOpen(false);
      setPreviewQuotation(created as Quotation);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal membuat surat penawaran: ${err?.message || 'Kesalahan sistem'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Update Status Quotation
  const handleUpdateStatus = async (quoteId: string, status: string) => {
    try {
      const { error } = await supabase
        .from('quotations')
        .update({ status, updated_at: new Date().toISOString() })
        .eq('id', quoteId);

      if (error) throw error;
      setQuotations((prev) => prev.map((q) => (q.id === quoteId ? { ...q, status: status as any } : q)));
    } catch (err: any) {
      setErrorMsg(`Gagal update status penawaran: ${err?.message}`);
    }
  };

  // Generate WhatsApp Message text
  const generateWhatsAppMessage = (q: Quotation) => {
    const isComparison = q.items.some((it) =>
      /\[(PILIHAN|OPSI)\s*[A-Z]/i.test(it.description)
    );

    let msg = `*SURAT PENAWARAN RESMI MANGGA POS*\n`;
    msg += `No. Ref: *${q.quote_number}*\n`;
    msg += `Kepada: *${q.client_name}* (${q.client_business_name})\n\n`;
    msg += `Halo Kak, terima kasih atas ketertarikan Anda menggunakan sistem kasir modern *Mangga POS*. `;

    if (isComparison) {
      msg += `Berikut kami siapkan *2 Opsi Solusi* yang dapat dipilih sesuai kebutuhan & alokasi budget usaha Kakak:\n\n`;

      q.items.forEach((item, idx) => {
        const optionMatch = item.description.match(/\[(PILIHAN\s*[A-Z][^\]]*)\]/i);
        const optionLabel = optionMatch ? optionMatch[1] : `OPSI ${idx + 1}`;
        const cleanDesc = item.description.replace(/\[(PILIHAN|OPSI)[^\]]*\]\s*/i, '');

        msg += `👉 *${optionLabel.toUpperCase()}*\n`;
        msg += `   📦 *${cleanDesc}*\n`;
        msg += `   💵 *Investasi: Rp ${Number(item.unit_price).toLocaleString('id-ID')}*\n\n`;
      });

      msg += `💡 *Keterangan:* Kakak cukup *memilih salah satu opsi* di atas. Jika memilih Paket Mesin Kasir, perangkat kasir langsung lengkap dan lisensi PRO sudah gratis selama 1 tahun.\n`;
    } else {
      msg += `Berikut kami lampirkan rincian penawaran paket:\n\n`;

      q.items.forEach((item, idx) => {
        msg += `${idx + 1}. *${item.description}*\n`;
        msg += `   Jumlah: ${item.qty}x @ Rp ${Number(item.unit_price).toLocaleString('id-ID')} = Rp ${Number(
          item.total_price
        ).toLocaleString('id-ID')}\n`;
      });

      if (q.discount_amount > 0) {
        msg += `\nSubtotal: Rp ${Number(q.subtotal).toLocaleString('id-ID')}\n`;
        msg += `Diskon Spesial: - Rp ${Number(q.discount_amount).toLocaleString('id-ID')}\n`;
      }

      msg += `\n*TOTAL INVESTASI: Rp ${Number(q.final_amount).toLocaleString('id-ID')}*\n`;
    }

    if (q.valid_until) {
      msg += `\n_(Penawaran harga ini berlaku s/d ${new Date(q.valid_until).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })})_\n`;
    }

    if (q.notes) {
      msg += `\n*Catatan & Garansi:*\n${q.notes}\n`;
    }

    msg += `\nUntuk konsultasi pemasangan, demo aplikasi, atau aktivasi paket, silakan langsung balas pesan ini. Tim kami siap membantu! 🙏`;

    return msg;
  };

  // Copy WhatsApp Text to Clipboard
  const handleCopyWhatsAppText = (q: Quotation) => {
    const text = generateWhatsAppMessage(q);
    navigator.clipboard.writeText(text);
    setCopiedId(q.id);
    setTimeout(() => setCopiedId(null), 2500);
  };

  // Filtered Quotations
  const filteredQuotations = useMemo(() => {
    return quotations.filter((q) => {
      // Security safeguard: If partner, NEVER show other partner's quotations
      if (currentUserRole === 'partner' && currentPartnerId) {
        if (q.partner_id !== currentPartnerId) return false;
      }

      const matchSearch =
        !searchQuery ||
        q.quote_number.toLowerCase().includes(searchQuery.toLowerCase()) ||
        q.client_business_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        q.client_name.toLowerCase().includes(searchQuery.toLowerCase());

      if (!matchSearch) return false;
      if (statusFilter !== 'all' && q.status !== statusFilter) return false;
      return true;
    });
  }, [quotations, searchQuery, statusFilter, currentUserRole, currentPartnerId]);

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Surat Penawaran (Quotations)"
        description="Buat penawaran harga resmi paket aplikasi dan bundling hardware kasir, kirim langsung ke WhatsApp calon klien"
      />

      {/* Top Banner Alerts */}
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

      {/* Action Header */}
      <div className="bg-white rounded-3xl border border-slate-200/80 shadow-xs p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-extrabold text-slate-900">Daftar Surat Penawaran</h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Format resmi siap kirim ke WhatsApp klien atau dicetak sebagai lembar penawaran
          </p>
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
            onClick={() => {
              setFormBizName('');
              setFormClientName('');
              setFormPhone('');
              setFormLeadId('');
              setFormPartnerId(currentUserRole === 'partner' ? (currentPartnerId || '') : '');
              setFormItems([
                {
                  description: 'Langganan Mangga POS PRO (1 Tahun)',
                  qty: 1,
                  unit_price: price1Year,
                  total_price: price1Year,
                },
              ]);
              setFormDiscount(0);
              setIsCreateModalOpen(true);
            }}
            style={{ background: 'linear-gradient(135deg, #7c3aed 0%, #4f46e5 100%)', color: '#ffffff' }}
            className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95"
          >
            <PlusCircle className="w-4 h-4 text-white" />
            <span className="text-white">+ Buat Penawaran Baru</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white rounded-3xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="p-4 bg-slate-50/60 border-b border-slate-100 flex flex-col sm:flex-row gap-3 items-center justify-between">
          <div className="relative w-full sm:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari no penawaran, nama toko, atau klien..."
              value={searchQuery}
              onInput={(e) => setSearchQuery((e.target as HTMLInputElement).value)}
              className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
            />
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto">
            <span className="text-xs text-slate-400 font-medium">Status:</span>
            {['all', 'sent', 'accepted', 'rejected'].map((st) => (
              <button
                key={st}
                onClick={() => setStatusFilter(st)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold capitalize transition-all ${statusFilter === st
                    ? 'bg-purple-600 text-white shadow-xs'
                    : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-100'
                  }`}
              >
                {st === 'all' ? 'Semua' : st}
              </button>
            ))}
          </div>
        </div>

        {/* Table of Quotations */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/40 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                <th className="py-3.5 px-6">Nomor & Tanggal</th>
                <th className="py-3.5 px-4">Calon Klien & Toko</th>
                <th className="py-3.5 px-4">Paket & Hardware</th>
                <th className="py-3.5 px-4">Total Penawaran</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-6 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-slate-400" />
                    Memuat surat penawaran...
                  </td>
                </tr>
              ) : filteredQuotations.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    Belum ada surat penawaran. Klik &ldquo;+ Buat Penawaran Baru&rdquo; untuk memulai.
                  </td>
                </tr>
              ) : (
                filteredQuotations.map((q) => {
                  const isAccepted = q.status === 'accepted';
                  const isSent = q.status === 'sent';

                  return (
                    <tr key={q.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-4 px-6">
                        <div className="font-mono font-bold text-purple-700 bg-purple-50 px-2 py-0.5 rounded-md inline-block border border-purple-200">
                          {q.quote_number}
                        </div>
                        <div className="text-[11px] text-slate-400 mt-1">
                          {new Date(q.created_at).toLocaleDateString('id-ID', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </div>
                      </td>

                      <td className="py-4 px-4">
                        <div className="font-extrabold text-slate-900 text-sm">{q.client_business_name}</div>
                        <div className="text-[11px] text-slate-500">
                          {q.client_name} {q.client_phone ? `• ${q.client_phone}` : ''}
                        </div>
                      </td>

                      <td className="py-4 px-4 max-w-xs">
                        <div className="space-y-0.5 truncate">
                          {q.items.map((item, i) => (
                            <div key={i} className="text-slate-700 truncate">
                              • {item.qty}x {item.description}
                            </div>
                          ))}
                        </div>
                      </td>

                      <td className="py-4 px-4">
                        {q.items.some((it) => /\[(PILIHAN|OPSI)\s*[A-Z]/i.test(it.description)) ? (
                          <div>
                            <span className="inline-block px-1.5 py-0.5 rounded-md bg-purple-100 text-purple-800 font-extrabold text-[9px] mb-0.5">
                              2 Opsi Pilihan
                            </span>
                            <div className="font-black text-slate-900 text-xs">
                              Mulai Rp{' '}
                              {Math.min(...q.items.map((it) => Number(it.unit_price))).toLocaleString('id-ID')}
                            </div>
                            <div className="text-[10px] text-slate-500">Alternatif Opsi</div>
                          </div>
                        ) : (
                          <>
                            <div className="font-black text-slate-900 text-sm">
                              Rp {Number(q.final_amount).toLocaleString('id-ID')}
                            </div>
                            {q.discount_amount > 0 && (
                              <div className="text-[10px] text-emerald-600 font-semibold">
                                Hemat: Rp {Number(q.discount_amount).toLocaleString('id-ID')}
                              </div>
                            )}
                          </>
                        )}
                      </td>

                      <td className="py-4 px-4">
                        <select
                          value={q.status}
                          onChange={(e) => handleUpdateStatus(q.id, e.target.value)}
                          className={`text-[11px] font-bold px-2 py-1 rounded-lg border focus:outline-hidden ${isAccepted
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : isSent
                                ? 'bg-purple-50 text-purple-700 border-purple-200'
                                : 'bg-slate-100 text-slate-600 border-slate-200'
                            }`}
                        >
                          <option value="draft">Draft</option>
                          <option value="sent">Terkirim (Sent)</option>
                          <option value="accepted">Diterima (Deal)</option>
                          <option value="rejected">Ditolak</option>
                        </select>
                      </td>

                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Send via WhatsApp */}
                          {q.client_phone && (
                            <a
                              href={`https://wa.me/${q.client_phone.replace(
                                /[^0-9]/g,
                                ''
                              )}?text=${encodeURIComponent(generateWhatsAppMessage(q))}`}
                              target="_blank"
                              rel="noreferrer"
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-600 hover:text-white text-emerald-700 font-bold transition-all"
                              title="Buka Chat WhatsApp"
                            >
                              <MessageCircle className="w-3.5 h-3.5" />
                              <span>Kirim WA</span>
                            </a>
                          )}

                          {/* Copy Text Button */}
                          <button
                            onClick={() => handleCopyWhatsAppText(q)}
                            className="p-1.5 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-100 transition-colors"
                            title="Salin Teks Penawaran"
                          >
                            {copiedId === q.id ? (
                              <Check className="w-3.5 h-3.5 text-emerald-600" />
                            ) : (
                              <Copy className="w-3.5 h-3.5" />
                            )}
                          </button>

                          {/* Preview Modal Button */}
                          <button
                            onClick={() => setPreviewQuotation(q)}
                            className="p-1.5 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-100 transition-colors"
                            title="Preview Lembar Penawaran"
                          >
                            <Printer className="w-3.5 h-3.5" />
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
      </div>

      {/* MODAL: BUAT PENAWARAN BARU */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div
              style={{ background: 'linear-gradient(135deg, #7c3aed 0%, #4f46e5 100%)', color: '#ffffff' }}
              className="p-6 bg-purple-600 text-white flex items-center justify-between shadow-sm"
            >
              <div>
                <h3 className="text-lg font-extrabold flex items-center gap-2 text-white">
                  <FileText className="w-5 h-5 text-purple-200" />
                  <span className="text-white">Buat Surat Penawaran Resmi</span>
                </h3>
                <p className="text-xs text-purple-100 mt-0.5">
                  Rancang paket berlangganan & hardware untuk calon klien
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsCreateModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[75vh] overflow-y-auto text-xs">
              {/* Partner Read-Only Mode Banner */}
              {currentUserRole === 'partner' && (
                <div className="p-3.5 rounded-2xl bg-indigo-50 border border-indigo-200 flex items-center justify-between text-indigo-950">
                  <div className="flex items-center gap-2.5">
                    <span className="text-xl">🔒</span>
                    <div>
                      <div className="text-xs font-black flex items-center gap-1.5">
                        <span>Mode Mitra: Harga Resmi Terkunci (Read-Only)</span>
                        <span className="text-[10px] bg-indigo-200 text-indigo-800 px-1.5 py-0.5 rounded font-extrabold">
                          Admin Controlled
                        </span>
                      </div>
                      <p className="text-[11px] text-indigo-700 mt-0.5">
                        Harga satuan lisensi dan paket bundling telah ditetapkan resmi oleh Super Admin pusat agar seragam. Anda dapat mengatur jumlah (qty) dan pilihan paket.
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {/* Client Info */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Nama Toko / Usaha *</label>
                  <input
                    type="text"
                    placeholder="Kopi Kenangan Senja"
                    value={formBizName}
                    onInput={(e) => setFormBizName((e.target as HTMLInputElement).value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-bold focus:outline-hidden focus:border-purple-500"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Nama Calon Klien</label>
                  <input
                    type="text"
                    placeholder="Mas Ryan"
                    value={formClientName}
                    onInput={(e) => setFormClientName((e.target as HTMLInputElement).value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-purple-500"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">No. WhatsApp</label>
                  <input
                    type="text"
                    placeholder="08123456789"
                    value={formPhone}
                    onInput={(e) => setFormPhone((e.target as HTMLInputElement).value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 focus:outline-hidden focus:border-purple-500"
                  />
                </div>
              </div>

              {/* 1-Click Comparison Banner */}
              <div className="p-4 rounded-2xl bg-linear-to-r from-purple-900 via-indigo-900 to-slate-900 text-white shadow-md border border-purple-800">
                <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                  <div className="space-y-1">
                    <div className="flex items-center gap-1.5 text-amber-300 font-extrabold text-xs">
                      <Crown className="w-4 h-4 fill-amber-300 text-amber-300" />
                      <span>REKOMENDASI: 1-Click Buat Penawaran 2 Opsi Sekaligus</span>
                    </div>
                    <p className="text-[11px] text-purple-200">
                      Opsi A (Lisensi PRO 1 Tahun) <b>vs</b> Opsi B (Paket Meja Kasir Lengkap + Free Lisensi 1 Tahun)
                    </p>
                    <p className="text-[10px] text-slate-300">
                      Format pesan WhatsApp otomatis memisahkan per Opsi sehingga klien tinggal memilih salah satu!
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={handleApplyComparisonPreset}
                    className="px-4 py-2 rounded-xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-black text-xs transition-all shadow-md hover:scale-105 active:scale-95 shrink-0 flex items-center gap-1.5"
                  >
                    <Layers className="w-3.5 h-3.5" />
                    <span>Terapkan 2 Opsi</span>
                  </button>
                </div>
              </div>

              {/* Template Cepat Berdasarkan Kategori */}
              <div className="space-y-3">
                {/* 1. Software Licenses */}
                <div className="p-3.5 rounded-2xl bg-purple-50/70 border border-purple-100 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-bold text-purple-950 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5 text-purple-600" />
                      💻 Lisensi Software Aplikasi Saja (Live Sync Master Plan):
                    </span>
                    <span className="text-[10px] font-bold text-purple-700 bg-purple-100 px-2 py-0.5 rounded-md">
                      Software Only
                    </span>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {softwarePresets.map((tmpl, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleAddItem(tmpl.description, tmpl.unit_price)}
                        className="px-2.5 py-1.5 rounded-lg bg-white border border-purple-200 hover:border-purple-400 text-purple-900 text-[11px] font-semibold transition-all hover:shadow-xs flex items-center gap-1.5"
                      >
                        <span className="font-bold text-purple-700">[{tmpl.tag}]</span>
                        <span>{tmpl.description}</span>
                        <span className="text-purple-600 font-extrabold text-[10px]">
                          (Rp {tmpl.unit_price.toLocaleString('id-ID')})
                        </span>
                      </button>
                    ))}
                  </div>
                </div>

                {/* 2. Hardware Bundles */}
                <div className="p-3.5 rounded-2xl bg-indigo-50/70 border border-indigo-100 space-y-2.5">
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-bold text-indigo-950 flex items-center gap-1.5">
                      <ShoppingBag className="w-3.5 h-3.5 text-indigo-600" />
                      🖥️ Paket Lengkap Mesin Kasir (+ Free Lisensi PRO):
                    </span>
                    <span className="text-[10px] font-bold text-indigo-700 bg-indigo-100 px-2 py-0.5 rounded-md">
                      Hardware + Software Bundle
                    </span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                    {hardwareBundles.map((b, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleAddItem(b.description, b.unit_price)}
                        className="p-2.5 rounded-xl bg-white border border-indigo-200 hover:border-indigo-400 text-left transition-all hover:shadow-xs flex flex-col justify-between group"
                      >
                        <div>
                          <div className="flex items-center justify-between mb-1">
                            <span className="text-[9px] font-extrabold px-1.5 py-0.5 rounded-md bg-amber-100 text-amber-800">
                              {b.badge}
                            </span>
                            <span className="text-indigo-600 font-black text-xs">
                              Rp {b.unit_price.toLocaleString('id-ID')}
                            </span>
                          </div>
                          <div className="font-bold text-slate-800 text-[11px] group-hover:text-indigo-700 leading-snug">
                            {b.name}
                          </div>
                        </div>
                        <div className="text-[10px] text-slate-500 mt-2 font-medium">
                          + Klik untuk tambahkan
                        </div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* 3. Extra Hardware Items */}
                <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <span className="text-[11px] font-bold text-slate-700 block">
                    🔌 Aksesoris & Hardware Tambahan (Eceran):
                  </span>
                  <div className="flex flex-wrap gap-1.5">
                    {extraHardwareItems.map((item, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleAddItem(item.description, item.unit_price)}
                        className="px-2.5 py-1 rounded-lg bg-white border border-slate-200 hover:border-slate-400 text-slate-700 text-[10px] font-medium transition-all flex items-center gap-1"
                      >
                        <span>+ {item.description}</span>
                        <span className="text-slate-900 font-bold">
                          (Rp {item.unit_price.toLocaleString('id-ID')})
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Items List */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <label className="font-bold text-slate-800">Rincian Paket & Perangkat Penawaran:</label>
                    {currentUserRole === 'partner' && (
                      <span className="text-[10px] font-bold text-indigo-700 bg-indigo-100/70 border border-indigo-200 px-2 py-0.5 rounded-md flex items-center gap-1">
                        <span>🔒</span> Harga Resmi Terkunci
                      </span>
                    )}
                  </div>
                  {currentUserRole !== 'partner' && (
                    <button
                      type="button"
                      onClick={() => handleAddItem('', 0)}
                      className="text-[11px] font-bold text-purple-700 hover:underline"
                    >
                      + Tambah Baris Manual
                    </button>
                  )}
                </div>

                <div className="space-y-2">
                  {formItems.map((item, idx) => (
                    <div
                      key={idx}
                      className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50/50"
                    >
                      <input
                        type="text"
                        placeholder="Deskripsi item / paket"
                        value={item.description}
                        readOnly={currentUserRole === 'partner'}
                        onInput={(e) =>
                          handleUpdateItem(idx, 'description', (e.target as HTMLInputElement).value)
                        }
                        className={`flex-1 px-2.5 py-1.5 rounded-lg border text-xs font-semibold ${currentUserRole === 'partner'
                            ? 'bg-slate-100 text-slate-700 border-slate-200 cursor-default select-none'
                            : 'bg-white text-slate-900 border-slate-200'
                          }`}
                      />
                      <input
                        type="number"
                        min="1"
                        placeholder="Qty"
                        value={item.qty}
                        onInput={(e) =>
                          handleUpdateItem(idx, 'qty', Number((e.target as HTMLInputElement).value))
                        }
                        className="w-16 px-2 py-1.5 rounded-lg border border-slate-200 bg-white text-xs text-center font-bold"
                        title="Ubah jumlah item"
                      />
                      <div className="relative">
                        <input
                          type="number"
                          placeholder="Harga (Rp)"
                          value={item.unit_price}
                          readOnly={currentUserRole === 'partner'}
                          disabled={currentUserRole === 'partner'}
                          onInput={(e) =>
                            handleUpdateItem(idx, 'unit_price', Number((e.target as HTMLInputElement).value))
                          }
                          className={`w-32 px-2.5 py-1.5 rounded-lg border text-xs font-bold ${currentUserRole === 'partner'
                              ? 'bg-slate-100 text-slate-600 border-slate-200 cursor-not-allowed select-none pr-6'
                              : 'bg-white text-slate-900 border-slate-200'
                            }`}
                          title={currentUserRole === 'partner' ? 'Harga resmi ditentukan Admin (Read-Only)' : ''}
                        />
                        {currentUserRole === 'partner' && (
                          <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 pointer-events-none select-none">
                            🔒
                          </span>
                        )}
                      </div>
                      <span className="w-24 text-right font-black text-slate-800">
                        Rp {Number(item.total_price).toLocaleString('id-ID')}
                      </span>
                      <button
                        type="button"
                        onClick={() => handleRemoveItem(idx)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 transition-colors"
                        title="Hapus baris item"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Total Calculation */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2 text-xs">
                {isFormComparison && (
                  <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-[11px] font-semibold flex items-center gap-2 mb-2">
                    <Crown className="w-4 h-4 text-amber-600 shrink-0" />
                    <span>
                      <b>Mode 2 Opsi Terdeteksi:</b> Klien diberikan pilihan alternatif (Software vs Mesin Kasir). Total investasi di pesan WhatsApp otomatis disajikan per opsi terpisah agar klien dapat memilih salah satu.
                    </span>
                  </div>
                )}
                <div className="flex justify-between text-slate-600">
                  <span>Subtotal Rincian:</span>
                  <span className="font-bold text-slate-900">Rp {formSubtotal.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between items-center text-slate-600">
                  <div className="flex items-center gap-1.5">
                    <span>Diskon Khusus (Rp):</span>
                    {currentUserRole === 'partner' && (
                      <span className="text-[10px] text-amber-800 bg-amber-100 font-bold px-1.5 py-0.5 rounded-sm">
                        🔒 Khusus Admin
                      </span>
                    )}
                  </div>
                  <input
                    type="number"
                    readOnly={currentUserRole === 'partner'}
                    disabled={currentUserRole === 'partner'}
                    value={currentUserRole === 'partner' ? 0 : formDiscount}
                    onInput={(e) => setFormDiscount(Number((e.target as HTMLInputElement).value))}
                    className={`w-32 px-2.5 py-1 rounded-lg border text-right font-bold ${currentUserRole === 'partner'
                        ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed select-none'
                        : 'bg-white text-emerald-700 border-slate-200'
                      }`}
                    title={currentUserRole === 'partner' ? 'Diskon khusus hanya dapat diberikan oleh Super Admin' : ''}
                  />
                </div>
                <div className="pt-2 border-t border-slate-200 flex justify-between items-center text-sm font-black text-slate-900">
                  <span>Total Investasi Akhir:</span>
                  <span className="text-purple-700 text-lg">
                    Rp {formFinalAmount.toLocaleString('id-ID')}
                  </span>
                </div>
              </div>

              {/* Notes & Validity */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Masa Berlaku Penawaran (Hari):</label>
                  <select
                    value={formValidDays}
                    onChange={(e) => setFormValidDays(Number(e.target.value))}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                  >
                    <option value={7}>7 Hari</option>
                    <option value={14}>14 Hari (2 Minggu)</option>
                    <option value={30}>30 Hari (1 Bulan)</option>
                  </select>
                </div>
                {currentUserRole === 'partner' ? (
                  <div className="p-3 rounded-xl bg-purple-50 border border-purple-200">
                    <span className="text-[11px] font-bold text-slate-700 block mb-0.5">Mitra Penanggung Jawab:</span>
                    <span className="text-xs font-extrabold text-purple-800">
                      {currentPartnerName || 'Akun Mitra Anda'} (Otomatis Ditautkan)
                    </span>
                  </div>
                ) : (
                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Mitra Penanggung Jawab:</label>
                    <select
                      value={formPartnerId}
                      onChange={(e) => setFormPartnerId(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900 font-semibold"
                    >
                      <option value="">-- Tanpa Mitra (Pusat) --</option>
                      {partners.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Catatan Tambahan:</label>
                <textarea
                  rows={2}
                  value={formNotes}
                  onInput={(e) => setFormNotes((e.target as HTMLTextAreaElement).value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-200 text-slate-900"
                />
              </div>
            </div>

            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setIsCreateModalOpen(false)}
                className="px-4 py-2.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleCreateQuotation}
                disabled={isSubmitting}
                style={{ backgroundColor: '#7c3aed', color: '#ffffff' }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold shadow-md hover:shadow-lg transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    <span className="text-white">Menyimpan...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-white" />
                    <span className="text-white">Buat Surat Penawaran</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: PREVIEW / PRINT QUOTATION */}
      {previewQuotation && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="p-6 bg-slate-900 text-white flex items-center justify-between">
              <div>
                <h3 className="text-base font-extrabold flex items-center gap-2">
                  <Printer className="w-5 h-5 text-purple-400" />
                  Lembar Surat Penawaran
                </h3>
                <p className="text-xs text-slate-400">{previewQuotation.quote_number}</p>
              </div>
              <button
                onClick={() => setPreviewQuotation(null)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Document Sheet */}
            <div className="p-8 space-y-6 text-xs text-slate-800 max-h-[75vh] overflow-y-auto">
              {/* Brand Header */}
              <div className="flex items-start justify-between border-b pb-6 border-slate-200">
                <div>
                  <div className="text-2xl font-black tracking-tight text-orange-600">MANGGA POS</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">Sistem Kasir & Operasional Toko Modern</div>
                  <div className="text-[11px] text-slate-500">mudahkan.online • WhatsApp: 0812-3456-7890</div>
                </div>
                <div className="text-right">
                  <div className="text-sm font-black text-slate-900">SURAT PENAWARAN</div>
                  <div className="font-mono text-purple-700 font-bold">{previewQuotation.quote_number}</div>
                  <div className="text-slate-500 text-[11px] mt-1">
                    {new Date(previewQuotation.created_at).toLocaleDateString('id-ID', {
                      day: 'numeric',
                      month: 'long',
                      year: 'numeric',
                    })}
                  </div>
                </div>
              </div>

              {/* Client Info */}
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block mb-1">
                  Ditujukan Kepada:
                </span>
                <div className="font-extrabold text-slate-900 text-sm">
                  {previewQuotation.client_business_name}
                </div>
                <div className="text-slate-600">
                  U.p: {previewQuotation.client_name} ({previewQuotation.client_phone || '-'})
                </div>
              </div>

              {/* Items Table */}
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-100/60 font-bold text-[11px] text-slate-600">
                    <th className="py-2.5 px-3">No</th>
                    <th className="py-2.5 px-3">Deskripsi Item / Paket</th>
                    <th className="py-2.5 px-3 text-center">Qty</th>
                    <th className="py-2.5 px-3 text-right">Harga Satuan</th>
                    <th className="py-2.5 px-3 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {previewQuotation.items.map((item, i) => (
                    <tr key={i}>
                      <td className="py-2.5 px-3 text-slate-400">{i + 1}</td>
                      <td className="py-2.5 px-3 font-semibold text-slate-900">{item.description}</td>
                      <td className="py-2.5 px-3 text-center font-bold">{item.qty}</td>
                      <td className="py-2.5 px-3 text-right">
                        Rp {Number(item.unit_price).toLocaleString('id-ID')}
                      </td>
                      <td className="py-2.5 px-3 text-right font-bold text-slate-900">
                        Rp {Number(item.total_price).toLocaleString('id-ID')}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {/* Summary */}
              {previewQuotation.items.some((it) => /\[(PILIHAN|OPSI)\s*[A-Z]/i.test(it.description)) ? (
                <div className="pt-4 border-t border-slate-200 flex flex-col items-end space-y-1.5 text-xs">
                  <div className="inline-block px-2.5 py-1 rounded-md bg-purple-100 text-purple-900 font-extrabold text-[10px] mb-1">
                    MODE PENAWARAN 2 OPSI (KLIEN MEMILIH SALAH SATU)
                  </div>
                  {previewQuotation.items.map((item, i) => {
                    const match = item.description.match(/\[(PILIHAN\s*[A-Z][^\]]*)\]/i);
                    const label = match ? match[1] : `Opsi ${i + 1}`;
                    return (
                      <div
                        key={i}
                        className="flex justify-between w-80 text-slate-800 text-[11px] py-1 border-b border-slate-100 last:border-b-0"
                      >
                        <span className="font-bold text-slate-700">{label}:</span>
                        <span className="font-black text-purple-700 text-xs">
                          Rp {Number(item.total_price).toLocaleString('id-ID')}
                        </span>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="pt-4 border-t border-slate-200 flex flex-col items-end space-y-1 text-xs">
                  <div className="flex justify-between w-64 text-slate-600">
                    <span>Subtotal:</span>
                    <span className="font-bold text-slate-900">
                      Rp {Number(previewQuotation.subtotal).toLocaleString('id-ID')}
                    </span>
                  </div>
                  {previewQuotation.discount_amount > 0 && (
                    <div className="flex justify-between w-64 text-emerald-600">
                      <span>Diskon:</span>
                      <span className="font-bold">
                        - Rp {Number(previewQuotation.discount_amount).toLocaleString('id-ID')}
                      </span>
                    </div>
                  )}
                  <div className="flex justify-between w-64 text-base font-black text-slate-900 pt-2 border-t border-slate-200">
                    <span>Total Investasi:</span>
                    <span className="text-purple-700">
                      Rp {Number(previewQuotation.final_amount).toLocaleString('id-ID')}
                    </span>
                  </div>
                </div>
              )}

              {/* Notes */}
              {previewQuotation.notes && (
                <div className="pt-2 text-[11px] text-slate-500 border-t border-slate-100">
                  <strong>Catatan:</strong> {previewQuotation.notes}
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="p-5 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
              <button
                type="button"
                onClick={() => handleCopyWhatsAppText(previewQuotation)}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-white border border-slate-200 hover:bg-slate-100 text-slate-700 text-xs font-bold transition-colors"
              >
                <Copy className="w-4 h-4" />
                <span>Salin Teks WhatsApp</span>
              </button>

              <button
                type="button"
                onClick={() => window.print()}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold shadow-xs transition-all"
              >
                <Printer className="w-4 h-4" />
                <span>Cetak / Simpan PDF</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default function QuotationsPage() {
  return (
    <Suspense fallback={<div className="p-12 text-center text-slate-400">Memuat penawaran...</div>}>
      <QuotationsContent />
    </Suspense>
  );
}
