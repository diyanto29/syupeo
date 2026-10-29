'use server';

import { createClient } from '@/lib/supabase/server';
import CryptoJS from 'crypto-js';

const APP_SECRETS: Record<string, { secret: string; salt: string }> = {
  BATIKU: {
    secret: process.env.BATIKU_OFFLINE_SECRET || 'BATIKU_OFFLINE_SECRET_2026_@PoSystemMasterV1',
    salt: 'BATIKU_HARDWARE_LOCK_SALT',
  },
  KOSANKU: {
    secret: process.env.KOSANKU_OFFLINE_SECRET || 'KOSANKU_OFFLINE_SECRET_2026_@PropertyMasterV1',
    salt: 'KOSANKU_HARDWARE_LOCK_SALT',
  },
  MANGGOPOS: {
    secret: process.env.MANGGOPOS_OFFLINE_SECRET || 'MANGGOPOS_SECRET_2026_@PosMasterV1',
    salt: 'MANGGOPOS_HARDWARE_LOCK_SALT',
  },
};

/**
 * Validasi otorisasi Super Admin atau Admin aktif.
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
 * Server Action privat untuk menghasilkan Serial Key offline secara aman di server side.
 * Mencegah kebocoran secret key HMAC ke dalam JavaScript bundle browser publik.
 */
export async function generateAppSerialKeyAction(params: {
  appCode: 'BATIKU' | 'KOSANKU' | 'MANGGOPOS' | 'CUSTOM';
  deviceId: string;
  customSecret?: string;
  customSalt?: string;
}): Promise<{ success: boolean; serialKey?: string; message?: string }> {
  try {
    await assertAuthorizedAdmin();

    const { appCode, deviceId, customSecret, customSalt } = params;
    const cleanId = deviceId.replace(/-/g, '').trim().toUpperCase();

    if (!cleanId) {
      return { success: false, message: 'Device ID tidak boleh kosong!' };
    }

    let secret = '';
    let salt = '';

    if (appCode === 'CUSTOM') {
      secret = customSecret?.trim() || '';
      salt = customSalt?.trim() || 'CUSTOM_HARDWARE_LOCK_SALT';
    } else {
      const config = APP_SECRETS[appCode];
      if (!config) {
        return { success: false, message: 'Aplikasi tidak dikenal!' };
      }
      secret = config.secret;
      salt = config.salt;
    }

    if (!secret) {
      return { success: false, message: 'Master secret key belum diisi!' };
    }

    const message = cleanId + salt;
    const hmac = CryptoJS.HmacSHA256(message, secret);
    const digest = hmac.toString(CryptoJS.enc.Hex).toUpperCase();

    const p1 = digest.substring(0, 4);
    const p2 = digest.substring(4, 8);
    const p3 = digest.substring(8, 12);
    const p4 = digest.substring(12, 16);

    const serialKey = `${p1}-${p2}-${p3}-${p4}`;
    return { success: true, serialKey };
  } catch (err: any) {
    return { success: false, message: err.message || 'Gagal menghasilkan serial key' };
  }
}
