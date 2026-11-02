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
  Layers,
  CheckCircle2,
} from 'lucide-react';

export interface MenuItemVariant {
  id: string;
  menu_item_id: string;
  name: string;
  price: number;
  stock_available?: boolean;
  unit_ratio?: number | null;
}

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

export interface MenuItem {
  id: string;
  name: string;
  price: number;
  description?: string | null;
  image_url?: string | null;
  is_active?: boolean;
  stock_available?: boolean;
  unit?: string | null;
  category_id?: string | null;
  barcode?: string | null;
  variants?: MenuItemVariant[];
}

interface Category {
  id: string;
  name: string;
  sort_order?: number;
}

export interface CartItem {
  cartKey: string;
  item: MenuItem;
  variant?: MenuItemVariant | null;
  unitPrice: number;
  displayName: string;
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

  // Variant Modal State
  const [variantModalItem, setVariantModalItem] = useState<MenuItem | null>(null);
  const [selectedVariantId, setSelectedVariantId] = useState<string>('base'); // 'base' or variant.id
  const [modalQty, setModalQty] = useState<number>(1);
  const [modalNotes, setModalNotes] = useState<string>('');

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
      (sum, item) => sum + item.unitPrice * item.quantity,
      0
    );
  }, [cart]);

  // Count items of a specific product in cart (including across variants)
  const getItemCartCount = (itemId: string) => {
    return Object.values(cart)
      .filter((c) => c.item.id === itemId)
      .reduce((sum, c) => sum + c.quantity, 0);
  };

  // Add standard item (without variant selection modal)
  const addSimpleItemToCart = (item: MenuItem) => {
    const cartKey = `${item.id}_base`;
    setCart((prev) => {
      const current = prev[cartKey];
      const newQty = (current ? current.quantity : 0) + 1;
      return {
        ...prev,
        [cartKey]: {
          cartKey,
          item,
          variant: null,
          unitPrice: item.price,
          displayName: item.name,
          quantity: newQty,
          notes: current?.notes || '',
        },
      };
    });
  };

  // Remove standard item
  const removeSimpleItemFromCart = (itemId: string) => {
    const cartKey = `${itemId}_base`;
    setCart((prev) => {
      const current = prev[cartKey];
      if (!current) return prev;
      if (current.quantity <= 1) {
        const copy = { ...prev };
        delete copy[cartKey];
        return copy;
      }
      return {
        ...prev,
        [cartKey]: {
          ...current,
          quantity: current.quantity - 1,
        },
      };
    });
  };

  // Open Variant Modal
  const openVariantModal = (item: MenuItem) => {
    setVariantModalItem(item);
    setSelectedVariantId('base');
    setModalQty(1);
    setModalNotes('');
  };

  // Confirm Variant Selection
  const confirmVariantAddToCart = () => {
    if (!variantModalItem) return;

    let variant: MenuItemVariant | null = null;
    let unitPrice = variantModalItem.price;
    let displayName = variantModalItem.name;

    if (selectedVariantId !== 'base') {
      const found = variantModalItem.variants?.find((v) => v.id === selectedVariantId);
      if (found) {
        variant = found;
        unitPrice = found.price;
        displayName = `${variantModalItem.name} (${found.name})`;
      }
    }

    const cartKey = variant
      ? `${variantModalItem.id}_${variant.id}`
      : `${variantModalItem.id}_base`;

    setCart((prev) => {
      const current = prev[cartKey];
      const newQty = (current ? current.quantity : 0) + modalQty;
      return {
        ...prev,
        [cartKey]: {
          cartKey,
          item: variantModalItem,
          variant,
          unitPrice,
          displayName,
          quantity: newQty,
          notes: modalNotes.trim() || current?.notes || '',
        },
      };
    });

    setVariantModalItem(null);
  };

  // Update cart quantity in Cart Drawer
  const updateCartItemQty = (cartKey: string, delta: number) => {
    setCart((prev) => {
      const current = prev[cartKey];
      if (!current) return prev;
      const nextQty = current.quantity + delta;
      if (nextQty <= 0) {
        const copy = { ...prev };
        delete copy[cartKey];
        return copy;
      }
      return {
        ...prev,
        [cartKey]: {
          ...current,
          quantity: nextQty,
        },
      };
    });
  };

  // Price Display Helper
  const getItemPriceDisplay = (item: MenuItem) => {
    if (!item.variants || item.variants.length === 0) {
      return formatRupiah(item.price);
    }
    const allPrices = [item.price, ...item.variants.map((v) => v.price)];
    const minPrice = Math.min(...allPrices);
    const maxPrice = Math.max(...allPrices);
    if (minPrice === maxPrice) {
      return formatRupiah(minPrice);
    }
    return `Mulai ${formatRupiah(minPrice)}`;
  };

  const shareStore = () => {
    if (typeof window !== 'undefined') {
      const url = window.location.href;
      if (navigator.share) {
        navigator.share({
          title: `Toko Online ${store.name}`,
          text: `Belanja dan pesan langsung di ${store.name}:`,
          url: url,
        });
      } else {
        navigator.clipboard.writeText(url);
        setCopiedLink(true);
        setTimeout(() => setCopiedLink(false), 2500);
      }
    }
  };

  // WhatsApp Checkout Handler
  const handleCheckoutViaWhatsApp = () => {
    if (totalItemsCount === 0) return;

    if (!customerName.trim()) {
      alert('Mohon isi nama lengkap Anda.');
      return;
    }

    if (orderType === 'dine_in' && !tableNumber.trim()) {
      alert('Mohon masukkan nomor meja Anda.');
      return;
    }

    if (orderType === 'delivery' && !customerAddress.trim()) {
      alert('Mohon isi alamat lengkap pengiriman pesanan.');
      return;
    }

    // Format WhatsApp Message
    const orderTypeLabel =
      orderType === 'takeaway'
        ? 'Ambil Sendiri di Toko (Takeaway)'
        : orderType === 'delivery'
        ? 'Kirim ke Alamat (Delivery)'
        : `Makan di Tempat / Meja ${tableNumber.trim()}`;

    let message = `*HALO ${store.name.toUpperCase()}*\n`;
    message += `Saya ingin memesan via Toko Online Syupeo:\n\n`;
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
      const subtotal = c.unitPrice * c.quantity;
      const noteStr = c.notes ? ` _(Catatan: ${c.notes})_` : '';
      message += `${idx + 1}. *${c.displayName}* x${c.quantity} = ${formatRupiah(subtotal)}${noteStr}\n`;
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
              <p className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5 truncate max-w-[220px] sm:max-w-md">
                <MapPin className="w-3 h-3 text-slate-400 shrink-0" />
                {store.address || 'Indonesia'}
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
              Pilih produk kebutuhan Anda, pilih varian/ukuran, masukkan ke keranjang, dan kirim pesanan langsung via WhatsApp.
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
              const hasVariants = Boolean(item.variants && item.variants.length > 0);
              const totalInCartForThisItem = getItemCartCount(item.id);
              const simpleCartItem = cart[`${item.id}_base`];

              return (
                <div
                  key={item.id}
                  className="bg-white rounded-2xl border border-slate-200/90 overflow-hidden shadow-2xs hover:shadow-md transition-all flex flex-col justify-between"
                >
                  {/* Image / Thumbnail */}
                  <div
                    onClick={() => hasVariants && openVariantModal(item)}
                    className={`relative aspect-square w-full bg-slate-100 overflow-hidden ${
                      hasVariants ? 'cursor-pointer' : ''
                    }`}
                  >
                    {item.image_url ? (
                      <img
                        src={item.image_url}
                        alt={item.name}
                        className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
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

                    {/* Cart Quantity Badge on Image */}
                    {totalInCartForThisItem > 0 && (
                      <span className="absolute top-2 right-2 bg-[#0070fc] text-white text-[10px] font-black w-6 h-6 rounded-full flex items-center justify-center shadow-md">
                        {totalInCartForThisItem}
                      </span>
                    )}

                    {/* Variant Badge on Image */}
                    {hasVariants && (
                      <span className="absolute bottom-2 left-2 inline-flex items-center gap-1 bg-slate-900/80 backdrop-blur-xs text-white text-[10px] font-bold px-2 py-0.5 rounded-md shadow-xs">
                        <Layers className="w-3 h-3 text-blue-300" />
                        {item.variants!.length} Varian
                      </span>
                    )}
                  </div>

                  {/* Info */}
                  <div className="p-3 flex-1 flex flex-col justify-between">
                    <div>
                      <h4
                        onClick={() => hasVariants && openVariantModal(item)}
                        className={`font-bold text-slate-900 text-xs sm:text-sm line-clamp-2 leading-snug ${
                          hasVariants ? 'cursor-pointer hover:text-[#0070fc]' : ''
                        }`}
                      >
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
                        {getItemPriceDisplay(item)}
                      </span>

                      {/* Action Button: Variant Modal vs Direct Stepper */}
                      {hasVariants ? (
                        <button
                          onClick={() => openVariantModal(item)}
                          className="px-2.5 py-1 text-xs font-bold rounded-lg bg-blue-50 text-[#0070fc] border border-blue-200 hover:bg-[#0070fc] hover:text-white flex items-center gap-1 transition-all shadow-2xs"
                        >
                          <Layers className="w-3 h-3" />
                          <span>Pilih</span>
                        </button>
                      ) : simpleCartItem ? (
                        <div className="flex items-center gap-1.5 bg-blue-50 border border-blue-200 rounded-lg p-0.5">
                          <button
                            onClick={() => removeSimpleItemFromCart(item.id)}
                            className="w-5 h-5 rounded-md bg-white flex items-center justify-center text-[#0070fc] hover:bg-blue-100 transition-colors"
                          >
                            <Minus className="w-3 h-3" />
                          </button>
                          <span className="text-xs font-bold text-[#0070fc] min-w-[12px] text-center">
                            {simpleCartItem.quantity}
                          </span>
                          <button
                            onClick={() => addSimpleItemToCart(item)}
                            className="w-5 h-5 rounded-md bg-[#0070fc] flex items-center justify-center text-white hover:bg-[#005ecc] transition-colors"
                          >
                            <Plus className="w-3 h-3" />
                          </button>
                        </div>
                      ) : (
                        <button
                          onClick={() => addSimpleItemToCart(item)}
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

      {/* ── Variant Selector Modal / Bottom Sheet ───────────────────────────── */}
      {variantModalItem && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
          <div className="bg-white w-full max-w-md rounded-t-3xl sm:rounded-3xl max-h-[90vh] flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom-6 duration-200">
            {/* Modal Header */}
            <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
              <div className="flex items-center gap-2">
                <Layers className="w-5 h-5 text-[#0070fc]" />
                <div>
                  <h3 className="font-black text-slate-900 text-sm sm:text-base leading-tight">
                    Pilih Varian Produk
                  </h3>
                  <p className="text-[11px] text-slate-500 mt-0.5">
                    {variantModalItem.name}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setVariantModalItem(null)}
                className="w-8 h-8 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-slate-800"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-4 overflow-y-auto space-y-4 flex-1 text-xs">
              {/* Product Info Bar */}
              <div className="p-3 rounded-2xl bg-slate-50 border border-slate-200 flex items-center gap-3">
                {variantModalItem.image_url ? (
                  <img
                    src={variantModalItem.image_url}
                    alt={variantModalItem.name}
                    className="w-14 h-14 rounded-xl object-cover border border-slate-200"
                  />
                ) : (
                  <div className="w-14 h-14 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center text-[#0070fc]">
                    <Store className="w-6 h-6" />
                  </div>
                )}
                <div>
                  <h4 className="font-bold text-slate-900 text-sm">
                    {variantModalItem.name}
                  </h4>
                  {variantModalItem.description && (
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      {variantModalItem.description}
                    </p>
                  )}
                </div>
              </div>

              {/* Options List */}
              <div className="space-y-2">
                <span className="font-bold text-slate-600 uppercase tracking-wider text-[10px] block">
                  Pilihan Varian / Ukuran
                </span>

                {/* Base Option */}
                <button
                  type="button"
                  onClick={() => setSelectedVariantId('base')}
                  className={`w-full p-3 rounded-xl border text-left flex items-center justify-between transition-all ${
                    selectedVariantId === 'base'
                      ? 'bg-blue-50/70 border-[#0070fc] ring-2 ring-[#0070fc]/20'
                      : 'bg-white border-slate-200 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center gap-2.5">
                    <div
                      className={`w-4 h-4 rounded-full border flex items-center justify-center ${
                        selectedVariantId === 'base'
                          ? 'border-[#0070fc] bg-[#0070fc]'
                          : 'border-slate-300 bg-white'
                      }`}
                    >
                      {selectedVariantId === 'base' && (
                        <div className="w-1.5 h-1.5 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <span className="font-bold text-slate-900 text-xs block">
                        {variantModalItem.unit
                          ? `Ukuran Standar (${variantModalItem.unit})`
                          : 'Pilihan Standar / Reguler'}
                      </span>
                    </div>
                  </div>
                  <span className="font-black text-slate-900 text-xs">
                    {formatRupiah(variantModalItem.price)}
                  </span>
                </button>

                {/* Additional Variants */}
                {variantModalItem.variants?.map((v) => {
                  const isSelected = selectedVariantId === v.id;
                  return (
                    <button
                      key={v.id}
                      type="button"
                      onClick={() => setSelectedVariantId(v.id)}
                      className={`w-full p-3 rounded-xl border text-left flex items-center justify-between transition-all ${
                        isSelected
                          ? 'bg-blue-50/70 border-[#0070fc] ring-2 ring-[#0070fc]/20'
                          : 'bg-white border-slate-200 hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex items-center gap-2.5">
                        <div
                          className={`w-4 h-4 rounded-full border flex items-center justify-center ${
                            isSelected
                              ? 'border-[#0070fc] bg-[#0070fc]'
                              : 'border-slate-300 bg-white'
                          }`}
                        >
                          {isSelected && (
                            <div className="w-1.5 h-1.5 rounded-full bg-white" />
                          )}
                        </div>
                        <div>
                          <span className="font-bold text-slate-900 text-xs block">
                            {v.name}
                          </span>
                        </div>
                      </div>
                      <span className="font-black text-slate-900 text-xs">
                        {formatRupiah(v.price)}
                      </span>
                    </button>
                  );
                })}
              </div>

              {/* Quantity Stepper */}
              <div className="pt-2 flex items-center justify-between">
                <span className="font-bold text-slate-700 text-xs">
                  Jumlah Pesanan
                </span>
                <div className="flex items-center gap-2 bg-slate-100 border border-slate-200 rounded-xl p-1">
                  <button
                    onClick={() => setModalQty((prev) => Math.max(1, prev - 1))}
                    className="w-7 h-7 rounded-lg bg-white flex items-center justify-center text-slate-700 hover:bg-slate-200 shadow-2xs font-bold"
                  >
                    <Minus className="w-3.5 h-3.5" />
                  </button>
                  <span className="font-black text-slate-900 text-sm min-w-[24px] text-center">
                    {modalQty}
                  </span>
                  <button
                    onClick={() => setModalQty((prev) => prev + 1)}
                    className="w-7 h-7 rounded-lg bg-[#0070fc] flex items-center justify-center text-white hover:bg-[#005ecc] shadow-2xs font-bold"
                  >
                    <Plus className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* Notes Input */}
              <div>
                <label className="font-bold text-slate-700 text-[11px] block mb-1">
                  Catatan untuk Produk Ini (Opsional)
                </label>
                <input
                  type="text"
                  value={modalNotes}
                  onChange={(e) => setModalNotes(e.target.value)}
                  placeholder="Misal: bungkus plastik rapi, tanpa pedas..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                />
              </div>
            </div>

            {/* Modal Footer CTA */}
            <div className="p-4 border-t border-slate-100 bg-white">
              {(() => {
                let unitPrice = variantModalItem.price;
                if (selectedVariantId !== 'base') {
                  const f = variantModalItem.variants?.find((v) => v.id === selectedVariantId);
                  if (f) unitPrice = f.price;
                }
                const subtotal = unitPrice * modalQty;
                return (
                  <button
                    onClick={confirmVariantAddToCart}
                    className="w-full py-3 px-4 rounded-xl font-bold bg-[#0070fc] hover:bg-[#005ecc] text-white flex items-center justify-between transition-colors shadow-md text-xs sm:text-sm"
                  >
                    <span>Tambah ke Keranjang</span>
                    <span>{formatRupiah(subtotal)}</span>
                  </button>
                );
              })()}
            </div>
          </div>
        </div>
      )}

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
                    key={c.cartKey}
                    className="p-3 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between gap-3"
                  >
                    <div className="flex-1">
                      <p className="font-bold text-slate-900 text-xs">
                        {c.displayName}
                      </p>
                      {c.notes && (
                        <p className="text-[10px] text-amber-700 italic mt-0.5">
                          Catatan: {c.notes}
                        </p>
                      )}
                      <p className="text-slate-500 text-[11px] font-semibold mt-0.5">
                        {formatRupiah(c.unitPrice)}
                      </p>
                    </div>

                    <div className="flex items-center gap-2">
                      <div className="flex items-center gap-1.5 bg-white border border-slate-200 rounded-lg p-0.5">
                        <button
                          onClick={() => updateCartItemQty(c.cartKey, -1)}
                          className="w-6 h-6 rounded-md bg-slate-100 flex items-center justify-center text-slate-700 hover:bg-slate-200"
                        >
                          <Minus className="w-3 h-3" />
                        </button>
                        <span className="text-xs font-bold text-slate-900 min-w-[16px] text-center">
                          {c.quantity}
                        </span>
                        <button
                          onClick={() => updateCartItemQty(c.cartKey, 1)}
                          className="w-6 h-6 rounded-md bg-[#0070fc] flex items-center justify-center text-white hover:bg-[#005ecc]"
                        >
                          <Plus className="w-3 h-3" />
                        </button>
                      </div>

                      <span className="font-bold text-slate-900 min-w-[65px] text-right">
                        {formatRupiah(c.unitPrice * c.quantity)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Order Fulfillment Type */}
              <div className="space-y-2">
                <span className="font-bold text-slate-500 uppercase tracking-wider text-[10px] block">
                  Opsi Pengambilan / Layanan
                </span>
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setOrderType('takeaway')}
                    className={`p-2.5 rounded-xl border text-center transition-all ${
                      orderType === 'takeaway'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc] font-bold shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <PackageCheck className="w-4 h-4 mx-auto mb-1 text-inherit" />
                    <span>Ambil Toko</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setOrderType('delivery')}
                    className={`p-2.5 rounded-xl border text-center transition-all ${
                      orderType === 'delivery'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc] font-bold shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <MapPin className="w-4 h-4 mx-auto mb-1 text-inherit" />
                    <span>Kirim Alamat</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setOrderType('dine_in')}
                    className={`p-2.5 rounded-xl border text-center transition-all ${
                      orderType === 'dine_in'
                        ? 'bg-blue-50 border-[#0070fc] text-[#0070fc] font-bold shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <Clock className="w-4 h-4 mx-auto mb-1 text-inherit" />
                    <span>Makan Sini</span>
                  </button>
                </div>
              </div>

              {/* Customer Info Form */}
              <div className="space-y-3 pt-1">
                <span className="font-bold text-slate-500 uppercase tracking-wider text-[10px] block">
                  Data Pemesan
                </span>
                <div>
                  <label className="font-bold text-slate-700 text-[11px] block mb-1">
                    Nama Lengkap <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={customerName}
                    onChange={(e) => setCustomerName(e.target.value)}
                    placeholder="Contoh: Budi Santoso"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                  />
                </div>

                <div>
                  <label className="font-bold text-slate-700 text-[11px] block mb-1">
                    No. WhatsApp Anda (Opsional)
                  </label>
                  <input
                    type="tel"
                    value={customerPhone}
                    onChange={(e) => setCustomerPhone(e.target.value)}
                    placeholder="Contoh: 08123456789"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                  />
                </div>

                {orderType === 'dine_in' && (
                  <div>
                    <label className="font-bold text-slate-700 text-[11px] block mb-1">
                      Nomor Meja <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={tableNumber}
                      onChange={(e) => setTableNumber(e.target.value)}
                      placeholder="Contoh: Meja 05"
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>
                )}

                {orderType === 'delivery' && (
                  <div>
                    <label className="font-bold text-slate-700 text-[11px] block mb-1">
                      Alamat Lengkap Pengiriman <span className="text-red-500">*</span>
                    </label>
                    <textarea
                      rows={2}
                      value={customerAddress}
                      onChange={(e) => setCustomerAddress(e.target.value)}
                      placeholder="Tuliskan nama jalan, no rumah, RT/RW, dan patokan..."
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>
                )}

                <div>
                  <label className="font-bold text-slate-700 text-[11px] block mb-1">
                    Catatan Pesanan Keseluruhan (Opsional)
                  </label>
                  <input
                    type="text"
                    value={orderNotes}
                    onChange={(e) => setOrderNotes(e.target.value)}
                    placeholder="Contoh: Minta struk belanja dicetak"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]"
                  />
                </div>
              </div>
            </div>

            {/* Modal Footer CTA */}
            <div className="p-4 border-t border-slate-100 bg-white space-y-2">
              <div className="flex items-center justify-between text-xs sm:text-sm font-bold">
                <span className="text-slate-600">Total Pembayaran:</span>
                <span className="text-base sm:text-lg font-black text-[#0070fc]">
                  {formatRupiah(totalCartPrice)}
                </span>
              </div>

              <button
                onClick={handleCheckoutViaWhatsApp}
                className="w-full py-3.5 px-4 rounded-xl font-bold bg-[#16A34A] hover:bg-[#15803d] text-white flex items-center justify-center gap-2 transition-colors shadow-md text-sm active:scale-[0.99]"
              >
                <MessageCircle className="w-5 h-5" />
                <span>Pesan Sekarang via WhatsApp</span>
              </button>
              <p className="text-[10px] text-center text-slate-400">
                Pesanan akan otomatis terformat dan dikirim ke nomor WhatsApp kasir toko.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
