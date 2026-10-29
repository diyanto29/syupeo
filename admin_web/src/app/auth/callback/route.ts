import { createClient } from '@/lib/supabase/server';
import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const rawNext = searchParams.get('next') ?? '/dashboard';
  
  // Mencegah Open Redirect: pastikan hanya path lokal yang dimulai dengan satu '/'
  const isSafeNext = rawNext.startsWith('/') && !rawNext.startsWith('//') && !rawNext.startsWith('/\\');
  const safeNext = isSafeNext ? rawNext : '/dashboard';

  if (code) {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error && data?.user?.email) {
      const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
      const userEmail = data.user.email.toLowerCase();
      let isAuthorized = userEmail === adminEmail.toLowerCase();

      if (!isAuthorized) {
        const { data: adminRecord } = await supabase
          .from('admin_users')
          .select('id, role')
          .eq('email', userEmail)
          .eq('is_active', true)
          .in('role', ['super_admin', 'admin'])
          .maybeSingle();

        if (adminRecord) {
          isAuthorized = true;
        }
      }

      if (isAuthorized) {
        return NextResponse.redirect(`${origin}${safeNext}`);
      }

      // Check if user is a partner
      const { data: partnerRecord } = await supabase
        .from('admin_users')
        .select('id, role')
        .eq('email', userEmail)
        .eq('is_active', true)
        .eq('role', 'partner')
        .maybeSingle();

      if (partnerRecord) {
        return NextResponse.redirect(`${origin}/dashboard/partners`);
      }

      // Check if user is a merchant owner or member
      const { data: business } = await supabase
        .from('businesses')
        .select('id')
        .eq('owner_user_id', data.user.id)
        .maybeSingle();

      if (business) {
        const dest = safeNext.startsWith('/merchant') ? safeNext : '/merchant';
        return NextResponse.redirect(`${origin}${dest}`);
      }

      const { data: member } = await supabase
        .from('business_members')
        .select('business_id')
        .eq('user_id', data.user.id)
        .maybeSingle();

      if (member) {
        const dest = safeNext.startsWith('/merchant') ? safeNext : '/merchant';
        return NextResponse.redirect(`${origin}${dest}`);
      }

      // Allow login to merchant view (which will guide onboarding if no business yet)
      return NextResponse.redirect(`${origin}/merchant`);
    }
  }

  // Fallback jika ada error
  return NextResponse.redirect(`${origin}/login?error=auth_failed`);
}
