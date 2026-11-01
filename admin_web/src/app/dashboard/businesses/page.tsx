'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { Business, BusinessTypeTemplate, RetailStarterKit, Warehouse } from '@/types/database';
import WilayahSelector, { WilayahSelection } from '@/components/WilayahSelector';
import GooglePlacesAutocomplete, { PlaceResult } from '@/components/GooglePlacesAutocomplete';
import Link from 'next/link';
import {
  Search,
  CheckCircle,
  X,
  AlertCircle,
  Sparkles,
  Store,
  Check,
  Eye,
  Trash2,
  PlusCircle,
  Package,
  MapPin,
  Truck,
  CheckCircle2,
  Navigation,
  Phone,
  UserCheck,
  Loader2,
  Clock,
} from 'lucide-react';

export default function BusinessesPage() {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [templates, setTemplates] = useState<BusinessTypeTemplate[]>([]);
  const [starterKits, setStarterKits] = useState<RetailStarterKit[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTypeFilter, setSelectedTypeFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // --- Modal Onboarding Toko Baru & Starter Kit ---
  const [isRegisterModalOpen, setIsRegisterModalOpen] = useState(false);
  const [formStoreName, setFormStoreName] = useState('');
  const [formOwnerName, setFormOwnerName] = useState('');
  const [formPhone, setFormPhone] = useState('');
  const [formEmail, setFormEmail] = useState('');
  const [formTemplateCode, setFormTemplateCode] = useState('retail');
  const [formProvince, setFormProvince] = useState('');
  const [formCity, setFormCity] = useState('');
  const [formDistrict, setFormDistrict] = useState('');
  const [formVillage, setFormVillage] = useState('');
  const [formAddress, setFormAddress] = useState('');
  const [formLat, setFormLat] = useState<number | null>(null);
  const [formLng, setFormLng] = useState<number | null>(null);
  const [formStarterKitId, setFormStarterKitId] = useState('');
  const [formPaymentStatus, setFormPaymentStatus] = useState<'paid_cash' | 'paid_transfer' | 'pending'>('paid_cash');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [isUpdating, setIsUpdating] = useState(false);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const supabase = createClient();

  const loadData = async () => {
    setLoading(true);
    try {
      const [bizRes, tplRes, kitRes, whRes] = await Promise.all([
        supabase
          .from('businesses')
          .select('*, retail_starter_kits(*)')
          .order('created_at', { ascending: false }),
        supabase.from('business_type_templates').select('*').order('name'),
        supabase.from('retail_starter_kits').select('*').eq('is_active', true).order('sort_order', { ascending: true }),
        supabase.from('warehouses').select('*').eq('is_active', true),
      ]);

      if (!bizRes.error && bizRes.data) {
        setBusinesses(bizRes.data as Business[]);
      } else if (bizRes.error) {
        console.warn('bizRes error, fallback to simple select:', bizRes.error);
        const fallbackBiz = await supabase.from('businesses').select('*').order('created_at', { ascending: false });
        if (fallbackBiz.data) setBusinesses(fallbackBiz.data as Business[]);
      }

      if (!tplRes.error && tplRes.data) {
        setTemplates(tplRes.data as BusinessTypeTemplate[]);
      }
      if (!kitRes.error && kitRes.data) {
        setStarterKits(kitRes.data as RetailStarterKit[]);
        if (kitRes.data.length > 0 && !formStarterKitId) {
          setFormStarterKitId(kitRes.data[0].id);
        }
      }
      if (!whRes.error && whRes.data) {
        setWarehouses(whRes.data as Warehouse[]);
      }
    } catch (err) {
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const resetRegisterForm = () => {
    setFormStoreName('');
    setFormOwnerName('');
    setFormPhone('');
    setFormEmail('');
    setFormTemplateCode('retail');
    setFormProvince('');
    setFormCity('');
    setFormDistrict('');
    setFormVillage('');
    setFormAddress('');
    setFormLat(null);
    setFormLng(null);
    setFormStarterKitId(starterKits[0]?.id || '');
    setFormPaymentStatus('paid_cash');
    setErrorMsg(null);
  };

  // Handle Daftarkan Toko & Kirim Starter Kit
  const handleRegisterStore = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      if (!formStoreName.trim()) throw new Error('Nama toko wajib diisi.');
      if (!formOwnerName.trim()) throw new Error('Nama pemilik toko wajib diisi.');
      if (!formPhone.trim()) throw new Error('Nomor WhatsApp wajib diisi.');
      if (!formCity.trim() || !formAddress.trim()) throw new Error('Alamat dan Kota toko wajib diisi.');

      const cleanSlug = `${formStoreName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${Date.now().toString().slice(-4)}`;
      const fallbackEmail = formEmail.trim() || `toko_${Date.now().toString().slice(-6)}@syupeo.com`;

      const chosenTpl = templates.find((t) => t.code === formTemplateCode) || templates[0];

      // 1. Simpan ke tabel businesses
      const bizPayload: any = {
        name: formStoreName.trim(),
        owner_name: formOwnerName.trim() || null,
        slug: cleanSlug,
        business_type: chosenTpl?.code || 'retail',
        phone: formPhone.trim(),
        email: fallbackEmail,
        address: formAddress.trim(),
        city: formCity.trim(),
        province: formProvince.trim() || null,
        district: formDistrict.trim() || null,
        village: formVillage.trim() || null,
        latitude: formLat,
        longitude: formLng,
        status: 'active',
        subscription_status: 'active',
        enabled_features: chosenTpl?.default_enabled_features || ['pos', 'inventory', 'cash_flow'],
        max_transactions: chosenTpl?.max_transactions ?? 1000,
        max_products: chosenTpl?.max_products ?? 100,
        max_outlets: chosenTpl?.max_outlets ?? 1,
        starter_kit_id: formStarterKitId || null,
      };

      const { data: newBiz, error: newBizErr } = await supabase
        .from('businesses')
        .insert(bizPayload)
        .select()
        .single();

      if (newBizErr) throw newBizErr;

      // 2. Buat default Outlet
      await supabase.from('outlets').insert({
        business_id: newBiz.id,
        name: 'Toko Utama',
        address: formAddress.trim(),
        phone: formPhone.trim(),
        latitude: formLat,
        longitude: formLng,
        is_active: true,
      });

      // 3. Jika memilih starter kit, jalankan auto-seed produk & buat dispatch order
      if (formStarterKitId) {
        const selectedKit = starterKits.find((k) => k.id === formStarterKitId);

        // a. Panggil stored procedure auto-seed produk
        try {
          await supabase.rpc('apply_starter_kit_to_business', {
            p_business_id: newBiz.id,
            p_starter_kit_id: formStarterKitId,
          });
        } catch (rpcErr) {
          console.warn('RPC apply_starter_kit_to_business warning:', rpcErr);
        }

        // b. Cari gudang terdekat dari kota/wilayah
        const matchedWarehouse = warehouses.find(
          (w) => w.city?.toLowerCase().includes(formCity.toLowerCase()) || formCity.toLowerCase().includes(w.city?.toLowerCase() || '')
        ) || warehouses[0];

        // c. Buat Order Fulfillment Dispatch
        const orderCode = `ORD-${Date.now().toString().slice(-6)}`;
        await supabase.from('package_fulfillment_orders').insert({
          order_code: orderCode,
          starter_kit_id: formStarterKitId,
          kit_name: selectedKit?.name || 'Paket Usaha Retail',
          recipient_name: `${formOwnerName.trim()} (${formStoreName.trim()})`,
          recipient_phone: formPhone.trim(),
          shipping_address: formAddress.trim(),
          shipping_city: formCity.trim(),
          shipping_province: formProvince.trim() || null,
          shipping_district: formDistrict.trim() || null,
          shipping_village: formVillage.trim() || null,
          recipient_lat: formLat,
          recipient_lng: formLng,
          status: formPaymentStatus === 'pending' ? 'pending_dispatch' : 'packing',
          fulfillment_mode: 'agent_direct',
          assigned_warehouse_id: matchedWarehouse?.id || null,
          sender_alias: 'Syupeo Official',
          notes: `Pendaftaran via Admin/Sales. Status bayar: ${formPaymentStatus === 'paid_cash' ? 'LUNAS (TUNAI)' : formPaymentStatus === 'paid_transfer' ? 'LUNAS (TRANSFER)' : 'PENDING'}.`,
        });
      }

      setSuccessMsg(
        `Toko "${formStoreName}" berhasil didaftarkan! Produk starter kit otomatis disalin ke stok toko & tiket pengiriman gudang telah diterbitkan.`
      );
      setIsRegisterModalOpen(false);
      resetRegisterForm();
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal mendaftarkan toko: ${err.message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // --- Handler Aktivasi Akun Toko oleh Admin ---
  const handleActivateBusiness = async (biz: Business) => {
    if (
      !confirm(
        `Aktivasi akun toko "${biz.name}"?\nStatus toko akan aktif dan pesanan paket usaha akan diteruskan ke tim gudang untuk packing.`
      )
    ) {
      return;
    }
    try {
      setIsUpdating(true);
      setErrorMsg(null);

      // 1. Coba aktivasi melalui fungsi RPC activate_business
      const { data: rpcData, error: rpcErr } = await supabase.rpc('activate_business', {
        p_business_id: biz.id,
      });

      if (rpcErr) {
        console.warn('RPC activate_business warning, mencoba direct update:', rpcErr);

        // 2. Fallback: Direct update via Supabase client
        const { error: bizErr, data: updatedData } = await supabase
          .from('businesses')
          .update({
            status: 'active',
            subscription_status: 'active',
          })
          .eq('id', biz.id)
          .select();

        if (bizErr) throw bizErr;

        if (biz.phone) {
          await supabase
            .from('package_fulfillment_orders')
            .update({ status: 'packing' })
            .eq('recipient_phone', biz.phone)
            .eq('status', 'pending_dispatch');
        }
      }

      setSuccessMsg(`Toko "${biz.name}" berhasil diaktivasi! Pengguna kasir sekarang memiliki akses penuh.`);
      await loadData();
    } catch (err: any) {
      setErrorMsg(`Gagal aktivasi toko: ${err?.message || err}`);
    } finally {
      setIsUpdating(false);
    }
  };

  // --- Handler for Delete Business ---
  const handleDeleteBusiness = async (biz: Business) => {
    if (!confirm(`Hapus permanen toko "${biz.name}"? Data toko dan outlet yang berkaitan akan dibersihkan.`)) {
      return;
    }
    try {
      const { error: rpcErr } = await supabase.rpc('delete_business_by_admin', {
        p_business_id: biz.id,
      });

      if (rpcErr) {
        const { data: outlets } = await supabase.from('outlets').select('id').eq('business_id', biz.id);
        if (outlets && outlets.length > 0) {
          const outletIds = outlets.map((o) => o.id);
          await supabase.from('outlet_members').delete().in('outlet_id', outletIds);
          await supabase.from('outlets').delete().in('id', outletIds);
        }
        await supabase.from('business_members').delete().eq('business_id', biz.id);
        const { error: delErr } = await supabase.from('businesses').delete().eq('id', biz.id);
        if (delErr) throw delErr;
      }

      setSuccessMsg(`Toko "${biz.name}" berhasil dihapus.`);
      await loadData();
    } catch (err: any) {
      alert(`Gagal menghapus toko: ${err?.message || 'Pastikan migration SQL delete sudah dijalankan di Supabase'}`);
    }
  };

  // Filter Search & Template (Bebas dari Plan Filter)
  const filteredBusinesses = businesses.filter((b) => {
    const matchesSearch =
      b.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.owner_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.phone?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.city?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      b.email?.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesType =
      selectedTypeFilter === 'ALL' || b.business_type === selectedTypeFilter;

    const matchesStatus =
      statusFilter === 'ALL' || b.status === statusFilter;

    return matchesSearch && matchesType && matchesStatus;
  });

  return (
    <div>
      <Navbar
        title="Mitra Toko Retail Syupeo"
        description="Kelola aktivasi Toko Retail, paket usaha perdana, inventori produk, dan titik lokasi seluruh mitra toko"
      />

      <div className="space-y-6 mt-6">
        {/* Toast Alert */}
        {successMsg && (
          <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <CheckCircle className="w-5 h-5 text-emerald-600" />
              <span>{successMsg}</span>
            </div>
            <button onClick={() => setSuccessMsg(null)}>
              <X className="w-4 h-4 text-emerald-600 hover:text-slate-900" />
            </button>
          </div>
        )}

        {/* Filter & Action Bar (Clean tanpa Plan) */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari nama toko, pemilik, kota, atau nomor WhatsApp..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-slate-300 text-slate-900 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-[#0070fc] shadow-xs"
            />
          </div>

          <div className="flex flex-wrap items-center gap-2.5">
            {/* Filter Template Tipe Usaha */}
            <select
              value={selectedTypeFilter}
              onChange={(e) => setSelectedTypeFilter(e.target.value)}
              className="px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-800 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-[#0070fc] shadow-xs"
            >
              <option value="ALL">Semua Tipe Usaha</option>
              {templates.map((t) => (
                <option key={t.code} value={t.code}>
                  {t.name}
                </option>
              ))}
            </select>

            {/* Filter Status Aktivasi */}
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-3 py-2 rounded-xl bg-white border border-slate-300 text-slate-800 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-[#0070fc] shadow-xs"
            >
              <option value="ALL">Semua Status</option>
              <option value="pending">Menunggu Aktivasi</option>
              <option value="active">Aktif</option>
            </select>

            {/* Tombol Daftarkan Toko Baru & Kirim Starter Kit */}
            <button
              type="button"
              onClick={() => {
                resetRegisterForm();
                setIsRegisterModalOpen(true);
              }}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-[#0070fc] hover:bg-[#005ecc] text-white text-xs font-bold transition-all shadow-sm"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Daftarkan Toko Baru</span>
            </button>
          </div>
        </div>

        {/* Table of Businesses */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          {loading ? (
            <div className="text-center py-20">
              <div className="w-8 h-8 border-2 border-[#0070fc] border-t-transparent rounded-full animate-spin mx-auto mb-3" />
              <p className="text-xs text-slate-500 font-medium">Memuat data toko retail...</p>
            </div>
          ) : filteredBusinesses.length === 0 ? (
            <div className="p-16 text-center text-slate-500 space-y-3">
              <Store className="w-10 h-10 text-slate-300 mx-auto" />
              <p className="text-sm font-semibold text-slate-700">Belum ada data toko retail terdaftar</p>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                Daftarkan toko retail perdana dengan paket usaha @ Rp 200.000 untuk memulai jaringan supply chain Anda.
              </p>
              <button
                type="button"
                onClick={() => {
                  resetRegisterForm();
                  setIsRegisterModalOpen(true);
                }}
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-[#0070fc] text-white rounded-xl text-xs font-bold hover:bg-blue-600 transition-all shadow-xs"
              >
                <PlusCircle className="w-4 h-4" />
                <span>+ Daftarkan Toko Baru Sekarang</span>
              </button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-50/80 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider text-[11px]">
                    <th className="py-3.5 px-5">Nama Toko & Pemilik</th>
                    <th className="py-3.5 px-5">Paket Usaha (Starter Kit)</th>
                    <th className="py-3.5 px-5">Wilayah & Titik GPS</th>
                    <th className="py-3.5 px-5">Tipe Usaha</th>
                    <th className="py-3.5 px-5">Status</th>
                    <th className="py-3.5 px-5 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredBusinesses.map((b) => {
                    const linkedKit = b.retail_starter_kits;
                    return (
                      <tr key={b.id} className="hover:bg-slate-50/70 transition-colors">
                        {/* Nama Toko & Pemilik */}
                        <td className="py-3.5 px-5">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-xl bg-blue-50 text-[#0070fc] border border-blue-200 flex items-center justify-center font-bold text-sm shrink-0">
                              {b.name?.charAt(0)?.toUpperCase() || 'T'}
                            </div>
                            <div className="min-w-0">
                              <Link
                                href={`/dashboard/businesses/${b.id}`}
                                className="font-bold text-slate-900 hover:text-[#0070fc] transition-colors truncate block group"
                              >
                                <span className="group-hover:underline">{b.name}</span>
                              </Link>
                              <div className="text-[11px] text-slate-500 flex items-center gap-2 mt-0.5">
                                <span>{b.owner_name || 'Pemilik'}</span>
                                {b.phone && (
                                  <>
                                    <span>•</span>
                                    <span className="font-mono text-slate-600">{b.phone}</span>
                                  </>
                                )}
                              </div>
                            </div>
                          </div>
                        </td>

                        {/* Paket Usaha (Starter Kit) */}
                        <td className="py-3.5 px-5">
                          {linkedKit ? (
                            <div className="space-y-1">
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                                <Package className="w-3 h-3 text-amber-600" />
                                <span>{linkedKit.name}</span>
                              </span>
                              <div className="text-[10px] text-emerald-600 font-bold">
                                Rp {Number(linkedKit.price).toLocaleString('id-ID')}
                              </div>
                            </div>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-600">
                              Toko Mandiri
                            </span>
                          )}
                        </td>

                        {/* Wilayah & Titik GPS */}
                        <td className="py-3.5 px-5">
                          <div className="space-y-0.5">
                            <div className="font-medium text-slate-800 flex items-center gap-1">
                              <MapPin className="w-3 h-3 text-[#0070fc] shrink-0" />
                              <span className="truncate max-w-[180px]">
                                {b.city || 'Indonesia'}{b.district ? `, ${b.district}` : ''}
                              </span>
                            </div>
                            {b.latitude && b.longitude ? (
                              <a
                                href={`https://www.google.com/maps/search/?api=1&query=${b.latitude},${b.longitude}`}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 text-[10px] font-mono text-blue-600 hover:underline"
                              >
                                <Navigation className="w-2.5 h-2.5" />
                                <span>{b.latitude.toFixed(4)}, {b.longitude.toFixed(4)}</span>
                              </a>
                            ) : (
                              <span className="text-[10px] text-slate-400 italic">GPS belum diset</span>
                            )}
                          </div>
                        </td>

                        {/* Tipe Usaha */}
                        <td className="py-3.5 px-5">
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[11px] font-semibold bg-slate-100 text-slate-700 border border-slate-200 capitalize">
                            {b.business_type || 'Retail'}
                          </span>
                        </td>

                        {/* Status Toko */}
                        <td className="py-3.5 px-5">
                          {b.status === 'pending' ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                              <Clock className="w-3 h-3 text-amber-600" />
                              <span>Menunggu Aktivasi</span>
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                              <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                              <span>Aktif</span>
                            </span>
                          )}
                        </td>

                        {/* Aksi */}
                        <td className="py-3.5 px-5 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {b.status === 'pending' && (
                              <button
                                onClick={() => handleActivateBusiness(b)}
                                disabled={isUpdating}
                                className="px-2.5 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white transition-all flex items-center gap-1.5 shadow-2xs"
                                title="Aktivasi Akun Toko Sekarang"
                              >
                                <UserCheck className="w-3.5 h-3.5" />
                                <span>Aktivasi</span>
                              </button>
                            )}

                            <Link
                              href={`/dashboard/businesses/${b.id}`}
                              className="px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-700 transition-all flex items-center gap-1.5 shadow-2xs"
                              title="Buka Detail Toko"
                            >
                              <Eye className="w-3.5 h-3.5 text-slate-600" />
                              <span>Detail</span>
                            </Link>

                            <button
                              onClick={() => handleDeleteBusiness(b)}
                              className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 transition-colors"
                              title="Hapus Toko"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ======================================================== */}
        {/* MODAL: DAFTARKAN TOKO RETAIL BARU & STARTER KIT         */}
        {/* ======================================================== */}
        {isRegisterModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white w-full max-w-2xl rounded-2xl p-6 border border-slate-200 shadow-2xl relative max-h-[90vh] overflow-y-auto space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="w-9 h-9 rounded-xl bg-blue-50 text-[#0070fc] flex items-center justify-center font-bold">
                    <Store className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Daftarkan Toko Retail & Starter Kit</h3>
                    <p className="text-xs text-slate-500">Auto-seed katalog stok perdana & terbitkan pengiriman dari gudang terdekat</p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setIsRegisterModalOpen(false)}
                  className="p-1 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {errorMsg && (
                <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <form onSubmit={handleRegisterStore} className="space-y-4 text-xs">
                {/* 1. Informasi Toko & Pemilik */}
                <div className="bg-slate-50 border border-slate-200 rounded-xl p-3.5 space-y-3">
                  <h4 className="font-bold text-slate-800 flex items-center gap-1.5">
                    <UserCheck className="w-4 h-4 text-[#0070fc]" />
                    <span>Informasi Toko & Pemilik</span>
                  </h4>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block font-semibold text-slate-700 mb-1">Nama Toko Retail</label>
                      <input
                        type="text"
                        required
                        placeholder="Contoh: Toko Berkah Mandiri"
                        value={formStoreName}
                        onChange={(e) => setFormStoreName(e.target.value)}
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                      />
                    </div>
                    <div>
                      <label className="block font-semibold text-slate-700 mb-1">Nama Pemilik / PIC</label>
                      <input
                        type="text"
                        required
                        placeholder="Contoh: Ibu Hj. Siti Aminah"
                        value={formOwnerName}
                        onChange={(e) => setFormOwnerName(e.target.value)}
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                      />
                    </div>

                    <div>
                      <label className="block font-semibold text-slate-700 mb-1">No. WhatsApp Pemilik</label>
                      <input
                        type="tel"
                        required
                        placeholder="Contoh: 0812-3456-7890"
                        value={formPhone}
                        onChange={(e) => setFormPhone(e.target.value)}
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                      />
                    </div>
                    <div>
                      <label className="block font-semibold text-slate-700 mb-1">Email Pemilik (Opsional)</label>
                      <input
                        type="email"
                        placeholder="Otomatis dibuat jika kosong"
                        value={formEmail}
                        onChange={(e) => setFormEmail(e.target.value)}
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                      />
                    </div>
                  </div>
                </div>

                {/* 2. Pilihan Starter Kit Perdana (@ Rp 200.000) */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <label className="block font-bold text-slate-800 flex items-center gap-1.5">
                      <Package className="w-4 h-4 text-[#ba8c02]" />
                      <span>Pilih Paket Usaha (Starter Kit) Perdana</span>
                    </label>
                    <span className="text-[11px] font-bold text-blue-700 bg-blue-50 px-2 py-0.5 rounded border border-blue-200">
                      Modal Rp 200.000
                    </span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                    {starterKits.map((kit) => {
                      const isSelected = formStarterKitId === kit.id;
                      const itemCount = Array.isArray(kit.items_included) ? kit.items_included.length : 0;
                      return (
                        <div
                          key={kit.id}
                          onClick={() => setFormStarterKitId(kit.id)}
                          className={`p-3 rounded-xl border cursor-pointer transition-all flex flex-col justify-between ${
                            isSelected
                              ? 'bg-blue-50/70 border-[#0070fc] ring-2 ring-blue-100 shadow-xs'
                              : 'bg-white border-slate-200 hover:border-slate-300'
                          }`}
                        >
                          <div>
                            <div className="flex items-center justify-between gap-1 mb-1">
                              <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-slate-100 text-slate-700">
                                {kit.badge || 'Starter Kit'}
                              </span>
                              {isSelected && <Check className="w-3.5 h-3.5 text-[#0070fc]" />}
                            </div>
                            <h5 className="font-bold text-slate-900 leading-snug">{kit.name}</h5>
                            <p className="text-[11px] text-slate-500 mt-1 line-clamp-2">{kit.description}</p>
                          </div>

                          <div className="mt-2.5 pt-2 border-t border-slate-100 flex items-center justify-between text-[11px]">
                            <span className="font-bold text-emerald-600">
                              Rp {Number(kit.price).toLocaleString('id-ID')}
                            </span>
                            <span className="text-slate-500 font-mono">
                              {itemCount > 0 ? `${itemCount} Produk` : 'Siap Jual'}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* 3. Lokasi Toko: Wilayah Administratif & GPS */}
                <div className="space-y-3">
                  <WilayahSelector
                    initialProvince={formProvince}
                    initialCity={formCity}
                    initialDistrict={formDistrict}
                    initialVillage={formVillage}
                    onChange={(sel: WilayahSelection) => {
                      setFormProvince(sel.provinceName);
                      setFormCity(sel.regencyName);
                      setFormDistrict(sel.districtName);
                      setFormVillage(sel.villageName);
                      if (!formAddress && sel.formattedText) {
                        setFormAddress(sel.formattedText);
                      }
                    }}
                  />

                  <GooglePlacesAutocomplete
                    initialAddress={formAddress}
                    initialLat={formLat}
                    initialLng={formLng}
                    placeholder="Cari patokan toko / jalan via Google Places..."
                    onSelectPlace={(place: PlaceResult) => {
                      setFormAddress(place.formattedAddress);
                      setFormLat(place.latitude);
                      setFormLng(place.longitude);
                    }}
                  />

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Alamat Fisik Lengkap Toko</label>
                    <textarea
                      required
                      rows={2}
                      placeholder="Jalan, nomor rumah, RT/RW, patokan depan toko untuk supir pengiriman..."
                      value={formAddress}
                      onChange={(e) => setFormAddress(e.target.value)}
                      className="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0070fc]"
                    />
                  </div>
                </div>

                {/* 4. Status Pembayaran */}
                <div className="p-3 bg-amber-50/70 border border-amber-200 rounded-xl space-y-2">
                  <label className="block font-bold text-amber-900">Status Pembayaran Starter Kit (Rp 200.000)</label>
                  <div className="grid grid-cols-3 gap-2">
                    {[
                      { id: 'paid_cash', label: 'Lunas (Tunai ke Sales)' },
                      { id: 'paid_transfer', label: 'Lunas (Transfer Rekening)' },
                      { id: 'pending', label: 'Pending (Menunggu Bayar)' },
                    ].map((st) => (
                      <button
                        key={st.id}
                        type="button"
                        onClick={() => setFormPaymentStatus(st.id as any)}
                        className={`py-2 px-2.5 rounded-lg text-[11px] font-bold border transition-all text-center ${
                          formPaymentStatus === st.id
                            ? 'bg-amber-600 border-amber-600 text-white shadow-xs'
                            : 'bg-white border-amber-200 text-amber-900 hover:bg-amber-100/60'
                        }`}
                      >
                        {st.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Tombol Aksi */}
                <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2.5">
                  <button
                    type="button"
                    onClick={() => setIsRegisterModalOpen(false)}
                    className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold transition-colors"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="px-5 py-2 rounded-xl bg-[#0070fc] hover:bg-[#005ecc] text-white font-bold transition-all shadow-md shadow-blue-500/20 flex items-center gap-2 disabled:opacity-60"
                  >
                    {isSubmitting && <Loader2 className="w-4 h-4 animate-spin" />}
                    <Truck className="w-4 h-4" />
                    <span>Daftarkan & Terbitkan Pengiriman</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
