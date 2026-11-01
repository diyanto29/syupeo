'use client';

import { useState, useEffect } from 'react';
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
  Truck,
  X,
} from 'lucide-react';

const navItems = [
  {
    name: 'Portal Toko Retail',
    href: '/merchant',
    icon: Store,
    description: 'Backoffice & Kasir Toko Mitra',
  },
  {
    name: 'Overview HQ',
    href: '/dashboard',
    icon: LayoutDashboard,
    description: 'Statistik & Ringkasan Ekosistem',
  },
  {
    name: 'Paket Usaha Retail',
    href: '/dashboard/starter-kits',
    icon: ShoppingBag,
    description: '4 Paket Awal @ Rp200.000',
  },
  {
    name: 'Gudang & Dispatch',
    href: '/dashboard/warehouses',
    icon: Truck,
    description: 'Multi-Node Agen & Pengiriman',
  },
  {
    name: 'Master Katalog Produk',
    href: '/dashboard/master-catalog',
    icon: Barcode,
    description: 'Harga Pabrik, Grosir & HET',
  },
  {
    name: 'Mitra Toko Retail',
    href: '/dashboard/businesses',
    icon: Building2,
    description: 'Daftar Toko Mitra & Status Paket',
  },
  {
    name: 'Perekrutan Mitra (CRM)',
    href: '/dashboard/crm',
    icon: Target,
    description: 'Pipeline Calon Reseller & Toko',
  },
  {
    name: 'Penawaran Paket Usaha',
    href: '/dashboard/quotations',
    icon: FileText,
    description: 'Kirim Brosur & Penawaran WA',
  },
  {
    name: 'Transaksi & GMV Nasional',
    href: '/dashboard/transactions',
    icon: Receipt,
    description: 'Monitoring Penjualan Retail & Restock',
  },
  {
    name: 'Arus Kas & Shift Kasir',
    href: '/dashboard/cash-flow',
    icon: Wallet,
    description: 'Kas Laci, Shift & Setoran',
  },
  {
    name: 'Mitra Affiliate & Komisi',
    href: '/dashboard/partners',
    icon: Users,
    description: 'Bagi Hasil & Referral Mitra',
  },
  {
    name: 'Kelola Tim Admin',
    href: '/dashboard/admins',
    icon: Shield,
    description: 'Hak Akses & Pengguna HQ',
  },
  {
    name: 'Broadcast Pengumuman',
    href: '/dashboard/announcements',
    icon: Megaphone,
    description: 'Notifikasi & Info Restock Toko',
  },
  {
    name: 'Pengaturan Sistem',
    href: '/dashboard/settings',
    icon: Settings,
    description: 'Koneksi & Konfigurasi Syupeo',
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
  const [pendingCount, setPendingCount] = useState<number>(0);
  const supabase = createClient();

  useEffect(() => {
    const fetchPendingCount = async () => {
      try {
        const { count, error } = await supabase
          .from('businesses')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'pending');
        if (!error && count !== null) {
          setPendingCount(count);
        }
      } catch (_) {}
    };

    fetchPendingCount();

    const channel = supabase
      .channel('sidebar-businesses-pending-count')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'businesses' },
        () => {
          fetchPendingCount();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const handleSignOut = async () => {
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
          name: 'Paket Usaha Retail',
          href: '/dashboard/starter-kits',
          icon: ShoppingBag,
          description: 'Brosur & Paket Usaha Rp200rb',
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
          <div className="w-10 h-10 rounded-[8px] overflow-hidden shadow-xs border border-slate-200 bg-white flex items-center justify-center flex-shrink-0 group-hover:shadow-sm transition-shadow p-1">
            <Image
              src="/syupeo-icon.svg"
              alt="Syupeo"
              width={36}
              height={36}
              className="w-full h-full object-contain group-hover:scale-105 transition-transform"
              priority
            />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-lg text-slate-900 tracking-tight">Syupeo</span>
              <span className={`px-1.5 py-0.5 text-[10px] font-bold rounded-md border ${
                isPartner
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                  : 'bg-primary/10 text-primary border-primary/20'
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
          className="lg:hidden p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-md transition-colors"
          aria-label="Tutup Menu"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {/* Switcher to Merchant Portal */}
      <div className="px-3 pt-3 pb-1">
        <Link
          href="/merchant"
          className="flex items-center justify-between p-2.5 rounded-md bg-blue-50/70 hover:bg-blue-100/70 border border-primary/20 text-slate-800 font-bold text-xs transition-all shadow-xs group"
        >
          <div className="flex items-center gap-2">
            <Store className="w-4 h-4 text-primary" />
            <span>Portal Toko (Merchant View)</span>
          </div>
          <ChevronRight className="w-3.5 h-3.5 text-primary group-hover:translate-x-0.5 transition-transform" />
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
              className={`flex items-center justify-between px-3.5 py-3 rounded-md text-sm font-medium transition-all duration-200 group ${
                isActive
                  ? 'bg-blue-50 text-primary border border-primary/20 shadow-xs font-semibold'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50 border border-transparent'
              }`}
            >
              <div className="flex items-center gap-3 min-w-0">
                <Icon
                  className={`w-5 h-5 flex-shrink-0 transition-colors ${
                    isActive ? 'text-primary' : 'text-slate-400 group-hover:text-slate-600'
                  }`}
                />
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="font-semibold text-sm truncate">{item.name}</span>
                    {item.href === '/dashboard/businesses' && pendingCount > 0 && (
                      <span className="px-1.5 py-0.2 rounded-full text-[10px] font-extrabold bg-amber-500 text-white shadow-2xs animate-pulse">
                        {pendingCount}
                      </span>
                    )}
                    {isLocked && (
                      <Lock className="w-3 h-3 text-slate-400 flex-shrink-0" />
                    )}
                  </div>
                  <div
                    className={`text-[11px] truncate ${
                      isLocked
                        ? 'text-amber-600'
                        : isActive
                        ? 'text-primary/80'
                        : 'text-slate-400 group-hover:text-slate-500'
                    }`}
                  >
                    {isLocked ? 'Izin Super Admin' : item.description}
                  </div>
                </div>
              </div>
              {isActive && <ChevronRight className="w-4 h-4 text-primary flex-shrink-0" />}
            </Link>
          );
        })}
      </nav>

      {/* User Footer */}
      <div className="p-4 border-t border-slate-100 bg-slate-50/50">
        <div className="flex items-center justify-between gap-3 p-2.5 rounded-md bg-white border border-slate-200 shadow-xs">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className={`w-8 h-8 rounded-full border flex items-center justify-center flex-shrink-0 font-bold text-xs ${
              isPartner
                ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                : 'bg-primary/10 text-primary border-primary/20'
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
