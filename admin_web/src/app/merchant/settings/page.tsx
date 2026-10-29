'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import {
  Settings,
  Store,
  Receipt,
  Percent,
  Sparkles,
  Save,
  CheckCircle2,
  Wifi,
  Phone,
  Mail,
  MapPin,
  Shield,
  Layers,
} from 'lucide-react';

export default function MerchantSettingsPage() {
  const { business, refreshData } = useMerchant();

  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState(false);

  // Form State
  const [name, setName] = useState('');
  const [businessType, setBusinessType] = useState('fnb');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [address, setAddress] = useState('');

  // Receipt Settings
  const [receiptHeader, setReceiptHeader] = useState('');
  const [receiptFooter, setReceiptFooter] = useState('');
  const [wifiName, setWifiName] = useState('');
  const [wifiPassword, setWifiPassword] = useState('');

  // Tax & Service Charge
  const [enableTax, setEnableTax] = useState(false);
  const [taxPercentage, setTaxPercentage] = useState('10');
  const [enableServiceCharge, setEnableServiceCharge] = useState(false);
  const [serviceChargePercentage, setServiceChargePercentage] = useState('5');

  useEffect(() => {
    if (business) {
      setName(business.name || '');
      setBusinessType(business.business_type || 'fnb');
      setPhone(business.phone || '');
      setEmail(business.email || '');
      setAddress(business.address || '');

      const settings = (business as any).settings || {};
      setReceiptHeader(settings.receipt_header || '');
      setReceiptFooter(settings.receipt_footer || 'Terima kasih atas kunjungan Anda!');
      setWifiName(settings.wifi_name || '');
      setWifiPassword(settings.wifi_password || '');

      setEnableTax(Boolean(settings.enable_tax));
      setTaxPercentage(String(settings.tax_percentage ?? 10));
      setEnableServiceCharge(Boolean(settings.enable_service_charge));
      setServiceChargePercentage(String(settings.service_charge_percentage ?? 5));
    }
  }, [business]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    try {
      setSaving(true);
      const supabase = createClient();

      const existingSettings = (business as any).settings || {};
      const updatedSettings = {
        ...existingSettings,
        receipt_header: receiptHeader,
        receipt_footer: receiptFooter,
        wifi_name: wifiName,
        wifi_password: wifiPassword,
        enable_tax: enableTax,
        tax_percentage: parseFloat(taxPercentage) || 0,
        enable_service_charge: enableServiceCharge,
        service_charge_percentage: parseFloat(serviceChargePercentage) || 0,
      };

      const { error } = await supabase
        .from('businesses')
        .update({
          name: name.trim(),
          business_type: businessType,
          phone: phone.trim() || null,
          email: email.trim() || null,
          address: address.trim() || null,
          settings: updatedSettings,
          updated_at: new Date().toISOString(),
        })
        .eq('id', business.id);

      if (error) throw error;

      setSuccessMsg(true);
      setTimeout(() => setSuccessMsg(false), 4000);
      refreshData();
    } catch (err: any) {
      console.error('Error saving settings:', err);
      alert('Gagal menyimpan pengaturan: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Konfigurasi Toko & Sistem
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Pengaturan Bisnis & Struk
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Atur profil toko, format cetak struk kasir, persentase pajak PB1/PPN, dan biaya layanan
          </p>
        </div>

        {successMsg && (
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-bold animate-in fade-in">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
            <span>Pengaturan Berhasil Disimpan!</span>
          </div>
        )}
      </div>

      <form onSubmit={handleSave} className="space-y-6">
        {/* Profil Bisnis */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
            <div className="w-8 h-8 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center">
              <Store className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-sm">Profil Toko / Usaha</h3>
              <p className="text-[11px] text-slate-400">Identitas utama toko yang tampil di aplikasi dan nota kasir</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div>
              <label className="font-bold text-slate-700 block mb-1">Nama Toko *</label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Contoh: Kopi Kenangan Manis"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1">Jenis Usaha</label>
              <select
                value={businessType}
                onChange={(e) => setBusinessType(e.target.value)}
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              >
                <option value="fnb">Kuliner / Cafe / Resto (F&B)</option>
                <option value="retail">Toko Retail / Minimarket</option>
                <option value="service">Jasa / Barbershop / Salon</option>
                <option value="other">Usaha Lainnya</option>
              </select>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1">Nomor WhatsApp Toko</label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="0812xxxx"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1">Email Toko</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="kontak@toko.com"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="font-bold text-slate-700 block mb-1">Alamat Toko</label>
              <textarea
                rows={2}
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Alamat lengkap lokasi usaha..."
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>
          </div>
        </div>

        {/* Pengaturan Struk Kasir */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
            <div className="w-8 h-8 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
              <Receipt className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-sm">Pengaturan Struk Kasir & Nota</h3>
              <p className="text-[11px] text-slate-400">Pesan footer dan informasi yang dicetak pada printer thermal</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div className="sm:col-span-2">
              <label className="font-bold text-slate-700 block mb-1">Catatan Header Struk (Opsional)</label>
              <input
                type="text"
                value={receiptHeader}
                onChange={(e) => setReceiptHeader(e.target.value)}
                placeholder="Contoh: Cabang Resmi Dipatiukur • IG: @kopikita"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="font-bold text-slate-700 block mb-1">Pesan Footer Struk (Penutup)</label>
              <textarea
                rows={2}
                value={receiptFooter}
                onChange={(e) => setReceiptFooter(e.target.value)}
                placeholder="Terima kasih atas kunjungan Anda! Barang yang dibeli tidak dapat ditukar."
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1">Nama WiFi Toko (Tampil di Struk)</label>
              <input
                type="text"
                value={wifiName}
                onChange={(e) => setWifiName(e.target.value)}
                placeholder="Contoh: KopiKita_Guest"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1">Password WiFi</label>
              <input
                type="text"
                value={wifiPassword}
                onChange={(e) => setWifiPassword(e.target.value)}
                placeholder="Contoh: kopienak123"
                className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
              />
            </div>
          </div>
        </div>

        {/* Pajak & Biaya Layanan */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
            <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <Percent className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-sm">Pajak (PB1 / PPN) & Service Charge</h3>
              <p className="text-[11px] text-slate-400">Kalkulasi otomatis biaya pajak dan layanan saat kasir checkout</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            {/* Pajak PB1/PPN */}
            <div className="p-4 rounded-xl border border-slate-200 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <span className="font-bold text-slate-900 block">Pajak (PB1 / PPN)</span>
                  <span className="text-[10px] text-slate-400">Tambahkan pajak ke tagihan pelanggan</span>
                </div>
                <input
                  type="checkbox"
                  checked={enableTax}
                  onChange={(e) => setEnableTax(e.target.checked)}
                  className="w-4 h-4 accent-orange-600 cursor-pointer"
                />
              </div>

              {enableTax && (
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Persentase Pajak (%)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={taxPercentage}
                    onChange={(e) => setTaxPercentage(e.target.value)}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-bold text-slate-900 focus:outline-none focus:border-orange-500"
                  />
                </div>
              )}
            </div>

            {/* Service Charge */}
            <div className="p-4 rounded-xl border border-slate-200 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <span className="font-bold text-slate-900 block">Biaya Layanan (Service Charge)</span>
                  <span className="text-[10px] text-slate-400">Biaya servis untuk restoran / cafe</span>
                </div>
                <input
                  type="checkbox"
                  checked={enableServiceCharge}
                  onChange={(e) => setEnableServiceCharge(e.target.checked)}
                  className="w-4 h-4 accent-orange-600 cursor-pointer"
                />
              </div>

              {enableServiceCharge && (
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Persentase Biaya Layanan (%)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={serviceChargePercentage}
                    onChange={(e) => setServiceChargePercentage(e.target.value)}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-bold text-slate-900 focus:outline-none focus:border-orange-500"
                  />
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Submit Button */}
        <div className="flex justify-end pt-2">
          <button
            type="submit"
            disabled={saving}
            className="px-6 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold flex items-center gap-2 shadow-sm disabled:opacity-50 transition-all"
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Menyimpan...' : 'Simpan Semua Pengaturan'}</span>
          </button>
        </div>
      </form>
    </div>
  );
}
