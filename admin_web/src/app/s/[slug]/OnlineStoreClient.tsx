'use client';

import React, { useState, useMemo } from 'react';
import {
  Search,
  ShoppingCart,
  Phone,
  MapPin,
  Clock,
  Plus,
  Minus,
  Check,
  X,
  Share2,
  ChevronRight,
  Store,
  ArrowLeft,
  MessageCircle,
  PackageCheck,
  AlertCircle,
  Sparkles,
} from 'lucide-react';

interface PublicStore {
  id: string;
  name: string;
  slug: string;
  phone?: string | null;
  address?: string | null;
  logo_url?: string | null;
  banner_url?: string | null;
  business_type?: string | null;
  district?: string | null;
  regency?: string | null;
  province?: string | null;
}

interface MenuItem {
  id: string;
  name: string;
  price: number;
  description?: string | null;
  image_url?: string | null;
  is_available: boolean;
  category_id?: string | null;
  barcode?: string | null;
}

interface Category {
  id: string;
  name: string;
  sort_order?: number;
}

interface CartItem {
  item: MenuItem;
  quantity: number;
  notes?: string;
}

interface Props {
  store: PublicStore;
  items: MenuItem[];
  categories: Category[];
}

export default function OnlineStoreClient({ store, items, categories }: Props) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('ALL');
  const [cart, setCart] = useState<Record<string, CartItem>>({});
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);

  // Order Details Form
  const [orderType, setOrderType] = useState<'takeaway' | 'delivery' | 'dine_in'>('takeaway');
  const [customerName, setCustomerName] = useState('');
  const [customerPhone, setCustomerPhone] = useState('');
  const [customerAddress, setCustomerAddress] = useState('');
  const [tableNumber, setTableNumber] = useState('');
  const [orderNotes, setOrderNotes] = useState('');

  // Currency Formatter
  const formatRupiah = (amount: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  // Filter items based on category and search query
  const filteredItems = useMemo(() => {
    return items.filter((item) => {
      const matchCat =
        selectedCategoryId === 'ALL' || item.category_id === selectedCategoryId;
      const matchSearch =
        !searchQuery ||
        item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (item.description &&
          item.description.toLowerCase().includes(searchQuery.toLowerCase()));
      return matchCat && matchSearch;
    });
  }, [items, selectedCategoryId, searchQuery]);

  // Cart calculations
  const totalItemsCount = useMemo(() => {
    return Object.values(cart).reduce((sum, item) => sum + item.quantity, 0);
  }, [cart]);

  const totalCartPrice = useMemo(() => {
    return Object.values(cart).reduce(
      (sum, item) => sum + item.item.price * item.quantity,
      0
    );
  }, [cart]);

  const addToCart = (item: MenuItem) => {
    setCart((prev) => {
      const current = prev[item.id];
      const newQty = (current ? current.quantity : 0) + 1;
      return {
        ...prev,
        [item.id]: {
          item,
          quantity: newQty,
          notes: current?.notes || '',
        },
      };
    });
  };

  const removeFromCart = (itemId: string) => {
    setCart((prev) => {
      const current = prev[itemId];
      if (!current) return prev;
      if (current.quantity <= 1) {
        const copy = { ...prev };
        delete copy[itemId];
        return copy;
      }
      return {
        ...prev,
        [itemId]: {
          ...current,
          quantity: current.quantity - 1,
        },
      };
    });
  };

  const shareStore = () => {
    if (typeof window !== 'undefined') {
      const url = window.location.href;
      if (navigator.share) {
        navigator.share({
          title: `Toko Online ${store.name}`,
          text: `Belanja dan pesan langsung di ${store.name}:`,
          url,
        }).catch(() => {});
      } else {
        navigator.clipboard.writeText(url);
        setCopiedLink(true);
        setTimeout(() => setCopiedLink(false), 2000);
      }
    }
  };

  // Generate WhatsApp Order Message
  const handleCheckoutWhatsApp = () => {
    if (!customerName.trim()) {
      alert('Mohon isi nama pemesan terlebih dahulu.');
      return;
    }

    if (totalItemsCount === 0) {
      alert('Keranjang belanja Anda masih kosong.');
      return;
    }

    const orderTypeLabel =
      orderType === 'delivery'
        ? '🛵 Pengiriman ke Alamat (Delivery)'
        : orderType === 'dine_in'
        ? `🍽️ Makan di Tempat (Meja: ${tableNumber || '-'})`
        : '🏪 Ambil di Toko (Pickup / Takeaway)';

    let message = `*PESANAN BARU DARI TOKO ONLINE SYUPEO*\n`;
    message += `───────────────────────\n`;
    message += `*Nama Pemesan:* ${customerName.trim()}\n`;
    if (customerPhone.trim()) {
      message += `*No. WhatsApp:* ${customerPhone.trim()}\n`;
    }
    message += `*Tipe Pesanan:* ${orderTypeLabel}\n`;

    if (orderType === 'delivery' && customerAddress.trim()) {
      message += `*Alamat Pengiriman:* ${customerAddress.trim()}\n`;
    }

    if (orderNotes.trim()) {
      message += `*Catatan Khusus:* ${orderNotes.trim()}\n`;
    }

    message += `───────────────────────\n`;
    message += `*RINCIAN ITEM PESANAN:*\n`;

    Object.values(cart).forEach((c, idx) => {
      const subtotal = c.item.price * c.quantity;
      message += `${idx + 1}. *${c.item.name}* x${c.quantity} = ${formatRupiah(subtotal)}\n`;
    });

    message += `───────────────────────\n`;
    message += `*TOTAL PEMBAYARAN: ${formatRupiah(totalCartPrice)}*\n`;
    message += `───────────────────────\n`;
    message += `_Mohon konfirmasi ketersediaan pesanan dan nomor rekening / instruksi pembayaran. Terima kasih!_`;

    // Normalisasi nomor telepon toko
    let rawPhone = (store.phone || '').replace(/[^0-9]/g, '');
    if (rawPhone.startsWith('0')) {
      rawPhone = '62' + rawPhone.substring(1);
    } else if (!rawPhone.startsWith('62')) {
      rawPhone = '62' + rawPhone;
    }

    const waUrl = `https://wa.me/${rawPhone}?text=${encodeURIComponent(message)}`;
    window.open(waUrl, '_blank');
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 font-sans pb-28">
      {/* ── Top App Bar / Header Toko ────────────────────────────────────────── */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-xs">
        <div className="max-w-3xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {store.logo_url ? (
              <img
                src={store.logo_url}
                alt={store.name}
                className="w-10 h-10 rounded-xl object-cover border border-slate-200 shadow-2xs"
              />
            ) : (
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-[#005ecc] to-[#0070fc] flex items-center justify-center text-white font-bold shadow-2xs">
                <Store className="w-5 h-5 text-white" />
              </div>
            )}
            <div>
              <div className="flex items-center gap-1.5">
                <h1 className="font-black text-slate-900 text-base leading-tight truncate max-w-[200px] sm:max-w-md">
                  {store.name}
                </h1>
                <span className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[10px] font-black bg-blue-50 text-[#0070fc] border border-blue-200">
                  <Sparkles className="w-2.5 h-2.5" /> Mitra Syupeo
                </span>
              </div>
              <p className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5">
                <MapPin className="w-3 h-3 text-slate-400" />
                {store.district ? `${store.district}, ` : ''}
                {store.regency || store.address || 'Indonesia'}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={shareStore}
              className="p-2 rounded-xl border border-slate-200 hover:bg-slate-100 text-slate-600 transition-colors shadow-2xs"
              title="Bagikan Tautan Toko"
            >
              <Share2 className="w-4 h-4" />
            </button>
            {copiedLink && (
              <span className="absolute top-14 right-4 bg-slate-900 text-white text-[11px] font-semibold px-2.5 py-1 rounded-lg shadow-lg">
                Link tersalin!
              </span>
            )}
          </div>
        </div>
      </header>

      {/* ── Main Container ─────────────────────────────────────────────────── */}
      <main className="max-w-3xl mx-auto px-4 pt-4 space-y-4">
        {/* Banner Toko / Hero Mini */}
        <div className="rounded-2xl bg-gradient-to-r from-[#005ecc] via-[#0070fc] to-[#2563eb] p-5 text-white shadow-md relative overflow-hidden">
          <div className="relative z-10 space-y-1">
            <span className="inline-block px-2 py-0.5 rounded-md bg-white/20 backdrop-blur-xs text-[10px] font-black tracking-wider uppercase">
              Katalog Toko Online
            </span>
            <h2 className="text-xl sm:text-2xl font-black tracking-tight">
              Selamat Datang di {store.name}
            </h2>
            <p className="text-xs text-blue-100 max-w-md leading-relaxed">
              Pilih produk kebutuhan Anda, masukkan ke keranjang, dan kirim pesanan langsung via WhatsApp dengan cepat & mudah.
            </p>
            {store.phone && (
              <div className="pt-2 flex items-center gap-2 text-xs font-semibold text-white/90">
                <Phone className="w-3.5 h-3.5" /> WhatsApp Toko: {store.phone}
              </div>
            )}
          </div>
          {/* Subtle Decorative Circle */}
          <div className="absolute -bottom-10 -right-10 w-36 h-36 rounded-full bg-white/10 pointer-events-none" />
        </div>

        {/* Search Bar */}
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Cari produk, sembako, makanan, minuman..."
            className="w-full pl-10 pr-4 py-2.5 text-xs sm:text-sm bg-white border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-[#0070fc] shadow-2xs placeholder:text-slate-400"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Category Pills (Horizontal Scroll) */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar -mx-4 px-4">
          <button
            onClick={() => setSelectedCategoryId('ALL')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all shadow-2xs ${
              selectedCategoryId === 'ALL'
                ? 'bg-[#0070fc] text-white shadow-blue-500/20'
                : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-100'
            }`}
          >
            Semua Menu ({items.length})
          </button>
          {categories.map((cat) => {
            const count = items.filter((i) => i.category_id === cat.id).length;
            if (count === 0) return null;
            const isSelected = selectedCategoryId === cat.id;
            return (
              <button
                key={cat.id}
                onClick={() => setSelectedCategoryId(cat.id)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all shadow-2xs ${
                  isSelected
                    ? 'bg-[#0070fc] text-white shadow-blue-500/20'
                    : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-100'
                }`}
              >
                {cat.name} ({count})
              </button>
            );
          })}
        </div>

        {/* Product List Grid */}
        {filteredItems.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-8 text-center space-y-3 shadow-2xs">
            <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto">
              <Search className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-slate-800 text-sm">
              Tidak ada produk yang cocok
            </h3>
            <p className="text-xs text-slate-500 max-w-xs mx-auto">
              Coba gunakan kata kunci pencarian lain atau pilih kategori Semua Menu.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {filteredItems.map((item) => {
              const inCart = cart[item.id];
              return (
                <div
                  key={item.id}
                  className="bg-white rounded-2xl border border-slate-200/90 overflow-hidden shadow-2xs hover:shadow-md transition-all flex flex-col justify-between"
                >
                  {/* Image / Thumbnail */}
                  <div className="relative aspect-square w-full bg-slate-100 overflow-hidden">
                    {item.image_url ? (
                      <img
                        src={item.image_url}
                        alt={item.name}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                        loading="lazy"
                      />
                    ) : (
                      <div className="w-full h-full flex flex-col items-center justify-center bg-gradient-to-b from-slate-50 to-slate-100 text-slate-400">
                        <Store className="w-8 h-8 stroke-1 text-slate-300 mb-1" />
                        <span className="text-[10px] font-semibold text-slate-400">
                          {store.name}
                        </span>
                      </div>
                    )}
                    {inCart && (
                      <span className="absolute top-2 right-2 bg-[#0070fc] text-white text-[10px] font-black w-6 h-6 rounded-full flex items-center justify-center shadow-md">
                        {inCart.quantity}
                      </span>
                    )}
                  </div>

                  {/* Info */}
                  <div className="p-3 flex-1 flex flex-col justify-between">
                    <div>
                      <h4 className="font-bold text-slate-900 text-xs sm:text-sm line-clamp-2 leading-snug">
                        {item.name}
                      </h4>
                      {item.description && (
                        <p className="text-[11px] text-slate-500 line-clamp-1 mt-0.5">
                          {item.description}
                        </p>
                      )}
                    </div>

                    <div className="mt-2.5 pt-2 border-t border-slate-100 flex items-center justify-between gap-1">
                      <span className="font-black text-xs sm:text-sm text-slate-900">
                        {formatRupiah(item.price)}
                      </span>

                      {/* Add to Cart Stepper / Button */}
                      {inCart ? (
                        <div className="flex items-center gap-1.5 bg-blue-50 border border-blue-200 rounded-lg p-0.5">
                          <button
                            onClick={() => removeFromCart(item.id)}
                            className="w-5 h-5 rounded-md bg-white flex items-center justify-center text-[#0070fc] hover:bg-blue-100 transition-colors"
                          >
                            <Minus className="w-3 h-3" />
                          </button>
                          <span className="text-xs font-bold text-[#0070fc] min-w-[12px] text-center">
                            {inCart.quantity}
                          </span>
                          <button
                            onClick={() => addToCart(item)}
                            className="w-5 h-5 rounded-md bg-[#0070fc] flex items-center justify-center text-white hover:bg-[#005ecc] transition-colors"
                          >
                            <Plus className="w-3 h-3" />
                          </button>
                        </div>
                      ) : (
                        <button
                          onClick={() => addToCart(item)}
                          className="px-2.5 py-1 text-xs font-bold rounded-lg bg-[#0070fc] hover:bg-[#005ecc] text-white flex items-center gap-1 transition-colors shadow-xs"
                        >
                          <Plus className="w-3 h-3" />
                          <span>Pesan</span>
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* ── Syupeo Platform Badge Footer ──────────────────────────────────── */}
        <footer className="pt-8 text-center space-y-2">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-slate-200 text-xs text-slate-600 shadow-2xs">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Katalog Toko Online Resmi & Terverifikasi</span>
          </div>
          <p className="text-[11px] text-slate-400">
            Ditenagai oleh{' '}
            <a
              href="https://syupeo.mudahkan.online"
              target="_blank"
              rel="noreferrer"
              className="text-[#0070fc] font-bold hover:underline"
            >
              Syupeo POS
            </a>{' '}
            • Ekosistem Closed-Loop Supply Chain & Toko Ritel Modern
          </p>
        </footer>
      </main>

      {/* ── Sticky Bottom Floating Cart Bar ─────────────────────────────────── */}
      {totalItemsCount > 0 && (
        <aside
          aria-label="Keranjang Belanja"
          className="fixed bottom-3 inset-x-0 z-40 px-4 pointer-events-none"
        >
          <div className="max-w-md mx-auto pointer-events-auto">
            <button
              onClick={() => setIsCartOpen(true)}
              className="w-full bg-gradient-to-r from-slate-900 via-[#005ecc] to-[#0070fc] text-white p-3.5 rounded-2xl shadow-xl flex items-center justify-between hover:scale-[1.01] transition-transform cursor-pointer border border-white/20"
            >
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-white/20 backdrop-blur-xs flex items-center justify-center font-black text-sm">
                  <ShoppingCart className="w-4 h-4 text-white" />
                </div>
                <div className="text-left">
                  <p className="text-[11px] font-bold text-blue-100">
                    {totalItemsCount} Barang di Keranjang
                  </p>
                  <p className="text-sm font-black text-white">
                    {formatRupiah(totalCartPrice)}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-1.5 text-xs font-black bg-white text-[#0070fc] px-3.5 py-1.5 rounded-xl shadow-xs">
                <span>Lihat Pesanan</span>
                <ChevronRight className="w-4 h-4" />
              </div>
            </button>
          </div>
        </aside>
      )}

      {/* ── Cart Drawer / Checkout Modal ────────────────────────────────────── */}
      {isCartOpen && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
          <div className="bg-white w-full max-w-lg rounded-t-3xl sm:rounded-3xl max-h-[90vh] flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom-6 duration-200">
            {/* Modal Header */}
            <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
              <div className="flex items-center gap-2">
                <ShoppingCart className="w-5 h-5 text-[#0070fc]" />
                <h3 className="font-black text-slate-900 text-base">
                  Keranjang Pesanan ({totalItemsCount})
                </h3>
              </div>
              <button
                onClick={() => setIsCartOpen(false)}
                className="w-8 h-8 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-slate-800"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body (Scrollable) */}
            <div className="p-4 overflow-y-auto space-y-5 flex-1 text-xs">
              {/* Order Items List */}
              <div className="space-y-2.5">
                <span className="font-bold text-slate-500 uppercase tracking-wider text-[10px] block">
                  Daftar Barang
                </span>
                {Object.values(cart).map((c) => (
                  <div
                    key={c.item.id}
                    className="p-3 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between gap-3"
                  >
                    <div className="flex-1">
                      <p className="font-bold text-slate-900 text-xs">
                        {c.item.name}
                      </p>
                      <p className="text-slate-500 text-[11px] font-semibold mt-0.5">
                        {formatRupiah(c.item.price)}
                      </p>
                    </div>

                    <div className="flex items-center gap-2">
                      <div className="flex items-center gap-1.5 bg-white border border-slate-200 rounded-lg p-0.5">
                        <button
                          onClick={() => removeFromCart(c.item.id)}
                          className="w-6 h-6 rounded-md bg-slate-100 flex items-center justify-center text-slate-700 hover:bg-slate-200"
                        >
                          <Minus className="w-3 h-3" />
                        </button>
                        <span className="text-xs font-bold text-slate-900 min-w-[16px] text-center">
                          {c.quantity}
                        </span>
                        <button
                          onClick={() => addToCart(c.item)}
                          className="w-6 h-6 rounded-md bg-[#0070fc] flex items-center justify-center text-white hover:bg-[#005ecc]"
                        >
                          <Plus className="w-3 h-3" />
                        </button>
                      </div>

                      <span className="font-bold text-slate-900 min-w-[65px] text-right">
                        {formatRupiah(c.item.price * c.quantity)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Order Type Tabs */}
              <div className="space-y-1.5">
                <span className="font-bold text-slate-500 uppercase tracking-wider text-[10px] block">
                  Metode Penerimaan Pesanan
                </span>
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setOrderType('takeaway')}
                    className={`py-2 px-1 text-center rounded-xl border text-xs font-bold transition-all ${
                      orderType === 'takeaway'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc]'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    🏪 Ambil Toko
                  </button>
                  <button
                    type="button"
                    onClick={() => setOrderType('delivery')}
                    className={`py-2 px-1 text-center rounded-xl border text-xs font-bold transition-all ${
                      orderType === 'delivery'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc]'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    🛵 Kirim Alamat
                  </button>
                  <button
                    type="button"
                    onClick={() => setOrderType('dine_in')}
                    className={`py-2 px-1 text-center rounded-xl border text-xs font-bold transition-all ${
                      orderType === 'dine_in'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc]'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    🍽️ Di Tempat
                  </button>
                </div>
              </div>

              {/* Customer Info Form */}
              <div className="space-y-3 bg-slate-50 p-3.5 rounded-2xl border border-slate-200">
                <span className="font-bold text-slate-700 text-xs block">
                  Informasi Pemesan
                </span>

                <div>
                  <label className="text-[11px] font-semibold text-slate-600 block mb-1">
                    Nama Pemesan <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={customerName}
                    onChange={(e) => setCustomerName(e.target.value)}
                    placeholder="Contoh: Budi Santoso"
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-[#0070fc] focus:outline-hidden"
                  />
                </div>

                <div>
                  <label className="text-[11px] font-semibold text-slate-600 block mb-1">
                    Nomor WhatsApp Pemesan (Opsional)
                  </label>
                  <input
                    type="tel"
                    value={customerPhone}
                    onChange={(e) => setCustomerPhone(e.target.value)}
                    placeholder="Contoh: 081234567890"
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-[#0070fc] focus:outline-hidden"
                  />
                </div>

                {orderType === 'delivery' && (
                  <div>
                    <label className="text-[11px] font-semibold text-slate-600 block mb-1">
                      Alamat Pengiriman Lengkap <span className="text-red-500">*</span>
                    </label>
                    <textarea
                      value={customerAddress}
                      onChange={(e) => setCustomerAddress(e.target.value)}
                      placeholder="Nama jalan, nomor rumah, RT/RW, patokan..."
                      rows={2}
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-[#0070fc] focus:outline-hidden resize-none"
                    />
                  </div>
                )}

                {orderType === 'dine_in' && (
                  <div>
                    <label className="text-[11px] font-semibold text-slate-600 block mb-1">
                      Nomor Meja
                    </label>
                    <input
                      type="text"
                      value={tableNumber}
                      onChange={(e) => setTableNumber(e.target.value)}
                      placeholder="Contoh: Meja 05"
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-[#0070fc] focus:outline-hidden"
                    />
                  </div>
                )}

                <div>
                  <label className="text-[11px] font-semibold text-slate-600 block mb-1">
                    Catatan Pesanan (Opsional)
                  </label>
                  <input
                    type="text"
                    value={orderNotes}
                    onChange={(e) => setOrderNotes(e.target.value)}
                    placeholder="Contoh: Jangan terlalu pedas, bungkus terpisah..."
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-[#0070fc] focus:outline-hidden"
                  />
                </div>
              </div>
            </div>

            {/* Modal Footer / WhatsApp Action */}
            <div className="p-4 border-t border-slate-200 bg-white space-y-3">
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-500 font-semibold">Total Tagihan</span>
                <span className="font-black text-base text-slate-900">
                  {formatRupiah(totalCartPrice)}
                </span>
              </div>

              <button
                type="button"
                onClick={handleCheckoutWhatsApp}
                className="w-full bg-[#25D366] hover:bg-[#20bd5a] text-white py-3 px-4 rounded-xl font-bold flex items-center justify-center gap-2 shadow-md shadow-emerald-500/20 text-xs transition-all active:scale-[0.99] cursor-pointer"
              >
                <MessageCircle className="w-4 h-4 fill-white" />
                <span>Kirim Pesanan ke WhatsApp Toko</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

