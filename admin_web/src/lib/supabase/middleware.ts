import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const pathname = request.nextUrl.pathname;
  const searchParams = request.nextUrl.searchParams;

  // Jika request mengarah ke API route (/api/*), jangan redirect OAuth
  if (pathname.startsWith('/api/')) {
    return supabaseResponse;
  }

  // Jika ada query parameter ?code= (dari OAuth redirect yang mendarat di /),
  // forward langsung ke /auth/callback agar ditukar menjadi session
  if (searchParams.has('code') && pathname !== '/auth/callback') {
    const url = request.nextUrl.clone();
    url.pathname = '/auth/callback';
    return NextResponse.redirect(url);
  }

  let user = null;
  try {
    const { data } = await supabase.auth.getUser();
    user = data?.user || null;
  } catch {
    user = null;
  }

  const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';

  const isAuthPage = pathname === '/login' || pathname.startsWith('/login');
  const isDashboardPage = pathname === '/dashboard' || pathname.startsWith('/dashboard');
  const isMerchantPage = pathname === '/merchant' || pathname.startsWith('/merchant');

  let isAuthorizedAdmin = false;
  if (user && user.email) {
    const userEmail = user.email.toLowerCase();
    if (userEmail === adminEmail.toLowerCase()) {
      isAuthorizedAdmin = true;
    } else {
      const { data: adminRecord } = await supabase
        .from('admin_users')
        .select('id, role')
        .eq('email', userEmail)
        .eq('is_active', true)
        .in('role', ['super_admin', 'admin'])
        .maybeSingle();

      if (adminRecord) {
        isAuthorizedAdmin = true;
      }
    }
  }

  // Proteksi rute /dashboard (khusus Super Admin)
  if (isDashboardPage) {
    if (!user) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      return NextResponse.redirect(url);
    }

    if (!isAuthorizedAdmin) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('error', 'unauthorized');
      return NextResponse.redirect(url);
    }
  }

  // Proteksi rute /merchant (Merchant & Super Admin)
  if (isMerchantPage) {
    if (!user) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('next', pathname);
      return NextResponse.redirect(url);
    }
  }

  // Jika sudah login dan membuka halaman /login
  if (isAuthPage && user) {
    const url = request.nextUrl.clone();
    if (isAuthorizedAdmin) {
      url.pathname = '/dashboard';
    } else {
      url.pathname = '/merchant';
    }
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
