'use client';

import { useState, Suspense } from 'react';
import Image from 'next/image';
import { useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import {
  AlertCircle,
  ShieldCheck,
  CheckCircle2,
  ArrowRight,
  PackageCheck,
  Store,
  Truck,
  Sparkles,
} from 'lucide-react';

function LoginForm() {
  const searchParams = useSearchParams();
  const errorParam = searchParams.get('error');
  const nextParam = searchParams.get('next');

  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(
    errorParam === 'unauthorized'
      ? 'Akses Ditolak: Akun Google Anda tidak terdaftar sebagai administrator sistem.'
      : errorParam === 'no_business'
      ? 'Akun Google Anda belum terdaftar sebagai mitra toko Syupeo. Hubungi admin untuk aktivasi.'
      : errorParam === 'auth_failed'
      ? 'Gagal terhubung dengan autentikasi Google. Silakan coba kembali.'
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
      setErrorMessage(err?.message || 'Terjadi kesalahan sistem saat menghubungi Google Auth.');
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-5xl mx-auto bg-white rounded-[12px] border border-[rgba(26,26,26,0.12)] shadow-[0_10px_30px_-5px_rgba(0,112,252,0.08),0_4px_10px_-2px_rgba(26,26,26,0.04)] overflow-hidden grid grid-cols-1 lg:grid-cols-12 min-h-[600px]">
      {/* ========================================================
          LEFT PANEL: Syupeo Brand Showcase & Retail Supply Chain
          ======================================================== */}
      <div className="lg:col-span-7 bg-gradient-to-br from-[#005ecc] via-[#0070fc] to-[#004db3] p-8 sm:p-12 text-white flex flex-col justify-between relative overflow-hidden">
        {/* Subtle Decorative Elements */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-white/10 rounded-full blur-3xl pointer-events-none -mr-20 -mt-20" />
        <div className="absolute bottom-0 left-0 w-64 h-64 bg-[#ffd000]/15 rounded-full blur-3xl pointer-events-none -ml-20 -mb-20" />

        {/* Top Header & Brand */}
        <div className="relative z-10">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-[6px] bg-white/15 backdrop-blur-md border border-white/20 text-white text-[12px] font-semibold mb-6">
            <Sparkles className="w-3.5 h-3.5 text-[#ffd000]" />
            <span>Closed-Loop Supply Chain & Retail POS</span>
          </div>

          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 rounded-[10px] bg-white p-1.5 shadow-md flex items-center justify-center flex-shrink-0">
              <Image
                src="/syupeo-icon.svg"
                alt="Syupeo Icon"
                width={40}
                height={40}
                className="w-full h-full object-contain"
                priority
              />
            </div>
            <div>
              <div className="text-2xl font-black tracking-tight leading-none text-white">
                Syupeo
              </div>
              <div className="text-[12px] text-blue-100 font-medium mt-1">
                Aplikasi Toko Retail Online
              </div>
            </div>
          </div>

          <h2 className="text-2xl sm:text-3xl font-extrabold tracking-tight leading-snug text-white mt-4">
            Dari Stok Pertama, Sampai ke Tangan Pelanggan
          </h2>
          <p className="text-blue-100 text-sm mt-2 max-w-md leading-relaxed font-normal">
            Platform terpadu pasokan langsung pabrik, gudang regional, kasir POS gratis, dan toko online untuk UMKM retail mandiri.
          </p>
        </div>

        {/* Infographic 3-Step Highlights (From User's Infographic) */}
        <div className="relative z-10 space-y-3.5 my-8">
          <div className="p-3.5 rounded-[8px] bg-white/10 backdrop-blur-sm border border-white/15 flex items-start gap-3">
            <div className="w-8 h-8 rounded-[6px] bg-[#ffd000] text-[#1a1a1a] font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5 shadow-sm">
              <PackageCheck className="w-4 h-4 text-[#1a1a1a]" />
            </div>
            <div>
              <div className="text-sm font-bold text-white">1. Starter Kit & Restock Grosir</div>
              <div className="text-xs text-blue-100 mt-0.5">
                Pilih produk dari master katalog nasional dengan harga grosir langsung dari pabrik.
              </div>
            </div>
          </div>

          <div className="p-3.5 rounded-[8px] bg-white/10 backdrop-blur-sm border border-white/15 flex items-start gap-3">
            <div className="w-8 h-8 rounded-[6px] bg-white text-[#0070fc] font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5 shadow-sm">
              <Store className="w-4 h-4 text-[#0070fc]" />
            </div>
            <div>
              <div className="text-sm font-bold text-white">2. Aktivasi Toko & Kasir Gratis</div>
              <div className="text-xs text-blue-100 mt-0.5">
                Kelola kasir POS, stok barang, barcode scanner, dan toko online tanpa biaya langganan.
              </div>
            </div>
          </div>

          <div className="p-3.5 rounded-[8px] bg-white/10 backdrop-blur-sm border border-white/15 flex items-start gap-3">
            <div className="w-8 h-8 rounded-[6px] bg-[#3396fa] text-white font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5 shadow-sm">
              <Truck className="w-4 h-4 text-white" />
            </div>
            <div>
              <div className="text-sm font-bold text-white">3. Pesanan Diproses & Dikirim</div>
              <div className="text-xs text-blue-100 mt-0.5">
                Pelanggan memesan via aplikasi/link toko, pesanan diproses dan dikirim cepat & terpercaya.
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Tagline */}
        <div className="relative z-10 pt-4 border-t border-white/15 flex flex-wrap items-center justify-between text-xs text-blue-100 font-medium gap-2">
          <span>Satu Aplikasi, Banyak Peluang!</span>
          <span className="text-[#ffd000] font-bold">100% Bebas Biaya Software</span>
        </div>
      </div>

      {/* ========================================================
          RIGHT PANEL: Authentication Center (Strictly 8px radius)
          ======================================================== */}
      <div className="lg:col-span-5 p-8 sm:p-12 flex flex-col justify-between bg-white">
        <div>
          {/* Top Badge */}
          <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-[4px] text-[12px] font-semibold bg-[#eff6ff] text-[#0070fc] border border-[#bfdbfe] mb-4">
            <span className="w-1.5 h-1.5 rounded-full bg-[#0070fc]" />
            Portal Masuk Resmi
          </div>

          <h1 className="text-2xl sm:text-[28px] font-bold tracking-tight text-[#1a1a1a] leading-tight">
            Selamat Datang
          </h1>
          <p className="text-sm text-[#64748b] mt-1.5 leading-relaxed">
            Masuk dengan Akun Google untuk mengakses Backoffice Toko Retail atau Super Admin Control Hub.
          </p>

          {/* Error Banner */}
          {errorMessage && (
            <div className="mt-5 p-3 rounded-[8px] bg-[#f0f7ff] border border-[#bfdbfe] flex items-start gap-2.5 text-[#1a1a1a] text-xs sm:text-sm animate-in fade-in duration-200">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-[#3294f5]" />
              <div className="font-medium text-[#1a1a1a]">{errorMessage}</div>
            </div>
          )}

          {/* Single Primary Action: One-Click Google SSO */}
          <div className="mt-8 space-y-4">
            <button
              onClick={handleGoogleLogin}
              disabled={loading}
              className="w-full relative flex items-center justify-center gap-3 py-3.5 px-4 rounded-[8px] font-bold text-sm text-[#1a1a1a] bg-white hover:bg-[#f8fafc] border border-[rgba(26,26,26,0.18)] hover:border-[#0070fc] focus:outline-none focus:ring-2 focus:ring-[#0070fc]/20 transition-all duration-150 shadow-[0_1px_3px_0_rgba(26,26,26,0.06)] active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer group"
            >
              {loading ? (
                <div className="flex items-center gap-2 text-[#0070fc]">
                  <div className="w-4 h-4 border-2 border-[#0070fc] border-t-transparent rounded-full animate-spin" />
                  <span>Menghubungkan Akun Google...</span>
                </div>
              ) : (
                <>
                  <svg className="w-5 h-5 flex-shrink-0" viewBox="0 0 24 24">
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
                  <span className="text-[#1a1a1a]">Lanjutkan dengan Akun Google</span>
                  <ArrowRight className="w-4 h-4 text-[#94a3b8] ml-auto group-hover:translate-x-0.5 group-hover:text-[#0070fc] transition-all" />
                </>
              )}
            </button>

            {/* Role Verification Information */}
            <div className="pt-5 border-t border-[rgba(26,26,26,0.08)] space-y-3">
              <div className="flex items-start gap-2.5 text-xs text-[#64748b]">
                <CheckCircle2 className="w-4 h-4 text-[#0070fc] flex-shrink-0 mt-0.5" />
                <div>
                  <strong className="text-[#1a1a1a] font-semibold">Super Admin:</strong> Mengelola rantai pasok pabrik, katalog nasional, alokasi gudang regional, dan CRM.
                </div>
              </div>
              <div className="flex items-start gap-2.5 text-xs text-[#64748b]">
                <CheckCircle2 className="w-4 h-4 text-[#ba8c02] flex-shrink-0 mt-0.5" />
                <div>
                  <strong className="text-[#1a1a1a] font-semibold">Toko Retail:</strong> Kelola kasir POS, stok kulakan, dan penjualan langsung ke pelanggan.
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Security Badge Footer */}
        <div className="pt-6 mt-8 border-t border-[rgba(26,26,26,0.08)] flex items-center justify-between text-xs text-[#64748b]">
          <span className="flex items-center gap-1.5 font-medium">
            <ShieldCheck className="w-4 h-4 text-[#0070fc]" />
            <span>Google & Supabase Auth</span>
          </span>
          <span className="text-[11px] text-[#94a3b8]">&copy; {new Date().getFullYear()} Syupeo</span>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4 sm:p-6 lg:p-8 bg-[#f8fafc]">
      <Suspense
        fallback={
          <div className="text-center text-[#64748b]">
            <div className="w-6 h-6 border-2 border-[#0070fc] border-t-transparent rounded-full animate-spin mx-auto mb-2" />
            <p className="text-xs font-medium">Memuat halaman login Syupeo...</p>
          </div>
        }
      >
        <LoginForm />
      </Suspense>
    </div>
  );
}
