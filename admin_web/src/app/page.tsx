import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ code?: string; error?: string }>;
}) {
  const params = await searchParams;
  if (params?.code) {
    redirect(`/auth/callback?code=${params.code}`);
  }

  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  const user = data?.user;

  if (!user) {
    redirect('/login');
  }

  const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
  if (user.email?.toLowerCase() === adminEmail.toLowerCase()) {
    redirect('/dashboard');
  }

  const { data: adminRecord } = await supabase
    .from('admin_users')
    .select('id')
    .eq('email', user.email?.toLowerCase())
    .eq('is_active', true)
    .maybeSingle();

  if (adminRecord) {
    redirect('/dashboard');
  }

  redirect('/merchant');
}
