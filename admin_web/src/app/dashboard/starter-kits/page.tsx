'use client';

import { useState, useEffect, useRef } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { RetailStarterKit } from '@/types/database';
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
  Search,
  Package,
  Sparkles,
  Calculator,
  Tag,
  Barcode,
  Minus,
  Plus,
  HelpCircle,
  Layers,
  ArrowRight,
  BadgePercent,
} from 'lucide-react';

// Default packages fallback based on official Syupeo Retail Starter Kits (@ Rp 200.000)
const DEFAULT_PACKAGES: RetailStarterKit[] = [
  {
    id: 'pkg-1-toko-pemula',
    name: 'Paket 01 — Toko Pemula',
    slug: 'paket-01-toko-pemula',
    badge: 'FAVORIT KELUARGA 🌾',
    price: 200000,
    original_price: 240000,
    description: 'Stok sembako & kebutuhan harian rutin yang paling cepat berputar di lingkungan perumahan.',
    suitable_for: 'Tetangga, Usaha Rumahan, Kos-kosan, Komunitas Lingkungan',
    items_included: [
      'Beras Premium 2 kg (Bahan Pokok)',
      'Minyak Goreng 1 Liter & Gula Pasir 1 kg',
      'Tepung Terigu 1 kg & Mi Instan Pilihan (5 pcs)',
      'Kopi Sachet Nikmat (10 pcs) & Teh Pilihan',
      'Sabun Mandi (2 pcs) & Sabun Cuci Piring',
      'Deterjen Pakaian & Pasta Gigi Keluarga',
      'Kecap Manis, Tisu & Perlengkapan Kemasan Toko',
      'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      'Web Toko Online Siap Pakai & Dukungan QRIS Kasir',
    ],
    is_popular: true,
    is_active: true,
    sort_order: 1,
  },
  {
    id: 'pkg-2-gen-z-box',
    name: 'Paket 02 — Gen Z Box',
    slug: 'paket-02-gen-z-box',
    badge: 'TREN VIRAL 🔥',
    price: 200000,
    original_price: 260000,
    description: 'Aksesori kekinian & fashion items margin tinggi yang sangat diminati kalangan anak muda.',
    suitable_for: 'Mahasiswa, Pelajar, Reseller Kampus, TikTok & Instagram Shop',
    items_included: [
      'Phone Charm Kekinian (5 pcs)',
      'Pop Socket Karakter Trendi (3 pcs)',
      'Pelindung Kabel Handphone (5 pcs)',
      'Scrunchie Rambut (5 pcs) & Jepit Rambut Korea (4 pcs)',
      'Gantungan Kunci Estetik (5 pcs) & Stiker Pack (10 pcs)',
      'Kaos Kaki Korea Stylish (3 pasang)',
      'Mini Tote Bag (2 pcs) & Mini Pouch Cantik (2 pcs)',
      'Alokasi Kemasan Estetik Siap Display',
      'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      'Katalog Online untuk Share Status WA & Medsos',
    ],
    is_popular: false,
    is_active: true,
    sort_order: 2,
  },
  {
    id: 'pkg-3-beauty-box',
    name: 'Paket 03 — Beauty Box Makarizo',
    slug: 'paket-03-beauty-box',
    badge: 'STOK RESELLER 💄',
    price: 200000,
    original_price: 250000,
    description: 'Stok produk perawatan & kecantikan resmi Makarizo untuk dijual kembali dengan margin menarik.',
    suitable_for: 'Reseller Kecantikan, Mahasiswi, Salon Rumahan, Beauty Content Creator',
    items_included: [
      'Produk Perawatan Rambut & Tubuh Makarizo Resmi',
      'Produk Kecantikan Pelengkap Terlaris',
      'Kemasan Reseller Eksklusif (Pouch & Label Toko)',
      'Cadangan Biaya Operasional & Kemasan Rapi',
      'Materi Promosi Foto Produk Asli & Konten Video Pendek',
      'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      'Toko Online Pribadi untuk Terima Order Langsung',
    ],
    is_popular: false,
    is_active: true,
    sort_order: 3,
  },
  {
    id: 'pkg-4-air-mineral',
    name: 'Paket 04 — Air Mineral (VICA + Pure Life)',
    slug: 'paket-04-air-mineral',
    badge: 'KEBUTUHAN RUTIN 💧',
    price: 200000,
    original_price: 225000,
    description: 'Paket air minum siap jual dari brand terpercaya dengan perputaran repeat order sangat tinggi.',
    suitable_for: 'Warung, Rumah Tangga, Kantor Kecil, Kos-kosan, Tempat Usaha',
    items_included: [
      '1 Karton VICA 600 mL Tutup Kuning (24 Botol) @ Rp 84.000',
      '1 Galon Nestlé Pure Life 19 Liter @ Rp 70.000',
      'Alokasi Kemasan & Cadangan Biaya Operasional @ Rp 46.000',
      'Acuan: VICA 600 mL Tutup Kuning Label Biru-Hijau Resmi',
      'Panduan Lengkap Kebijakan Galon & Mekanisme Penukaran',
      'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS',
      'Pencatatan Pelanggan Rutin & Riwayat Order Otomatis',
    ],
    is_popular: false,
    is_active: true,
    sort_order: 4,
  },
];

// Template preset fasilitas jasa & ekosistem Syupeo (Bukan hardware)
const SERVICE_PRESETS: string[] = [
  'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS Selamanya',
  'Web Toko Online Siap Pakai & QRIS Kasir Otomatis',
  'Jaminan Pasokan & Restok Rutin dari Gudang Regional',
  'Kemasan Rapi & Alokasi Display Toko Siap Jual',
  'Pendampingan & SOP Kasir Toko Retail',
  'Materi Promosi Foto Produk & Konten Penjualan',
  'Aktivasi Lisensi Toko Tanpa Biaya Langganan Bulanan',
];

export default function StarterKitsPage() {
  const [packages, setPackages] = useState<RetailStarterKit[]>([]);
  const [loading, setLoading] = useState(true);
  const [isSeeding, setIsSeeding] = useState(false);
  const [isDbLoaded, setIsDbLoaded] = useState(false);
  const [copiedWA, setCopiedWA] = useState(false);
  const [isDownloadingPDF, setIsDownloadingPDF] = useState(false);

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isBrochureModalOpen, setIsBrochureModalOpen] = useState(false);
  const [editingPkg, setEditingPkg] = useState<RetailStarterKit | null>(null);

  // Form State
  const [formName, setFormName] = useState('');
  const [formBadge, setFormBadge] = useState('HEMAT');
  const [formPrice, setFormPrice] = useState(200000);
  const [formOriginalPrice, setFormOriginalPrice] = useState(240000);
  const [formSuitableFor, setFormSuitableFor] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formItems, setFormItems] = useState<string[]>(['']);
  const [formIsPopular, setFormIsPopular] = useState(false);
  const [formIsActive, setFormIsActive] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Master Catalog Product Picker State
  const [catalogSearch, setCatalogSearch] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [isSearchingCatalog, setIsSearchingCatalog] = useState(false);
  const [formProducts, setFormProducts] = useState<any[]>([]);

  const supabase = createClient();
  const brochureRef = useRef<HTMLDivElement>(null);

  // Load packages from Supabase (with linked retail_starter_kit_items)
  const loadPackages = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      let { data, error } = await supabase
        .from('retail_starter_kits')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        const fallback = await supabase
          .from('hardware_packages')
          .select('*')
          .order('created_at', { ascending: false });
        data = fallback.data;
        error = fallback.error;
      }

      if (error || !data || data.length === 0) {
        setIsDbLoaded(false);
        setPackages(DEFAULT_PACKAGES);
      } else {
        setIsDbLoaded(true);
        // Load linked items from retail_starter_kit_items
        try {
          const { data: itemsData } = await supabase
            .from('retail_starter_kit_items')
            .select('*');

          if (itemsData && itemsData.length > 0) {
            const mapped = data.map((pkg: any) => ({
              ...pkg,
              items: itemsData.filter((it: any) => it.starter_kit_id === pkg.id),
            }));
            setPackages(mapped as RetailStarterKit[]);
            return;
          }
        } catch {
          // Ignore items lookup error
        }
        setPackages(data as RetailStarterKit[]);
      }
    } catch {
      setIsDbLoaded(false);
      setPackages(DEFAULT_PACKAGES);
    } finally {
      setLoading(false);
    }
  };

  const handleSyncToDatabase = async () => {
    try {
      setIsSeeding(true);
      setErrorMsg(null);
      const payload = DEFAULT_PACKAGES.map((pkg) => ({
        slug: pkg.slug,
        name: pkg.name,
        badge: pkg.badge,
        price: pkg.price,
        original_price: pkg.original_price,
        description: pkg.description,
        suitable_for: pkg.suitable_for,
        items_included: pkg.items_included,
        is_popular: pkg.is_popular,
        is_active: pkg.is_active,
        sort_order: pkg.sort_order,
      }));

      let { error } = await supabase
        .from('retail_starter_kits')
        .upsert(payload, { onConflict: 'slug' });

      if (error) {
        const fallback = await supabase
          .from('hardware_packages')
          .upsert(payload, { onConflict: 'slug' });
        error = fallback.error;
      }

      if (error) throw error;
      setSuccessMsg('4 Paket Usaha Awal berhasil disimpan ke database Supabase!');
      await loadPackages();
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan ke database: ${err?.message || 'Pastikan akun Anda adalah admin'}`);
    } finally {
      setIsSeeding(false);
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
      pdf.save('Katalog-Paket-Usaha-Retail-Syupeo.pdf');
    } catch (err: any) {
      console.error('Error downloading PDF:', err);
      alert('Gagal mengunduh PDF. Silakan coba kembali.');
    } finally {
      setIsDownloadingPDF(false);
    }
  };

  // Debounce search Master Catalog di dalam modal
  useEffect(() => {
    if (!catalogSearch.trim()) {
      setSearchResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setIsSearchingCatalog(true);
      try {
        const query = catalogSearch.trim();
        const { data, error } = await supabase
          .from('master_catalog')
          .select('id, name, barcode, category, unit, base_price, selling_price')
          .or(`name.ilike.%${query}%,barcode.ilike.%${query}%`)
          .limit(10);
        if (!error && data) {
          setSearchResults(data);
        }
      } catch (err) {
        console.error('Error searching master catalog:', err);
      } finally {
        setIsSearchingCatalog(false);
      }
    }, 280);
    return () => clearTimeout(timer);
  }, [catalogSearch]);

  const openCreateModal = () => {
    setEditingPkg(null);
    setFormName('');
    setFormBadge('HEMAT');
    setFormPrice(200000);
    setFormOriginalPrice(245000);
    setFormSuitableFor('Toko Retail, Warung, Reseller, Pemula');
    setFormDescription('Stok perdana siap jual lengkap dengan aplikasi kasir POS & ekosistem Syupeo 100% gratis.');
    setFormItems([
      'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS Selamanya',
      'Web Toko Online Siap Pakai & QRIS Kasir Otomatis',
      'Jaminan Pasokan & Restok Rutin dari Gudang Regional',
      'Kemasan Rapi & Alokasi Display Toko Siap Jual',
      'Pendampingan & SOP Kasir Toko Retail',
    ]);
    setFormProducts([]);
    setCatalogSearch('');
    setSearchResults([]);
    setFormIsPopular(false);
    setFormIsActive(true);
    setIsModalOpen(true);
  };

  const openEditModal = (pkg: RetailStarterKit) => {
    setEditingPkg(pkg);
    setFormName(pkg.name);
    setFormBadge(pkg.badge || 'HEMAT');
    setFormPrice(pkg.price);
    setFormOriginalPrice(pkg.original_price || 0);
    setFormSuitableFor(pkg.suitable_for || '');
    setFormDescription(pkg.description || '');
    setFormItems(
      pkg.items_included && pkg.items_included.length > 0
        ? [...pkg.items_included]
        : [
            'Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS Selamanya',
            'Web Toko Online Siap Pakai & QRIS Kasir Otomatis',
            'Jaminan Pasokan & Restok Rutin dari Gudang Regional',
          ]
    );
    setFormProducts(pkg.items && pkg.items.length > 0 ? pkg.items.map((it) => ({ ...it })) : []);
    setCatalogSearch('');
    setSearchResults([]);
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

  const handleAddServicePreset = (text: string) => {
    if (!formItems.includes(text)) {
      setFormItems((prev) => {
        const filtered = prev.filter((i) => i.trim().length > 0);
        return [...filtered, text];
      });
    }
  };

  // Product Selection Handlers
  const handleAddProductFromCatalog = (prod: any) => {
    setFormProducts((prev) => {
      const existingIdx = prev.findIndex(
        (p) =>
          (p.master_catalog_id && p.master_catalog_id === prod.id) ||
          (p.barcode && prod.barcode && p.barcode === prod.barcode) ||
          p.product_name.toLowerCase() === prod.name.toLowerCase()
      );

      if (existingIdx !== -1) {
        const copy = [...prev];
        copy[existingIdx] = {
          ...copy[existingIdx],
          quantity: (Number(copy[existingIdx].quantity) || 1) + 1,
        };
        return copy;
      }

      const newItem: any = {
        id: 'item-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6),
        starter_kit_id: editingPkg?.id || '',
        master_catalog_id: prod.id,
        product_name: prod.name,
        barcode: prod.barcode || '',
        quantity: 1,
        unit: prod.unit || 'Pcs',
        unit_base_price: Math.round(Number(prod.base_price) || 0),
        unit_selling_price: Math.round(Number(prod.selling_price) || 0),
        category: prod.category || 'Sembako',
      };
      return [...prev, newItem];
    });
    setCatalogSearch('');
    setSearchResults([]);
  };

  const handleUpdateProductQuantity = (idx: number, delta: number) => {
    setFormProducts((prev) => {
      const copy = [...prev];
      const newQty = Math.max(1, (Number(copy[idx].quantity) || 1) + delta);
      copy[idx] = { ...copy[idx], quantity: newQty };
      return copy;
    });
  };

  const handleSetProductQuantity = (idx: number, val: number) => {
    setFormProducts((prev) => {
      const copy = [...prev];
      copy[idx] = { ...copy[idx], quantity: Math.max(1, Math.round(val || 1)) };
      return copy;
    });
  };

  const handleUpdateProductField = (idx: number, field: string, val: any) => {
    setFormProducts((prev) => {
      const copy = [...prev];
      copy[idx] = { ...copy[idx], [field]: val };
      return copy;
    });
  };

  const handleRemoveProduct = (idx: number) => {
    setFormProducts((prev) => prev.filter((_, i) => i !== idx));
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
      price: Math.round(Number(formPrice)),
      original_price: Math.round(Number(formOriginalPrice)) || 0,
      description: formDescription.trim(),
      suitable_for: formSuitableFor.trim(),
      items_included: cleanedItems,
      is_popular: formIsPopular,
      is_active: formIsActive,
      updated_at: new Date().toISOString(),
    };

    try {
      let savedKitId = editingPkg?.id;
      let dbSaveSuccess = true;

      if (editingPkg) {
        let { error } = await supabase
          .from('retail_starter_kits')
          .update(payload)
          .eq('id', editingPkg.id);

        if (error) {
          const fallback = await supabase
            .from('hardware_packages')
            .update(payload)
            .eq('id', editingPkg.id);
          error = fallback.error;
        }

        if (error) {
          console.warn('[handleSave] Supabase update warning:', error.message);
          dbSaveSuccess = false;
          // Fallback update ke state lokal jika tabel Supabase belum dimigrasi
          setPackages((prev) =>
            prev.map((p) =>
              p.id === editingPkg.id
                ? {
                    ...p,
                    ...payload,
                    items: formProducts.map((it) => ({ ...it })),
                  }
                : p
            )
          );
        } else {
          await loadPackages();
        }
        savedKitId = editingPkg.id;
      } else {
        const newId =
          typeof crypto !== 'undefined' && crypto.randomUUID
            ? crypto.randomUUID()
            : 'pkg-' + Date.now();
        let { error } = await supabase
          .from('retail_starter_kits')
          .insert({ ...payload, id: newId, sort_order: packages.length + 1 });

        if (error) {
          const fallback = await supabase
            .from('hardware_packages')
            .insert({ ...payload, id: newId, sort_order: packages.length + 1 });
          if (fallback.error) {
            console.warn('[handleSave] Supabase insert warning:', fallback.error.message);
            dbSaveSuccess = false;
            // Fallback tambah ke state lokal jika tabel Supabase belum dimigrasi
            const newPkg: RetailStarterKit = {
              id: newId,
              ...payload,
              sort_order: packages.length + 1,
              items: formProducts.map((it) => ({ ...it })),
            };
            setPackages((prev) => [...prev, newPkg]);
          } else {
            await loadPackages();
          }
        } else {
          await loadPackages();
        }
        savedKitId = newId;
      }

      // Sinkronkan daftar barang fisik ke retail_starter_kit_items jika tabel cloud tersedia
      if (savedKitId && dbSaveSuccess) {
        try {
          await supabase
            .from('retail_starter_kit_items')
            .delete()
            .eq('starter_kit_id', savedKitId);

          if (formProducts.length > 0) {
            const itemsPayload = formProducts.map((p) => ({
              starter_kit_id: savedKitId,
              master_catalog_id: p.master_catalog_id || null,
              product_name: p.product_name,
              barcode: p.barcode || null,
              quantity: Math.max(1, Math.round(Number(p.quantity) || 1)),
              unit: p.unit || 'Pcs',
              unit_base_price: Math.round(Number(p.unit_base_price) || 0),
              unit_selling_price: Math.round(Number(p.unit_selling_price) || 0),
              category: p.category || 'Sembako',
            }));

            const { error: itemsErr } = await supabase
              .from('retail_starter_kit_items')
              .insert(itemsPayload);

            if (itemsErr) {
              console.warn('[handleSave] items insert warning:', itemsErr);
            }
          }
        } catch (itemSyncErr) {
          console.warn('[handleSave] Error syncing kit items:', itemSyncErr);
        }
      }

      setSuccessMsg(
        editingPkg
          ? `Paket "${formName}" berhasil diperbarui dengan ${formProducts.length} produk master!`
          : `Paket baru "${formName}" berhasil ditambahkan dengan ${formProducts.length} produk master!`
      );
      setIsModalOpen(false);
    } catch (err: any) {
      setErrorMsg(`Gagal menyimpan: ${err.message || 'Terjadi kesalahan'}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (pkg: RetailStarterKit) => {
    if (!confirm(`Hapus paket "${pkg.name}"?`)) return;

    try {
      await supabase
        .from('retail_starter_kit_items')
        .delete()
        .eq('starter_kit_id', pkg.id);

      let { error } = await supabase
        .from('retail_starter_kits')
        .delete()
        .eq('id', pkg.id);

      if (error) {
        const fallback = await supabase
          .from('hardware_packages')
          .delete()
          .eq('id', pkg.id);
        error = fallback.error;
      }

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
    let text = `🛍️ *PROPOSAL RESMI PAKET USAHA RETAIL SYUPEO*\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `*Dari Stok Pertama, Sampai ke Tangan Pelanggan*\n`;
    text += `Mulai bisnis tokomu sendiri dengan modal ringan @ Rp 200.000! Lengkap dengan stok produk perdana + Aplikasi Kasir POS & Web Toko Online 100% GRATIS (Tanpa biaya sewa bulanan).\n\n`;

    packages.filter((p) => p.is_active).forEach((p, idx) => {
      text += `📦 *${idx + 1}. ${p.name.toUpperCase()}* [${p.badge || 'STARTER KIT'}]\n`;
      text += `💰 *Modal Awal: Rp ${Number(p.price).toLocaleString('id-ID')}*`;
      if (p.original_price && p.original_price > p.price) {
        text += ` _(Nilai Barang: Rp ${Number(p.original_price).toLocaleString('id-ID')})_`;
      }
      text += `\n🎯 *Target Pasar:* ${p.suitable_for || 'Semua kalangan'}\n`;
      text += `📋 *Rincian Isi Paket:*\n`;
      p.items_included.forEach((item) => {
        text += `   ✓ ${item}\n`;
      });
      text += `\n`;
    });

    text += `━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `🌟 *Keunggulan Mitra Toko Retail Syupeo:*\n`;
    text += `• 100% GRATIS Aplikasi Kasir POS & Backoffice Toko\n`;
    text += `• GRATIS Web Toko Online Siap Pakai & QRIS Kasir\n`;
    text += `• Jaminan Pasokan Rutin Langsung dari Pabrik & Gudang Regional\n`;
    text += `• Margin Keuntungan Langsung Milik Mitra Toko\n\n`;
    text += `📲 *Konsultasi & Pendaftaran Mitra:*\n`;
    text += `Hubungi Tim Syupeo atau akses: https://syupeo.com\n`;

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
      className="bg-white p-7 rounded-[16px] text-slate-900 border border-slate-200 flex flex-col justify-between box-border overflow-hidden select-none font-sans"
    >
      {/* ── 1. HEADER (BRAND & SUBTITLE) ── */}
      <div className="flex items-center justify-between border-b-2 border-[#0070fc] pb-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-[12px] bg-[#0070fc] flex items-center justify-center p-1 shadow-sm">
            <img
              src="/syupeo-icon.svg"
              alt="Syupeo Logo"
              className="w-10 h-10 object-contain"
            />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-black text-[#0070fc] tracking-tight leading-none">
                Syupeo
              </h1>
              <span className="px-2 py-0.5 rounded-md bg-[#eff6ff] text-[#0070fc] text-[10px] font-black uppercase tracking-wider border border-[#bfdbfe]">
                PAKET USAHA RETAIL
              </span>
            </div>
            <p className="text-[11px] font-extrabold text-[#ba8c02] tracking-wide mt-1 uppercase">
              Aplikasi Toko Retail Online • Dari Stok Pertama Sampai ke Pelanggan
            </p>
          </div>
        </div>

        <div className="text-right">
          <span className="inline-block px-3 py-1 rounded-full bg-[#0070fc] text-white text-[10px] font-black uppercase tracking-wider mb-0.5 shadow-xs">
            4 PILIHAN PAKET AWAL @ RP 200.000
          </span>
          <p className="text-[10px] font-bold text-slate-500">
            https://syupeo.com • Hotline WA: 0856-2427-7920
          </p>
        </div>
      </div>

      {/* ── 2. VALUE PROPOSITION PILLARS ── */}
      <div className="grid grid-cols-3 gap-3 my-2.5 bg-[#f0f7ff] p-2.5 rounded-[10px] border border-[#dbeafe] text-center">
        <div className="px-2">
          <p className="text-[11px] font-black text-[#0070fc]">🚀 Modal Ringan Rp 200.000</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Mulai usaha toko retail sendiri tanpa risiko modal besar.
          </p>
        </div>
        <div className="px-2 border-x border-[#bfdbfe]">
          <p className="text-[11px] font-black text-[#0070fc]">📱 Aplikasi Kasir 100% Gratis</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Termasuk Backoffice, POS kasir ponsel, dan QRIS instan.
          </p>
        </div>
        <div className="px-2">
          <p className="text-[11px] font-black text-[#0070fc]">🔄 Rantai Pasok Terjamin</p>
          <p className="text-[9px] text-slate-600 mt-0.5 leading-tight font-medium">
            Restock mudah langsung dari pabrik & gudang regional.
          </p>
        </div>
      </div>

      {/* ── 3. PACKAGES COMPARISON (4 CARDS GRID) ── */}
      <div className="grid grid-cols-2 gap-3 flex-1 items-stretch my-1">
        {packages.filter((p) => p.is_active).slice(0, 4).map((pkg, idx) => {
          const isBest = pkg.is_popular || idx === 0;
          const items = Array.isArray(pkg.items_included) ? pkg.items_included : [];

          return (
            <div
              key={pkg.id}
              className={`rounded-[12px] p-3 flex flex-col justify-between h-full transition-all relative ${
                isBest
                  ? 'border-2 border-[#0070fc] bg-[#f8fbff] shadow-sm'
                  : 'border border-slate-200 bg-white'
              }`}
            >
              {/* Card Header Section */}
              <div>
                <div className="flex items-center justify-between gap-1 mb-1">
                  <span
                    className={`inline-block px-2 py-0.5 rounded-md text-[9px] font-black tracking-wide uppercase ${
                      isBest
                        ? 'bg-[#0070fc] text-white'
                        : 'bg-slate-800 text-white'
                    }`}
                  >
                    {pkg.badge || 'STARTER KIT'}
                  </span>
                  <span className="text-[9px] font-extrabold text-[#ba8c02] bg-[#fefce8] border border-[#fef08a] px-1.5 py-0.2 rounded">
                    MODAL RP 200.000
                  </span>
                </div>

                <h3 className="text-sm font-black text-slate-900 leading-tight">
                  {pkg.name}
                </h3>

                <p className="text-[9px] text-slate-500 font-semibold mt-1 mb-1.5 leading-snug line-clamp-1 bg-slate-50 p-1 rounded border border-slate-100">
                  🎯 {pkg.suitable_for || pkg.description}
                </p>

                {/* Price Block */}
                <div className="p-1.5 rounded-[8px] border mb-2 bg-white border-[#dbeafe]">
                  <div className="flex items-baseline justify-between">
                    <span className="text-base font-black text-[#0070fc]">
                      Rp {Number(pkg.price).toLocaleString('id-ID')}
                    </span>
                    {pkg.original_price && pkg.original_price > pkg.price && (
                      <span className="text-[8.5px] font-extrabold text-emerald-700 bg-emerald-50 px-1 py-0.2 rounded border border-emerald-200">
                        NILAI PRODUK RP {Number(pkg.original_price).toLocaleString('id-ID')}
                      </span>
                    )}
                  </div>
                </div>

                {/* Checklist Items */}
                <div className="space-y-1">
                  <ul className="space-y-1">
                    {items.slice(0, 6).map((item, i) => (
                      <li key={i} className="flex items-start gap-1 text-[8.5px] text-slate-700 font-medium leading-tight">
                        <div className="w-3 h-3 rounded-full bg-[#0070fc] text-white flex items-center justify-center shrink-0 mt-0.5">
                          <svg className="w-2 h-2 fill-current" viewBox="0 0 20 20">
                            <path d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" />
                          </svg>
                        </div>
                        <span className="line-clamp-1">{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Card Bottom Pill Tag */}
              <div className="mt-2 pt-1.5 border-t border-slate-100">
                <div
                  className={`py-1 px-2 rounded-md text-center text-[8.5px] font-extrabold tracking-tight ${
                    isBest
                      ? 'bg-[#0070fc] text-white'
                      : 'bg-slate-100 text-slate-700'
                  }`}
                >
                  ✓ Stok Perdana Siap Jual + Aplikasi POS Gratis
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
            <span className="text-[#0070fc] font-black text-xs">⭐ SATU APLIKASI, BANYAK PELUANG!</span>
            <span className="text-[10px] text-slate-300">•</span>
            <span className="text-[10px] font-bold text-slate-700">Mulai Kecil, Tumbuh Bersama Syupeo</span>
          </div>
          <p className="text-[9px] text-slate-500 leading-tight">
            Akses Kapan Saja di Mana Saja • Dukung Pertumbuhan Toko Retail Anda • Jangkau Lebih Banyak Pelanggan Retail.
          </p>
        </div>

        <div className="text-right shrink-0 bg-[#f0f7ff] px-3.5 py-1.5 rounded-[10px] border border-[#bfdbfe]">
          <p className="text-[9.5px] font-black text-[#0070fc] uppercase tracking-wide">
            Pendaftaran & Aktivasi Toko:
          </p>
          <p className="text-xs font-black text-slate-900 mt-0.5">
            WhatsApp: <span className="text-[#0070fc] font-black">0856-2427-7920</span>
          </p>
          <p className="text-[9px] font-semibold text-slate-500">https://syupeo.com</p>
        </div>
      </div>
    </div>
  );

  return (
    <div className="space-y-6 max-w-7xl pb-16">
      <Navbar
        title="Paket Usaha Retail Syupeo"
        description="Kelola 4 paket stok awal (@ Rp 200.000) untuk mitra Toko Retail & Reseller, unduh brosur PDF, dan share ke WhatsApp."
      />

      {/* Top Action Bar & Quick Actions */}
      <div className="bg-white p-5 rounded-[12px] border border-[rgba(26,26,26,0.12)] shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-extrabold text-[#1a1a1a] flex items-center gap-2">
            <ShoppingBag className="w-5 h-5 text-[#0070fc]" />
            Katalog 4 Paket Usaha Awal (@ Rp 200.000)
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Mulai kecil, tumbuh bersama. Paket awal untuk Toko Pemula, Gen Z Box, Beauty Box, dan Air Mineral.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {/* Direct 1-Click PDF Download Button */}
          <button
            onClick={handleDownloadPDF}
            disabled={isDownloadingPDF}
            className="flex items-center gap-2 px-4 py-2.5 rounded-[8px] bg-[#0070fc] hover:bg-[#005ecc] text-white font-extrabold text-xs shadow-md shadow-[#0070fc]/20 active:scale-95 transition-all disabled:opacity-50"
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

          {/* Sync to Supabase Database button */}
          <button
            onClick={handleSyncToDatabase}
            disabled={isSeeding}
            className={`flex items-center gap-1.5 px-3.5 py-2.5 rounded-[8px] font-bold text-xs shadow-xs active:scale-95 transition-all ${
              isDbLoaded
                ? 'bg-[#eff6ff] hover:bg-[#dbeafe] text-[#0070fc] border border-[#bfdbfe]'
                : 'bg-[#ffd000] hover:bg-[#e6bc00] text-slate-900 border border-[#e6bc00] animate-pulse'
            }`}
            title="Simpan atau update 4 paket usaha ini ke tabel database Supabase"
          >
            {isSeeding ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin text-[#0070fc]" />
                <span>Menyimpan ke DB...</span>
              </>
            ) : (
              <>
                <CheckCircle2 className={`w-4 h-4 ${isDbLoaded ? 'text-[#0070fc]' : 'text-slate-900'}`} />
                <span>{isDbLoaded ? 'Tersimpan di DB Supabase' : '⚡ Simpan ke Database'}</span>
              </>
            )}
          </button>

          <button
            onClick={openCreateModal}
            className="flex items-center gap-2 px-4 py-2.5 rounded-[8px] bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs shadow-md shadow-emerald-600/20 active:scale-95 transition-all"
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
        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-[#eff6ff] border border-[#bfdbfe] flex items-center justify-center text-[#0070fc]">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Paket Usaha Tersedia</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">
              {packages.filter((p) => p.is_active).length} Paket (@ Rp 200.000)
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-amber-50 border border-amber-200/80 flex items-center justify-center text-amber-600">
            <Flame className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Paket Terlaris</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5 truncate">
              {packages.find((p) => p.is_popular)?.name || 'Toko Pemula (Sembako)'}
            </h4>
          </div>
        </div>

        <div className="p-5 rounded-[12px] bg-white border border-[rgba(26,26,26,0.12)] shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-[10px] bg-emerald-50 border border-emerald-200/80 flex items-center justify-center text-emerald-600">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs text-slate-500 font-semibold">Model Lisensi Software</p>
            <h4 className="text-xl font-black text-slate-900 mt-0.5">100% Gratis Tanpa Sewa</h4>
          </div>
        </div>
      </div>

      {/* Hardware Packages Cards Grid (Light Theme) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 items-stretch">
        {packages.map((pkg) => {
          const isBestSeller = pkg.is_popular || pkg.badge?.includes('BEST') || pkg.badge?.includes('FAVORIT');
          return (
            <div
              key={pkg.id}
              className={`rounded-[12px] p-5 flex flex-col justify-between transition-all relative ${
                isBestSeller
                  ? 'bg-gradient-to-b from-[#f0f7ff] via-white to-[#f0f7ff]/40 border-2 border-[#0070fc] shadow-md shadow-[#0070fc]/10'
                  : 'bg-white border border-[rgba(26,26,26,0.12)] shadow-xs hover:border-slate-300 hover:shadow-md'
              }`}
            >
              {/* Badge Tag */}
              {pkg.badge && (
                <div
                  className={`absolute -top-3 right-4 px-3 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider shadow-xs ${
                    isBestSeller ? 'bg-[#0070fc] text-white' : 'bg-slate-800 text-white'
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
                  <div className="mt-3 py-2 px-3 rounded-[8px] bg-slate-50 border border-slate-200/80 text-[11px] text-slate-700 font-bold flex items-center gap-1.5">
                    <Store className="w-3.5 h-3.5 flex-shrink-0 text-[#0070fc]" />
                    <span className="truncate">{pkg.suitable_for}</span>
                  </div>
                )}

                {/* Price Box */}
                <div className="my-5 p-4 rounded-[10px] bg-slate-50/90 border border-slate-200/80">
                  <div className="flex items-baseline gap-2">
                    <span
                      className={`text-2xl font-black ${
                        isBestSeller ? 'text-[#0070fc]' : 'text-slate-900'
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

                {/* Linked Products Breakdown (if available) */}
                {pkg.items && pkg.items.length > 0 ? (() => {
                  const totalRetail = pkg.items.reduce(
                    (sum, it) => sum + (Number(it.unit_selling_price || 0) * (Number(it.quantity) || 1)),
                    0
                  );
                  const profit = totalRetail - pkg.price;
                  const profitPct = totalRetail > 0 ? ((profit / totalRetail) * 100).toFixed(1) : '0';

                  return (
                    <div className="mb-4 p-3 rounded-xl bg-blue-50/70 border border-blue-200">
                      <div className="flex items-center justify-between text-xs font-bold text-[#0070fc] mb-2">
                        <span className="flex items-center gap-1.5">
                          <Package className="w-3.5 h-3.5" />
                          <span>{pkg.items.length} Produk Master Terhubung:</span>
                        </span>
                        <span className="text-[10px] text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200 font-mono font-black">
                          +Rp {profit.toLocaleString('id-ID')} ({profitPct}%)
                        </span>
                      </div>
                      <div className="space-y-1.5 divide-y divide-blue-100 max-h-48 overflow-y-auto pr-1">
                        {pkg.items.map((it, idx) => (
                          <div key={idx} className="pt-1.5 flex items-center justify-between text-xs text-slate-700">
                            <span className="truncate max-w-[170px] font-medium" title={it.product_name}>
                              • {it.product_name}
                            </span>
                            <span className="font-mono font-bold text-[#0070fc] bg-white px-1.5 py-0.5 rounded border border-blue-100 text-[11px]">
                              {it.quantity} {it.unit}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })() : null}

                {/* Services & Ecosystem Included Checklist */}
                <div className="space-y-2 mb-6">
                  <p className="text-[11px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center gap-1">
                    <Sparkles className="w-3 h-3 text-amber-500" />
                    <span>Layanan & Fasilitas Bisnis:</span>
                  </p>
                  <ul className="space-y-1.5">
                    {pkg.items_included.map((item, idx) => (
                      <li key={idx} className="flex items-start gap-2 text-xs text-slate-700 font-medium">
                        <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 flex-shrink-0 mt-0.5" />
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

      {/* ── MODAL: EDIT / CREATE PACKAGE (PAKET USAHA & MASTER PRODUK) ───────────────── */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
          <div className="bg-white border border-slate-200 rounded-3xl w-full max-w-4xl p-6 sm:p-8 shadow-2xl relative max-h-[92vh] overflow-y-auto text-slate-900">
            <button
              onClick={() => setIsModalOpen(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 p-2 rounded-full hover:bg-slate-100 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="mb-6">
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#eff6ff] text-[#0070fc] text-xs font-bold mb-2">
                <Store className="w-3.5 h-3.5" />
                <span>Closed-Loop Supply Chain POS</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-black text-slate-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-[#0070fc]" />
                {editingPkg ? 'Edit Paket Usaha Kasir' : 'Tambah Paket Usaha Baru'}
              </h2>
              <p className="text-xs text-slate-500 mt-1">
                Atur alokasi stok produk perdana dari master katalog dan fasilitas jasa ekosistem kasir untuk mitra toko.
              </p>
            </div>

            <form onSubmit={handleSave} className="space-y-6">
              {/* 1. INFORMASI UTAMA PAKET */}
              <div className="p-4 sm:p-5 rounded-2xl bg-slate-50/80 border border-slate-200/80 space-y-4">
                <h3 className="text-xs font-extrabold uppercase tracking-wider text-slate-500 flex items-center gap-1.5">
                  <Tag className="w-3.5 h-3.5 text-[#0070fc]" />
                  Informasi & Branding Paket
                </h3>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Nama Paket <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formName}
                    onChange={(e) => setFormName(e.target.value)}
                    placeholder="Misal: Paket 01 — Toko Pemula"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all font-semibold"
                    required
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1">Badge / Tag Promo</label>
                    <input
                      type="text"
                      value={formBadge}
                      onChange={(e) => setFormBadge(e.target.value)}
                      placeholder="Misal: FAVORIT KELUARGA 🌾"
                      className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1">Target Segmen Pengguna</label>
                    <input
                      type="text"
                      value={formSuitableFor}
                      onChange={(e) => setFormSuitableFor(e.target.value)}
                      placeholder="Misal: Toko Retail, Warung, Reseller, Pemula"
                      className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1">
                      Harga Jual Paket Modal (Rp) <span className="text-rose-500">*</span>
                    </label>
                    <div className="relative">
                      <span className="absolute left-3.5 top-2.5 text-xs font-bold text-slate-400">Rp</span>
                      <input
                        type="number"
                        value={formPrice}
                        onChange={(e) => setFormPrice(Number(e.target.value))}
                        className="w-full pl-9 pr-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-sm text-[#0070fc] font-black outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all font-mono"
                        required
                      />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <label className="text-xs font-bold text-slate-700">Harga Normal / Coret (Rp)</label>
                      {formProducts.length > 0 && (
                        <button
                          type="button"
                          onClick={() => {
                            const retailSum = formProducts.reduce(
                              (sum, p) => sum + (Number(p.unit_selling_price) || 0) * (Number(p.quantity) || 0),
                              0
                            );
                            if (retailSum > 0) setFormOriginalPrice(retailSum);
                          }}
                          className="text-[10px] text-[#0070fc] hover:underline font-bold"
                          title="Gunakan total nilai jual retail sebagai harga coret"
                        >
                          Gunakan Nilai Retail Produk
                        </button>
                      )}
                    </div>
                    <div className="relative">
                      <span className="absolute left-3.5 top-2.5 text-xs font-bold text-slate-400">Rp</span>
                      <input
                        type="number"
                        value={formOriginalPrice}
                        onChange={(e) => setFormOriginalPrice(Number(e.target.value))}
                        className="w-full pl-9 pr-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-sm text-slate-700 font-bold outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all font-mono"
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Deskripsi Singkat Paket</label>
                  <textarea
                    rows={2}
                    value={formDescription}
                    onChange={(e) => setFormDescription(e.target.value)}
                    placeholder="Keterangan singkat tentang peruntukan dan daya tarik paket ini..."
                    className="w-full px-3.5 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all"
                  />
                </div>
              </div>

              {/* 2. ALOKASI PRODUK DAGANG FISIK (PILIH DARI MASTER KATALOG) */}
              <div className="p-4 sm:p-5 rounded-2xl bg-white border border-slate-200 space-y-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-slate-100">
                  <div>
                    <h3 className="text-sm font-extrabold text-slate-900 flex items-center gap-2">
                      <Package className="w-4 h-4 text-[#0070fc]" />
                      <span>Alokasi Produk Dagang Fisik</span>
                      <span className="text-xs font-mono font-bold px-2 py-0.5 rounded-full bg-blue-50 text-[#0070fc] border border-blue-200">
                        {formProducts.length} Produk Terpilih
                      </span>
                    </h3>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      Pilih dari Master Katalog. Produk ini akan dikirim gudang & otomatis terisi sebagai stok kasir POS mitra.
                    </p>
                  </div>
                </div>

                {/* Search Bar Master Catalog */}
                <div className="relative">
                  <div className="flex items-center gap-2">
                    <div className="relative flex-1">
                      <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
                      <input
                        type="text"
                        value={catalogSearch}
                        onChange={(e) => setCatalogSearch(e.target.value)}
                        placeholder="Ketik nama produk atau scan barcode dari 30.000+ Master Produk..."
                        className="w-full pl-10 pr-10 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-[#0070fc] focus:ring-1 focus:ring-[#0070fc] transition-all font-medium"
                      />
                      {isSearchingCatalog ? (
                        <Loader2 className="w-4 h-4 animate-spin text-[#0070fc] absolute right-3.5 top-3" />
                      ) : catalogSearch ? (
                        <button
                          type="button"
                          onClick={() => {
                            setCatalogSearch('');
                            setSearchResults([]);
                          }}
                          className="absolute right-3.5 top-3 text-slate-400 hover:text-slate-600"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      ) : null}
                    </div>
                  </div>

                  {/* Dropdown Hasil Pencarian */}
                  {searchResults.length > 0 && (
                    <div className="absolute left-0 right-0 top-full mt-1.5 z-30 bg-white border border-slate-200 rounded-2xl shadow-xl max-h-60 overflow-y-auto divide-y divide-slate-100">
                      {searchResults.map((prod) => (
                        <div
                          key={prod.id}
                          onClick={() => handleAddProductFromCatalog(prod)}
                          className="p-3 hover:bg-blue-50/70 cursor-pointer flex items-center justify-between gap-3 transition-colors"
                        >
                          <div className="min-w-0">
                            <div className="font-bold text-xs text-slate-900 truncate">
                              {prod.name}
                            </div>
                            <div className="flex items-center gap-2 mt-1 text-[10px] text-slate-500 font-mono">
                              {prod.barcode && (
                                <span className="bg-slate-100 px-1.5 py-0.5 rounded text-slate-600">
                                  {prod.barcode}
                                </span>
                              )}
                              <span className="bg-blue-50 text-blue-700 px-1.5 py-0.5 rounded font-sans font-semibold">
                                {prod.category || 'Sembako'}
                              </span>
                              <span>Satuan: {prod.unit || 'Pcs'}</span>
                            </div>
                          </div>
                          <div className="text-right flex-shrink-0">
                            <div className="text-xs font-mono font-bold text-[#0070fc]">
                              HET Rp {Number(prod.selling_price || 0).toLocaleString('id-ID')}
                            </div>
                            <div className="text-[10px] text-slate-400 font-mono">
                              Modal Rp {Number(prod.base_price || 0).toLocaleString('id-ID')}
                            </div>
                            <span className="text-[10px] font-bold text-emerald-600 hover:underline">
                              + Masukkan ke Paket
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Tabel Daftar Produk yang Dipilih */}
                {formProducts.length === 0 ? (
                  <div className="p-8 rounded-xl bg-slate-50 border border-dashed border-slate-300 text-center">
                    <Package className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                    <p className="text-xs font-bold text-slate-600">Belum ada produk master yang dimasukkan</p>
                    <p className="text-[11px] text-slate-400 mt-1 max-w-md mx-auto">
                      Ketik nama produk pada kolom pencarian di atas untuk memilih barang dari katalog nasional Syupeo.
                    </p>
                  </div>
                ) : (
                  <div className="border border-slate-200 rounded-xl overflow-hidden">
                    <div className="overflow-x-auto max-h-72 overflow-y-auto">
                      <table className="w-full text-left border-collapse text-xs">
                        <thead className="bg-slate-100/80 text-slate-600 text-[11px] font-bold sticky top-0 z-10">
                          <tr>
                            <th className="py-2.5 px-3">Produk & Barcode</th>
                            <th className="py-2.5 px-2 text-center w-28">Qty</th>
                            <th className="py-2.5 px-2 w-24">Satuan</th>
                            <th className="py-2.5 px-2 text-right">Modal/HPP</th>
                            <th className="py-2.5 px-2 text-right">Harga Jual</th>
                            <th className="py-2.5 px-2 text-right">Subtotal Jual</th>
                            <th className="py-2.5 px-2 text-center w-10"></th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100 font-medium">
                          {formProducts.map((p, idx) => {
                            const subtotal = (Number(p.quantity) || 1) * (Number(p.unit_selling_price) || 0);
                            return (
                              <tr key={idx} className="hover:bg-slate-50/70 transition-colors">
                                <td className="py-2 px-3">
                                  <div className="font-bold text-slate-900 leading-snug">
                                    {p.product_name}
                                  </div>
                                  <div className="flex items-center gap-1.5 mt-0.5 text-[10px] text-slate-500 font-mono">
                                    {p.barcode && <span>{p.barcode} • </span>}
                                    <span className="font-sans text-blue-600 font-semibold">{p.category || 'Sembako'}</span>
                                  </div>
                                </td>
                                <td className="py-2 px-2 text-center">
                                  <div className="flex items-center justify-center gap-1">
                                    <button
                                      type="button"
                                      onClick={() => handleUpdateProductQuantity(idx, -1)}
                                      className="w-6 h-6 rounded-md bg-slate-100 hover:bg-slate-200 text-slate-700 flex items-center justify-center font-bold"
                                    >
                                      -
                                    </button>
                                    <input
                                      type="number"
                                      min={1}
                                      value={p.quantity}
                                      onChange={(e) => handleSetProductQuantity(idx, Number(e.target.value))}
                                      className="w-10 py-1 text-center font-mono font-bold text-slate-900 bg-white border border-slate-200 rounded-md text-xs"
                                    />
                                    <button
                                      type="button"
                                      onClick={() => handleUpdateProductQuantity(idx, 1)}
                                      className="w-6 h-6 rounded-md bg-slate-100 hover:bg-slate-200 text-slate-700 flex items-center justify-center font-bold"
                                    >
                                      +
                                    </button>
                                  </div>
                                </td>
                                <td className="py-2 px-2">
                                  <input
                                    type="text"
                                    value={p.unit || 'Pcs'}
                                    onChange={(e) => handleUpdateProductField(idx, 'unit', e.target.value)}
                                    className="w-full py-1 px-2 font-semibold text-slate-700 bg-white border border-slate-200 rounded-md text-xs"
                                  />
                                </td>
                                <td className="py-2 px-2 text-right">
                                  <input
                                    type="number"
                                    value={p.unit_base_price || 0}
                                    onChange={(e) => handleUpdateProductField(idx, 'unit_base_price', Number(e.target.value))}
                                    className="w-20 py-1 px-2 font-mono text-right text-slate-600 bg-white border border-slate-200 rounded-md text-xs"
                                  />
                                </td>
                                <td className="py-2 px-2 text-right">
                                  <input
                                    type="number"
                                    value={p.unit_selling_price || 0}
                                    onChange={(e) => handleUpdateProductField(idx, 'unit_selling_price', Number(e.target.value))}
                                    className="w-20 py-1 px-2 font-mono text-right text-[#0070fc] font-bold bg-white border border-slate-200 rounded-md text-xs"
                                  />
                                </td>
                                <td className="py-2 px-2 text-right font-mono font-bold text-slate-900">
                                  Rp {subtotal.toLocaleString('id-ID')}
                                </td>
                                <td className="py-2 px-2 text-center">
                                  <button
                                    type="button"
                                    onClick={() => handleRemoveProduct(idx)}
                                    className="p-1.5 text-slate-400 hover:text-rose-600 rounded-md hover:bg-rose-50 transition-colors"
                                    title="Hapus barang dari paket"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}

                {/* Live Financial Valuation Card */}
                {formProducts.length > 0 && (() => {
                  const totalQty = formProducts.reduce((sum, p) => sum + (Number(p.quantity) || 0), 0);
                  const totalHpp = formProducts.reduce(
                    (sum, p) => sum + (Number(p.unit_base_price) || 0) * (Number(p.quantity) || 0),
                    0
                  );
                  const totalRetail = formProducts.reduce(
                    (sum, p) => sum + (Number(p.unit_selling_price) || 0) * (Number(p.quantity) || 0),
                    0
                  );
                  const profit = totalRetail - formPrice;
                  const profitPct = totalRetail > 0 ? ((profit / totalRetail) * 100).toFixed(1) : '0';

                  return (
                    <div className="p-4 rounded-2xl bg-gradient-to-r from-blue-50/70 to-indigo-50/60 border border-blue-200/80">
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                          <Calculator className="w-4 h-4 text-[#0070fc]" />
                          <span className="text-xs font-extrabold text-slate-900 uppercase tracking-wider">
                            Kalkulator Valuasi & Potensi Laba Mitra
                          </span>
                        </div>
                        <span className="text-[11px] font-bold text-[#0070fc] bg-white px-2.5 py-0.5 rounded-full border border-blue-200">
                          {totalQty} Total Fisik Barang
                        </span>
                      </div>

                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                        <div className="p-2.5 bg-white/90 rounded-xl border border-blue-100">
                          <span className="text-[10px] text-slate-500 font-semibold block">Total HPP Gudang</span>
                          <span className="text-xs font-mono font-bold text-slate-700">
                            Rp {totalHpp.toLocaleString('id-ID')}
                          </span>
                        </div>
                        <div className="p-2.5 bg-white/90 rounded-xl border border-blue-100">
                          <span className="text-[10px] text-slate-500 font-semibold block">Total Nilai Retail</span>
                          <span className="text-xs font-mono font-bold text-[#0070fc]">
                            Rp {totalRetail.toLocaleString('id-ID')}
                          </span>
                        </div>
                        <div className="p-2.5 bg-white/90 rounded-xl border border-blue-100">
                          <span className="text-[10px] text-slate-500 font-semibold block">Harga Modal Paket</span>
                          <span className="text-xs font-mono font-bold text-slate-900">
                            Rp {Number(formPrice).toLocaleString('id-ID')}
                          </span>
                        </div>
                        <div className="p-2.5 bg-emerald-50 rounded-xl border border-emerald-200">
                          <span className="text-[10px] text-emerald-800 font-semibold block">Potensi Laba Mitra</span>
                          <span className="text-xs font-mono font-black text-emerald-700">
                            +Rp {profit.toLocaleString('id-ID')} ({profitPct}%)
                          </span>
                        </div>
                      </div>
                    </div>
                  );
                })()}
              </div>

              {/* 3. LAYANAN & FASILITAS EKOSISTEM (JASA BISNIS — BUKAN HARDWARE) */}
              <div className="p-4 sm:p-5 rounded-2xl bg-white border border-slate-200 space-y-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-slate-100">
                  <div>
                    <h3 className="text-sm font-extrabold text-slate-900 flex items-center gap-2">
                      <Sparkles className="w-4 h-4 text-amber-500" />
                      <span>Layanan & Fasilitas Bisnis (Jasa Ekosistem)</span>
                    </h3>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      Dukungan sistem kasir, web toko, dan jaminan restok gratis selamanya yang didapatkan mitra.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={handleAddItemRow}
                    className="text-xs font-bold text-[#0070fc] hover:underline flex items-center gap-1 self-start sm:self-auto"
                  >
                    + Tambah Fasilitas
                  </button>
                </div>

                {/* Preset Chips */}
                <div>
                  <label className="block text-[11px] font-bold text-slate-500 mb-1.5">
                    Klik Cepat Template Fasilitas Resmi Syupeo:
                  </label>
                  <div className="flex flex-wrap gap-1.5">
                    {SERVICE_PRESETS.map((preset, pIdx) => {
                      const isAdded = formItems.includes(preset);
                      return (
                        <button
                          key={pIdx}
                          type="button"
                          onClick={() => handleAddServicePreset(preset)}
                          disabled={isAdded}
                          className={`text-[11px] font-semibold px-2.5 py-1 rounded-lg border transition-all ${
                            isAdded
                              ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed'
                              : 'bg-slate-50 hover:bg-[#eff6ff] text-slate-700 hover:text-[#0070fc] border-slate-200 hover:border-[#bfdbfe]'
                          }`}
                        >
                          {isAdded ? '✓ ' : '+ '}
                          {preset}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Editable List of Service Items */}
                <div className="space-y-2 pt-1">
                  {formItems.map((item, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <div className="w-6 h-6 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0 text-xs font-bold">
                        ✓
                      </div>
                      <input
                        type="text"
                        value={item}
                        onChange={(e) => handleItemChange(idx, e.target.value)}
                        placeholder={`Deskripsi fasilitas jasa #${idx + 1}`}
                        className="flex-1 px-3 py-2 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 outline-none focus:bg-white focus:border-[#0070fc] transition-all font-medium"
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

              {/* 4. PENGATURAN STATUS & TAMPILAN */}
              <div className="flex flex-wrap items-center gap-6 pt-2">
                <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={formIsPopular}
                    onChange={(e) => setFormIsPopular(e.target.checked)}
                    className="w-4 h-4 rounded text-[#0070fc] focus:ring-[#0070fc] border-slate-300"
                  />
                  <span>Tandai sebagai Best Seller</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={formIsActive}
                    onChange={(e) => setFormIsActive(e.target.checked)}
                    className="w-4 h-4 rounded text-[#0070fc] focus:ring-[#0070fc] border-slate-300"
                  />
                  <span>Paket Aktif & Tampil</span>
                </label>
              </div>

              {/* 5. FOOTER ACTIONS */}
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
                  className="px-6 py-2.5 rounded-xl bg-[#0070fc] hover:bg-[#005ecc] text-white font-extrabold text-xs shadow-md shadow-[#0070fc]/20 active:scale-95 transition-all disabled:opacity-50 flex items-center gap-2"
                >
                  {isSaving && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{isSaving ? 'Menyimpan...' : 'Simpan Perubahan'}</span>
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
