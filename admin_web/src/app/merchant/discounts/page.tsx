'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { Discount } from '@/types/database';
import {
  Tag,
  Plus,
  Search,
  Filter,
  Edit2,
  Trash2,
  Calendar,
  CheckCircle2,
  Clock,
  AlertCircle,
  Copy,
  Percent,
  DollarSign,
  Sparkles,
  RefreshCw,
  X,
  ToggleLeft,
  ToggleRight,
} from 'lucide-react';

export default function MerchantDiscountsPage() {
  const { business } = useMerchant();

  const [discounts, setDiscounts] = useState<Discount[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'upcoming' | 'expired'>('all');

  // Modal State
  const [modalOpen, setModalOpen] = useState(false);
  const [editingDiscount, setEditingDiscount] = useState<Discount | null>(null);
  const [saving, setSaving] = useState(false);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  // Form Fields
  const [formName, setFormName] = useState('');
  const [formCode, setFormCode] = useState('');
  const [formType, setFormType] = useState<'percentage' | 'fixed_amount'>('percentage');
  const [formPercentage, setFormPercentage] = useState<number>(10);
  const [formAmount, setFormAmount] = useState<number>(5000);
  const [formMaxDiscount, setFormMaxDiscount] = useState<number | ''>('');
  const [formUseSchedule, setFormUseSchedule] = useState(false);
  const [formStartsAt, setFormStartsAt] = useState('');
  const [formEndsAt, setFormEndsAt] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formIsActive, setFormIsActive] = useState(true);

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadDiscounts = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();
      const { data, error } = await supabase
        .from('discounts')
        .select('*')
        .eq('business_id', business.id)
        .order('is_active', { ascending: false })
        .order('created_at', { ascending: false });

      if (!error && data) {
        setDiscounts(data);
      }
    } catch (err) {
      console.error('Error fetching discounts:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDiscounts();
  }, [business?.id]);

  const handleCopyCode = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const handleOpenModal = (disc?: Discount) => {
    if (disc) {
      setEditingDiscount(disc);
      setFormName(disc.name);
      setFormCode(disc.code || '');
      setFormType(disc.type);
      setFormPercentage(disc.percentage_value || 10);
      setFormAmount(disc.amount_value || 5000);
      setFormMaxDiscount(disc.max_discount_amount || '');
      setFormUseSchedule(Boolean(disc.starts_at || disc.ends_at));
      setFormStartsAt(disc.starts_at ? disc.starts_at.split('T')[0] : '');
      setFormEndsAt(disc.ends_at ? disc.ends_at.split('T')[0] : '');
      setFormDescription(disc.description || '');
      setFormIsActive(disc.is_active);
    } else {
      setEditingDiscount(null);
      setFormName('');
      setFormCode('');
      setFormType('percentage');
      setFormPercentage(10);
      setFormAmount(5000);
      setFormMaxDiscount('');
      setFormUseSchedule(false);
      setFormStartsAt('');
      setFormEndsAt('');
      setFormDescription('');
      setFormIsActive(true);
    }
    setModalOpen(true);
  };

  const handleToggleActive = async (disc: Discount) => {
    if (!business) return;
    try {
      const supabase = createClient();
      const newActive = !disc.is_active;
      await supabase
        .from('discounts')
        .update({ is_active: newActive, updated_at: new Date().toISOString() })
        .eq('id', disc.id);

      setDiscounts((prev) =>
        prev.map((d) => (d.id === disc.id ? { ...d, is_active: newActive } : d))
      );
    } catch (err) {
      console.error('Error toggling active discount:', err);
    }
  };

  const handleDeleteDiscount = async (id: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus promo/diskon ini?')) return;
    try {
      const supabase = createClient();
      await supabase.from('discounts').delete().eq('id', id);
      loadDiscounts();
    } catch (err) {
      console.error('Error deleting discount:', err);
    }
  };

  const handleSaveDiscount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business || !formName) return;

    try {
      setSaving(true);
      const supabase = createClient();

      const payload = {
        name: formName.trim(),
        code: formCode.trim() ? formCode.trim().toUpperCase() : null,
        type: formType,
        percentage_value: formType === 'percentage' ? Number(formPercentage) : null,
        amount_value: formType === 'fixed_amount' ? Number(formAmount) : null,
        max_discount_amount:
          formType === 'percentage' && formMaxDiscount !== ''
            ? Number(formMaxDiscount)
            : null,
        is_active: formIsActive,
        starts_at: formUseSchedule && formStartsAt ? new Date(formStartsAt).toISOString() : null,
        ends_at: formUseSchedule && formEndsAt ? new Date(`${formEndsAt}T23:59:59`).toISOString() : null,
        description: formDescription.trim() || null,
        updated_at: new Date().toISOString(),
      };

      if (editingDiscount) {
        await supabase.from('discounts').update(payload).eq('id', editingDiscount.id);
      } else {
        await supabase.from('discounts').insert({
          business_id: business.id,
          created_at: new Date().toISOString(),
          ...payload,
        });
      }

      setModalOpen(false);
      loadDiscounts();
    } catch (err) {
      console.error('Error saving discount:', err);
      alert('Gagal menyimpan promo diskon.');
    } finally {
      setSaving(false);
    }
  };

  // Helper status
  const now = new Date();
  const getDiscountStatus = (d: Discount) => {
    if (!d.is_active) return { label: 'Nonaktif', color: 'bg-slate-100 text-slate-600 border-slate-200' };
    if (d.starts_at && new Date(d.starts_at) > now) {
      return { label: 'Terjadwal', color: 'bg-blue-50 text-blue-700 border-blue-200' };
    }
    if (d.ends_at && new Date(d.ends_at) < now) {
      return { label: 'Berakhir', color: 'bg-red-50 text-red-700 border-red-200' };
    }
    return { label: 'Aktif', color: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
  };

  // Metrics
  const activeCount = discounts.filter((d) => d.is_active && (!d.ends_at || new Date(d.ends_at) >= now)).length;
  const percentageCount = discounts.filter((d) => d.type === 'percentage').length;
  const fixedCount = discounts.filter((d) => d.type === 'fixed_amount').length;

  // Filtered
  const filteredDiscounts = discounts.filter((d) => {
    const matchSearch =
      d.name.toLowerCase().includes(search.toLowerCase()) ||
      (d.code && d.code.toLowerCase().includes(search.toLowerCase()));

    const status = getDiscountStatus(d).label.toLowerCase();
    if (statusFilter === 'active' && status !== 'aktif') return false;
    if (statusFilter === 'upcoming' && status !== 'terjadwal') return false;
    if (statusFilter === 'expired' && (status !== 'berakhir' && status !== 'nonaktif')) return false;

    return matchSearch;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Promosi & Kampanye
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Manajemen Diskon & Promo
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Buat voucher diskon rupiah atau persentase yang tersinkronisasi otomatis dengan aplikasi kasir Syupeo
          </p>
        </div>

        <button
          onClick={() => handleOpenModal()}
          className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-2 shadow-sm shadow-orange-600/20 transition-all self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Promo Baru</span>
        </button>
      </div>

      {/* Metrics Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block">
              Promo Aktif Saat Ini
            </span>
            <div className="text-2xl font-black text-slate-900 mt-0.5">{activeCount} Promo</div>
            <span className="text-[11px] text-emerald-600 font-semibold">Siap digunakan di kasir</span>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Percent className="w-6 h-6" />
          </div>
          <div>
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block">
              Tipe Persentase (%)
            </span>
            <div className="text-2xl font-black text-slate-900 mt-0.5">{percentageCount} Kupon</div>
            <span className="text-[11px] text-slate-400">Potongan persen dengan opsi batas</span>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center flex-shrink-0">
            <DollarSign className="w-6 h-6" />
          </div>
          <div>
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block">
              Tipe Potongan Tetap (Rp)
            </span>
            <div className="text-2xl font-black text-slate-900 mt-0.5">{fixedCount} Kupon</div>
            <span className="text-[11px] text-slate-400">Nominal rupiah langsung</span>
          </div>
        </div>
      </div>

      {/* Filter Tabs & Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        {/* Status Filter Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl overflow-x-auto text-xs font-bold text-slate-600 w-full sm:w-auto">
          <button
            onClick={() => setStatusFilter('all')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'all' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
            }`}
          >
            Semua ({discounts.length})
          </button>
          <button
            onClick={() => setStatusFilter('active')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'active' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
            }`}
          >
            Aktif
          </button>
          <button
            onClick={() => setStatusFilter('upcoming')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'upcoming' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
            }`}
          >
            Terjadwal
          </button>
          <button
            onClick={() => setStatusFilter('expired')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'expired' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
            }`}
          >
            Nonaktif / Berakhir
          </button>
        </div>

        {/* Search Input */}
        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari promo atau kode kupon..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
          />
        </div>
      </div>

      {/* Discounts Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4">Nama Diskon & Kupon</th>
                <th className="py-3 px-4">Nilai Potongan</th>
                <th className="py-3 px-4">Masa Berlaku</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-center">Saklar Aktif</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat daftar diskon...</span>
                  </td>
                </tr>
              ) : filteredDiscounts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    Belum ada diskon atau promo yang sesuai.
                  </td>
                </tr>
              ) : (
                filteredDiscounts.map((disc) => {
                  const status = getDiscountStatus(disc);
                  return (
                    <tr key={disc.id} className="hover:bg-slate-50/60 transition-colors">
                      {/* Name & Code */}
                      <td className="py-3.5 px-4">
                        <div>
                          <span className="font-bold text-slate-900 block text-xs sm:text-sm">
                            {disc.name}
                          </span>
                          {disc.code ? (
                            <div className="flex items-center gap-1.5 mt-0.5">
                              <span className="font-mono bg-orange-50 text-orange-700 px-2 py-0.5 rounded text-[10px] font-bold border border-orange-200">
                                {disc.code}
                              </span>
                              <button
                                onClick={() => handleCopyCode(disc.code!)}
                                title="Salin Kode Kupon"
                                className="text-slate-400 hover:text-slate-600 p-0.5"
                              >
                                <Copy className="w-3 h-3" />
                              </button>
                              {copiedCode === disc.code && (
                                <span className="text-[10px] text-emerald-600 font-bold">Disalin!</span>
                              )}
                            </div>
                          ) : (
                            <span className="text-[10px] text-slate-400 italic">Diskon Otomatis / Manual</span>
                          )}
                          {disc.description && (
                            <p className="text-[10px] text-slate-500 mt-1 line-clamp-1">{disc.description}</p>
                          )}
                        </div>
                      </td>

                      {/* Value */}
                      <td className="py-3.5 px-4">
                        {disc.type === 'percentage' ? (
                          <div>
                            <span className="font-black text-orange-600 text-sm">
                              {disc.percentage_value}%
                            </span>
                            {disc.max_discount_amount && (
                              <span className="text-[10px] text-slate-400 block mt-0.5">
                                Maks. {formatRupiah(disc.max_discount_amount)}
                              </span>
                            )}
                          </div>
                        ) : (
                          <div>
                            <span className="font-black text-slate-900 text-sm">
                              {formatRupiah(disc.amount_value || 0)}
                            </span>
                            <span className="text-[10px] text-slate-400 block mt-0.5">Potongan Langsung</span>
                          </div>
                        )}
                      </td>

                      {/* Schedule */}
                      <td className="py-3.5 px-4 text-slate-600">
                        {disc.starts_at || disc.ends_at ? (
                          <div className="space-y-0.5 text-[11px]">
                            {disc.starts_at && (
                              <div className="flex items-center gap-1 text-slate-500">
                                <span>Mulai:</span>
                                <span className="font-medium text-slate-800">
                                  {new Date(disc.starts_at).toLocaleDateString('id-ID', {
                                    day: 'numeric',
                                    month: 'short',
                                    year: 'numeric',
                                  })}
                                </span>
                              </div>
                            )}
                            {disc.ends_at && (
                              <div className="flex items-center gap-1 text-slate-500">
                                <span>Selesai:</span>
                                <span className="font-medium text-slate-800">
                                  {new Date(disc.ends_at).toLocaleDateString('id-ID', {
                                    day: 'numeric',
                                    month: 'short',
                                    year: 'numeric',
                                  })}
                                </span>
                              </div>
                            )}
                          </div>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-500">
                            <Clock className="w-3 h-3 text-slate-400" />
                            <span>Berlaku Seterusnya</span>
                          </span>
                        )}
                      </td>

                      {/* Status Badge */}
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-block px-2.5 py-0.5 rounded-full font-bold text-[10px] border ${status.color}`}
                        >
                          {status.label}
                        </span>
                      </td>

                      {/* Switch */}
                      <td className="py-3.5 px-4 text-center">
                        <button
                          onClick={() => handleToggleActive(disc)}
                          title={disc.is_active ? 'Klik untuk nonaktifkan' : 'Klik untuk aktifkan'}
                          className="transition-transform active:scale-95"
                        >
                          {disc.is_active ? (
                            <ToggleRight className="w-6 h-6 text-orange-600 inline" />
                          ) : (
                            <ToggleLeft className="w-6 h-6 text-slate-300 inline" />
                          )}
                        </button>
                      </td>

                      {/* Actions */}
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => handleOpenModal(disc)}
                            title="Edit Promo"
                            className="p-1.5 text-slate-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDeleteDiscount(disc.id)}
                            title="Hapus Promo"
                            className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
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

      {/* Modal Add / Edit Discount */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs overflow-y-auto">
          <div className="bg-white w-full max-w-lg rounded-2xl border border-slate-200 shadow-2xl overflow-hidden my-8">
            <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center">
                  <Tag className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-slate-900 text-base">
                    {editingDiscount ? 'Edit Promo Diskon' : 'Buat Promo Diskon Baru'}
                  </h3>
                  <p className="text-xs text-slate-500">Tentukan aturan potongan harga untuk kasir</p>
                </div>
              </div>
              <button
                onClick={() => setModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveDiscount} className="p-5 space-y-4">
              {/* Nama Diskon */}
              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">
                  Nama Promo / Diskon <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  required
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="Contoh: Diskon Gajian, Promo Jumat Berkah"
                  className="w-full text-xs font-medium px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                />
              </div>

              {/* Kode Voucher */}
              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">
                  Kode Kupon / Voucher <span className="text-slate-400 font-normal">(Opsional)</span>
                </label>
                <input
                  type="text"
                  value={formCode}
                  onChange={(e) => setFormCode(e.target.value.toUpperCase())}
                  placeholder="Contoh: HEMAT10, GAJIAN50"
                  className="w-full font-mono uppercase text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                />
                <span className="text-[10px] text-slate-400 mt-1 block">
                  Kosongkan jika ingin promo ini dapat dipilih langsung oleh kasir tanpa ketik kode
                </span>
              </div>

              {/* Tipe Diskon Selection */}
              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1.5">
                  Tipe Potongan Harga <span className="text-red-500">*</span>
                </label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setFormType('percentage')}
                    className={`p-3 rounded-xl border text-left flex items-start gap-2.5 transition-all ${
                      formType === 'percentage'
                        ? 'border-orange-500 bg-orange-50/50 text-orange-950 font-bold'
                        : 'border-slate-200 hover:border-slate-300 text-slate-700'
                    }`}
                  >
                    <Percent className="w-4 h-4 text-orange-600 mt-0.5 flex-shrink-0" />
                    <div>
                      <div className="text-xs">Persentase (%)</div>
                      <span className="text-[10px] font-normal text-slate-500 block mt-0.5">
                        Potongan berdasarkan % dari total
                      </span>
                    </div>
                  </button>

                  <button
                    type="button"
                    onClick={() => setFormType('fixed_amount')}
                    className={`p-3 rounded-xl border text-left flex items-start gap-2.5 transition-all ${
                      formType === 'fixed_amount'
                        ? 'border-orange-500 bg-orange-50/50 text-orange-950 font-bold'
                        : 'border-slate-200 hover:border-slate-300 text-slate-700'
                    }`}
                  >
                    <DollarSign className="w-4 h-4 text-orange-600 mt-0.5 flex-shrink-0" />
                    <div>
                      <div className="text-xs">Nominal Tetap (Rp)</div>
                      <span className="text-[10px] font-normal text-slate-500 block mt-0.5">
                        Potongan harga rupiah langsung
                      </span>
                    </div>
                  </button>
                </div>
              </div>

              {/* Input Nilai Diskon */}
              {formType === 'percentage' ? (
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-bold text-slate-700 block mb-1">
                      Besar Persen (%) <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        min="1"
                        max="100"
                        required
                        value={formPercentage}
                        onChange={(e) => setFormPercentage(Number(e.target.value))}
                        className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                      />
                      <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                        %
                      </span>
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-bold text-slate-700 block mb-1">
                      Maksimal Diskon (Rp) <span className="text-slate-400 font-normal">(Opsional)</span>
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={formMaxDiscount}
                      onChange={(e) => setFormMaxDiscount(e.target.value === '' ? '' : Number(e.target.value))}
                      placeholder="Contoh: 20000"
                      className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                    />
                  </div>
                </div>
              ) : (
                <div>
                  <label className="text-xs font-bold text-slate-700 block mb-1">
                    Nominal Potongan (Rp) <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="number"
                    min="100"
                    required
                    value={formAmount}
                    onChange={(e) => setFormAmount(Number(e.target.value))}
                    placeholder="Contoh: 10000"
                    className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                  />
                </div>
              )}

              {/* Masa Berlaku Schedule */}
              <div className="border border-slate-200 rounded-xl p-3.5 space-y-3 bg-slate-50/50">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formUseSchedule}
                    onChange={(e) => setFormUseSchedule(e.target.checked)}
                    className="w-4 h-4 text-orange-600 rounded border-slate-300 focus:ring-orange-500"
                  />
                  <span className="text-xs font-bold text-slate-800">
                    Atur Jadwal Tanggal Mulai & Berakhir
                  </span>
                </label>

                {formUseSchedule && (
                  <div className="grid grid-cols-2 gap-3 pt-1">
                    <div>
                      <span className="text-[11px] font-semibold text-slate-600 block mb-1">
                        Tanggal Mulai
                      </span>
                      <input
                        type="date"
                        value={formStartsAt}
                        onChange={(e) => setFormStartsAt(e.target.value)}
                        className="w-full text-xs font-semibold px-3 py-2 bg-white rounded-lg border border-slate-200"
                      />
                    </div>
                    <div>
                      <span className="text-[11px] font-semibold text-slate-600 block mb-1">
                        Tanggal Berakhir
                      </span>
                      <input
                        type="date"
                        value={formEndsAt}
                        onChange={(e) => setFormEndsAt(e.target.value)}
                        className="w-full text-xs font-semibold px-3 py-2 bg-white rounded-lg border border-slate-200"
                      />
                    </div>
                  </div>
                )}
              </div>

              {/* Status Aktif */}
              <div className="flex items-center justify-between p-3 border border-slate-200 rounded-xl">
                <div>
                  <span className="text-xs font-bold text-slate-800 block">Status Promo Aktif</span>
                  <span className="text-[10px] text-slate-500">
                    Hanya promo aktif yang dapat diterapkan di kasir
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => setFormIsActive(!formIsActive)}
                  className="transition-transform active:scale-95"
                >
                  {formIsActive ? (
                    <ToggleRight className="w-7 h-7 text-orange-600" />
                  ) : (
                    <ToggleLeft className="w-7 h-7 text-slate-300" />
                  )}
                </button>
              </div>

              {/* Deskripsi */}
              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">
                  Deskripsi / Catatan Promo <span className="text-slate-400 font-normal">(Opsional)</span>
                </label>
                <textarea
                  rows={2}
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  placeholder="Contoh: Khusus pembelian minimal Rp 50.000, tidak dapat digabung promo lain"
                  className="w-full text-xs font-medium px-3.5 py-2 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 resize-none"
                />
              </div>

              {/* Footer */}
              <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setModalOpen(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2 text-xs font-bold text-white bg-orange-600 hover:bg-orange-700 rounded-xl shadow-sm shadow-orange-600/20 transition-all flex items-center gap-1.5"
                >
                  {saving && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  <span>{editingDiscount ? 'Simpan Perubahan' : 'Buat Promo'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
