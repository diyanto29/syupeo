'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import { RetailStarterKit } from '@/types/database';
import WilayahSelector, { WilayahSelection } from '@/components/WilayahSelector';
import GooglePlacesAutocomplete, { PlaceResult } from '@/components/GooglePlacesAutocomplete';
import {
  Package,
  Store,
  CheckCircle2,
  Truck,
  Sparkles,
  ArrowRight,
  ShieldCheck,
  MapPin,
  QrCode,
  Check,
  Clock,
  Phone,
  User,
  ExternalLink,
  ChevronRight,
  AlertCircle,
  Loader2,
} from 'lucide-react';

export default function StarterKitPublicPage() {
  const [starterKits, setStarterKits] = useState<RetailStarterKit[]>([]);
  const [selectedKit, setSelectedKit] = useState<RetailStarterKit | null>(null);
  const [loadingKits, setLoadingKits] = useState(true);

  // Form Fields
  const [storeName, setStoreName] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [province, setProvince] = useState('');
  const [city, setCity] = useState('');
  const [district, setDistrict] = useState('');
  const [village, setVillage] = useState('');
  const [address, setAddress] = useState('');
  const [lat, setLat] = useState<number | null>(null);
  const [lng, setLng] = useState<number | null>(null);

  // Checkout Step
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [orderSuccess, setOrderSuccess] = useState<any | null>(null);

  const supabase = createClient();

  useEffect(() => {
    async function loadKits() {
      setLoadingKits(true);
      try {
        const { data, error } = await supabase
          .from('retail_starter_kits')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', { ascending: true });

        if (!error && data && data.length > 0) {
          setStarterKits(data as RetailStarterKit[]);
          setSelectedKit(data[0] as RetailStarterKit);
        }
      } catch (err) {
        console.error('Error fetching starter kits:', err);
      } finally {
        setLoadingKits(false);
      }
    }
    loadKits();
  }, []);

  const handleCheckout = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedKit) return;
    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      if (!storeName.trim()) throw new Error('Nama toko wajib diisi');
      if (!ownerName.trim()) throw new Error('Nama pemilik wajib diisi');
      if (!phone.trim()) throw new Error('Nomor WhatsApp wajib diisi');
      if (!city.trim() || !address.trim()) throw new Error('Alamat dan Kota toko wajib diisi');

      const cleanSlug = `${storeName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${Date.now().toString().slice(-4)}`;
      const fallbackEmail = email.trim() || `toko_${Date.now().toString().slice(-6)}@syupeo.com`;

      // 1. Buat record akun toko di businesses
      const { data: newBiz, error: bizErr } = await supabase
        .from('businesses')
        .insert({
          name: storeName.trim(),
          slug: cleanSlug,
          business_type: 'retail',
          phone: phone.trim(),
          email: fallbackEmail,
          address: address.trim(),
          city: city.trim(),
          province: province.trim() || null,
          district: district.trim() || null,
          village: village.trim() || null,
          latitude: lat,
          longitude: lng,
          status: 'active',
          subscription_status: 'active',
          starter_kit_id: selectedKit.id,
        })
        .select()
        .single();

      if (bizErr) throw bizErr;

      // 2. Buat default outlet
      await supabase.from('outlets').insert({
        business_id: newBiz.id,
        name: 'Toko Utama',
        address: address.trim(),
        phone: phone.trim(),
        latitude: lat,
        longitude: lng,
        is_active: true,
      });

      // 3. Jalankan auto-seed produk ke menu_items toko
      try {
        await supabase.rpc('apply_starter_kit_to_business', {
          p_business_id: newBiz.id,
          p_starter_kit_id: selectedKit.id,
        });
      } catch (rpcErr) {
        console.warn('RPC warning:', rpcErr);
      }

      // 4. Cari gudang terdekat dan buatkan Order Fulfillment
      const { data: whList } = await supabase.from('warehouses').select('*').eq('is_active', true);
      const matchedWarehouse = (whList || []).find(
        (w) => w.city?.toLowerCase().includes(city.toLowerCase()) || city.toLowerCase().includes(w.city?.toLowerCase() || '')
      ) || (whList && whList[0]) || null;

      const orderCode = `ORD-${Date.now().toString().slice(-6)}`;
      const { data: ordData, error: ordErr } = await supabase
        .from('package_fulfillment_orders')
        .insert({
          order_code: orderCode,
          starter_kit_id: selectedKit.id,
          kit_name: selectedKit.name,
          recipient_name: `${ownerName.trim()} (${storeName.trim()})`,
          recipient_phone: phone.trim(),
          shipping_address: address.trim(),
          shipping_city: city.trim(),
          shipping_province: province.trim() || null,
          shipping_district: district.trim() || null,
          shipping_village: village.trim() || null,
          recipient_lat: lat,
          recipient_lng: lng,
          status: 'pending_dispatch',
          fulfillment_mode: 'agent_direct',
          assigned_warehouse_id: matchedWarehouse?.id || null,
          sender_alias: 'Syupeo Official',
          notes: 'Pemesanan mandiri via Web Publik Starter Kit Syupeo.',
        })
        .select()
        .single();

      if (ordErr) throw ordErr;

      // Tampilkan status sukses dengan nomor order
      setOrderSuccess({
        orderCode,
        storeName: storeName.trim(),
        ownerName: ownerName.trim(),
        kitName: selectedKit.name,
        price: selectedKit.price,
        address: address.trim(),
        city: city.trim(),
      });
    } catch (err: any) {
      setErrorMsg(err.message || 'Gagal memproses pemesanan');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 font-sans">
      {/* Header Publik */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-[#0070fc] flex items-center justify-center text-white font-bold text-lg shadow-sm">
              S
            </div>
            <span className="font-extrabold text-xl tracking-tight text-slate-900">
              Syupeo<span className="text-[#0070fc]">.</span>
            </span>
          </Link>
          <div className="flex items-center gap-3">
            <Link
              href="/login"
              className="text-xs font-bold text-slate-600 hover:text-slate-900 px-3 py-1.5 rounded-lg transition-colors"
            >
              Masuk ke Aplikasi
            </Link>
            <a
              href="#order-form"
              className="text-xs font-bold bg-[#0070fc] hover:bg-[#005ecc] text-white px-4 py-2 rounded-lg transition-all shadow-sm"
            >
              Beli Starter Kit
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="bg-gradient-to-b from-blue-50/60 to-slate-50 pt-12 pb-8 border-b border-slate-200/60">
        <div className="max-w-4xl mx-auto px-4 text-center space-y-4">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-blue-100/70 text-[#0070fc] text-xs font-bold border border-blue-200">
            <Sparkles className="w-3.5 h-3.5 text-[#0070fc]" />
            <span>Peluang Usaha Toko Retail Terbuka</span>
          </div>

          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-black text-slate-900 tracking-tight leading-tight">
            Mulai Bisnis Toko Retail Mandiri <br className="hidden sm:inline" />
            Cuma Modal <span className="text-[#0070fc]">Rp 200.000!</span>
          </h1>

          <p className="text-sm sm:text-base text-slate-600 max-w-2xl mx-auto leading-relaxed">
            Dari stok pertama, sampai ke tangan pelanggan. Dapatkan paket produk siap jual, aplikasi kasir (POS),
            dan website toko online dalam 1 genggaman.
          </p>

          {/* 6 Langkah Alur Bisnis (Infografis Mini) */}
          <div className="pt-6 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 text-left">
            {[
              { num: '1', title: 'Beli Paket', desc: 'Modal Rp 200rb' },
              { num: '2', title: 'Aktivasi Toko', desc: 'Akun langsung aktif' },
              { num: '3', title: 'Stok Otomatis', desc: 'Katalog terisi instan' },
              { num: '4', title: 'Sebar Link', desc: 'Jual online & offline' },
              { num: '5', title: 'Pembeli Pesan', desc: 'Checkout mudah' },
              { num: '6', title: 'Gudang Kirim', desc: 'Diantar truk Syupeo' },
            ].map((step) => (
              <div key={step.num} className="bg-white p-2.5 rounded-xl border border-slate-200 shadow-2xs">
                <span className="w-5 h-5 rounded-full bg-[#0070fc] text-white text-[11px] font-black flex items-center justify-center mb-1">
                  {step.num}
                </span>
                <div className="text-xs font-bold text-slate-900 leading-tight">{step.title}</div>
                <div className="text-[10px] text-slate-500">{step.desc}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Main Content: Katalog Starter Kit & Form Checkout */}
      <main className="max-w-5xl mx-auto px-4 py-10" id="order-form">
        {orderSuccess ? (
          /* Layar Konfirmasi Berhasil */
          <div className="bg-white rounded-2xl p-8 border border-emerald-200 shadow-lg max-w-xl mx-auto text-center space-y-4">
            <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto">
              <CheckCircle2 className="w-8 h-8" />
            </div>
            <h2 className="text-2xl font-black text-slate-900">Pemesanan Starter Kit Berhasil!</h2>
            <p className="text-xs text-slate-600">
              Selamat bergabung dengan ekosistem Toko Retail Syupeo! Paket usaha Anda sedang disiapkan di gudang terdekat.
            </p>

            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 text-left space-y-2 text-xs font-medium">
              <div className="flex justify-between border-b pb-1.5">
                <span className="text-slate-500">Nomor Pesanan:</span>
                <strong className="font-mono text-blue-700">{orderSuccess.orderCode}</strong>
              </div>
              <div className="flex justify-between border-b pb-1.5">
                <span className="text-slate-500">Nama Toko:</span>
                <strong className="text-slate-900">{orderSuccess.storeName}</strong>
              </div>
              <div className="flex justify-between border-b pb-1.5">
                <span className="text-slate-500">Paket Usaha:</span>
                <strong className="text-slate-900">{orderSuccess.kitName}</strong>
              </div>
              <div className="flex justify-between border-b pb-1.5">
                <span className="text-slate-500">Total Biaya:</span>
                <strong className="text-emerald-700 font-bold">
                  Rp {Number(orderSuccess.price).toLocaleString('id-ID')}
                </strong>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Tujuan Pengiriman:</span>
                <span className="text-slate-900 text-right max-w-[200px] truncate">{orderSuccess.address}, {orderSuccess.city}</span>
              </div>
            </div>

            <div className="pt-2 flex flex-col sm:flex-row gap-2.5">
              <Link
                href="/login"
                className="flex-1 py-3 px-4 rounded-xl bg-[#0070fc] hover:bg-blue-600 text-white font-bold text-xs flex items-center justify-center gap-1.5 shadow-md"
              >
                <span>Masuk ke Dashboard Toko</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
              <a
                href={`https://wa.me/6281234567890?text=Halo%20Admin%20Syupeo,%20saya%20sudah%20memesan%20starter%20kit%20${orderSuccess.orderCode}`}
                target="_blank"
                rel="noreferrer"
                className="py-3 px-4 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs flex items-center justify-center gap-1.5"
              >
                <Phone className="w-4 h-4" />
                <span>Konfirmasi via WhatsApp</span>
              </a>
            </div>
          </div>
        ) : (
          /* Form Pemesanan Normal */
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            {/* Kolom Kiri: Pilihan Starter Kit */}
            <div className="lg:col-span-5 space-y-4">
              <div>
                <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Package className="w-5 h-5 text-[#ba8c02]" />
                  <span>1. Pilih Paket Usaha Perdana Anda</span>
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Setiap paket berisi barang siap jual senilai lebih dari Rp 200.000
                </p>
              </div>

              {loadingKits ? (
                <div className="p-8 text-center bg-white rounded-2xl border border-slate-200">
                  <Loader2 className="w-6 h-6 animate-spin text-[#0070fc] mx-auto mb-2" />
                  <span className="text-xs text-slate-500">Memuat paket resmi...</span>
                </div>
              ) : (
                <div className="space-y-3">
                  {starterKits.map((kit) => {
                    const isSelected = selectedKit?.id === kit.id;
                    const items = Array.isArray(kit.items_included) ? kit.items_included : [];
                    return (
                      <div
                        key={kit.id}
                        onClick={() => setSelectedKit(kit)}
                        className={`p-4 rounded-2xl border cursor-pointer transition-all ${
                          isSelected
                            ? 'bg-blue-50/60 border-[#0070fc] ring-2 ring-blue-100 shadow-sm'
                            : 'bg-white border-slate-200 hover:border-slate-300 shadow-2xs'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2 mb-1.5">
                          <div>
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-700">
                              {kit.badge || 'Starter Kit'}
                            </span>
                            <h4 className="font-bold text-sm text-slate-900 mt-1">{kit.name}</h4>
                          </div>
                          <div className="text-right">
                            <span className="font-black text-sm text-[#0070fc]">
                              Rp {Number(kit.price).toLocaleString('id-ID')}
                            </span>
                            {kit.original_price && (
                              <div className="text-[10px] text-slate-400 line-through">
                                Rp {Number(kit.original_price).toLocaleString('id-ID')}
                              </div>
                            )}
                          </div>
                        </div>

                        <p className="text-xs text-slate-600 mb-2.5 leading-relaxed">{kit.description}</p>

                        {/* List Barang Termasuk */}
                        {items.length > 0 && (
                          <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-1">
                            <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                              Isi Paket ({items.length} Produk):
                            </div>
                            <div className="grid grid-cols-2 gap-x-2 gap-y-0.5 text-[11px] text-slate-700">
                              {items.slice(0, 6).map((it: any, idx: number) => (
                                <div key={idx} className="truncate flex items-center gap-1">
                                  <span className="text-emerald-500">✓</span>
                                  <span>{it.qty || it.quantity || 1}x {it.name}</span>
                                </div>
                              ))}
                            </div>
                            {items.length > 6 && (
                              <div className="text-[10px] text-blue-700 font-semibold pt-0.5">
                                + {items.length - 6} produk lainnya
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Kolom Kanan: Form Pendaftaran & Checkout */}
            <div className="lg:col-span-7 bg-white rounded-2xl p-6 border border-slate-200 shadow-sm space-y-5">
              <div>
                <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Store className="w-5 h-5 text-[#0070fc]" />
                  <span>2. Data Toko & Alamat Pengiriman Paket</span>
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Paket starter kit akan dikirim langsung ke alamat toko Anda dari depo/gudang terdekat
                </p>
              </div>

              {errorMsg && (
                <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <form onSubmit={handleCheckout} className="space-y-4 text-xs">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Nama Toko Retail Anda</label>
                    <input
                      type="text"
                      required
                      placeholder="Contoh: Warung Berkah Abadi"
                      value={storeName}
                      onChange={(e) => setStoreName(e.target.value)}
                      className="w-full px-3 py-2.5 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Nama Lengkap Pemilik</label>
                    <input
                      type="text"
                      required
                      placeholder="Contoh: Ibu Siti Aminah"
                      value={ownerName}
                      onChange={(e) => setOwnerName(e.target.value)}
                      className="w-full px-3 py-2.5 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">No. WhatsApp Aktif</label>
                    <input
                      type="tel"
                      required
                      placeholder="0812-xxxx-xxxx"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="w-full px-3 py-2.5 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Alamat Email (Opsional)</label>
                    <input
                      type="email"
                      placeholder="email@anda.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="w-full px-3 py-2.5 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>
                </div>

                {/* Standarisasi Wilayah & GPS */}
                <div className="space-y-3 pt-1">
                  <WilayahSelector
                    initialProvince={province}
                    initialCity={city}
                    initialDistrict={district}
                    initialVillage={village}
                    onChange={(sel: WilayahSelection) => {
                      setProvince(sel.provinceName);
                      setCity(sel.regencyName);
                      setDistrict(sel.districtName);
                      setVillage(sel.villageName);
                      if (!address && sel.formattedText) {
                        setAddress(sel.formattedText);
                      }
                    }}
                  />

                  <GooglePlacesAutocomplete
                    initialAddress={address}
                    initialLat={lat}
                    initialLng={lng}
                    placeholder="Ketik patokan jalan toko untuk kurir armada Syupeo..."
                    onSelectPlace={(place: PlaceResult) => {
                      setAddress(place.formattedAddress);
                      setLat(place.latitude);
                      setLng(place.longitude);
                    }}
                  />

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Alamat Lengkap Toko</label>
                    <textarea
                      required
                      rows={2}
                      placeholder="Jalan, RT/RW, nomor rumah, patokan..."
                      value={address}
                      onChange={(e) => setAddress(e.target.value)}
                      className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>
                </div>

                {/* Ringkasan Pembayaran */}
                <div className="p-4 rounded-xl bg-blue-50/70 border border-blue-200 space-y-2">
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-slate-600">Paket Terpilih:</span>
                    <strong className="text-slate-900">{selectedKit?.name || '-'}</strong>
                  </div>
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-slate-600">Ongkos Kirim Armada Gudang:</span>
                    <span className="font-bold text-emerald-600">GRATIS (Radius 25km)</span>
                  </div>
                  <div className="pt-2 border-t border-blue-200 flex justify-between items-center text-sm font-extrabold text-slate-900">
                    <span>Total Pembayaran:</span>
                    <span className="text-lg text-[#0070fc]">
                      Rp {Number(selectedKit?.price || 200000).toLocaleString('id-ID')}
                    </span>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting || !selectedKit}
                  className="w-full py-3.5 px-4 rounded-xl bg-[#0070fc] hover:bg-[#005ecc] text-white text-sm font-bold transition-all shadow-md shadow-blue-500/20 flex items-center justify-center gap-2 disabled:opacity-60"
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Memproses Pendaftaran Toko...</span>
                    </>
                  ) : (
                    <>
                      <Truck className="w-4 h-4" />
                      <span>Beli Starter Kit & Buka Toko Sekarang</span>
                    </>
                  )}
                </button>
              </form>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 py-6 mt-12 text-center text-xs text-slate-500">
        <p>© 2026 Syupeo. Satu Aplikasi, Banyak Peluang — Dari Stok Pertama, Sampai ke Tangan Pelanggan.</p>
      </footer>
    </div>
  );
}

