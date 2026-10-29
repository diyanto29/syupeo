'use client';

import { useState, useEffect, useRef } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { HardwarePackage } from '@/types/database';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';
import {
  ShoppingBag,
  PlusCircle,
  Edit3,
  Trash2,
  CheckCircle2,
  Printer,
  Copy,
  Check,
  X,
  Store,
  TrendingUp,
  ShieldCheck,
  Flame,
  MessageCircle,
  FileDown,
  Loader2,
  Eye,
} from 'lucide-react';

// Default packages fallback if database table is initializing or empty
const DEFAULT_PACKAGES: HardwarePackage[] = [
  {
    id: 'pkg-1-starter',
    name: 'Paket Starter Mobile',
    slug: 'paket-starter-mobile',
    badge: 'HEMAT & PRAKTIS',
    price: 499000,
    original_price: 650000,
    description: 'Solusi kasir praktis dan fleksibel untuk usaha bergerak atau ruang terbatas.',
    suitable_for: 'Warung, Booth, Kedai Kaki Lima, Food Truck, Pedagang Keliling',
    items_included: [
      'Printer Thermal Bluetooth 58mm Portable (Rechargeable)',
      'Gratis 5 Roll Kertas Struk Thermal',
      'Aplikasi Mangga POS PRO Lisensi 6 Bulan Penuh',
      'Toko Online & Menu Digital Otomatis (pos.mudahkan.online)',
      'Dukungan Cetak Struk & Pembayaran QRIS Dinamis',
      'Garansi Hardware Tukar Baru 1 Bulan & Pendampingan WA',
    ],
    is_popular: false,
    is_active: true,
    sort_order: 1,
  },
  {
    id: 'pkg-2-cafe',
    name: 'Paket Meja Kafe & Resto',
    slug: 'paket-meja-kafe-resto',
    badge: 'BEST SELLER 👑',
    price: 2499000,
    original_price: 3200000,
    description: 'Set lengkap meja kasir modern siap pakai untuk F&B dan jasa profesional.',
    suitable_for: 'Coffee Shop, Restoran, Kedai Kopi, Barbershop, Salon, Laundry',
    items_included: [
      'Tablet Layar Jernih Android + Stand Holder Meja Kokoh',
      'Printer Kasir Thermal 58mm Auto Bluetooth & USB',
      'Laci Uang Kasir Logam Otomatis (Cash Drawer RJ11)',
      'Gratis 10 Roll Kertas Struk Kasir Berkualitas',
      'Lisensi Mangga POS PRO 1 Tahun Penuh (Tanpa Batas)',
      'Gratis Bantuan Input 30 Menu Awal & Logo Toko (Terima Beres)',
      'Fitur Manajemen Meja, Kitchen Display (KDS) & Split Bill',
      'Garansi Hardware 1 Tahun Resmi & Layanan Support Prioritas',
    ],
    is_popular: true,
    is_active: true,
    sort_order: 2,
  },
  {
    id: 'pkg-3-retail',
    name: 'Paket Super Ritel & Minimarket',
    slug: 'paket-super-ritel-minimarket',
    badge: 'SUPER LENGKAP',
    price: 3499000,
    original_price: 4500000,
    description: 'Perangkat kasir performa tinggi dengan barcode scanner cepat untuk toko kelontong dan ritel.',
    suitable_for: 'Minimarket, Toko Sembako, Apotek, Toko Sparepart, Toko Bangunan',
    items_included: [
      'Tablet Kasir Android 10 Inch / Layar Lebar Definisi Tinggi',
      'Barcode Scanner Laser Wireless 1D & 2D (Bisa Scan Layar HP & Dus Produk)',
      'Printer Thermal Struk Kasir Kecepatan Tinggi',
      'Laci Uang Kasir Logam Heavy-Duty (Cash Drawer RJ11)',
      'Master Katalog 10.000+ Barcode Produk Siap Pakai Langsung',
      'Lisensi Mangga POS PRO 1 Tahun Penuh (Tanpa Batas Transaksi)',
      'Fitur Stok Multi-Satuan (Pcs/Dus), Harga Grosir & Arus Kas Shift',
      'Garansi Hardware 1 Tahun & Training Penggunaan Lengkap',
    ],
    is_popular: false,
    is_active: true,
    sort_order: 3,
  },
];

export default function HardwarePackagesPage() {
  const [packages, setPackages] = useState<HardwarePackage[]>([]);
  const [loading, setLoading] = useState(true);
  const [copiedWA, setCopiedWA] = useState(false);
  const [isDownloadingPDF, setIsDownloadingPDF] = useState(false);

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isBrochureModalOpen, setIsBrochureModalOpen] = useState(false);
  const [editingPkg, setEditingPkg] = useState<HardwarePackage | null>(null);

  // Form State
  const [formName, setFormName] = useState('');
  const [formBadge, setFormBadge] = useState('HEMAT');
  const [formPrice, setFormPrice] = useState(0);
  const [formOriginalPrice, setFormOriginalPrice] = useState(0);
  const [formSuitableFor, setFormSuitableFor] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formItems, setFormItems] = useState<string[]>(['']);
  const [formIsPopular, setFormIsPopular] = useState(false);
  const [formIsActive, setFormIsActive] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const supabase = createClient();
  const brochureRef = useRef<HTMLDivElement>(null);

  // Load packages from Supabase
  const loadPackages = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const { data, error } = await supabase
        .from('hardware_packages')
        .select('*')
        .order('sort_order', { ascending: true });

      if (error || !data || data.length === 0) {
        setPackages(DEFAULT_PACKAGES);
      } else {
        setPackages(data as HardwarePackage[]);
      }
    } catch {
      setPackages(DEFAULT_PACKAGES);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPackages();
  }, []);

  // Direct PDF Download Handler (Strict 1-Page A4 Precision)
  const handleDownloadPDF = async () => {
    setIsDownloadingPDF(true);
    try {
      const element = document.getElementById('printable-brochure') || document.getElementById('printable-brochure-offscreen');
      if (!element) {
        alert('Elemen brosur tidak ditemukan.');
        return;
      }

      // Capture to canvas with 2x scale for razor-sharp vector-like text
      const canvas = await html2canvas(element, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: '#ffffff',
        windowWidth: 794,
      });

      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4',
      });

      // Exactly 1-page A4: 210mm x 297mm (No multi-page overflow or split cuts!)
      pdf.addImage(imgData, 'PNG', 0, 0, 210, 297, undefined, 'FAST');
      pdf.save('Katalog-Paket-Kasir-Mangga-POS.pdf');
    } catch (err: any) {
      console.error('Error downloading PDF:', err);
      alert('Gagal mengunduh PDF. Silakan coba kembali.');
    } finally {
      setIsDownloadingPDF(false);
    }
  };

  const openCreateModal = () => {
    setEditingPkg(null);
    setFormName('');
    setFormBadge('HEMAT');
    setFormPrice(499000);
    setFormOriginalPrice(650000);
    setFormSuitableFor('');
    setFormDescription('');
    setFormItems([
      'Printer Thermal Bluetooth 58mm Portable',
      'Gratis 5 Roll Kertas Struk Thermal',
      'Aplikasi Mangga POS PRO Lisensi 6 Bulan',
      'Web Toko Online & Menu Digital Otomatis',
      'Garansi Hardware 1 Tahun & Support WhatsApp',
    ]);
    setFormIsPopular(false);
    setFormIsActive(true);
    setIsModalOpen(true);
  };

  const openEditModal = (pkg: HardwarePackage) => {
    setEditingPkg(pkg);
    setFormName(pkg.name);
    setFormBadge(pkg.badge || 'HEMAT');
    setFormPrice(pkg.price);
    setFormOriginalPrice(pkg.original_price || 0);
    setFormSuitableFor(pkg.suitable_for || '');
    setFormDescription(pkg.description || '');
    setFormItems(pkg.items_included && pkg.items_included.length > 0 ? [...pkg.items_included] : ['']);
    setFormIsPopular(pkg.is_popular || false);
    setFormIsActive(pkg.is_active);
    setIsModalOpen(true);
  };

  const handleAddItemRow = () => {
    setFormItems((prev) => [...prev, '']);
  };

  const handleRemoveItemRow = (idx: number) => {
    setFormItems((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleItemChange = (idx: number, val: string) => {
    setFormItems((prev) => {
      const copy = [...prev];
      copy[idx] = val;
      return copy;
    });
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setErrorMsg(null);
    setSuccessMsg(null);

    const cleanedItems = formItems.map((i) => i.trim()).filter((i) => i.length > 0);
    if (!formName.trim()) {
      setErrorMsg('Nama paket tidak boleh kosong.');
      setIsSaving(false);
      return;
    }
    if (formPrice <= 0) {
      setErrorMsg('Harga jual paket harus lebih besar dari 0.');
      setIsSaving(false);
      return;
    }

    const payload = {
      name: formName.trim(),
      slug: formName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-'),
      badge: formBadge.trim(),
      price: Number(formPrice),
      original_price: Number(formOriginalPrice) || 0,
      description: formDescription.trim(),
      suitable_for: formSuitableFor.trim(),
      items_included: cleanedItems,
      is_popular: formIsPopular,
      is_active: formIsActive,
      updated_at: new Date().toISOString(),
    };

    try {
      if (editingPkg) {
        const { error } = await supabase
          .from('hardware_packages')
          .update(payload)
          .eq('id', editingPkg.id);

        if (error) {
          setPackages((prev) =>
            prev.map((p) => (p.id === editingPkg.id ? { ...p, ...payload } : p))
          );
        } else {
          await loadPackages();
        }
        setSuccessMsg(`Paket "${formName}" berhasil diperbarui!`);
      } else {
        const newId = 'pkg-' + Date.now();
        const { error } = await supabase
          .from('hardware_packages')
          .insert({ ...payload, id: newId, sort_order: packages.length + 1 });

        if (error) {
          const newPkg: HardwarePackage = {
            id: newId,
            ...payload,
            sort_order: packages.length + 1,
          };
          setPackages((prev) => [...prev, newPkg]);
        } else {
          await loadPackages();
        }
        setSuccessMsg(`Paket baru "${formName}" berhasil ditambahkan!`);
      }

      setIsModalOpen(false);
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan: ${err.message || 'Terjadi kesalahan'}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (pkg: HardwarePackage) => {
    if (!confirm(`Hapus paket "${pkg.name}"?`)) return;

    try {
      const { error } = await supabase
        .from('hardware_packages')
        .delete()
        .eq('id', pkg.id);

      if (error) {
        setPackages((prev) => prev.filter((p) => p.id !== pkg.id));
      } else {
        await loadPackages();
      }
      setSuccessMsg(`Paket "${pkg.name}" telah dihapus.`);
    } catch {
      setPackages((prev) => prev.filter((p) => p.id !== pkg.id));
    }
  };

  // Generate WhatsApp Share Text
  const generateWhatsAppShareText = () => {
    let text = `🛒 *KATALOG RESMI PAKET MESIN KASIR SIAP PAKAI MANGGA POS*\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `Solusi Kasir Plug & Play: Tinggal colok listrik langsung jualan! Alat 100% jadi HAK MILIK SELAMANYA (Bukan sistem sewa).\n\n`;

    packages.filter((p) => p.is_active).forEach((p, idx) => {
      text += `📦 *${idx + 1}. ${p.name.toUpperCase()}* [${p.badge || 'PROMO'}]\n`;
      text += `💰 *Harga Promo: Rp ${Number(p.price).toLocaleString('id-ID')}*`;
      if (p.original_price && p.original_price > p.price) {
        text += ` _(Normal: Rp ${Number(p.original_price).toLocaleString('id-ID')})_`;
      }
      text += `\n🎯 *Cocok Untuk:* ${p.suitable_for || 'Semua jenis usaha'}\n`;
      text += `📋 *Kelengkapan Paket:*\n`;
      p.items_included.forEach((item) => {
        text += `   ✓ ${item}\n`;
      });
      text += `\n`;
    });

    text += `━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `🎁 *Bonus Tambahan:*\n`;
    text += `• GRATIS Web Toko Online & Menu Digital Otomatis\n`;
    text += `• GRATIS Bantuan Input 30 Menu Awal (Terima Beres)\n`;
    text += `• Garansi Hardware Resmi 1 Tahun & Support WhatsApp\n\n`;
    text += `📲 *Konsultasi & Pemesanan:*\n`;
    text += `Hubungi Admin via WA atau kunjungi: https://pos.mudahkan.online\n`;

    return text;
  };

  const handleCopyWhatsApp = () => {
    const text = generateWhatsAppShareText();
    navigator.clipboard.writeText(text);
    setCopiedWA(true);
    setTimeout(() => setCopiedWA(false), 2500);
  };

  const handleOpenWhatsAppDirect = () => {
    const text = generateWhatsAppShareText();
    window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`, '_blank');
  };

  // Reusable Flyer Content Component (Strict A4 Aspect Ratio 794px x 1123px)
  const renderFlyerContent = (idAttr: string) => (
    <div
      id={idAttr}
      style={{ width: '794px', height: '1123px', minHeight: '1123px', maxHeight: '1123px' }}
      className="bg-white p-7 rounded-2xl text-slate-900 border border-slate-100 flex flex-col justify-between box-border overflow-hidden select-none font-sans"
    >
      {/* ── 1. HEADER (BRAND & SUBTITLE) ── */}
      <div className="flex items-center justify-between border-b-2 border-purple-600 pb-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-amber-500 via-orange-500 to-amber-600 flex items-center justify-center text-white text-2xl shadow-sm">
            🥭
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-black text-slate-950 tracking-tight leading-none">
                MANGGA POS
              </h1>
              <span className="px-2 py-0.5 rounded-md bg-purple-100 text-purple-800 text-[10px] font-black uppercase tracking-wider">
                PRO HARDWARE
              </span>
            </div>
            <p className="text-[11px] font-extrabold text-purple-700 tracking-wide mt-1 uppercase">
              Solusi Mesin Kasir Pintar, Ritel & F&B Terpercaya
            </p>
          </div>
        </div>

        <div className="text-right">
          <span className="inline-block px-3 py-1 rounded-full bg-slate-900 text-white text-[10px] font-black uppercase tracking-wider mb-0.5 shadow-xs">
            KATALOG & DAFTAR HARGA RESMI 2026
          </span>
          <p className="text-[10px] font-bold text-slate-500">
            https://pos.mudahkan.online • Hotline WA: 0856-2427-7920
          </p>
        </div>
      </div>

      {/* ── 2. VALUE PROPOSITION PILLARS ── */}
      <div className="grid grid-cols-3 gap-3 my-2.5 bg-gradient-to-r from-purple-50/80 via-indigo-50/50 to-purple-50/80 p-2.5 rounded-xl border border-purple-100 text-center">
        <div className="px-2">
          <p className="text-[11px] font-black text-purple-900">⚡ Plug & Play Siap Pakai</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Colok listrik langsung jualan, tanpa instalasi rumit.
          </p>
        </div>
        <div className="px-2 border-x border-purple-200/60">
          <p className="text-[11px] font-black text-purple-900">👑 100% Hak Milik Sendiri</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Bukan sistem sewa. Perangkat jadi milik Anda selamanya.
          </p>
        </div>
        <div className="px-2">
          <p className="text-[11px] font-black text-purple-900">🌐 Toko Online Gratis</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Termasuk web menu digital & terima order via WhatsApp.
          </p>
        </div>
      </div>

      {/* ── 3. PACKAGES COMPARISON (3 PERFECT EQUAL-HEIGHT CARDS) ── */}
      <div className="grid grid-cols-3 gap-3.5 flex-1 items-stretch my-1">
        {packages.filter((p) => p.is_active).slice(0, 3).map((pkg, idx) => {
          const isBest = pkg.is_popular || pkg.badge?.includes('BEST') || idx === 1;
          const isStarter = idx === 0;
          const items = Array.isArray(pkg.items_included) ? pkg.items_included : [];

          return (
            <div
              key={pkg.id}
              className={`rounded-2xl p-4 flex flex-col justify-between h-full transition-all relative ${
                isBest
                  ? 'border-2 border-purple-600 bg-gradient-to-b from-purple-50/60 via-white to-purple-50/30 shadow-md ring-1 ring-purple-600/20'
                  : 'border border-slate-200 bg-white'
              }`}
            >
              {/* Card Header Section */}
              <div>
                <div className="flex items-center justify-between gap-1 mb-1.5">
                  <span
                    className={`inline-block px-2.5 py-0.5 rounded-full text-[9px] font-black tracking-wide uppercase ${
                      isBest
                        ? 'bg-purple-600 text-white shadow-xs'
                        : isStarter
                        ? 'bg-emerald-600 text-white'
                        : 'bg-slate-800 text-white'
                    }`}
                  >
                    {pkg.badge || (isBest ? 'BEST SELLER 👑' : 'PAKET PILIHAN')}
                  </span>
                  {isBest && (
                    <span className="text-[9px] font-black text-purple-700 bg-purple-100 px-1.5 py-0.5 rounded">
                      REKOMENDASI
                    </span>
                  )}
                </div>

                <h3 className="text-base font-black text-slate-900 leading-tight">
                  {pkg.name}
                </h3>

                <p className="text-[9.5px] text-slate-500 font-semibold mt-1 mb-2 leading-snug line-clamp-2 bg-slate-50 p-1.5 rounded-lg border border-slate-100">
                  🎯 {pkg.suitable_for || pkg.description}
                </p>

                {/* Price Block */}
                <div
                  className={`p-2.5 rounded-xl border mb-3 ${
                    isBest
                      ? 'bg-purple-100/60 border-purple-200 text-purple-950'
                      : 'bg-slate-50 border-slate-150 text-slate-900'
                  }`}
                >
                  <div className="flex items-baseline justify-between">
                    <span className={`text-xl font-black ${isBest ? 'text-purple-700' : 'text-slate-950'}`}>
                      Rp {Number(pkg.price).toLocaleString('id-ID')}
                    </span>
                    {pkg.original_price && pkg.original_price > pkg.price && (
                      <span className="text-[9px] font-extrabold text-emerald-700 bg-emerald-100 px-1.5 py-0.5 rounded-md">
                        HEMAT {Math.round(((pkg.original_price - pkg.price) / pkg.original_price) * 100)}%
                      </span>
                    )}
                  </div>
                  {pkg.original_price && pkg.original_price > pkg.price && (
                    <p className="text-[9.5px] text-slate-400 line-through mt-0.5 font-medium">
                      Harga Normal: Rp {Number(pkg.original_price).toLocaleString('id-ID')}
                    </p>
                  )}
                </div>

                {/* Checklist Items */}
                <div className="space-y-1.5">
                  <p className="text-[9px] font-black uppercase tracking-wider text-slate-400">
                    Kelengkapan Hardware:
                  </p>
                  <ul className="space-y-1.5">
                    {items.map((item, i) => (
                      <li key={i} className="flex items-start gap-1.5 text-[9.5px] text-slate-700 font-medium leading-tight">
                        <div className="w-3.5 h-3.5 rounded-full bg-emerald-500 text-white flex items-center justify-center shrink-0 mt-0.5 shadow-2xs">
                          <svg className="w-2.5 h-2.5 fill-current" viewBox="0 0 20 20">
                            <path d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" />
                          </svg>
                        </div>
                        <span className="line-clamp-2">{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Card Bottom Pill Tag (Uniform baseline across all 3 cards) */}
              <div className="mt-3 pt-2.5 border-t border-slate-100">
                <div
                  className={`py-1.5 px-2 rounded-lg text-center text-[9.5px] font-extrabold tracking-tight ${
                    isBest
                      ? 'bg-purple-600 text-white shadow-xs'
                      : 'bg-slate-100 text-slate-700'
                  }`}
                >
                  {isBest
                    ? '✓ Rekomendasi Terlaris • Siap Pakai'
                    : isStarter
                    ? '✓ Praktis & Hemat • Bebas Biaya Bulanan'
                    : '✓ Master 10k Barcode • Heavy Duty'}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* ── 4. FOOTER: GUARANTEE SEALS & CONTACT ── */}
      <div className="border-t-2 border-slate-200/90 pt-3 flex items-center justify-between gap-4 text-slate-600">
        <div>
          <div className="flex items-center gap-2 mb-0.5">
            <span className="text-emerald-600 font-black text-xs">🛡️ GARANSI & LAYANAN RESMI</span>
            <span className="text-[10px] text-slate-300">•</span>
            <span className="text-[10px] font-bold text-slate-700">100% Hak Milik (Bebas Biaya Sewa)</span>
          </div>
          <p className="text-[9.5px] text-slate-500 leading-tight">
            Garansi Hardware 1 Tahun Tukar Baru • Pendampingan Kasir 7 Hari Seminggu • Gratis Update Aplikasi Selamanya.
          </p>
        </div>

        <div className="text-right shrink-0 bg-purple-50/80 px-3.5 py-1.5 rounded-xl border border-purple-100">
          <p className="text-[10px] font-black text-purple-900 uppercase tracking-wide">
            Pemesanan & Konsultasi Resmi:
          </p>
          <p className="text-xs font-black text-slate-900 mt-0.5">
            WhatsApp: <span className="text-purple-700 font-black">0856-2427-7920</span>
          </p>
          <p className="text-[9.5px] font-semibold text-slate-500">https://pos.mudahkan.online</p>
        </div>
      </div>
    </div>
  );

  return (
    <div className="space-y-6 max-w-7xl pb-16">
      <Navbar
        title="Paket Mesin Kasir & Hardware"
        description="Atur harga bundling printer, tablet, scanner & laci kasir secara dinamis, dan unduh brosur PDF resmi."
      />

      {/* Top Action Bar & Quick Actions */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
            <ShoppingBag className="w-5 h-5 text-purple-600" />
            Katalog Hardware & Mesin Kasir
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Harga yang Anda atur di sini akan langsung tampil pada website dan file brosur PDF.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {/* Direct 1-Click PDF Download Button */}
          <button
            onClick={handleDownloadPDF}
            disabled={isDownloadingPDF}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-extrabold text-xs shadow-md shadow-purple-600/20 active:scale-95 transition-all disabled:opacity-50"
            title="Langsung unduh file PDF ke komputer/HP tanpa dialog print"
          >
            {isDownloadingPDF ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Membuat PDF...</span>
              </>
            ) : (
              <>
                <FileDown className="w-4 h-4" />
                <span>⬇️ Download PDF Brosur</span>
              </>
            )}
          </button>

          <button
            onClick={() => setIsBrochureModalOpen(true)}
            className="flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs active:scale-95 transition-all"
            title="Buka pratinjau brosur di layar"
          >
            <Eye className="w-4 h-4 text-slate-500" />
            <span>Lihat Brosur</span>
          </button>

          <button
            onClick={handleCopyWhatsApp}
            className="flex items-center gap-2 px-3.5 py-2.5 rounded-xl bg-white hover:bg-slate-50 border border-slate-200 text-slate-700 font-bold text-xs shadow-xs active:scale-95 transition-all"
            title="Salin ringkasan harga ke format WhatsApp"
          >
            {copiedWA ? (
              <>
                <Check className="w-4 h-4 text-emerald-600" />
                <span className="text-emerald-700">Tersalin!</span>
              </>
            ) : (
              <>
                <Copy className="w-4 h-4 text-slate-500" />
                <span>Salin WA</span>
              </>
            )}
          </button>

          <button
            onClick={openCreateModal}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs shadow-md shadow-emerald-600/20 active:scale-95 transition-all"
          >
            <PlusCircle className="w-4 h-4" />
            <span>+ Tambah Paket</span>
          </button>
        </div>
      </div>

      {/* Alerts */}
      {errorMsg && (
        <div className="p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-center justify-between shadow-xs">
          <span className="font-semibold">{errorMsg}</span>
          <button onClick={() => setErrorMsg(null)} className="text-rose-600 hover:text-rose-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}
      {successMsg && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center justify-between shadow-xs">
          <span className="font-semibold">{successMsg}</span>
          <button onClick={() => setSuccessMsg(null)} className="text-emerald-600 hover:text-emerald-900">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Quick Highlights Info (Light Theme) */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-purple-50 border border-purple-200/80 flex items-center justify-center text-purple-600">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Paket Bundling Aktif</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">
              {packages.filter((p) => p.is_active).length} Paket Siap Jual
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-50 border border-amber-200/80 flex items-center justify-center text-amber-600">
            <Flame className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Paket Terlaris (Flagship)</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5 truncate">
              {packages.find((p) => p.is_popular)?.name || 'Paket Meja Kafe'}
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-emerald-50 border border-emerald-200/80 flex items-center justify-center text-emerald-600">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Status Kepemilikan</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">Hak Milik (Non-Sewa)</h4>
          </div>
        </div>
      </div>

      {/* Hardware Packages Cards Grid (Light Theme) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
        {packages.map((pkg) => {
          const isBestSeller = pkg.is_popular || pkg.badge?.includes('BEST');
          return (
            <div
              key={pkg.id}
              className={`rounded-3xl p-7 flex flex-col justify-between transition-all relative ${
                isBestSeller
                  ? 'bg-gradient-to-b from-purple-50/70 via-white to-purple-50/30 border-2 border-purple-500 shadow-xl shadow-purple-500/10'
                  : 'bg-white border border-slate-200/90 shadow-xs hover:border-slate-300 hover:shadow-md'
              }`}
            >
              {/* Badge Tag */}
              {pkg.badge && (
                <div
                  className={`absolute -top-3 right-6 px-3.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider shadow-sm ${
                    isBestSeller ? 'bg-purple-600 text-white' : 'bg-slate-800 text-white'
                  }`}
                >
                  {pkg.badge}
                </div>
              )}

              <div>
                <div className="mb-2">
                  <h3 className="text-xl font-black text-slate-900">{pkg.name}</h3>
                  <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                    {pkg.description || 'Solusi kasir lengkap siap pakai untuk bisnis Anda.'}
                  </p>
                </div>

                {/* Target Segment */}
                {pkg.suitable_for && (
                  <div className="mt-3 py-2 px-3 rounded-xl bg-slate-50 border border-slate-200/80 text-[11px] text-slate-700 font-bold flex items-center gap-1.5">
                    <Store className="w-3.5 h-3.5 flex-shrink-0 text-purple-600" />
                    <span className="truncate">{pkg.suitable_for}</span>
                  </div>
                )}

                {/* Price Box */}
                <div className="my-5 p-4 rounded-2xl bg-slate-50/90 border border-slate-200/80">
                  <div className="flex items-baseline gap-2">
                    <span
                      className={`text-2xl font-black ${
                        isBestSeller ? 'text-purple-700' : 'text-slate-900'
                      }`}
                    >
                      Rp {Number(pkg.price).toLocaleString('id-ID')}
                    </span>
                  </div>
                  {pkg.original_price && pkg.original_price > pkg.price ? (
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-xs text-slate-400 line-through">
                        Rp {Number(pkg.original_price).toLocaleString('id-ID')}
                      </span>
                      <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                        HEMAT Rp {Number(pkg.original_price - pkg.price).toLocaleString('id-ID')}
                      </span>
                    </div>
                  ) : null}
                </div>

                {/* Items Included Checklist */}
                <div className="space-y-2.5 mb-6">
                  <p className="text-[11px] font-extrabold uppercase tracking-wider text-slate-400">
                    Kelengkapan Paket:
                  </p>
                  <ul className="space-y-2">
                    {pkg.items_included.map((item, idx) => (
                      <li key={idx} className="flex items-start gap-2.5 text-xs text-slate-700 font-medium">
                        <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0 mt-0.5" />
                        <span className="leading-snug">{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Actions Footer */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => openEditModal(pkg)}
                    className="px-3.5 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold flex items-center gap-1.5 transition-all"
                  >
                    <Edit3 className="w-3.5 h-3.5 text-slate-600" />
                    <span>Ubah Harga / Isi</span>
                  </button>
                  <button
                    onClick={() => handleDelete(pkg)}
                    className="p-2 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-600 transition-all"
                    title="Hapus paket"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <span
                  className={`text-[10px] font-black px-2.5 py-1 rounded-full ${
                    pkg.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {pkg.is_active ? 'AKTIF' : 'NONAKTIF'}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Hidden Offscreen Container for Direct Download from Main Page (High fidelity capture) */}
      <div style={{ position: 'fixed', left: '-9999px', top: '0', width: '794px', pointerEvents: 'none', zIndex: -100 }}>
        {renderFlyerContent('printable-brochure-offscreen')}
      </div>

      {/* ── MODAL: EDIT / CREATE PACKAGE (CLEAN LIGHT THEME) ───────────────── */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white border border-slate-200 rounded-3xl w-full max-w-xl p-6 sm:p-7 shadow-2xl relative max-h-[90vh] overflow-y-auto text-slate-900">
            <button
              onClick={() => setIsModalOpen(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-700"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="mb-6">
              <h2 className="text-xl font-black text-slate-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-purple-600" />
                {editingPkg ? 'Edit Paket Kasir' : 'Tambah Paket Kasir Baru'}
              </h2>
              <p className="text-xs text-slate-500 mt-1">
                Atur harga printer, tablet, scanner, dan kelengkapan bundling yang siap dijual.
              </p>
            </div>

            <form onSubmit={handleSave} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Nama Paket</label>
                <input
                  type="text"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="Misal: Paket Meja Kafe & Resto"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all font-semibold"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Badge / Tag Promo</label>
                  <input
                    type="text"
                    value={formBadge}
                    onChange={(e) => setFormBadge(e.target.value)}
                    placeholder="Misal: BEST SELLER 👑"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Target Pengguna</label>
                  <input
                    type="text"
                    value={formSuitableFor}
                    onChange={(e) => setFormSuitableFor(e.target.value)}
                    placeholder="Misal: Kafe, Resto, Barbershop"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Harga Jual Promo (Rp) <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="number"
                    value={formPrice}
                    onChange={(e) => setFormPrice(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-sm text-slate-900 font-extrabold outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Harga Normal / Coret (Rp)
                  </label>
                  <input
                    type="number"
                    value={formOriginalPrice}
                    onChange={(e) => setFormOriginalPrice(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-sm text-slate-900 font-bold outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Deskripsi Singkat</label>
                <textarea
                  rows={2}
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  placeholder="Keterangan singkat tentang paket ini..."
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition-all"
                />
              </div>

              {/* Dynamic Items Included */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-xs font-bold text-slate-700">
                    Kelengkapan Hardware & Fasilitas:
                  </label>
                  <button
                    type="button"
                    onClick={handleAddItemRow}
                    className="text-xs font-bold text-purple-600 hover:text-purple-700 flex items-center gap-1"
                  >
                    + Tambah Item
                  </button>
                </div>

                <div className="space-y-2">
                  {formItems.map((item, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <input
                        type="text"
                        value={item}
                        onChange={(e) => handleItemChange(idx, e.target.value)}
                        placeholder={`Item kelengkapan #${idx + 1}`}
                        className="flex-1 px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-purple-500 transition-all font-medium"
                      />
                      {formItems.length > 1 && (
                        <button
                          type="button"
                          onClick={() => handleRemoveItemRow(idx)}
                          className="p-2 text-slate-400 hover:text-rose-600 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-center gap-6 pt-2">
                <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={formIsPopular}
                    onChange={(e) => setFormIsPopular(e.target.checked)}
                    className="w-4 h-4 rounded text-purple-600 focus:ring-purple-500 border-slate-300"
                  />
                  <span>Tandai sebagai Best Seller</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={formIsActive}
                    onChange={(e) => setFormIsActive(e.target.checked)}
                    className="w-4 h-4 rounded text-purple-600 focus:ring-purple-500 border-slate-300"
                  />
                  <span>Paket Aktif & Tampil</span>
                </label>
              </div>

              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 transition-all"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="px-5 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-extrabold text-xs shadow-md shadow-purple-600/20 active:scale-95 transition-all disabled:opacity-50"
                >
                  {isSaving ? 'Menyimpan...' : 'Simpan Perubahan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL: BROCHURE PREVIEW (WITH DIRECT DOWNLOAD) ──────────────── */}
      {isBrochureModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-6 overflow-y-auto">
          <div className="bg-white text-slate-900 rounded-3xl w-full max-w-4xl p-6 sm:p-8 shadow-2xl relative max-h-[92vh] overflow-y-auto print:max-h-none print:shadow-none print:p-0 print:border-none print:rounded-none">
            {/* Action Bar (Hidden on print) */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-6 mb-6 border-b border-slate-200 gap-4 print:hidden">
              <div>
                <h3 className="text-xl font-black text-slate-900">Brosur & Katalog Resmi Paket Kasir</h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Klik &ldquo;Download File PDF&rdquo; untuk mengunduh brosur langsung tanpa melalui dialog printer.
                </p>
              </div>

              <div className="flex items-center gap-2">
                {/* DIRECT PDF DOWNLOAD BUTTON */}
                <button
                  onClick={handleDownloadPDF}
                  disabled={isDownloadingPDF}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-extrabold text-xs shadow-md shadow-purple-200 active:scale-95 transition-all disabled:opacity-50"
                >
                  {isDownloadingPDF ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Mengunduh...</span>
                    </>
                  ) : (
                    <>
                      <FileDown className="w-4 h-4" />
                      <span>⬇️ Download File PDF</span>
                    </>
                  )}
                </button>

                {/* OPTIONAL PRINTER BUTTON */}
                <button
                  onClick={() => window.print()}
                  className="hidden sm:flex items-center gap-1.5 px-3 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition-all"
                  title="Cetak via printer fisik"
                >
                  <Printer className="w-3.5 h-3.5 text-slate-500" />
                  <span>Print</span>
                </button>

                <button
                  onClick={handleOpenWhatsAppDirect}
                  className="flex items-center gap-2 px-3.5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs shadow-md shadow-emerald-200 active:scale-95 transition-all"
                >
                  <MessageCircle className="w-4 h-4" />
                  <span className="hidden sm:inline">Kirim ke WA</span>
                </button>

                <button
                  onClick={() => setIsBrochureModalOpen(false)}
                  className="p-2 rounded-xl text-slate-400 hover:text-slate-700"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* FLYER CONTENT TO CAPTURE */}
            <div className="overflow-x-auto flex justify-center pb-4 bg-slate-100/50 p-4 rounded-2xl border border-slate-200">
              {renderFlyerContent('printable-brochure')}
            </div>
          </div>
        </div>
      )}

      {/* Print Specific CSS */}
      <style jsx global>{`
        @media print {
          body {
            background: white !important;
            color: black !important;
          }
          header, nav, aside, .navbar, button {
            display: none !important;
          }
          main {
            display: none !important;
          }
          #printable-brochure {
            display: block !important;
            width: 100% !important;
            margin: 0 !important;
            padding: 10px !important;
          }
        }
      `}</style>
    </div>
  );
}
