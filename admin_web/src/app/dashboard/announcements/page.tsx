'use client';

import { useState, useEffect } from 'react';
import {
  Megaphone,
  Plus,
  Search,
  CheckCircle2,
  AlertTriangle,
  Info,
  Sparkles,
  MapPin,
  ExternalLink,
  Edit2,
  Trash2,
  Eye,
  RefreshCw,
  Power,
  ChevronRight,
  ShieldAlert,
} from 'lucide-react';
import {
  getAnnouncements,
  saveAnnouncement,
  toggleAnnouncementActive,
  deleteAnnouncement,
  AnnouncementItem,
} from './actions';

export default function AnnouncementsPage() {
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCriteria, setFilterCriteria] = useState<string>('all');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<Partial<AnnouncementItem> | null>(null);
  const [saving, setSaving] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Form states
  const [formTitle, setFormTitle] = useState('');
  const [formMessage, setFormMessage] = useState('');
  const [formBadgeText, setFormBadgeText] = useState('PENGUMUMAN FITUR BARU');
  const [formType, setFormType] = useState<'feature' | 'info' | 'warning' | 'promo'>('feature');
  const [formTargetCriteria, setFormTargetCriteria] = useState<'all' | 'missing_location' | 'free_plan' | 'pro_plan'>('missing_location');
  const [formActionLabel, setFormActionLabel] = useState('Atur Lokasi Sekarang');
  const [formActionTarget, setFormActionTarget] = useState('businessProfileEdit');
  const [formSecondaryLabel, setFormSecondaryLabel] = useState('Kelola Outlet');
  const [formSecondaryTarget, setFormSecondaryTarget] = useState('outletManagement');
  const [formIsActive, setFormIsActive] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await getAnnouncements();
      setAnnouncements(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const openCreateModal = () => {
    setEditingItem(null);
    setFormTitle('Pin Titik Lokasi & Direktori Web Online');
    setFormMessage('Toko Anda belum mengatur titik koordinat GPS. Kunci lokasi gerai Anda sekarang agar otomatis tampil di peta web direktori toko aktif dan siap menghitung radius delivery pelanggan.');
    setFormBadgeText('PENGUMUMAN FITUR BARU');
    setFormType('feature');
    setFormTargetCriteria('missing_location');
    setFormActionLabel('Atur Lokasi Sekarang');
    setFormActionTarget('businessProfileEdit');
    setFormSecondaryLabel('Kelola Outlet');
    setFormSecondaryTarget('outletManagement');
    setFormIsActive(true);
    setIsModalOpen(true);
  };

  const openEditModal = (item: AnnouncementItem) => {
    setEditingItem(item);
    setFormTitle(item.title);
    setFormMessage(item.message);
    setFormBadgeText(item.badge_text);
    setFormType(item.type);
    setFormTargetCriteria(item.target_criteria);
    setFormActionLabel(item.action_label);
    setFormActionTarget(item.action_target);
    setFormSecondaryLabel(item.secondary_action_label || '');
    setFormSecondaryTarget(item.secondary_action_target || '');
    setFormIsActive(item.is_active);
    setIsModalOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const res = await saveAnnouncement({
        id: editingItem?.id,
        title: formTitle,
        message: formMessage,
        badge_text: formBadgeText,
        type: formType,
        target_criteria: formTargetCriteria,
        action_type: 'route',
        action_label: formActionLabel,
        action_target: formActionTarget,
        secondary_action_label: formSecondaryLabel || null,
        secondary_action_target: formSecondaryTarget || null,
        is_active: formIsActive,
      });

      if (res.success) {
        setIsModalOpen(false);
        showToast(editingItem ? 'Pengumuman berhasil diperbarui!' : 'Pengumuman baru berhasil diterbitkan!');
        await loadData();
      } else {
        alert(res.error || 'Gagal menyimpan pengumuman');
      }
    } catch (err: any) {
      alert(err.message || 'Terjadi kesalahan');
    } finally {
      setSaving(false);
    }
  };

  const handleToggleActive = async (item: AnnouncementItem) => {
    const nextState = !item.is_active;
    // Optimistic UI update
    setAnnouncements((prev) =>
      prev.map((a) => (a.id === item.id ? { ...a, is_active: nextState } : a))
    );

    const res = await toggleAnnouncementActive(item.id, nextState);
    if (!res.success) {
      alert(res.error || 'Gagal mengubah status');
      await loadData();
    } else {
      showToast(`Pengumuman "${item.title}" ${nextState ? 'diaktifkan' : 'dinonaktifkan'}.`);
    }
  };

  const handleDelete = async (id: string, title: string) => {
    if (!confirm(`Hapus pengumuman "${title}"?`)) return;

    const res = await deleteAnnouncement(id);
    if (res.success) {
      showToast('Pengumuman berhasil dihapus');
      setAnnouncements((prev) => prev.filter((a) => a.id !== id));
    } else {
      alert(res.error || 'Gagal menghapus pengumuman');
    }
  };

  const filteredAnnouncements = announcements.filter((a) => {
    const matchSearch =
      a.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.message.toLowerCase().includes(searchQuery.toLowerCase());
    const matchCriteria = filterCriteria === 'all' || a.target_criteria === filterCriteria;
    return matchSearch && matchCriteria;
  });

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 text-white px-4 py-3 rounded-xl shadow-xl flex items-center gap-3 border border-slate-700 animate-in fade-in slide-in-from-bottom-4 duration-200">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
          <p className="text-sm font-medium">{toastMessage}</p>
        </div>
      )}

      {/* Header Halaman */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs">
        <div>
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-orange-50 border border-orange-200 flex items-center justify-center text-orange-600">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-slate-900 tracking-tight">
                Broadcast & Pengumuman Kasir
              </h1>
              <p className="text-xs text-slate-500">
                Kelola banner pengumuman fitur baru & pengingat konfigurasi toko di aplikasi kasir Flutter
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2.5">
          <button
            onClick={loadData}
            disabled={loading}
            className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
            title="Refresh Data"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={openCreateModal}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 active:bg-orange-800 text-white font-semibold text-xs tracking-wide shadow-sm hover:shadow transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Buat Pengumuman Baru</span>
          </button>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Cari judul pengumuman / pesan..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9.5 pr-4 py-2.5 rounded-xl border border-slate-200 bg-white text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 shadow-2xs"
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-1 sm:pb-0">
          <select
            value={filterCriteria}
            onChange={(e) => setFilterCriteria(e.target.value)}
            className="px-3 py-2.5 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 shadow-2xs"
          >
            <option value="all">Semua Kriteria Target</option>
            <option value="missing_location">Toko Belum Set Lokasi GPS</option>
            <option value="free_plan">Toko Paket Free</option>
            <option value="pro_plan">Toko Paket Pro</option>
          </select>
        </div>
      </div>

      {/* List Kartu Pengumuman */}
      {loading ? (
        <div className="p-12 text-center bg-white rounded-2xl border border-slate-200 shadow-xs">
          <RefreshCw className="w-8 h-8 mx-auto animate-spin text-orange-500" />
          <p className="mt-3 text-xs text-slate-500 font-medium">Memuat daftar pengumuman...</p>
        </div>
      ) : filteredAnnouncements.length === 0 ? (
        <div className="p-12 text-center bg-white rounded-2xl border border-slate-200 shadow-xs">
          <div className="w-12 h-12 rounded-full bg-orange-50 text-orange-500 flex items-center justify-center mx-auto mb-3">
            <Megaphone className="w-6 h-6" />
          </div>
          <h3 className="text-sm font-bold text-slate-800">Belum Ada Pengumuman</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
            {searchQuery
              ? 'Tidak ada pengumuman yang sesuai dengan pencarian Anda.'
              : 'Buat pengumuman pertama untuk mengingatkan merchant tentang fitur lokasi baru atau info sistem.'}
          </p>
          {!searchQuery && (
            <button
              onClick={openCreateModal}
              className="mt-4 px-4 py-2 rounded-xl bg-orange-600 text-white text-xs font-semibold hover:bg-orange-700"
            >
              Buat Pengumuman
            </button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {filteredAnnouncements.map((item) => {
            const isLocationTarget = item.target_criteria === 'missing_location';
            return (
              <div
                key={item.id}
                className={`bg-white rounded-2xl border transition-all shadow-xs ${
                  item.is_active
                    ? 'border-orange-200 hover:border-orange-300'
                    : 'border-slate-200 opacity-60 bg-slate-50/50'
                } p-5`}
              >
                <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                  {/* Bagian Kiri: Info Pengumuman */}
                  <div className="space-y-3 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-[10px] font-extrabold uppercase tracking-wider bg-orange-100 text-orange-700 border border-orange-200">
                        <Sparkles className="w-3 h-3" />
                        {item.badge_text}
                      </span>

                      {/* Target Pill */}
                      <span
                        className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-[10px] font-bold ${
                          isLocationTarget
                            ? 'bg-amber-100 text-amber-800 border border-amber-200'
                            : 'bg-blue-50 text-blue-700 border border-blue-200'
                        }`}
                      >
                        {isLocationTarget ? (
                          <>
                            <MapPin className="w-3 h-3 text-amber-600" />
                            Target: Toko Belum Ada Lokasi GPS
                          </>
                        ) : (
                          <>Target: {item.target_criteria.toUpperCase()}</>
                        )}
                      </span>

                      {/* Status Aktif */}
                      <span
                        className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-bold ${
                          item.is_active
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-slate-200 text-slate-600'
                        }`}
                      >
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            item.is_active ? 'bg-emerald-600 animate-pulse' : 'bg-slate-400'
                          }`}
                        />
                        {item.is_active ? 'Aktif Tayang' : 'Nonaktif'}
                      </span>
                    </div>

                    <div>
                      <h2 className="text-base font-bold text-slate-900 tracking-tight">
                        {item.title}
                      </h2>
                      <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                        {item.message}
                      </p>
                    </div>

                    {/* Preview Tombol Tindakan */}
                    <div className="flex flex-wrap items-center gap-2 pt-1">
                      <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-orange-600 text-white text-xs font-semibold">
                        <MapPin className="w-3.5 h-3.5" />
                        <span>{item.action_label}</span>
                        <ChevronRight className="w-3 h-3 opacity-70" />
                      </div>

                      {item.secondary_action_label && (
                        <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-300 bg-white text-slate-700 text-xs font-medium">
                          <span>{item.secondary_action_label}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Bagian Kanan: Kontrol Aksi & Switch Saklar */}
                  <div className="flex lg:flex-col items-center lg:items-end justify-between lg:justify-start gap-3 border-t lg:border-t-0 pt-3 lg:pt-0 border-slate-100">
                    <div className="flex items-center gap-2">
                      <span className="text-[11px] font-semibold text-slate-500">
                        {item.is_active ? 'Tayang di Kasir' : 'Mati'}
                      </span>
                      <button
                        type="button"
                        onClick={() => handleToggleActive(item)}
                        className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                          item.is_active ? 'bg-orange-600' : 'bg-slate-300'
                        }`}
                      >
                        <span
                          className={`inline-block h-5 w-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${
                            item.is_active ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => openEditModal(item)}
                        className="p-2 text-slate-600 hover:text-orange-600 hover:bg-orange-50 rounded-xl transition-colors"
                        title="Edit Pengumuman"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDelete(item.id, item.title)}
                        className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-xl transition-colors"
                        title="Hapus"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>

                {/* Simulasi Tampilan di HP / Layar Kasir */}
                <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-400">
                  <span className="flex items-center gap-1">
                    <Eye className="w-3.5 h-3.5 text-slate-400" />
                    Preview: Jika toko sudah set GPS, banner ini otomatis menghilang di kasir toko tersebut.
                  </span>
                  <span>Aksi: {item.action_target}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal Tambah / Edit Pengumuman */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl border border-slate-200 shadow-2xl w-full max-w-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-orange-100 text-orange-600 flex items-center justify-center">
                  <Megaphone className="w-4 h-4" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-slate-900">
                    {editingItem ? 'Edit Pengumuman Broadcast' : 'Buat Pengumuman Baru'}
                  </h2>
                  <p className="text-[11px] text-slate-500">
                    Atur pesan yang akan ditampilkan di aplikasi Toko Retail & Kasir Syupeo
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="w-8 h-8 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center text-sm"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSave} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">
                  Judul Pengumuman *
                </label>
                <input
                  type="text"
                  required
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  placeholder="Contoh: Pin Titik Lokasi & Direktori Web Online"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">
                  Isi Pesan Penjelasan *
                </label>
                <textarea
                  required
                  rows={3}
                  value={formMessage}
                  onChange={(e) => setFormMessage(e.target.value)}
                  placeholder="Jelaskan manfaat fitur baru ini bagi toko mereka..."
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-white text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5">
                    Badge Teks
                  </label>
                  <input
                    type="text"
                    value={formBadgeText}
                    onChange={(e) => setFormBadgeText(e.target.value)}
                    placeholder="PENGUMUMAN FITUR BARU"
                    className="w-full px-3.5 py-2 rounded-xl border border-slate-200 bg-white text-xs font-medium text-slate-800"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5">
                    Kriteria Target Penerima *
                  </label>
                  <select
                    value={formTargetCriteria}
                    onChange={(e: any) => setFormTargetCriteria(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-orange-500/20"
                  >
                    <option value="missing_location">
                      Hanya Toko Belum Set GPS (Auto Hilang Jika Diisi)
                    </option>
                    <option value="all">Semua Toko Terdaftar</option>
                    <option value="free_plan">Hanya Toko Paket Free</option>
                    <option value="pro_plan">Hanya Toko Paket Pro</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-slate-100">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5">
                    Teks Tombol Aksi Utama
                  </label>
                  <input
                    type="text"
                    required
                    value={formActionLabel}
                    onChange={(e) => setFormActionLabel(e.target.value)}
                    placeholder="Atur Lokasi Sekarang"
                    className="w-full px-3.5 py-2 rounded-xl border border-slate-200 bg-white text-xs font-medium text-slate-800"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5">
                    Target Route Aplikasi
                  </label>
                  <select
                    value={formActionTarget}
                    onChange={(e) => setFormActionTarget(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-white text-xs font-medium text-slate-800"
                  >
                    <option value="businessProfileEdit">Edit Profil Toko (Lokasi GPS)</option>
                    <option value="outletManagement">Daftar Outlet Toko</option>
                    <option value="subscription">Upgrade Paket Langganan</option>
                    <option value="dashboard">Dashboard Kasir</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center gap-2 pt-2">
                <input
                  type="checkbox"
                  id="modalIsActive"
                  checked={formIsActive}
                  onChange={(e) => setFormIsActive(e.target.checked)}
                  className="w-4 h-4 rounded text-orange-600 focus:ring-orange-500 border-slate-300"
                />
                <label htmlFor="modalIsActive" className="text-xs font-semibold text-slate-800 cursor-pointer">
                  Aktifkan & langsung tayangkan di aplikasi kasir sekarang
                </label>
              </div>

              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl border border-slate-200 text-slate-600 text-xs font-semibold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 active:bg-orange-800 text-white text-xs font-bold tracking-wide shadow-sm"
                >
                  {saving ? 'Menyimpan...' : editingItem ? 'Simpan Perubahan' : 'Terbitkan Pengumuman'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
