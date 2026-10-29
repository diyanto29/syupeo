'use client';

import Link from 'next/link';
import Image from 'next/image';
import { usePathname, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import {
  LayoutDashboard,
  Layers,
  Building2,
  Settings,
  LogOut,
  Shield,
  Crown,
  ChevronRight,
  Barcode,
  Receipt,
  KeyRound,
  Lock,
  CreditCard,
  Users,
  Target,
  FileText,
  Home,
  Wallet,
  ShoppingBag,
  Store,
  Megaphone,
  X,
} from 'lucide-react';

const navItems = [
  {
    name: 'Portal Toko (Merchant)',
    href: '/merchant',
    icon: Store,
    description: 'Analitik & Katalog Toko',
  },
  {
    name: 'Overview',
    href: '/dashboard',
    icon: LayoutDashboard,
    description: 'Statistik & Ringkasan',
  },
  {
    name: 'Mini CRM Prospek',
    href: '/dashboard/crm',
    icon: Target,
    description: 'Pipeline Leads & Calon Klien',
  },
  {
    name: 'Surat Penawaran',
    href: '/dashboard/quotations',
    icon: FileText,
    description: 'Quotations & Kirim WhatsApp',
  },
  {
    name: 'Paket Mesin Kasir',
    href: '/dashboard/hardware-packages',
    icon: ShoppingBag,
    description: 'Hardware, Bundling & Brosur PDF',
  },
  {
    name: 'Langganan & Billing',
    href: '/dashboard/subscriptions',
    icon: CreditCard,
    description: 'Aktivasi, Perpanjangan & Trial',
  },
  {
    name: 'Mitra & Komisi',
    href: '/dashboard/partners',
    icon: Users,
    description: 'Bagi Hasil & Saldo Teman',
  },
  {
    name: 'Transaksi & GMV',
    href: '/dashboard/transactions',
    icon: Receipt,
    description: 'Monitoring Penjualan Real-time',
  },
  {
    name: 'Arus Kas & Shift',
    href: '/dashboard/cash-flow',
    icon: Wallet,
    description: 'Kas Laci, Shift & Petty Cash',
  },
  {
    name: 'Master Katalog',
    href: '/dashboard/master-catalog',
    icon: Barcode,
    description: 'Katalog Barcode & Produk Nasional',
  },
  {
    name: 'Paket & Harga App',
    href: '/dashboard/pricing',
    icon: Crown,
    description: 'Atur Harga Paket Pro & Durasi',
  },
  {
    name: 'Lisensi & Serial Key',
    href: '/dashboard/licenses',
    icon: KeyRound,
    description: 'BatiKu, KosanKu & ManggoPOS',
    requiresLicensePermission: true,
  },
  {
    name: 'KosanKu Cloud',
    href: '/dashboard/kosanku',
    icon: Home,
    description: 'Monitoring Kos, Kamar & Lisensi',
  },
  {
    name: 'Template Bisnis',
    href: '/dashboard/templates',
    icon: Layers,
    description: 'Atur Modul & Batasan Fitur',
  },
  {
    name: 'Akun Bisnis',
    href: '/dashboard/businesses',
    icon: Building2,
    description: 'Daftar Bisnis & Ganti Tipe',
  },
  {
    name: 'Kelola Admin',
    href: '/dashboard/admins',
    icon: Shield,
    description: 'Hak Akses & Pengguna Admin',
  },
  {
    name: 'Broadcast Pengumuman',
    href: '/dashboard/announcements',
    icon: Megaphone,
    description: 'Banner Notifikasi & Pengumuman Kasir',
  },
  {
    name: 'Pengaturan Sistem',
    href: '/dashboard/settings',
    icon: Settings,
    description: 'Koneksi & Konfigurasi',
  },
];

interface SidebarProps {
  userEmail?: string;
  canManageLicenses?: boolean;
  isSuperAdmin?: boolean;
  role?: 'super_admin' | 'admin' | 'partner';
  partnerId?: string | null;
  mobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export default function Sidebar({
  userEmail,
  canManageLicenses = true,
  isSuperAdmin = false,
  role = 'admin',
  partnerId,
  mobileOpen = false,
  onCloseMobile,
}: SidebarProps) {
  const pathname = usePathname();
  const router = useRouter();
  const isPartner = role === 'partner';

  const handleSignOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  // Filter menu items if logged in as partner
  const displayedNavItems = isPartner
    ? [
        {
          name: 'Dashboard Mitra',
          href: '/dashboard',
          icon: LayoutDashboard,
          description: 'Saldo, Klien & Komisi',
        },
        {
          name: 'Mini CRM Prospek',
          href: '/dashboard/crm',
          icon: Target,
          description: 'Kelola Prospek Klien Anda',
        },
        {
          name: 'Surat Penawaran',
          href: '/dashboard/quotations',
          icon: FileText,
          description: 'Penawaran & Kirim WhatsApp',
        },
        {
          name: 'Langganan & Trial',
          href: '/dashboard/subscriptions',
          icon: CreditCard,
          description: 'Beri Trial PRO Toko (7-60 Hari)',
        },
        {
          name: 'Paket Mesin Kasir',
          href: '/dashboard/hardware-packages',
          icon: ShoppingBag,
          description: 'Brosur & Paket Hardware',
        },
      ]
    : navItems;

  return (
    <aside
      className={`fixed top-0 bottom-0 left-0 z-50 w-72 sm:w-80 lg:w-64 bg-white border-r border-slate-200 flex flex-col h-screen shadow-2xl lg:shadow-sm transition-transform duration-300 ease-in-out ${
        mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      }`}
    >
      {/* Brand Header */}
      <div className="p-4 sm:p-6 border-b border-slate-100 flex items-center justify-between">
        <Link
          href="/dashboard"
          onClick={() => onCloseMobile?.()}
          className="flex items-center gap-3 group"
        >
          <div className="w-10 h-10 rounded-xl overflow-hidden shadow-sm border border-slate-200 bg-white flex items-center justify-center flex-shrink-0 group-hover:shadow-md transition-shadow">
            <Image
              src="/logo.png"
              alt="Mangga POS Logo"
              width={40}
              height={40}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform"
              priority
            />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-lg text-slate-900 tracking-tight">Mangga POS</span>
              <span className={`px-1.5 py-0.5 text-[10px] font-bold rounded border ${
                isPartner
                  ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                  : 'bg-orange-100 text-orange-700 border-orange-200'
              }`}>
                {isPartner ? 'MITRA' : 'ADMIN'}
              </span>
            </div>
            <p className="text-xs text-slate-500">
              {isPartner ? 'Portal Kemitraan' : 'Super Control Panel'}
            </p>
          </div>
        </Link>

        {/* Tombol Tutup Mobile Drawer */}
        <button
          onClick={onCloseMobile}
          className="lg:hidden p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors"
          aria-label="Tutup Menu"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {/* Switcher to Merchant Portal */}
      <div className="px-3 pt-3 pb-1">
        <Link
          href="/merchant"
          className="flex items-center justify-between p-2.5 rounded-xl bg-orange-50 hover:bg-orange-100 border border-orange-200/90 text-orange-900 font-bold text-xs transition-all shadow-xs group"
        >
          <div className="flex items-center gap-2">
            <Store className="w-4 h-4 text-orange-600" />
            <span>Portal Toko (Merchant View)</span>
          </div>
          <ChevronRight className="w-3.5 h-3.5 text-orange-500 group-hover:translate-x-0.5 transition-transform" />
        </Link>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 p-3 sm:p-4 space-y-1.5 overflow-y-auto">
        <div className="px-3 pb-2 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
          {isPartner ? 'Menu Kemitraan' : 'Menu Utama'}
        </div>
        {displayedNavItems.map((item) => {
          const isLicenseItem = item.href === '/dashboard/licenses';
          const isLocked = isLicenseItem && !canManageLicenses && !isSuperAdmin;

          const isActive =
            pathname === item.href ||
            (item.href !== '/dashboard' && pathname.startsWith(item.href));
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => onCloseMobile?.()}
              className={`flex items-center justify-between px-3.5 py-3 rounded-xl text-sm font-medium transition-all duration-200 group ${
                isActive
                  ? 'bg-orange-50 text-orange-600 border border-orange-200/80 shadow-sm font-semibold'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50 border border-transparent'
              }`}
            >
              <div className="flex items-center gap-3 min-w-0">
                <Icon
                  className={`w-5 h-5 flex-shrink-0 transition-colors ${
                    isActive ? 'text-orange-600' : 'text-slate-400 group-hover:text-slate-600'
                  }`}
                />
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="font-semibold text-sm truncate">{item.name}</span>
                    {isLocked && (
                      <Lock className="w-3 h-3 text-slate-400 flex-shrink-0" />
                    )}
                  </div>
                  <div
                    className={`text-[11px] truncate ${
                      isLocked
                        ? 'text-amber-600'
                        : isActive
                        ? 'text-orange-600/80'
                        : 'text-slate-400 group-hover:text-slate-500'
                    }`}
                  >
                    {isLocked ? 'Izin Super Admin' : item.description}
                  </div>
                </div>
              </div>
              {isActive && <ChevronRight className="w-4 h-4 text-orange-600 flex-shrink-0" />}
            </Link>
          );
        })}
      </nav>

      {/* User Footer */}
      <div className="p-4 border-t border-slate-100 bg-slate-50/50">
        <div className="flex items-center justify-between gap-3 p-2.5 rounded-xl bg-white border border-slate-200 shadow-sm">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className={`w-8 h-8 rounded-full border flex items-center justify-center flex-shrink-0 font-bold text-xs ${
              isPartner
                ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                : 'bg-orange-100 text-orange-700 border-orange-200'
            }`}>
              {isPartner ? 'MT' : isSuperAdmin ? 'SA' : 'AD'}
            </div>
            <div className="min-w-0">
              <div className="text-xs font-bold text-slate-800 truncate">
                {isPartner ? 'Mitra Marketer' : isSuperAdmin ? 'Super Admin' : 'Admin'}
              </div>
              <div className="text-[11px] text-slate-500 truncate">{userEmail || 'diyanto2911@gmail.com'}</div>
            </div>
          </div>

          <button
            onClick={handleSignOut}
            title="Keluar"
            className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
}
