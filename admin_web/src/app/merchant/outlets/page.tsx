'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { Outlet } from '@/types/database';
import {
  Store,
  Plus,
  MapPin,
  Phone,
  CheckCircle2,
  XCircle,
  RefreshCw,
  Edit2,
  Trash2,
  X,
  Building2,
  Lock,
} from 'lucide-react';

export default function MerchantOutletsPage() {
  const { business, outlets: contextOutlets, refreshData } = useMerchant();

  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingOutlet, setEditingOutlet] = useState<Outlet | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const [formData, setFormData] = useState({
    name: '',
    code: '',
    address: '',
    phone: '',
  });

  const loadOutlets = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();
      const { data, error } = await supabase
        .from('outlets')
        .select('*')
        .eq('business_id', business.id)
        .order('created_at', { ascending: true });

      if (!error && data) {
        setOutlets(data);
      }
    } catch (err) {
      console.error('Error fetching outlets:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOutlets();
  }, [business?.id]);

  const maxOutlets = business?.max_outlets || 1;
  const isLimitReached = outlets.length >= maxOutlets;

  // Open Form
  const openForm = (outlet?: Outlet) => {
    if (outlet) {
      setEditingOutlet(outlet);
      setFormData({
        name: outlet.name,
        code: outlet.code || '',
        address: outlet.address || '',
        phone: outlet.phone || '',
      });
    } else {
      if (isLimitReached) {
        alert(
          `Kuota outlet paket toko Anda (${maxOutlets} cabang) telah terpenuhi. Silakan hubungi admin untuk upgrade ke paket PRO.`
        );
        return;
      }
      setEditingOutlet(null);
      setFormData({
        name: '',
        code: `CBG-${outlets.length + 1}`,
        address: '',
        phone: '',
      });
    }
    setIsModalOpen(true);
  };

  // Save Outlet
  const handleSaveOutlet = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    if (!formData.name.trim()) {
      alert('Nama cabang wajib diisi.');
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();

      const payload = {
        business_id: business.id,
        name: formData.name.trim(),
        code: formData.code.trim() || null,
        address: formData.address.trim() || null,
        phone: formData.phone.trim() || null,
        is_active: true,
      };

      if (editingOutlet) {
        const { error } = await supabase
          .from('outlets')
          .update(payload)
          .eq('id', editingOutlet.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('outlets').insert([payload]);
        if (error) throw error;
      }

      setIsModalOpen(false);
      loadOutlets();
      refreshData();
    } catch (err: any) {
      console.error('Error saving outlet:', err);
      alert('Gagal menyimpan cabang: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Toggle Active
  const handleToggleActive = async (outletId: string, currentStatus: boolean) => {
    if (outlets.length <= 1 && currentStatus) {
      alert('Anda harus memiliki minimal 1 outlet aktif.');
      return;
    }
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from('outlets')
        .update({ is_active: !currentStatus })
        .eq('id', outletId);
      if (error) throw error;
      loadOutlets();
      refreshData();
    } catch (err: any) {
      console.error('Error toggling outlet:', err);
      alert('Gagal mengubah status: ' + err.message);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Multi-Outlet Toko
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Kelola Cabang & Outlet
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Daftar cabang usaha, alamat operasional, dan pengaturan outlet toko
          </p>
        </div>

        <button
          onClick={() => openForm()}
          className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm transition-all self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Cabang</span>
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Total Cabang */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Cabang
            </span>
            <span className="text-xl font-black text-slate-900">
              {outlets.length} <span className="text-xs font-normal text-slate-500">Cabang</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Outlet yang terdaftar
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Store className="w-5 h-5" />
          </div>
        </div>

        {/* Cabang Aktif */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Cabang Beroperasi
            </span>
            <span className="text-xl font-black text-emerald-600">
              {outlets.filter((o) => o.is_active).length} <span className="text-xs font-normal text-slate-500">Aktif</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Dapat menerima pesanan & kasir
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <CheckCircle2 className="w-5 h-5" />
          </div>
        </div>

        {/* Kuota Outlet */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Batas Kuota Paket
            </span>
            <span className="text-xl font-black text-slate-900">
              {outlets.length} / {maxOutlets}{' '}
              <span className="text-xs font-normal text-slate-500">Outlet</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              {isLimitReached ? 'Kuota paket telah maksimal' : 'Slot cabang masih tersedia'}
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center flex-shrink-0">
            <Building2 className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Outlet Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {loading ? (
          <div className="col-span-full py-12 text-center text-slate-400 bg-white rounded-2xl border border-slate-200">
            <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
            <span>Memuat daftar cabang...</span>
          </div>
        ) : outlets.length === 0 ? (
          <div className="col-span-full py-12 text-center text-slate-400 bg-white rounded-2xl border border-slate-200">
            Belum ada cabang terdaftar.
          </div>
        ) : (
          outlets.map((outlet, idx) => (
            <div
              key={outlet.id}
              className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between space-y-4 hover:border-orange-300 transition-colors"
            >
              <div>
                <div className="flex items-start justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2.5">
                    <div className="w-9 h-9 rounded-xl bg-orange-50 text-orange-600 font-black flex items-center justify-center text-xs">
                      #{idx + 1}
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-900 text-sm">{outlet.name}</h3>
                      <span className="font-mono text-[10px] text-slate-400">
                        Kode: {outlet.code || 'UTAMA'}
                      </span>
                    </div>
                  </div>
                  <span
                    className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                      outlet.is_active
                        ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                        : 'bg-slate-100 text-slate-500'
                    }`}
                  >
                    {outlet.is_active ? 'Aktif' : 'Nonaktif'}
                  </span>
                </div>

                <div className="space-y-1.5 text-xs text-slate-600 mt-3 pt-3 border-t border-slate-100">
                  <div className="flex items-start gap-2">
                    <MapPin className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                    <span className="text-[11px] leading-relaxed">
                      {outlet.address || 'Alamat belum diatur'}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Phone className="w-3.5 h-3.5 text-slate-400 flex-shrink-0" />
                    <span className="text-[11px]">{outlet.phone || 'Nomor telepon belum diatur'}</span>
                  </div>
                </div>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                <button
                  onClick={() => handleToggleActive(outlet.id, outlet.is_active)}
                  className={`text-[11px] font-bold ${
                    outlet.is_active
                      ? 'text-slate-500 hover:text-rose-600'
                      : 'text-emerald-600 hover:text-emerald-700'
                  }`}
                >
                  {outlet.is_active ? 'Nonaktifkan' : 'Aktifkan'}
                </button>
                <button
                  onClick={() => openForm(outlet)}
                  className="px-3 py-1 text-xs font-bold rounded-lg border border-slate-200 hover:bg-slate-50 flex items-center gap-1 text-slate-700"
                >
                  <Edit2 className="w-3 h-3 text-slate-500" />
                  <span>Edit Info</span>
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Modal Tambah / Edit Cabang */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Outlet & Cabang
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  {editingOutlet ? 'Edit Informasi Cabang' : 'Tambah Cabang Baru'}
                </h3>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveOutlet} className="py-4 space-y-3.5 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Nama Cabang / Outlet *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Contoh: Cabang Pasar Baru, Outlet Mall"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Kode Cabang</label>
                <input
                  type="text"
                  value={formData.code}
                  onChange={(e) => setFormData({ ...formData, code: e.target.value })}
                  placeholder="CBG-01"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-mono focus:outline-none focus:border-orange-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Nomor Telepon Cabang</label>
                <input
                  type="text"
                  value={formData.phone}
                  onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                  placeholder="0812xxxx"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Alamat Lengkap</label>
                <textarea
                  rows={2}
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  placeholder="Jl. Merdeka No. 12..."
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Cabang'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
