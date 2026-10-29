'use server';

import { revalidatePath } from 'next/cache';
import { getKosankuAdminSupabase } from '@/lib/supabase/kosankuServer';
import { createClient } from '@/lib/supabase/server';
import CryptoJS from 'crypto-js';

const KOSANKU_SECRET = 'KOSANKU_OFFLINE_SECRET_2026_@PropertyMasterV1';
const KOSANKU_SALT = 'KOSANKU_HARDWARE_LOCK_SALT';

/**
 * Validasi otorisasi Super Admin atau Admin aktif.
 * Mencegah pemanggilan Server Action oleh pengguna publik atau yang tidak berhak.
 */
async function assertAuthorizedAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user || !user.email) {
    throw new Error('Akses ditolak: Anda belum login.');
  }

  const superAdminEmail =
    process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
  const userEmail = user.email.toLowerCase();

  if (userEmail === superAdminEmail.toLowerCase()) {
    return user;
  }

  const { data: adminRecord } = await supabase
    .from('admin_users')
    .select('id, role')
    .eq('email', userEmail)
    .eq('is_active', true)
    .in('role', ['super_admin', 'admin'])
    .maybeSingle();

  if (!adminRecord) {
    throw new Error('Akses ditolak: Hanya Super Admin / Admin yang dapat melakukan tindakan ini.');
  }

  return user;
}

/**
 * Menghasilkan Serial Key HMAC-SHA256 yang valid untuk Hardware ID KosanKu
 */
export async function generateKosankuSerialKey(hardwareId: string): Promise<string> {
  await assertAuthorizedAdmin();
  const cleanId = hardwareId.replace(/-/g, '').trim().toUpperCase();
  const message = `${cleanId}${KOSANKU_SALT}`;
  const hash = CryptoJS.HmacSHA256(message, KOSANKU_SECRET).toString(CryptoJS.enc.Hex).toUpperCase();
  return `${hash.slice(0, 4)}-${hash.slice(4, 8)}-${hash.slice(8, 12)}-${hash.slice(12, 16)}`;
}

export interface SubscriptionPackageInput {
  id: string;
  name: string;
  badge: string;
  sub_badge?: string | null;
  tagline: string;
  price: number;
  price_display: string;
  original_price_display?: string | null;
  period_display: string;
  secondary_price_display?: string | null;
  discount_badge?: string | null;
  suitable_for?: string | null;
  button_text: string;
  is_best_seller: boolean;
  is_active: boolean;
  features?: string[];
}

/**
 * Mengupdate data paket langganan KosanKu di Supabase
 */
export async function updateSubscriptionPackageAction(data: SubscriptionPackageInput) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();

    const { data: updatedRows, error } = await supabase
      .from('subscription_packages')
      .update({
        name: data.name,
        badge: data.badge,
        sub_badge: data.sub_badge || null,
        tagline: data.tagline,
        price: data.price,
        price_display: data.price_display,
        original_price_display: data.original_price_display || null,
        period_display: data.period_display,
        secondary_price_display: data.secondary_price_display || null,
        discount_badge: data.discount_badge || null,
        suitable_for: data.suitable_for || '',
        button_text: data.button_text,
        is_best_seller: data.is_best_seller,
        is_active: data.is_active,
        ...(data.features ? { features: data.features } : {}),
        updated_at: new Date().toISOString(),
      })
      .eq('id', data.id)
      .select();

    if (error) {
      return { success: false, message: `Gagal menyimpan paket: ${error.message}` };
    }

    if (!updatedRows || updatedRows.length === 0) {
      return {
        success: false,
        message: 'Gagal memperbarui paket (0 baris tersimpan).',
      };
    }

    revalidatePath('/dashboard/kosanku');
    return { success: true, message: `Paket ${data.name} berhasil diperbarui!` };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

export interface CreateLicenseInput {
  hardware_id: string;
  plan_code: 'starter' | 'mandiri_lifetime' | 'cloud_monthly' | 'cloud_yearly' | 'cloud_lifetime';
  notes?: string;
  custom_duration_days?: number;
  // Referral & Komisi Mitra
  buyer_name?: string;
  license_price?: number;
  referrer_name?: string;
  commission_amount?: number;
  commission_status?: 'unpaid' | 'paid' | 'none';
  platform?: string;
}

/**
 * Membuat atau memperbarui lisensi pengguna & mencatat komisi mitra di Supabase
 */
export async function createOrActivateLicenseAction(data: CreateLicenseInput) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const cleanHardwareId = data.hardware_id.trim().toUpperCase();

    if (!cleanHardwareId) {
      return { success: false, message: 'Hardware ID wajib diisi!' };
    }

    // Generate Serial Key
    const serialKey = await generateKosankuSerialKey(cleanHardwareId);

    // Hitung tanggal kedaluwarsa
    let expiresAt: string | null = null;
    const now = new Date();

    if (data.plan_code === 'cloud_monthly') {
      const exp = new Date(now);
      exp.setDate(exp.getDate() + 30);
      expiresAt = exp.toISOString();
    } else if (data.plan_code === 'cloud_yearly') {
      const exp = new Date(now);
      exp.setDate(exp.getDate() + 365);
      expiresAt = exp.toISOString();
    } else if (data.custom_duration_days && data.custom_duration_days > 0) {
      const exp = new Date(now);
      exp.setDate(exp.getDate() + data.custom_duration_days);
      expiresAt = exp.toISOString();
    } // mandiri_lifetime & cloud_lifetime = NULL (Permanen)

    // Simpan metadata komisi & pembeli dalam JSON notes agar selalu kompatibel 100%
    const commissionData = {
      buyer_name: data.buyer_name || null,
      license_price: Number(data.license_price) || 0,
      referrer_name: data.referrer_name || null,
      commission_amount: Number(data.commission_amount) || 0,
      commission_status: data.commission_status || (data.referrer_name ? 'unpaid' : 'none'),
      platform: data.platform || 'Direct',
      note_text: data.notes || '',
    };
    const structuredNotes = JSON.stringify(commissionData);

    // Cek apakah hardware_id sudah ada
    const { data: existing } = await supabase
      .from('user_licenses')
      .select('id')
      .eq('hardware_id', cleanHardwareId)
      .limit(1);

    if (existing && existing.length > 0) {
      const { data: updatedRows, error } = await supabase
        .from('user_licenses')
        .update({
          plan_code: data.plan_code,
          serial_key: serialKey,
          is_active: true,
          expires_at: expiresAt,
          notes: structuredNotes,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing[0].id)
        .select();

      if (error) {
        return { success: false, message: `Gagal memperbarui lisensi: ${error.message}` };
      }

      revalidatePath('/dashboard/kosanku');
      return {
        success: true,
        message: `Lisensi untuk ${cleanHardwareId} berhasil diperbarui!`,
        serialKey,
      };
    } else {
      const { data: insertedRows, error } = await supabase
        .from('user_licenses')
        .insert({
          hardware_id: cleanHardwareId,
          plan_code: data.plan_code,
          serial_key: serialKey,
          is_active: true,
          expires_at: expiresAt,
          notes: structuredNotes,
        })
        .select();

      if (error) {
        return { success: false, message: `Gagal membuat lisensi: ${error.message}` };
      }

      revalidatePath('/dashboard/kosanku');
      return {
        success: true,
        message: `Lisensi untuk ${cleanHardwareId} berhasil diaktifkan!`,
        serialKey,
      };
    }
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

/**
 * Mengubah status komisi lisensi tertentu (Pending <-> Lunas)
 */
export async function toggleCommissionStatusAction(licenseId: string, newStatus: 'unpaid' | 'paid') {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { data: lic, error: fetchErr } = await supabase
      .from('user_licenses')
      .select('notes')
      .eq('id', licenseId)
      .single();

    if (fetchErr || !lic) {
      return { success: false, message: 'Lisensi tidak ditemukan' };
    }

    let parsed: any = {};
    try {
      parsed = JSON.parse(lic.notes || '{}');
    } catch {
      parsed = { note_text: lic.notes || '' };
    }

    parsed.commission_status = newStatus;

    const { error: updateErr } = await supabase
      .from('user_licenses')
      .update({
        notes: JSON.stringify(parsed),
        updated_at: new Date().toISOString(),
      })
      .eq('id', licenseId);

    if (updateErr) {
      return { success: false, message: `Gagal mengubah status komisi: ${updateErr.message}` };
    }

    revalidatePath('/dashboard/kosanku');
    return {
      success: true,
      message: `Status komisi berhasil diubah jadi ${newStatus === 'paid' ? 'LUNAS (Sudah Ditransfer)' : 'PENDING'}!`,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

/**
 * Menandai semua komisi pending untuk seorang mitra tertentu menjadi LUNAS
 */
export async function markAllReferrerCommissionsPaidAction(referrerName: string) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { data: licenses, error: fetchErr } = await supabase
      .from('user_licenses')
      .select('id, notes');

    if (fetchErr || !licenses) {
      return { success: false, message: 'Gagal memuat lisensi' };
    }

    let updatedCount = 0;
    for (const lic of licenses) {
      try {
        const parsed = JSON.parse(lic.notes || '{}');
        if (
          parsed.referrer_name &&
          parsed.referrer_name.trim().toLowerCase() === referrerName.trim().toLowerCase() &&
          parsed.commission_status !== 'paid'
        ) {
          parsed.commission_status = 'paid';
          await supabase
            .from('user_licenses')
            .update({
              notes: JSON.stringify(parsed),
              updated_at: new Date().toISOString(),
            })
            .eq('id', lic.id);
          updatedCount++;
        }
      } catch (_) {}
    }

    revalidatePath('/dashboard/kosanku');
    return {
      success: true,
      message: `${updatedCount} komisi untuk mitra "${referrerName}" berhasil ditandai LUNAS!`,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

/**
 * Mengubah status aktif lisensi
 */
export async function toggleLicenseStatusAction(id: string, currentStatus: boolean) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { error } = await supabase
      .from('user_licenses')
      .update({
        is_active: !currentStatus,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id);

    if (error) {
      return { success: false, message: `Gagal mengubah status: ${error.message}` };
    }

    revalidatePath('/dashboard/kosanku');
    return { success: true, message: `Status lisensi berhasil diubah jadi ${!currentStatus ? 'Aktif' : 'Nonaktif'}` };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

/**
 * Menambah masa aktif lisensi (misal +30 hari atau +365 hari)
 */
export async function extendLicenseExpiryAction(id: string, daysToAdd: number) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { data: license, error: fetchErr } = await supabase
      .from('user_licenses')
      .select('expires_at')
      .eq('id', id)
      .single();

    if (fetchErr || !license) {
      return { success: false, message: 'Lisensi tidak ditemukan' };
    }

    const currentExpiry = license.expires_at ? new Date(license.expires_at) : new Date();
    const baseDate = currentExpiry > new Date() ? currentExpiry : new Date();
    baseDate.setDate(baseDate.getDate() + daysToAdd);

    const { error } = await supabase
      .from('user_licenses')
      .update({
        expires_at: baseDate.toISOString(),
        is_active: true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id);

    if (error) {
      return { success: false, message: `Gagal memperpanjang: ${error.message}` };
    }

    revalidatePath('/dashboard/kosanku');
    return { success: true, message: `Masa aktif berhasil diperpanjang +${daysToAdd} hari!` };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

/**
 * Menghapus lisensi
 */
export async function deleteLicenseAction(id: string) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { error } = await supabase.from('user_licenses').delete().eq('id', id);

    if (error) {
      return { success: false, message: `Gagal menghapus: ${error.message}` };
    }

    revalidatePath('/dashboard/kosanku');
    return { success: true, message: 'Lisensi berhasil dihapus' };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}

export interface SetJuraganSubscriptionInput {
  userId: string;
  planCode: 'starter' | 'mandiri_lifetime' | 'cloud_yearly' | 'cloud_monthly' | 'cloud_custom';
  durationYears?: number;
  durationMonths?: number;
  customExpiresAt?: string | null;
  buyerName?: string;
  referrerName?: string;
  commissionAmount?: number;
  commissionStatus?: 'unpaid' | 'paid' | 'none';
  propertyId?: string;
}

/**
 * Mengatur paket langganan langsung untuk akun Juragan Kost (Cloud, Mandiri, atau Starter)
 * Tanpa perlu repot validasi Hardware ID perangkat!
 */
export async function setJuraganSubscriptionAction(data: SetJuraganSubscriptionInput) {
  try {
    await assertAuthorizedAdmin();
    const supabase = getKosankuAdminSupabase();
    const { userId, planCode } = data;

    if (!userId) {
      return { success: false, message: 'User ID Juragan Kost tidak ditemukan!' };
    }

    // Ambil data lisensi lama jika sudah pernah ada (untuk ambil history & masa aktif lama)
    const { data: existingRows } = await supabase
      .from('user_licenses')
      .select('id, expires_at, notes, plan_code, serial_key, hardware_id')
      .eq('user_id', userId)
      .limit(1);

    const existing = existingRows && existingRows.length > 0 ? existingRows[0] : null;

    let existingHistory: any[] = [];
    if (existing?.notes) {
      try {
        const parsed = JSON.parse(existing.notes);
        if (Array.isArray(parsed.history)) existingHistory = parsed.history;
      } catch (_) {}
    }

    const now = new Date();

    // 1. Jika diubah ke Starter (Free / Nonaktifkan Lisensi Berbayar)
    if (planCode === 'starter') {
      const historyItem = {
        id: `hist_${Date.now()}`,
        action: 'DEMOTE_TO_STARTER',
        plan_code: 'starter',
        plan_name: 'Starter (Free)',
        duration_text: 'Kembali ke Free',
        previous_expiry: existing?.expires_at || null,
        new_expiry: null,
        buyer_name: data.buyerName || null,
        created_at: now.toISOString(),
        created_by: 'Super Admin Web',
        reason: 'Diubah ke paket Starter (Free)',
      };

      const { error } = await supabase
        .from('user_licenses')
        .update({
          is_active: false,
          notes: JSON.stringify({
            demoted_at: now.toISOString(),
            reason: 'Diubah ke paket Starter (Free)',
            buyer_name: data.buyerName || null,
            history: [...existingHistory, historyItem],
          }),
          updated_at: now.toISOString(),
        })
        .eq('user_id', userId);

      if (error) {
        return { success: false, message: `Gagal mengubah ke Starter: ${error.message}` };
      }

      revalidatePath('/dashboard/kosanku');
      return { success: true, message: 'Status Juragan berhasil diubah ke Starter (Free).' };
    }

    // 2. Jika Paket Mandiri Lifetime (1x Beli)
    if (planCode === 'mandiri_lifetime') {
      const shortId = userId.replace(/-/g, '').slice(0, 8).toUpperCase();
      const hardwareId = existing?.hardware_id || `ACCOUNT_${shortId}`;
      const serialKey = existing?.serial_key || `MANDIRI_${shortId}`;

      const historyItem = {
        id: `hist_${Date.now()}`,
        action: existing ? 'PLAN_CHANGE_MANDIRI' : 'NEW_ACTIVATION_MANDIRI',
        plan_code: 'mandiri_lifetime',
        plan_name: 'Juragan Mandiri (Lifetime)',
        duration_text: 'Lifetime (1x Beli Permanen)',
        previous_expiry: existing?.expires_at || null,
        new_expiry: null,
        buyer_name: data.buyerName || null,
        referrer_name: data.referrerName || null,
        commission_amount: Number(data.commissionAmount) || 0,
        commission_status: data.commissionStatus || (data.referrerName ? 'unpaid' : 'none'),
        created_at: now.toISOString(),
        created_by: 'Super Admin Web',
      };

      const commissionData = {
        buyer_name: data.buyerName || null,
        referrer_name: data.referrerName || null,
        commission_amount: Number(data.commissionAmount) || 0,
        commission_status: data.commissionStatus || (data.referrerName ? 'unpaid' : 'none'),
        property_id: data.propertyId || null,
        set_by: 'Super Admin Web',
        activated_via: 'direct_account_assignment',
        history: [...existingHistory, historyItem],
      };

      if (existing) {
        const { error } = await supabase
          .from('user_licenses')
          .update({
            plan_code: 'mandiri_lifetime',
            is_active: true,
            expires_at: null,
            notes: JSON.stringify(commissionData),
            updated_at: now.toISOString(),
          })
          .eq('id', existing.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('user_licenses')
          .insert({
            user_id: userId,
            hardware_id: hardwareId,
            plan_code: 'mandiri_lifetime',
            serial_key: serialKey,
            is_active: true,
            expires_at: null,
            notes: JSON.stringify(commissionData),
          });

        if (error) throw error;
      }

      revalidatePath('/dashboard/kosanku');
      return {
        success: true,
        message: 'Status Juragan Mandiri (Lifetime) berhasil diaktifkan untuk akun ini!',
      };
    }

    // 3. Jika Paket Cloud (Multi-HP Berlangganan)
    // AKUMULASI CERDAS: Jika saat ini masih aktif, perpanjangan dihitung dari tanggal berakhir saat ini!
    let baseDate = now;
    const isCurrentlyActive = existing?.expires_at && new Date(existing.expires_at) > now;
    if (isCurrentlyActive && planCode.includes('cloud')) {
      baseDate = new Date(existing.expires_at!);
    }

    let expiresAt: Date;
    let durationText = '';

    if (data.customExpiresAt) {
      expiresAt = new Date(data.customExpiresAt);
      durationText = 'Kustom Tanggal';
    } else if (data.durationYears && data.durationYears > 0) {
      expiresAt = new Date(baseDate);
      expiresAt.setFullYear(expiresAt.getFullYear() + data.durationYears);
      durationText = `${data.durationYears} Tahun${isCurrentlyActive ? ' (Perpanjangan)' : ''}`;
    } else if (data.durationMonths && data.durationMonths > 0) {
      expiresAt = new Date(baseDate);
      expiresAt.setMonth(expiresAt.getMonth() + data.durationMonths);
      durationText = `${data.durationMonths} Bulan${isCurrentlyActive ? ' (Perpanjangan)' : ''}`;
    } else if (planCode === 'cloud_monthly') {
      expiresAt = new Date(baseDate);
      expiresAt.setDate(expiresAt.getDate() + 30);
      durationText = `30 Hari${isCurrentlyActive ? ' (Perpanjangan)' : ''}`;
    } else {
      expiresAt = new Date(baseDate);
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
      durationText = `1 Tahun${isCurrentlyActive ? ' (Perpanjangan)' : ''}`;
    }

    const shortId = userId.replace(/-/g, '').slice(0, 8).toUpperCase();
    const hardwareId = existing?.hardware_id || `CLOUD_USER_${shortId}`;
    const serialKey = existing?.serial_key || `CLOUD_ACTIVE_${shortId}`;

    const historyItem = {
      id: `hist_${Date.now()}`,
      action: isCurrentlyActive ? 'RENEWAL' : (existing ? 'RE_ACTIVATION' : 'NEW_ACTIVATION'),
      plan_code: 'cloud_yearly',
      plan_name: 'Juragan Cloud (Multi-HP)',
      duration_text: durationText,
      duration_years: data.durationYears || null,
      previous_expiry: existing?.expires_at || null,
      new_expiry: expiresAt.toISOString(),
      buyer_name: data.buyerName || null,
      referrer_name: data.referrerName || null,
      commission_amount: Number(data.commissionAmount) || 0,
      commission_status: data.commissionStatus || (data.referrerName ? 'unpaid' : 'none'),
      created_at: now.toISOString(),
      created_by: 'Super Admin Web',
    };

    const commissionData = {
      buyer_name: data.buyerName || null,
      referrer_name: data.referrerName || null,
      commission_amount: Number(data.commissionAmount) || 0,
      commission_status: data.commissionStatus || (data.referrerName ? 'unpaid' : 'none'),
      property_id: data.propertyId || null,
      duration_years: data.durationYears || null,
      duration_months: data.durationMonths || null,
      set_by: 'Super Admin Web',
      activated_via: 'direct_account_assignment',
      history: [...existingHistory, historyItem],
    };

    if (existing) {
      const { error } = await supabase
        .from('user_licenses')
        .update({
          plan_code: 'cloud_yearly',
          is_active: true,
          expires_at: expiresAt.toISOString(),
          notes: JSON.stringify(commissionData),
          updated_at: now.toISOString(),
        })
        .eq('id', existing.id);

      if (error) throw error;
    } else {
      const { error } = await supabase
        .from('user_licenses')
        .insert({
          user_id: userId,
          hardware_id: hardwareId,
          plan_code: 'cloud_yearly',
          serial_key: serialKey,
          is_active: true,
          expires_at: expiresAt.toISOString(),
          notes: JSON.stringify(commissionData),
        });

      if (error) throw error;
    }

    const formattedDate = expiresAt.toLocaleDateString('id-ID', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    revalidatePath('/dashboard/kosanku');
    return {
      success: true,
      message: `Langganan Juragan Cloud berhasil ${isCurrentlyActive ? 'diperpanjang' : 'diaktifkan'} s/d ${formattedDate}! Riwayat perpanjangan tersimpan.`,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Terjadi kesalahan sistem' };
  }
}