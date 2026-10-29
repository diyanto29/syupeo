'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

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
    return { user, supabase };
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

  return { user, supabase };
}

export interface AnnouncementItem {
  id: string;
  title: string;
  message: string;
  badge_text: string;
  type: 'feature' | 'info' | 'warning' | 'promo';
  target_criteria: 'all' | 'missing_location' | 'free_plan' | 'pro_plan';
  action_type: 'route' | 'url';
  action_target: string;
  action_label: string;
  secondary_action_target?: string | null;
  secondary_action_label?: string | null;
  is_active: boolean;
  starts_at?: string | null;
  ends_at?: string | null;
  created_at?: string;
  updated_at?: string;
}

export async function getAnnouncements(): Promise<AnnouncementItem[]> {
  const { supabase } = await assertAuthorizedAdmin();

  const { data, error } = await supabase
    .from('system_announcements')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching announcements:', error);
    return [];
  }

  return (data || []) as AnnouncementItem[];
}

export async function saveAnnouncement(
  payload: Partial<AnnouncementItem> & { id?: string }
): Promise<{ success: boolean; error?: string }> {
  try {
    const { supabase } = await assertAuthorizedAdmin();

    const dataToSave = {
      title: payload.title?.trim() || 'Pengumuman Baru',
      message: payload.message?.trim() || '',
      badge_text: payload.badge_text?.trim() || 'PENGUMUMAN',
      type: payload.type || 'feature',
      target_criteria: payload.target_criteria || 'all',
      action_type: payload.action_type || 'route',
      action_target: payload.action_target?.trim() || 'businessProfileEdit',
      action_label: payload.action_label?.trim() || 'Atur Sekarang',
      secondary_action_target: payload.secondary_action_target?.trim() || null,
      secondary_action_label: payload.secondary_action_label?.trim() || null,
      is_active: payload.is_active ?? true,
      updated_at: new Date().toISOString(),
    };

    if (payload.id) {
      // Update
      const { error } = await supabase
        .from('system_announcements')
        .update(dataToSave)
        .eq('id', payload.id);

      if (error) throw error;
    } else {
      // Insert
      const { error } = await supabase
        .from('system_announcements')
        .insert([{ ...dataToSave, created_at: new Date().toISOString() }]);

      if (error) throw error;
    }

    revalidatePath('/dashboard/announcements');
    return { success: true };
  } catch (err: any) {
    console.error('Save announcement error:', err);
    return { success: false, error: err.message || 'Gagal menyimpan pengumuman' };
  }
}

export async function toggleAnnouncementActive(
  id: string,
  isActive: boolean
): Promise<{ success: boolean; error?: string }> {
  try {
    const { supabase } = await assertAuthorizedAdmin();

    const { error } = await supabase
      .from('system_announcements')
      .update({ is_active: isActive, updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) throw error;

    revalidatePath('/dashboard/announcements');
    return { success: true };
  } catch (err: any) {
    console.error('Toggle active error:', err);
    return { success: false, error: err.message || 'Gagal mengubah status' };
  }
}

export async function deleteAnnouncement(
  id: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const { supabase } = await assertAuthorizedAdmin();

    const { error } = await supabase
      .from('system_announcements')
      .delete()
      .eq('id', id);

    if (error) throw error;

    revalidatePath('/dashboard/announcements');
    return { success: true };
  } catch (err: any) {
    console.error('Delete announcement error:', err);
    return { success: false, error: err.message || 'Gagal menghapus pengumuman' };
  }
}
