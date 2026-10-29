import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import DashboardShell from '@/components/DashboardShell';

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
  let isAuthorized = false;
  let isSuperAdmin = false;
  let canManageLicenses = false;
  let role: 'super_admin' | 'admin' | 'partner' = 'admin';
  let partnerId: string | null = null;

  if (user && user.email) {
    const userEmail = user.email.toLowerCase();
    if (userEmail === adminEmail.toLowerCase()) {
      isAuthorized = true;
      isSuperAdmin = true;
      canManageLicenses = true;
      role = 'super_admin';
    } else {
      const { data: adminRecord } = await supabase
        .from('admin_users')
        .select('id, role, is_active, can_manage_licenses, partner_id')
        .eq('email', userEmail)
        .eq('is_active', true)
        .maybeSingle();

      if (adminRecord) {
        isAuthorized = true;
        role = adminRecord.role as 'super_admin' | 'admin' | 'partner';
        isSuperAdmin = role === 'super_admin';
        canManageLicenses = isSuperAdmin || Boolean(adminRecord.can_manage_licenses);
        partnerId = adminRecord.partner_id || null;
      }
    }
  }

  if (!user || !user.email || !isAuthorized) {
    redirect('/login?error=unauthorized');
  }

  return (
    <DashboardShell
      userEmail={user.email}
      canManageLicenses={canManageLicenses}
      isSuperAdmin={isSuperAdmin}
      role={role}
      partnerId={partnerId}
    >
      {children}
    </DashboardShell>
  );
}
