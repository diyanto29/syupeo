'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import {
  Users,
  UserPlus,
  Shield,
  Search,
  CheckCircle2,
  XCircle,
  RefreshCw,
  Mail,
  UserCheck,
  Edit2,
  Trash2,
  X,
  UserX,
  Lock,
  Key,
  BadgeCheck,
} from 'lucide-react';

interface UnifiedStaff {
  id: string;
  source: 'owner' | 'member' | 'invitation';
  user_id?: string;
  name: string;
  email?: string;
  staff_code?: string;
  role: 'owner' | 'admin' | 'cashier' | 'waiter' | 'kitchen';
  status: 'active' | 'invited' | 'disabled';
  created_at: string;
}

export default function MerchantStaffPage() {
  const { business } = useMerchant();

  const [members, setMembers] = useState<UnifiedStaff[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    staff_code: '',
    email: '',
    password: '',
    role: 'cashier' as 'admin' | 'cashier' | 'waiter' | 'kitchen',
  });

  const loadMembers = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();
      const combinedList: UnifiedStaff[] = [];

      // 1. Ambil Profil Owner Toko (Selalu tampilkan owner toko sebagai akun utama)
      const ownerUserId = business.owner_user_id;
      let ownerName = business.name ? `Owner (${business.name})` : 'Pemilik Toko (Owner)';
      let ownerEmail = business.email || '-';
      let ownerCode = 'OWNER';

      if (ownerUserId) {
        try {
          const { data: prof } = await supabase
            .from('profiles')
            .select('full_name, email, staff_code')
            .eq('id', ownerUserId)
            .maybeSingle();

          if (prof) {
            if (prof.full_name) ownerName = prof.full_name;
            if (prof.email) ownerEmail = prof.email;
            if (prof.staff_code) ownerCode = prof.staff_code;
          }
        } catch (e) {
          console.warn('Could not fetch owner profile:', e);
        }

        combinedList.push({
          id: `owner-${ownerUserId}`,
          source: 'owner',
          user_id: ownerUserId,
          name: ownerName,
          email: ownerEmail,
          staff_code: ownerCode,
          role: 'owner',
          status: 'active',
          created_at: business.created_at || new Date().toISOString(),
        });
      } else {
        // Fallback jika owner_user_id belum terisi di data bisnis
        combinedList.push({
          id: `owner-${business.id}`,
          source: 'owner',
          name: ownerName,
          email: ownerEmail,
          staff_code: ownerCode,
          role: 'owner',
          status: 'active',
          created_at: business.created_at || new Date().toISOString(),
        });
      }

      // 2. Ambil dari tabel business_members (Staf dengan akun terdaftar)
      try {
        const { data: memberData } = await supabase
          .from('business_members')
          .select('*, profiles:user_id(*)')
          .eq('business_id', business.id)
          .order('created_at', { ascending: false });

        if (memberData && memberData.length > 0) {
          memberData.forEach((m: any) => {
            if (m.user_id !== ownerUserId) {
              combinedList.push({
                id: m.id,
                source: 'member',
                user_id: m.user_id,
                name: m.profiles?.full_name || 'Karyawan',
                email: m.profiles?.email || '-',
                staff_code: m.profiles?.staff_code || '-',
                role: m.role || 'cashier',
                status: m.status || 'active',
                created_at: m.created_at,
              });
            }
          });
        }
      } catch (err) {
        console.warn('Error fetching business_members:', err);
      }

      // 3. Ambil dari tabel staff_invitations (Staf kasir/waiter yang dibuat via kode kasir)
      try {
        const { data: inviteData } = await supabase
          .from('staff_invitations')
          .select('*')
          .eq('business_id', business.id)
          .order('created_at', { ascending: false });

        if (inviteData && inviteData.length > 0) {
          inviteData.forEach((inv: any) => {
            const alreadyExists = combinedList.some(
              (c) =>
                (c.staff_code && c.staff_code === inv.staff_code) ||
                (c.email && inv.email && c.email.toLowerCase() === inv.email.toLowerCase())
            );
            if (!alreadyExists) {
              combinedList.push({
                id: inv.id,
                source: 'invitation',
                name: inv.full_name || `Staf (${inv.staff_code})`,
                email: inv.email || '-',
                staff_code: inv.staff_code,
                role: inv.role || 'cashier',
                status: inv.status || 'active',
                created_at: inv.created_at,
              });
            }
          });
        }
      } catch (err) {
        console.warn('Error fetching staff_invitations:', err);
      }

      // 4. Periksa nama kasir dari riwayat cash_shifts jika ada yang belum terdaftar
      try {
        const { data: shiftCashiers } = await supabase
          .from('cash_shifts')
          .select('cashier_id, cashier_name')
          .eq('business_id', business.id)
          .not('cashier_name', 'is', null);

        if (shiftCashiers && shiftCashiers.length > 0) {
          const uniqueCashiers = Array.from(
            new Set(shiftCashiers.map((s) => s.cashier_name?.trim()).filter(Boolean))
          );
          uniqueCashiers.forEach((cName) => {
            const alreadyExists = combinedList.some(
              (c) => c.name.toLowerCase() === cName.toLowerCase()
            );
            if (!alreadyExists) {
              combinedList.push({
                id: `shift-${cName}`,
                source: 'invitation',
                name: cName,
                email: '-',
                staff_code: '-',
                role: 'cashier',
                status: 'active',
                created_at: new Date().toISOString(),
              });
            }
          });
        }
      } catch (err) {
        console.warn('Error fetching shift cashiers:', err);
      }

      setMembers(combinedList);
    } catch (err) {
      console.error('Error fetching staff members:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadMembers();
  }, [business?.id]);

  // Calculations
  const totalStaff = members.length;
  const activeStaff = members.filter((m) => m.status === 'active').length;
  const cashierCount = members.filter((m) => m.role === 'cashier').length;

  // Role labels
  const roleLabels: Record<string, { label: string; color: string; desc: string }> = {
    owner: {
      label: 'Pemilik (Owner)',
      color: 'bg-purple-50 text-purple-700 border-purple-200',
      desc: 'Akses penuh seluruh fitur toko & laporan',
    },
    admin: {
      label: 'Admin Toko',
      color: 'bg-blue-50 text-blue-700 border-blue-200',
      desc: 'Kelola produk, stok, kasbon, dan laporan',
    },
    cashier: {
      label: 'Kasir (POS)',
      color: 'bg-emerald-50 text-emerald-700 border-emerald-200',
      desc: 'Transaksi kasir, shift kasir, dan cetak struk',
    },
    waiter: {
      label: 'Pelayan (Waiter)',
      color: 'bg-amber-50 text-amber-700 border-amber-200',
      desc: 'Input pesanan meja dan kirim ke dapur',
    },
    kitchen: {
      label: 'Dapur (KDS)',
      color: 'bg-orange-50 text-orange-700 border-orange-200',
      desc: 'Melihat antrean pesanan masak di dapur',
    },
  };

  // Add Staff Member
  const handleAddMember = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    if (!formData.name.trim()) {
      alert('Nama karyawan wajib diisi.');
      return;
    }

    const staffCode = formData.staff_code.trim() || `kasir${Date.now().toString().slice(-3)}`;
    const identifier = formData.email.trim() || staffCode;

    try {
      setSubmitting(true);
      const supabase = createClient();

      // Coba panggil RPC resmi 'upsert_business_staff_entry'
      const { data: rpcData, error: rpcErr } = await supabase.rpc('upsert_business_staff_entry', {
        target_business_id: business.id,
        target_identifier: identifier,
        target_role: formData.role,
        target_status: 'active',
        target_full_name: formData.name.trim(),
        target_staff_code: staffCode,
        target_initial_password: formData.password.trim() || null,
      });

      if (rpcErr) {
        console.warn('RPC upsert_business_staff_entry fallback:', rpcErr);

        // Fallback: Langsung insert ke staff_invitations
        const { error: insertErr } = await supabase.from('staff_invitations').insert([
          {
            business_id: business.id,
            staff_code: staffCode,
            full_name: formData.name.trim(),
            email: formData.email.trim() || null,
            role: formData.role,
            status: 'active',
            created_at: new Date().toISOString(),
          },
        ]);

        if (insertErr) throw insertErr;
      }

      setIsModalOpen(false);
      setFormData({ name: '', staff_code: '', email: '', password: '', role: 'cashier' });
      loadMembers();
    } catch (err: any) {
      console.error('Error adding staff:', err);
      alert('Gagal menambahkan karyawan: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Toggle Member Status (Aktif / Nonaktif)
  const handleToggleStatus = async (staff: UnifiedStaff) => {
    if (staff.source === 'owner') {
      alert('Akun Pemilik Utama (Owner) tidak dapat dinonaktifkan.');
      return;
    }

    const nextStatus = staff.status === 'active' ? 'disabled' : 'active';
    try {
      const supabase = createClient();

      if (staff.source === 'invitation') {
        const { error } = await supabase
          .from('staff_invitations')
          .update({ status: nextStatus, updated_at: new Date().toISOString() })
          .eq('id', staff.id);
        if (error) throw error;
      } else if (staff.source === 'member') {
        const { error } = await supabase
          .from('business_members')
          .update({ status: nextStatus, updated_at: new Date().toISOString() })
          .eq('id', staff.id);
        if (error) throw error;
      }

      loadMembers();
    } catch (err: any) {
      console.error('Error updating status:', err);
      alert('Gagal mengubah status: ' + err.message);
    }
  };

  // Delete Member
  const handleDeleteMember = async (staff: UnifiedStaff) => {
    if (staff.source === 'owner') {
      alert('Akun Pemilik Utama (Owner) tidak dapat dihapus.');
      return;
    }

    if (!confirm(`Hapus akses karyawan "${staff.name}" dari toko Anda?`)) return;

    try {
      const supabase = createClient();
      if (staff.source === 'invitation') {
        const { error } = await supabase.from('staff_invitations').delete().eq('id', staff.id);
        if (error) throw error;
      } else if (staff.source === 'member') {
        const { error } = await supabase.from('business_members').delete().eq('id', staff.id);
        if (error) throw error;
      }

      loadMembers();
    } catch (err: any) {
      console.error('Error deleting member:', err);
      alert('Gagal menghapus karyawan: ' + err.message);
    }
  };

  // Filtered
  const filteredMembers = members.filter((m) => {
    const name = m.name.toLowerCase();
    const email = (m.email || '').toLowerCase();
    const code = (m.staff_code || '').toLowerCase();
    const q = search.toLowerCase();
    const matchSearch = name.includes(q) || email.includes(q) || code.includes(q);
    const matchRole = roleFilter === 'all' || m.role === roleFilter;
    return matchSearch && matchRole;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Manajemen Tim & Karyawan
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Kelola Karyawan & Staf
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Daftar seluruh staf kasir, waiter, kitchen, dan hak akses aplikasi kasir toko Anda
          </p>
        </div>

        <button
          onClick={() => {
            setFormData({
              name: '',
              staff_code: `kasir${members.filter((m) => m.role === 'cashier').length + 1}`,
              email: '',
              password: '',
              role: 'cashier',
            });
            setIsModalOpen(true);
          }}
          className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm transition-all self-start sm:self-auto"
        >
          <UserPlus className="w-4 h-4" />
          <span>Tambah Karyawan</span>
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Total Karyawan */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Staf Terdaftar
            </span>
            <span className="text-xl font-black text-slate-900">
              {totalStaff} <span className="text-xs font-normal text-slate-500">Orang</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Termasuk owner & staf kasir
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Users className="w-5 h-5" />
          </div>
        </div>

        {/* Kasir Aktif */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Staf Kasir (POS)
            </span>
            <span className="text-xl font-black text-emerald-600">
              {cashierCount} <span className="text-xs font-normal text-slate-500">Orang</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Memiliki akses kasir & mesin pembayaran
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <UserCheck className="w-5 h-5" />
          </div>
        </div>

        {/* Status Aktif */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Status Aktif
            </span>
            <span className="text-xl font-black text-slate-900">
              {activeStaff} <span className="text-xs font-normal text-slate-500">Aktif</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Bisa langsung login ke aplikasi
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center flex-shrink-0">
            <Shield className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Filter & Search */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama, ID staf, atau email..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="w-full sm:w-48 text-xs font-bold py-2 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="all">Semua Peran (Role)</option>
            <option value="owner">Pemilik (Owner)</option>
            <option value="admin">Admin Toko</option>
            <option value="cashier">Kasir (POS)</option>
            <option value="waiter">Pelayan (Waiter)</option>
            <option value="kitchen">Dapur (Kitchen)</option>
          </select>
        </div>
      </div>

      {/* Staff Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4">Nama Staf</th>
                <th className="py-3 px-4">ID Staf / Kode Login</th>
                <th className="py-3 px-4">Kontak / Email</th>
                <th className="py-3 px-4">Peran (Hak Akses)</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat daftar karyawan...</span>
                  </td>
                </tr>
              ) : filteredMembers.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400">
                    <Users className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                    <p className="font-bold text-slate-700 text-sm mb-1">Belum Ada Karyawan / Staf</p>
                    <p className="text-xs text-slate-400 max-w-sm mx-auto mb-4">
                      Tambahkan kasir atau staf toko Anda agar mereka dapat login ke aplikasi POS kasir menggunakan ID Staf & PIN.
                    </p>
                    <button
                      onClick={() => {
                        setFormData({
                          name: '',
                          staff_code: `kasir${members.filter((m) => m.role === 'cashier').length + 1}`,
                          email: '',
                          password: '',
                          role: 'cashier',
                        });
                        setIsModalOpen(true);
                      }}
                      className="inline-flex items-center gap-1.5 px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white font-bold rounded-xl text-xs transition-colors shadow-xs"
                    >
                      <UserPlus className="w-4 h-4" />
                      <span>Tambah Karyawan Baru</span>
                    </button>
                  </td>
                </tr>
              ) : (
                filteredMembers.map((m) => {
                  const roleConfig = roleLabels[m.role] || {
                    label: m.role,
                    color: 'bg-slate-100 text-slate-700',
                    desc: '-',
                  };

                  return (
                    <tr key={m.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-900 flex items-center gap-1.5">
                          <span>{m.name}</span>
                          {m.source === 'owner' && (
                            <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-purple-100 text-purple-700">
                              Owner
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-slate-400">{roleConfig.desc}</div>
                      </td>
                      <td className="py-3.5 px-4 font-mono font-bold text-slate-700">
                        <span className="px-2 py-0.5 rounded bg-slate-100 border border-slate-200/80">
                          {m.staff_code || '-'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-slate-600 font-medium">
                        <div className="flex items-center gap-1.5">
                          <Mail className="w-3.5 h-3.5 text-slate-400" />
                          <span>{m.email && m.email !== '-' ? m.email : 'Login via Kode'}</span>
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        <span
                          className={`px-2.5 py-1 rounded-lg border font-bold text-[10px] ${roleConfig.color}`}
                        >
                          {roleConfig.label}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                            m.status === 'active'
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : 'bg-slate-100 text-slate-500'
                          }`}
                        >
                          {m.status === 'active' ? 'Aktif' : 'Nonaktif'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        {m.source === 'owner' ? (
                          <span className="text-[11px] font-bold text-slate-400 italic">Akun Utama</span>
                        ) : (
                          <div className="flex items-center justify-end gap-1.5">
                            {/* Toggle Status */}
                            <button
                              onClick={() => handleToggleStatus(m)}
                              title={m.status === 'active' ? 'Nonaktifkan Akun' : 'Aktifkan Akun'}
                              className={`px-2.5 py-1 text-xs font-bold rounded-lg border transition-colors ${
                                m.status === 'active'
                                  ? 'border-slate-200 text-slate-600 hover:bg-rose-50 hover:text-rose-600'
                                  : 'border-emerald-200 bg-emerald-50 text-emerald-700'
                              }`}
                            >
                              {m.status === 'active' ? 'Nonaktifkan' : 'Aktifkan'}
                            </button>
                            {/* Hapus */}
                            <button
                              onClick={() => handleDeleteMember(m)}
                              title="Hapus Akses"
                              className="p-1.5 rounded-lg border border-slate-200 text-slate-400 hover:text-rose-600 hover:bg-rose-50 transition-colors"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Guide Card */}
      <div className="bg-orange-50/70 border border-orange-200/80 rounded-2xl p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center gap-4">
        <div className="w-10 h-10 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center flex-shrink-0">
          <Key className="w-5 h-5" />
        </div>
        <div className="flex-1">
          <h4 className="font-bold text-slate-900 text-xs sm:text-sm">
            Cara Karyawan / Kasir Login ke Aplikasi Kasir POS
          </h4>
          <p className="text-xs text-slate-600 mt-1 leading-relaxed">
            Staf kasir atau pelayan tidak wajib menggunakan akun email Google. Kasir dapat login di aplikasi Android/tablet langsung dengan memilih tombol <b>Login via Kode Kasir</b>, lalu memasukkan <b>Staff ID / Kode Login</b> dan <b>PIN Kasir</b> yang didaftarkan di atas.
          </p>
        </div>
      </div>

      {/* Modal Tambah Karyawan */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Manajemen Karyawan
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  Tambah Karyawan Baru
                </h3>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddMember} className="py-4 space-y-3.5 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Nama Lengkap Karyawan *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Contoh: Rian Hidayat"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Staff ID / Kode Login *</label>
                  <input
                    type="text"
                    required
                    value={formData.staff_code}
                    onChange={(e) => setFormData({ ...formData, staff_code: e.target.value })}
                    placeholder="Contoh: kasir1"
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-mono font-bold focus:outline-none focus:border-orange-500"
                  />
                  <span className="text-[9px] text-slate-400 block mt-0.5">
                    Dipakai kasir untuk login di mesin POS.
                  </span>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">PIN / Password Awal</label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    placeholder="Contoh: 123456"
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-mono focus:outline-none focus:border-orange-500"
                  />
                  <span className="text-[9px] text-slate-400 block mt-0.5">
                    Opsional (PIN login kasir).
                  </span>
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Email Akun Google (Opsional)</label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  placeholder="rian.kasir@gmail.com"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Peran / Hak Akses *</label>
                <div className="grid grid-cols-2 gap-2">
                  {(['cashier', 'admin', 'waiter', 'kitchen'] as const).map((r) => (
                    <button
                      key={r}
                      type="button"
                      onClick={() => setFormData({ ...formData, role: r })}
                      className={`p-3 rounded-xl border text-left transition-all ${
                        formData.role === r
                          ? 'border-orange-500 bg-orange-50/50 shadow-xs'
                          : 'border-slate-200 hover:bg-slate-50'
                      }`}
                    >
                      <span className="font-bold block text-slate-900 capitalize">
                        {r === 'cashier'
                          ? 'Kasir (POS)'
                          : r === 'admin'
                          ? 'Admin Toko'
                          : r === 'waiter'
                          ? 'Pelayan (Waiter)'
                          : 'Dapur (Kitchen)'}
                      </span>
                      <span className="text-[10px] text-slate-500 block mt-0.5">
                        {roleLabels[r]?.desc}
                      </span>
                    </button>
                  ))}
                </div>
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
                  {submitting ? 'Menyimpan...' : 'Tambahkan Karyawan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
