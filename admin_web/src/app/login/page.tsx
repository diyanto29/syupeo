'use client';

import { useState, Suspense } from 'react';
import Image from 'next/image';
import { useSearchParams, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Store, AlertCircle, Mail, KeyRound, ArrowRight, Sparkles } from 'lucide-react';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const errorParam = searchParams.get('error');
  const nextParam = searchParams.get('next');

  const [tab, setTab] = useState<'google' | 'password'>('google');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(
    errorParam === 'unauthorized'
      ? 'Akses Ditolak: Akun Anda tidak memiliki hak akses administrator sistem.'
      : errorParam === 'no_business'
      ? 'Akun Anda belum memiliki bisnis terdaftar di Mangga POS. Silakan daftar via aplikasi kasir.'
      : errorParam === 'auth_failed'
      ? 'Autentikasi gagal. Silakan coba kembali.'
      : null
  );

  const handleGoogleLogin = async () => {
    try {
      setLoading(true);
      setErrorMessage(null);
      const supabase = createClient();

      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/auth/callback${nextParam ? `?next=${encodeURIComponent(nextParam)}` : ''}`,
          queryParams: {
            access_type: 'offline',
            prompt: 'select_account',
          },
        },
      });

      if (error) {
        setErrorMessage(error.message);
        setLoading(false);
      }
    } catch (err: any) {
      setErrorMessage(err?.message || 'Terjadi kesalahan sistem.');
      setLoading(false);
    }
  };

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setErrorMessage('Silakan isi email dan password Anda.');
      return;
    }

    try {
      setLoading(true);
      setErrorMessage(null);
      const supabase = createClient();

      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (error) {
        setErrorMessage(error.message === 'Invalid login credentials' 
          ? 'Email atau password yang Anda masukkan salah.' 
          : error.message);
        setLoading(false);
        return;
      }

      if (data.user) {
        // Cek apakah admin atau merchant
        const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
        if (data.user.email?.toLowerCase() === adminEmail.toLowerCase()) {
          router.push(nextParam || '/dashboard');
        } else {
          router.push(nextParam || '/merchant');
        }
        router.refresh();
      }
    } catch (err: any) {
      setErrorMessage(err?.message || 'Gagal masuk. Silakan periksa koneksi internet.');
      setLoading(false);
    }
  };

  return (
    <div className="relative w-full max-w-md">
      {/* Card */}
      <div className="bg-white rounded-3xl p-8 sm:p-10 shadow-2xl border border-slate-200/90">
        {/* Logo & Header */}
        <div className="flex flex-col items-center text-center space-y-3 mb-6">
          <div className="w-16 h-16 rounded-2xl overflow-hidden shadow-lg border border-orange-100 bg-white flex items-center justify-center flex-shrink-0">
            <Image
              src="/logo.png"
              alt="Mangga POS Logo"
              width={64}
              height={64}
              className="w-full h-full object-cover"
              priority
            />
          </div>

          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-orange-50 text-orange-700 border border-orange-200 mb-2">
              <Sparkles className="w-3.5 h-3.5 text-orange-500" />
              Mangga POS Backoffice
            </div>
            <h1 className="text-2xl font-black tracking-tight text-slate-900">Portal Pemilik Toko</h1>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              Pantau omzet, kelola katalog produk, dan laporan analitik bisnis Anda
            </p>
          </div>
        </div>

        {/* Tab switch */}
        <div className="flex p-1 bg-slate-100 rounded-xl mb-6 text-xs font-bold text-slate-600">
          <button
            type="button"
            onClick={() => setTab('google')}
            className={`flex-1 py-2 rounded-lg transition-all ${
              tab === 'google' ? 'bg-white text-slate-900 shadow-sm' : 'hover:text-slate-900'
            }`}
          >
            Google Akun
          </button>
          <button
            type="button"
            onClick={() => setTab('password')}
            className={`flex-1 py-2 rounded-lg transition-all ${
              tab === 'password' ? 'bg-white text-slate-900 shadow-sm' : 'hover:text-slate-900'
            }`}
          >
            Email & Password
          </button>
        </div>

        {/* Error Alert */}
        {errorMessage && (
          <div className="mb-6 p-4 rounded-xl bg-red-50 border border-red-200 flex items-start gap-3 text-red-700 text-sm">
            <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5 text-red-500" />
            <div className="leading-relaxed font-medium text-xs sm:text-sm">{errorMessage}</div>
          </div>
        )}

        {tab === 'google' ? (
          <div>
            {/* Google SSO Button */}
            <button
              onClick={handleGoogleLogin}
              disabled={loading}
              className="w-full relative flex items-center justify-center gap-3 py-3.5 px-4 rounded-xl font-semibold text-slate-700 bg-white hover:bg-slate-50 border-2 border-slate-200 hover:border-orange-400 transition-all duration-200 shadow-xs hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed group"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-orange-500 border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <svg className="w-5 h-5" viewBox="0 0 24 24">
                    <path
                      fill="#4285F4"
                      d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.82-2.4 3.68v3.05h3.88c2.27-2.09 3.665-5.17 3.665-9.17z"
                    />
                    <path
                      fill="#34A853"
                      d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3.05c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.1-6.72-4.93H1.25v3.15C3.26 21.36 7.33 24 12 24z"
                    />
                    <path
                      fill="#FBBC05"
                      d="M5.28 14.27c-.25-.72-.38-1.49-.38-2.27s.13-1.55.38-2.27V6.58H1.25C.45 8.18 0 9.99 0 12s.45 3.82 1.25 5.42l4.03-3.15z"
                    />
                    <path
                      fill="#EA4335"
                      d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.33 0 3.26 2.64 1.25 6.58l4.03 3.15c.95-2.83 3.6-4.98 6.72-4.98z"
                    />
                  </svg>
                  <span className="font-bold text-sm">Masuk dengan Akun Google</span>
                </>
              )}
            </button>
            <p className="text-center text-xs text-slate-400 mt-4">
              Gunakan akun Google yang terdaftar di akun Mangga POS Anda.
            </p>
          </div>
        ) : (
          <form onSubmit={handlePasswordLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Email Toko / Akun</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="nama@toko.com"
                  required
                  className="w-full pl-10 pr-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100 transition-all font-medium text-slate-900"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Password</label>
              <div className="relative">
                <KeyRound className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full pl-10 pr-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100 transition-all font-medium text-slate-900"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl font-bold text-sm text-white bg-orange-600 hover:bg-orange-700 active:bg-orange-800 transition-all shadow-md shadow-orange-600/20 disabled:opacity-50"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <span>Masuk ke Backoffice</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>
        )}

        {/* Footer Info */}
        <div className="mt-8 pt-6 border-t border-slate-100 text-center">
          <p className="text-xs text-slate-400">
            Mangga POS Cloud Ecosystem &copy; {new Date().getFullYear()} • Terhubung dengan Supabase
          </p>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="relative min-h-screen flex items-center justify-center p-4 bg-[#F8FAFC] overflow-hidden">
      {/* Background Decorative Glow in Mangga Orange */}
      <div className="absolute top-1/4 -left-32 w-96 h-96 bg-orange-400/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 -right-32 w-96 h-96 bg-amber-300/10 rounded-full blur-[120px] pointer-events-none" />

      <Suspense
        fallback={
          <div className="text-center text-slate-500">
            <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
            <p className="text-xs font-semibold">Memuat halaman login...</p>
          </div>
        }
      >
        <LoginForm />
      </Suspense>
    </div>
  );
}
