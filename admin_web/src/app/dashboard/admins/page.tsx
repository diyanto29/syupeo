'use client';

import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { AdminUser, Partner } from '@/types/database';
import {
  Shield,
  ShieldCheck,
  Crown,
  UserPlus,
  Search,
  Filter,
  Trash2,
  Edit2,
  CheckCircle,
  XCircle,
  AlertCircle,
  X,
  Mail,
  User,
  Power,
  RefreshCw,
  Users,
  Lock,
  KeyRound,
  UserCheck,
} from 'lucide-react';

const MASTER_EMAIL = 'diyanto2911@gmail.com';

export default function AdminManagementPage() {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [registeredProfiles, setRegisteredProfiles] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState<'ALL' | 'super_admin' | 'admin' | 'partner'>('ALL');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'active' | 'inactive'>('ALL');

  // Modal State: Add/Edit
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingAdmin, setEditingAdmin] = useState<AdminUser | null>(null);
  const [formEmail, setFormEmail] = useState('');
  const [formName, setFormName] = useState('');
  const [formRole, setFormRole] = useState<'super_admin' | 'admin' | 'partner'>('admin');
  const [formPartnerId, setFormPartnerId] = useState<string>('');
  const [formIsActive, setFormIsActive] = useState(true);
  const [formCanManageLicenses, setFormCanManageLicenses] = useState(false);

  // Modal State: Delete Confirm
  const [deletingAdmin, setDeletingAdmin] = useState<AdminUser | null>(null);

  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  const supabase = createClient();

  const fetchAdmins = async () => {
    try {
      setLoading(true);
      setActionError(null);
      const { data, error } = await supabase
        .from('admin_users')
        .select('*, partners(*)')
        .order('created_at', { ascending: false });

      if (error) {
        throw error;
      }

      const { data: partnerData } = await supabase
        .from('partners')
        .select('*')
        .order('name', { ascending: true });

      // Ambil juga profil terdaftar dari public.profiles untuk quick-picker tambah admin
      try {
        const { data: profData } = await supabase
          .from('profiles')
          .select('id, full_name, email, role')
          .order('created_at', { ascending: false });
        if (profData) {
          setRegisteredProfiles(profData);
        }
      } catch (e) {
        console.warn('Could not fetch profiles:', e);
      }

      let adminList: AdminUser[] = (data as AdminUser[]) || [];

      // Pastikan Master Super Admin selalu ada di daftar (auto-inject jika belum ada di DB)
      const masterExists = adminList.some(
        (a) => a.email.toLowerCase() === MASTER_EMAIL.toLowerCase()
      );

      if (!masterExists) {
        try {
          const { data: upserted } = await supabase
            .from('admin_users')
            .upsert(
              {
                email: MASTER_EMAIL.toLowerCase(),
                name: 'Diyanto (Super Admin)',
                role: 'super_admin',
                is_active: true,
                can_manage_licenses: true,
              },
              { onConflict: 'email' }
            )
            .select('*, partners(*)')
            .maybeSingle();

          if (upserted) {
            adminList = [upserted as AdminUser, ...adminList];
          } else {
            adminList = [
              {
                id: 'master-super-admin',
                email: MASTER_EMAIL.toLowerCase(),
                name: 'Diyanto (Super Admin)',
                role: 'super_admin',
                is_active: true,
                can_manage_licenses: true,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              } as AdminUser,
              ...adminList,
            ];
          }
        } catch {
          adminList = [
            {
              id: 'master-super-admin',
              email: MASTER_EMAIL.toLowerCase(),
              name: 'Diyanto (Super Admin)',
              role: 'super_admin',
              is_active: true,
              can_manage_licenses: true,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            } as AdminUser,
            ...adminList,
          ];
        }
      }

      setAdmins(adminList);
      setPartners((partnerData as Partner[]) || []);
    } catch (err: any) {
      console.error('Gagal mengambil data admin:', err);
      setActionError(err?.message || 'Gagal memuat daftar admin. Pastikan tabel admin_users telah dibuat.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const openAddModal = () => {
    setEditingAdmin(null);
    setFormEmail('');
    setFormName('');
    setFormRole('admin');
    setFormPartnerId('');
    setFormIsActive(true);
    setFormCanManageLicenses(false);
    setActionError(null);
    setIsModalOpen(true);
  };

  const openEditModal = (admin: AdminUser) => {
    setEditingAdmin(admin);
    setFormEmail(admin.email);
    setFormName(admin.name || '');
    setFormRole(admin.role);
    setFormPartnerId(admin.partner_id || '');
    setFormIsActive(admin.is_active);
    setFormCanManageLicenses(Boolean(admin.can_manage_licenses));
    setActionError(null);
    setIsModalOpen(true);
  };

  const handleSaveAdmin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formEmail.trim()) {
      setActionError('Email wajib diisi.');
      return;
    }

    if (formRole === 'partner' && !formPartnerId) {
      setActionError('Pilih mitra yang ditautkan ke akun ini.');
      return;
    }

    try {
      setSaving(true);
      setActionError(null);

      const cleanEmail = formEmail.trim().toLowerCase();

      if (editingAdmin) {
        // Edit existing admin
        const { error } = await supabase
          .from('admin_users')
          .update({
            name: formName.trim() || null,
            role: formRole,
            partner_id: formRole === 'partner' ? formPartnerId : null,
            is_active: formIsActive,
            can_manage_licenses: formRole === "super_admin" ? true : formCanManageLicenses,
            updated_at: new Date().toISOString(),
          })
          .eq('id', editingAdmin.id);

        if (error) throw error;
        setActionSuccess(`Data admin ${cleanEmail} berhasil diperbarui.`);
      } else {
        // Add new admin
        const { error } = await supabase.from('admin_users').insert({
          email: cleanEmail,
          name: formName.trim() || null,
          role: formRole,
          partner_id: formRole === 'partner' ? formPartnerId : null,
          is_active: formIsActive,
          can_manage_licenses: formRole === "super_admin" ? true : formCanManageLicenses,
        });

        if (error) {
          if (error.code === '23505') {
            throw new Error(`Email ${cleanEmail} sudah terdaftar sebagai admin.`);
          }
          throw error;
        }
        setActionSuccess(`Akun ${cleanEmail} (${formRole === 'partner' ? 'Mitra' : 'Admin'}) berhasil ditambahkan!`);
      }

      setIsModalOpen(false);
      fetchAdmins();
    } catch (err: any) {
      setActionError(err?.message || 'Gagal menyimpan data admin.');
    } finally {
      setSaving(false);
    }
  };

  
  const handleToggleLicensePermission = async (admin: AdminUser) => {
    if (admin.role === "super_admin") return;
    try {
      const nextPerm = !admin.can_manage_licenses;
      const { error } = await supabase
        .from("admin_users")
        .update({ can_manage_licenses: nextPerm, updated_at: new Date().toISOString() })
        .eq("id", admin.id);

      if (error) throw error;

      setAdmins((prev) =>
        prev.map((item) => (item.id === admin.id ? { ...item, can_manage_licenses: nextPerm } : item))
      );
      setActionSuccess(`Izin akses lisensi untuk ${admin.email} diubah menjadi ${nextPerm ? "Diizinkan" : "Dibatasi"}.`);
    } catch (err: any) {
      alert(`Gagal mengubah izin lisensi: ${err.message}`);
    }
  };

  const handleToggleStatus = async (admin: AdminUser) => {
    if (admin.email.toLowerCase() === MASTER_EMAIL.toLowerCase()) {
      alert('Akun Super Admin utama tidak boleh dinonaktifkan.');
      return;
    }

    try {
      const nextStatus = !admin.is_active;
      const { error } = await supabase
        .from('admin_users')
        .update({ is_active: nextStatus, updated_at: new Date().toISOString() })
        .eq('id', admin.id);

      if (error) throw error;

      setAdmins((prev) =>
        prev.map((item) => (item.id === admin.id ? { ...item, is_active: nextStatus } : item))
      );
      setActionSuccess(`Status admin ${admin.email} diubah menjadi ${nextStatus ? 'Aktif' : 'Nonaktif'}.`);
    } catch (err: any) {
      alert(`Gagal mengubah status: ${err.message}`);
    }
  };

  const handleDeleteAdmin = async () => {
    if (!deletingAdmin) return;
    if (deletingAdmin.email.toLowerCase() === MASTER_EMAIL.toLowerCase()) {
      alert('Akun Super Admin utama tidak dapat dihapus.');
      setDeletingAdmin(null);
      return;
    }

    try {
      setSaving(true);
      const { error } = await supabase
        .from('admin_users')
        .delete()
        .eq('id', deletingAdmin.id);

      if (error) throw error;

      setActionSuccess(`Akses admin untuk ${deletingAdmin.email} berhasil dicabut/dihapus.`);
      setDeletingAdmin(null);
      fetchAdmins();
    } catch (err: any) {
      alert(`Gagal menghapus admin: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // Filtered List
  const filteredAdmins = admins.filter((admin) => {
    const matchesQuery =
      admin.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (admin.name && admin.name.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesRole = roleFilter === 'ALL' || admin.role === roleFilter;
    const matchesStatus =
      statusFilter === 'ALL' ||
      (statusFilter === 'active' && admin.is_active) ||
      (statusFilter === 'inactive' && !admin.is_active);

    return matchesQuery && matchesRole && matchesStatus;
  });

  const totalCount = admins.length;
  const activeCount = admins.filter((a) => a.is_active).length;
  const superAdminCount = admins.filter((a) => a.role === 'super_admin').length;

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Kelola Tim Admin Syupeo"
        description="Atur rekan tim dan pengguna yang memiliki hak akses ke Super Admin Control Hub Syupeo"
      />

      {/* Action Alerts */}
      {actionSuccess && (
        <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-between text-emerald-800 text-sm">
          <div className="flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-emerald-600 flex-shrink-0" />
            <span className="font-semibold">{actionSuccess}</span>
          </div>
          <button
            onClick={() => setActionSuccess(null)}
            className="p-1 text-emerald-600 hover:text-emerald-800 rounded-lg hover:bg-emerald-100/50"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {actionError && (
        <div className="p-4 rounded-2xl bg-red-50 border border-red-200 flex items-center justify-between text-red-800 text-sm">
          <div className="flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0" />
            <span className="font-semibold">{actionError}</span>
          </div>
          <button
            onClick={() => setActionError(null)}
            className="p-1 text-red-600 hover:text-red-800 rounded-lg hover:bg-red-100/50"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-orange-50 border border-orange-200 flex items-center justify-center text-orange-600 flex-shrink-0">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{totalCount}</div>
            <div className="text-xs font-semibold text-slate-500">Total Pengguna Admin</div>
          </div>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-purple-50 border border-purple-200 flex items-center justify-center text-purple-600 flex-shrink-0">
            <Crown className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{superAdminCount}</div>
            <div className="text-xs font-semibold text-slate-500">Super Administrator</div>
          </div>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600 flex-shrink-0">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{activeCount}</div>
            <div className="text-xs font-semibold text-slate-500">Akun Berstatus Aktif</div>
          </div>
        </div>
      </div>

      {/* Control & Search Bar */}
      <div className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200/90 shadow-xs space-y-4">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          {/* Search Box */}
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari email atau nama admin..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm"
            />
          </div>

          {/* Action Buttons & Filters */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Filter Role */}
            <select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value as any)}
              className="px-3 py-2.5 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 focus:outline-hidden"
            >
              <option value="ALL">Semua Role</option>
              <option value="super_admin">Super Admin</option>
              <option value="admin">Admin</option>
              <option value="partner">Mitra / Marketer</option>
            </select>

            {/* Filter Status */}
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="px-3 py-2.5 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 focus:outline-hidden"
            >
              <option value="ALL">Semua Status</option>
              <option value="active">Aktif</option>
              <option value="inactive">Nonaktif</option>
            </select>

            {/* Refresh Button */}
            <button
              onClick={fetchAdmins}
              title="Muat Ulang"
              className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>

            {/* Add Admin Button */}
            <button
              onClick={openAddModal}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold text-xs shadow-xs hover:shadow-md transition-all duration-200"
            >
              <UserPlus className="w-4 h-4" />
              <span>Tambah Admin Baru</span>
            </button>
          </div>
        </div>
      </div>

      {/* Admins Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50/80 border-b border-slate-200/80 text-[11px] uppercase tracking-wider text-slate-500 font-bold">
              <tr>
                <th className="py-4 px-6">Pengguna Admin</th>
                <th className="py-4 px-6">Role Akses</th>
                <th className="py-4 px-6">Status Akun</th>
                <th className="py-4 px-6">Izin Lisensi</th>
                <th className="py-4 px-6">Ditambahkan Pada</th>
                <th className="py-4 px-6 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                    <span>Memuat daftar admin...</span>
                  </td>
                </tr>
              ) : filteredAdmins.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <Lock className="w-10 h-10 text-slate-300 mx-auto mb-2" />
                    <p className="font-semibold text-slate-600">Tidak ada admin yang cocok</p>
                    <p className="text-xs text-slate-400 mt-1">Coba ubah kata kunci pencarian atau filter Anda.</p>
                  </td>
                </tr>
              ) : (
                filteredAdmins.map((admin) => {
                  const isMaster = admin.email.toLowerCase() === MASTER_EMAIL.toLowerCase();
                  const initials = (admin.name || admin.email)
                    .substring(0, 2)
                    .toUpperCase();

                  return (
                    <tr key={admin.id} className="hover:bg-slate-50/70 transition-colors">
                      {/* Name & Email */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div
                            className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-xs flex-shrink-0 ${
                              admin.role === 'super_admin'
                                ? 'bg-purple-100 text-purple-700 border border-purple-200'
                                : 'bg-orange-100 text-orange-700 border border-orange-200'
                            }`}
                          >
                            {initials}
                          </div>
                          <div>
                            <div className="font-bold text-slate-900 flex items-center gap-2">
                              <span>{admin.name || 'Admin'}</span>
                              {isMaster && (
                                <span className="px-2 py-0.5 text-[10px] font-bold bg-amber-100 text-amber-800 rounded-full border border-amber-200">
                                  Master Account
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-slate-500 font-mono mt-0.5">{admin.email}</div>
                          </div>
                        </div>
                      </td>

                      {/* Role */}
                      <td className="py-4 px-6">
                        {admin.role === 'super_admin' ? (
                          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-purple-50 text-purple-700 border border-purple-200">
                            <Crown className="w-3.5 h-3.5" />
                            <span>Super Admin</span>
                          </div>
                        ) : admin.role === 'partner' ? (
                          <div>
                            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                              <UserCheck className="w-3.5 h-3.5" />
                              <span>Mitra Marketer</span>
                            </div>
                            {admin.partners && (
                              <div className="text-[11px] text-slate-500 mt-0.5">
                                Mitra: <span className="font-semibold text-slate-800">{admin.partners.name}</span>
                              </div>
                            )}
                          </div>
                        ) : (
                          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-blue-50 text-blue-700 border border-blue-200">
                            <Shield className="w-3.5 h-3.5" />
                            <span>Admin</span>
                          </div>
                        )}
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        {admin.is_active ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            <span className="w-2 h-2 rounded-full bg-emerald-500" />
                            <span>Aktif</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-600 border border-slate-200">
                            <span className="w-2 h-2 rounded-full bg-slate-400" />
                            <span>Nonaktif</span>
                          </span>
                        )}
                      </td>

                      
                      {/* License Permission */}
                      <td className="py-4 px-6">
                        {admin.role === "super_admin" ? (
                          <span className="inline-flex items-center gap-1 text-[11px] font-bold text-purple-700 bg-purple-50 px-2.5 py-1 rounded-full border border-purple-200">
                            <Crown className="w-3 h-3" />
                            <span>Super Admin</span>
                          </span>
                        ) : (
                          <button
                            type="button"
                            onClick={() => handleToggleLicensePermission(admin)}
                            title="Klik untuk ubah izin akses generator & lisensi"
                            className={`inline-flex items-center gap-1.5 text-xs font-bold px-2.5 py-1 rounded-lg border transition-all ${
                              admin.can_manage_licenses
                                ? "bg-amber-50 text-amber-800 border-amber-200 hover:bg-amber-100"
                                : "bg-slate-100 text-slate-500 border-slate-200 hover:bg-slate-200"
                            }`}
                          >
                            <KeyRound className="w-3 h-3 text-amber-600" />
                            <span>{admin.can_manage_licenses ? "✓ Diizinkan" : "✕ Dibatasi"}</span>
                          </button>
                        )}
                      </td>

                      {/* Created At */}
                      <td className="py-4 px-6 text-xs text-slate-500">
                        {new Date(admin.created_at).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Toggle Active Switch */}
                          <button
                            onClick={() => handleToggleStatus(admin)}
                            disabled={isMaster}
                            title={admin.is_active ? 'Nonaktifkan Akun' : 'Aktifkan Akun'}
                            className={`p-2 rounded-lg transition-colors ${
                              isMaster
                                ? 'opacity-30 cursor-not-allowed text-slate-400'
                                : admin.is_active
                                ? 'text-emerald-600 hover:bg-emerald-50'
                                : 'text-slate-400 hover:text-emerald-600 hover:bg-slate-100'
                            }`}
                          >
                            <Power className="w-4 h-4" />
                          </button>

                          {/* Edit button */}
                          <button
                            onClick={() => openEditModal(admin)}
                            title="Edit Data Admin"
                            className="p-2 text-slate-500 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>

                          {/* Delete button */}
                          <button
                            onClick={() => setDeletingAdmin(admin)}
                            disabled={isMaster}
                            title={isMaster ? 'Akun Master tidak bisa dihapus' : 'Cabut/Hapus Akses Admin'}
                            className={`p-2 rounded-lg transition-colors ${
                              isMaster
                                ? 'opacity-30 cursor-not-allowed text-slate-400'
                                : 'text-slate-400 hover:text-red-600 hover:bg-red-50'
                            }`}
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

      {/* Add / Edit Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-md w-full shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="p-6 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="w-10 h-10 rounded-2xl bg-blue-50 text-[#0070fc] flex items-center justify-center font-bold border border-blue-100">
                  {editingAdmin ? <Edit2 className="w-5 h-5" /> : <UserPlus className="w-5 h-5" />}
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-900">
                    {editingAdmin ? 'Edit Data Admin' : 'Tambah Admin Baru'}
                  </h3>
                  <p className="text-xs text-slate-500">
                    {editingAdmin ? 'Ubah role atau nama admin' : 'Berikan hak akses login Google'}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSaveAdmin} className="p-6 space-y-4">
              {/* Quick Select from Registered Profiles */}
              {!editingAdmin && registeredProfiles.length > 0 && (
                <div className="p-3 bg-blue-50/70 rounded-2xl border border-blue-200/80 space-y-1.5">
                  <label className="block text-[11px] font-bold text-blue-900 uppercase tracking-wider flex items-center gap-1.5">
                    <UserCheck className="w-3.5 h-3.5 text-[#0070fc]" />
                    <span>Pilih dari Pengguna Terdaftar (Opsional)</span>
                  </label>
                  <select
                    onChange={(e) => {
                      const selected = registeredProfiles.find((p) => p.email === e.target.value);
                      if (selected) {
                        setFormEmail(selected.email || '');
                        setFormName(selected.full_name || '');
                      }
                    }}
                    className="w-full px-3 py-2 rounded-xl bg-white border border-blue-200 text-xs font-semibold text-slate-800 focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]/20"
                    defaultValue=""
                  >
                    <option value="" disabled>-- Klik untuk memilih akun terdaftar --</option>
                    {registeredProfiles.map((p) => (
                      <option key={p.id} value={p.email}>
                        {p.full_name || 'Tanpa Nama'} — {p.email}
                      </option>
                    ))}
                  </select>
                  <p className="text-[10px] text-blue-700">
                    Pilih akun di atas untuk mengisi otomatis nama & email di bawah.
                  </p>
                </div>
              )}

              {/* Email */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Email Akun Google <span className="text-red-500">*</span>
                </label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    required
                    disabled={!!editingAdmin}
                    placeholder="contoh@gmail.com"
                    value={formEmail}
                    onChange={(e) => setFormEmail(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-[#0070fc]/20 focus:border-[#0070fc] text-sm disabled:bg-slate-100 disabled:text-slate-500"
                  />
                </div>
                <p className="text-[11px] text-slate-400 mt-1">
                  Harus berupa akun Google yang valid (untuk login via Google SSO).
                </p>
              </div>

              {/* Name */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Nama Lengkap / Panggilan
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="cth: Budi Setiawan"
                    value={formName}
                    onChange={(e) => setFormName(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm"
                  />
                </div>
              </div>

              {/* Role Selection */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Tingkat Hak Akses (Role)
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <button
                    type="button"
                    onClick={() => setFormRole('admin')}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      formRole === 'admin'
                        ? 'bg-blue-50 border-blue-300 text-blue-900 shadow-xs'
                        : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs mb-1">
                      <Shield className="w-3.5 h-3.5 text-blue-600" />
                      <span>Admin</span>
                    </div>
                    <p className="text-[11px] text-slate-500 leading-tight">
                      Akses operasional kelola bisnis dan paket
                    </p>
                  </button>

                  <button
                    type="button"
                    onClick={() => setFormRole('super_admin')}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      formRole === 'super_admin'
                        ? 'bg-purple-50 border-purple-300 text-purple-900 shadow-xs'
                        : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs mb-1">
                      <Crown className="w-3.5 h-3.5 text-purple-600" />
                      <span>Super Admin</span>
                    </div>
                    <p className="text-[11px] text-slate-500 leading-tight">
                      Akses penuh seluruh sistem & admin lain
                    </p>
                  </button>

                  <button
                    type="button"
                    onClick={() => setFormRole('partner')}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      formRole === 'partner'
                        ? 'bg-emerald-50 border-emerald-300 text-emerald-900 shadow-xs'
                        : 'border-slate-200 hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs mb-1">
                      <UserCheck className="w-3.5 h-3.5 text-emerald-600" />
                      <span>Mitra</span>
                    </div>
                    <p className="text-[11px] text-slate-500 leading-tight">
                      Akses terbatas CRM & Quotation mitra sendiri
                    </p>
                  </button>
                </div>
              </div>

              {/* Tautkan ke Data Mitra jika role === 'partner' */}
              {formRole === 'partner' && (
                <div className="p-3.5 rounded-2xl bg-emerald-50/70 border border-emerald-200 space-y-2">
                  <label className="block text-xs font-bold text-emerald-950 uppercase tracking-wider">
                    Tautkan ke Profil Mitra <span className="text-red-500">*</span>:
                  </label>
                  <select
                    value={formPartnerId}
                    onChange={(e) => setFormPartnerId(e.target.value)}
                    required
                    className="w-full px-3 py-2 rounded-xl border border-emerald-300 bg-white text-xs font-bold text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-emerald-500/20"
                  >
                    <option value="">-- Pilih Mitra Terdaftar --</option>
                    {partners.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.commission_rate}% - {p.phone || p.bank_name || 'Mitra'})
                      </option>
                    ))}
                  </select>
                  <p className="text-[11px] text-emerald-800 leading-relaxed">
                    💡 Mitra ini hanya akan melihat data Leads CRM, Surat Penawaran, serta Dashboard Komisi miliknya sendiri.
                  </p>
                </div>
              )}

              
              {/* Permission: Manage Licenses */}
              <div className="pt-1">
                <label className="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formRole === "super_admin" || formCanManageLicenses}
                    disabled={formRole === "super_admin"}
                    onChange={(e) => setFormCanManageLicenses(e.target.checked)}
                    className="w-4 h-4 mt-0.5 text-orange-600 rounded border-slate-300 focus:ring-orange-500 disabled:opacity-50"
                  />
                  <div>
                    <div className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                      <KeyRound className="w-3.5 h-3.5 text-amber-600" />
                      <span>Izin Akses Generator & Lisensi</span>
                      {formRole === "super_admin" && (
                        <span className="text-[10px] text-purple-700 bg-purple-50 px-1.5 py-0.5 rounded font-bold">
                          Otomatis (Super Admin)
                        </span>
                      )}
                    </div>
                    <div className="text-[11px] text-slate-500 mt-0.5">
                      Izinkan admin ini mengelola alokasi stok Starter Kit retail, persetujuan restock, serta rekap bagi hasil mitra.
                    </div>
                  </div>
                </label>
              </div>

              {/* Is Active Toggle */}
              <div className="pt-2">
                <label className="flex items-center gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formIsActive}
                    onChange={(e) => setFormIsActive(e.target.checked)}
                    className="w-4 h-4 text-orange-600 rounded border-slate-300 focus:ring-orange-500"
                  />
                  <div>
                    <div className="text-xs font-bold text-slate-800">Status Akun Aktif</div>
                    <div className="text-[11px] text-slate-500">
                      Jika dinonaktifkan, akun ini tidak dapat login ke admin web.
                    </div>
                  </div>
                </label>
              </div>

              {/* Submit Buttons */}
              <div className="pt-4 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold shadow-xs hover:shadow-md transition-all disabled:opacity-50"
                >
                  {saving ? (
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  ) : (
                    <span>{editingAdmin ? 'Simpan Perubahan' : 'Tambahkan Admin'}</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingAdmin && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-sm w-full p-6 shadow-2xl border border-slate-200 text-center animate-in fade-in zoom-in-95 duration-200">
            <div className="w-12 h-12 rounded-full bg-red-100 text-red-600 flex items-center justify-center mx-auto mb-4">
              <Trash2 className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-lg text-slate-900 mb-1">Cabut Akses Admin?</h3>
            <p className="text-xs text-slate-500 leading-relaxed mb-6">
              Akun <strong className="text-slate-800">{deletingAdmin.email}</strong> tidak akan bisa login lagi ke panel admin. Data riwayat tidak akan terhapus.
            </p>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setDeletingAdmin(null)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleDeleteAdmin}
                disabled={saving}
                className="flex-1 py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-bold transition-all shadow-xs"
              >
                {saving ? 'Menghapus...' : 'Ya, Hapus'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
