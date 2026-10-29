'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import {
  Globe,
  QrCode,
  Copy,
  Check,
  ExternalLink,
  Share2,
  Store,
  Phone,
  Clock,
  MapPin,
  Save,
  CheckCircle2,
  AlertCircle,
  Download,
} from 'lucide-react';

export default function MerchantOnlineShopPage() {
  const { business, refreshData, loading: shellLoading } = useMerchant();

  const [copied, setCopied] = useState(false);
  const [storeName, setStoreName] = useState('');
  const [slug, setSlug] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [saving, setSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (business) {
      setStoreName(business.name || '');
      setSlug(business.slug || '');
      setPhone(business.phone || '');
      setAddress(business.address || '');
    }
  }, [business]);

  const shopUrl = slug ? `https://pos.mudahkan.online/s/${slug}` : '';
  const qrUrl = shopUrl ? `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(shopUrl)}` : '';

  const handleCopy = () => {
    if (!shopUrl) return;
    navigator.clipboard.writeText(shopUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSaveSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    try {
      setSaving(true);
      setErrorMessage(null);
      setSavedSuccess(false);

      const supabase = createClient();
      const cleanSlug = slug.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');

      const { error } = await supabase
        .from('businesses')
        .update({
          name: storeName.trim(),
          slug: cleanSlug,
          phone: phone.trim(),
          address: address.trim(),
        })
        .eq('id', business.id);

      if (error) {
        setErrorMessage(error.message);
        return;
      }

      setSavedSuccess(true);
      setTimeout(() => setSavedSuccess(false), 3000);
      await refreshData();
    } catch (err: any) {
      setErrorMessage(err?.message || 'Gagal menyimpan pengaturan.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
          Pemasaran Digital
        </span>
        <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
          Pengaturan Toko Online & QR Menu
        </h2>
        <p className="text-xs text-slate-500 mt-0.5">
          Toko online mandiri untuk pelanggan pesan menu via WhatsApp tanpa unduh aplikasi
        </p>
      </div>

      {/* Live Store Link & QR Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* URL Card & Sharing (2 cols) */}
        <div className="lg:col-span-2 bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Globe className="w-5 h-5 text-orange-600" />
              <h3 className="font-bold text-slate-900 text-sm sm:text-base">
                Tautan Toko Online Anda
              </h3>
            </div>
            <p className="text-xs text-slate-500 mb-4 leading-relaxed">
              Pelanggan Anda dapat membuka katalog produk, memilih menu, dan langsung mengirimkan pesanan ke WhatsApp toko Anda melalui link ini:
            </p>

            {/* URL Box */}
            <div className="flex items-center gap-2 p-3 bg-slate-50 border border-slate-200 rounded-xl mb-4">
              <span className="text-xs font-mono font-bold text-slate-800 truncate flex-1">
                {shopUrl || 'Belum ada slug toko'}
              </span>
              <button
                onClick={handleCopy}
                disabled={!shopUrl}
                className="px-3 py-1.5 text-xs font-bold rounded-lg bg-white border border-slate-200 hover:bg-slate-100 text-slate-700 flex items-center gap-1.5 transition-colors shadow-2xs"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5 text-slate-500" />}
                <span>{copied ? 'Tersalin!' : 'Salin'}</span>
              </button>
            </div>
          </div>

          {/* Quick Action Buttons */}
          <div className="flex flex-wrap gap-2.5 pt-4 border-t border-slate-100">
            {shopUrl && (
              <>
                <a
                  href={shopUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm shadow-orange-600/20 transition-all"
                >
                  <ExternalLink className="w-4 h-4" />
                  <span>Buka Toko Online</span>
                </a>

                <a
                  href={`https://wa.me/?text=${encodeURIComponent(`Halo! Silakan lihat menu dan pesan langsung di toko online kami: ${shopUrl}`)}`}
                  target="_blank"
                  rel="noreferrer"
                  className="px-4 py-2 text-xs font-bold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white flex items-center gap-1.5 shadow-sm shadow-emerald-600/20 transition-all"
                >
                  <Share2 className="w-4 h-4" />
                  <span>Bagikan ke WhatsApp</span>
                </a>
              </>
            )}
          </div>
        </div>

        {/* QR Code Standee Card (1 col) */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col items-center text-center justify-between">
          <div>
            <h3 className="font-bold text-slate-900 text-sm mb-1">
              QR Code Toko & Meja
            </h3>
            <p className="text-[11px] text-slate-500 mb-4">
              Cetak QR Code ini untuk diletakkan di kasir atau meja pelanggan
            </p>

            {/* QR Image */}
            {qrUrl ? (
              <div className="p-3 bg-white border-2 border-slate-100 rounded-2xl shadow-xs inline-block mb-3">
                <img
                  src={qrUrl}
                  alt="QR Code Toko"
                  className="w-40 h-40 object-contain mx-auto"
                />
              </div>
            ) : (
              <div className="w-40 h-40 bg-slate-100 rounded-2xl flex items-center justify-center text-xs text-slate-400 mb-3 mx-auto">
                QR Code Belum Tersedia
              </div>
            )}
          </div>

          {qrUrl && (
            <a
              href={qrUrl}
              download="QR_Menu_Toko.png"
              target="_blank"
              rel="noreferrer"
              className="px-4 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
            >
              <Download className="w-4 h-4 text-slate-600" />
              <span>Download Gambar QR</span>
            </a>
          )}
        </div>
      </div>

      {/* Edit Store Settings Form */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <h3 className="font-bold text-slate-900 text-base mb-1">
          Informasi & Pengaturan Toko
        </h3>
        <p className="text-xs text-slate-500 mb-5">
          Perbarui nama usaha, nomor kontak WhatsApp untuk menerima pesanan, dan alamat gerai
        </p>

        {savedSuccess && (
          <div className="mb-4 p-3 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center gap-2 text-xs font-bold text-emerald-800">
            <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
            <span>Pengaturan toko berhasil diperbarui!</span>
          </div>
        )}

        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-red-50 border border-red-200 flex items-center gap-2 text-xs font-bold text-red-800">
            <AlertCircle className="w-4 h-4 text-red-600 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSaveSettings} className="space-y-4 max-w-xl">
          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Nama Toko / Bisnis</label>
            <div className="relative">
              <Store className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={storeName}
                onChange={(e) => setStoreName(e.target.value)}
                required
                className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">URL Slug Toko</label>
            <div className="flex items-center gap-1">
              <span className="text-xs text-slate-400 font-mono">pos.mudahkan.online/s/</span>
              <input
                type="text"
                value={slug}
                onChange={(e) => setSlug(e.target.value)}
                required
                className="flex-1 px-3 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium font-mono"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">
              Nomor WhatsApp Penerima Pesanan
            </label>
            <div className="relative">
              <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="Contoh: 08123456789 atau 628123456789"
                required
                className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
              />
            </div>
            <p className="text-[10px] text-slate-400 mt-1">
              Setiap pesanan online dari pembeli akan langsung dikirimkan ke WhatsApp nomor ini.
            </p>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Alamat Toko Fisik</label>
            <div className="relative">
              <MapPin className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
              <textarea
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                rows={3}
                placeholder="Alamat lengkap toko / resto Anda"
                className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={saving}
            className="px-5 py-2.5 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm shadow-orange-600/20 disabled:opacity-50 transition-all"
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Menyimpan...' : 'Simpan Pengaturan Toko'}</span>
          </button>
        </form>
      </div>
    </div>
  );
}
