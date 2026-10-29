'use client';

import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import Sidebar from '@/components/Sidebar';
import { Menu, Shield } from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';

interface DashboardShellProps {
  children: React.ReactNode;
  userEmail?: string;
  canManageLicenses?: boolean;
  isSuperAdmin?: boolean;
  role?: 'super_admin' | 'admin' | 'partner';
  partnerId?: string | null;
}

export default function DashboardShell({
  children,
  userEmail,
  canManageLicenses = true,
  isSuperAdmin = false,
  role = 'admin',
  partnerId = null,
}: DashboardShellProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const pathname = usePathname();

  // Tutup mobile drawer saat berpindah halaman
  useEffect(() => {
    setMobileMenuOpen(false);
  }, [pathname]);

  // Kunci scroll body saat drawer terbuka di layar kecil
  useEffect(() => {
    if (mobileMenuOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [mobileMenuOpen]);

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-800 flex flex-col lg:flex-row">
      {/* Mobile Top App Bar (Hanya tampil di layar ponsel/tablet < lg) */}
      <div className="lg:hidden sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-200 px-4 py-2.5 flex items-center justify-between shadow-xs">
        <Link href="/dashboard" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg overflow-hidden border border-slate-200 bg-white flex items-center justify-center flex-shrink-0 shadow-xs">
            <Image
              src="/logo.png"
              alt="Mangga POS Logo"
              width={32}
              height={32}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform"
              priority
            />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-sm text-slate-900 tracking-tight leading-none">Mangga POS</span>
              <span className={`px-1.5 py-0.2 text-[9px] font-bold rounded border ${
                role === 'partner'
                  ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                  : 'bg-orange-100 text-orange-700 border-orange-200'
              }`}>
                {role === 'partner' ? 'MITRA' : 'ADMIN'}
              </span>
            </div>
            <p className="text-[10px] text-slate-500 leading-tight mt-0.5">
              {role === 'partner' ? 'Portal Kemitraan' : 'Control Panel'}
            </p>
          </div>
        </Link>

        <div className="flex items-center gap-2">
          {isSuperAdmin && (
            <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
              <Shield className="w-3 h-3 text-orange-500" />
              <span>Super Admin</span>
            </span>
          )}
          {role === 'partner' && (
            <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
              <span>Mitra Marketer</span>
            </span>
          )}

          <button
            onClick={() => setMobileMenuOpen(true)}
            className="p-2 rounded-xl text-slate-700 hover:text-slate-900 hover:bg-slate-100 active:bg-slate-200 border border-slate-200 transition-colors"
            aria-label="Buka Menu Navigasi"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Backdrop overlay saat drawer sidebar terbuka di mobile */}
      {mobileMenuOpen && (
        <div
          className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 lg:hidden transition-opacity duration-300"
          onClick={() => setMobileMenuOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* Sidebar (Responsive: drawer di mobile, fixed left di desktop) */}
      <Sidebar
        userEmail={userEmail}
        canManageLicenses={canManageLicenses}
        isSuperAdmin={isSuperAdmin}
        role={role}
        partnerId={partnerId}
        mobileOpen={mobileMenuOpen}
        onCloseMobile={() => setMobileMenuOpen(false)}
      />

      {/* Main Content Area (ml-0 di mobile, ml-64 di desktop) */}
      <div className="flex-1 lg:ml-64 min-w-0 flex flex-col min-h-screen">
        <main className="flex-1 p-3 sm:p-6 lg:p-8 min-w-0 max-w-full overflow-x-hidden">
          {children}
        </main>
      </div>
    </div>
  );
}
