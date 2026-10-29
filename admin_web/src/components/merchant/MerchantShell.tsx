'use client';

import { useState, useEffect, createContext, useContext } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Business, Outlet } from '@/types/database';
import {
  LayoutDashboard,
  Receipt,
  Package,
  TrendingUp,
  Globe,
  Settings,
  LogOut,
  ChevronDown,
  ExternalLink,
  Store,
  Menu,
  X,
  ShieldAlert,
  ArrowRight,
  RefreshCw,
  Bell,
  Sparkles,
  Tag,
  Boxes,
  BookOpen,
  Wallet,
  Users,
} from 'lucide-react';

interface MerchantContextType {
  business: Business | null;
  outlets: Outlet[];
  selectedOutletId: string; // 'all' or outlet UUID
  setSelectedOutletId: (id: string) => void;
  loading: boolean;
  refreshData: () => Promise<void>;
  isSuperAdmin: boolean;
}

const MerchantContext = createContext<MerchantContextType>({
  business: null,
  outlets: [],
  selectedOutletId: 'all',
  setSelectedOutletId: () => {},
  loading: true,
  refreshData: async () => {},
  isSuperAdmin: false,
});

export const useMerchant = () => useContext(MerchantContext);

export default function MerchantShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  const [business, setBusiness] = useState<Business | null>(null);
  const [allBusinesses, setAllBusinesses] = useState<Business[]>([]);
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [selectedOutletId, setSelectedOutletId] = useState<string>('all');
  const [loading, setLoading] = useState(true);
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [userEmail, setUserEmail] = useState<string>('');
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const fetchOutletsForBusiness = async (bizId: string) => {
    const supabase = createClient();
    const { data: outletData } = await supabase
      .from('outlets')
      .select('*')
      .eq('business_id', bizId)
      .order('name');
    setOutlets(outletData || []);
    setSelectedOutletId('all');
  };

  const handleSelectBusiness = async (bizId: string) => {
    const found = allBusinesses.find((b) => b.id === bizId);
    if (found) {
      setBusiness(found);
      await fetchOutletsForBusiness(found.id);
    }
  };

  const fetchMerchantData = async () => {
    try {
      setLoading(true);
      const supabase = createClient();
      const { data: authData } = await supabase.auth.getUser();
      const user = authData?.user;

      if (!user) {
        router.push('/login');
        return;
      }

      setUserEmail(user.email || '');
      const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
      const isSuper = user.email?.toLowerCase() === adminEmail.toLowerCase();
      setIsSuperAdmin(isSuper);

      let allBizList: Business[] = [];
      if (isSuper) {
        const { data: allB } = await supabase
          .from('businesses')
          .select('*')
          .order('name');
        allBizList = allB || [];
        setAllBusinesses(allBizList);
      }

      // Cari bisnis milik user
      let { data: bizData } = await supabase
        .from('businesses')
        .select('*')
        .eq('owner_user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      // Jika user adalah super admin dan tidak punya bisnis sendiri, ambil bisnis pertama untuk preview
      if (!bizData && isSuper && allBizList.length > 0) {
        bizData = allBizList[0];
      }

      // Jika belum ditemukan, cari melalui business_members
      if (!bizData) {
        const { data: member } = await supabase
          .from('business_members')
          .select('business_id, businesses(*)')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();
        if (member && member.businesses) {
          bizData = member.businesses as any;
        }
      }

      setBusiness(bizData || null);

      if (bizData) {
        await fetchOutletsForBusiness(bizData.id);
      }
    } catch (err) {
      console.error('Error loading merchant data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMerchantData();
  }, []);

  const handleLogout = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  const navSections = [
    {
      title: 'OPERASIONAL',
      items: [
        {
          name: 'Analitik & Omzet',
          href: '/merchant',
          icon: LayoutDashboard,
          badge: 'Live',
        },
        {
          name: 'Riwayat Transaksi',
          href: '/merchant/transactions',
          icon: Receipt,
        },
        {
          name: 'Arus Kas & Shift',
          href: '/merchant/cash-flow',
          icon: Wallet,
        },
        {
          name: 'Buku Kasbon & Piutang',
          href: '/merchant/debts',
          icon: BookOpen,
        },
      ],
    },
    {
      title: 'KATALOG & LAPORAN',
      items: [
        {
          name: 'Katalog Produk',
          href: '/merchant/products',
          icon: Package,
        },
        {
          name: 'Bahan & Inventaris',
          href: '/merchant/inventory',
          icon: Boxes,
        },
        {
          name: 'Diskon & Promo',
          href: '/merchant/discounts',
          icon: Tag,
        },
        {
          name: 'Laporan Keuangan',
          href: '/merchant/reports',
          icon: TrendingUp,
        },
        {
          name: 'AI Business Copilot',
          href: '/merchant/ai',
          icon: Sparkles,
          badge: 'PRO',
        },
      ],
    },
    {
      title: 'PENGATURAN TOKO',
      items: [
        {
          name: 'Toko Online & QR',
          href: '/merchant/online-shop',
          icon: Globe,
        },
        {
          name: 'Kelola Karyawan',
          href: '/merchant/staff',
          icon: Users,
        },
        {
          name: 'Kelola Cabang',
          href: '/merchant/outlets',
          icon: Store,
        },
        {
          name: 'Pengaturan Toko',
          href: '/merchant/settings',
          icon: Settings,
        },
      ],
    },
  ];

  return (
    <MerchantContext.Provider
      value={{
        business,
        outlets,
        selectedOutletId,
        setSelectedOutletId,
        loading,
        refreshData: fetchMerchantData,
        isSuperAdmin,
      }}
    >
      <div className="min-h-screen bg-[#F8FAFC] flex text-slate-900">
        {/* Mobile Sidebar Backdrop */}
        {sidebarOpen && (
          <div
            onClick={() => setSidebarOpen(false)}
            className="fixed inset-0 bg-slate-900/50 backdrop-blur-xs z-40 lg:hidden"
          />
        )}

        {/* Sidebar */}
        <aside
          className={`fixed inset-y-0 left-0 z-50 w-64 bg-white border-r border-slate-200/90 flex flex-col transition-transform duration-200 lg:translate-x-0 ${
            sidebarOpen ? 'translate-x-0' : '-translate-x-full'
          }`}
        >
          {/* Logo & Store Header */}
          <div className="p-5 border-b border-slate-100 flex items-center justify-between">
            <Link href="/merchant" className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl overflow-hidden bg-orange-50 border border-orange-100 flex items-center justify-center flex-shrink-0">
                <Image src="/logo.png" alt="Mangga POS" width={40} height={40} className="w-full h-full object-cover" />
              </div>
              <div>
                <span className="font-black text-sm tracking-tight text-slate-900 block leading-tight">
                  Mangga POS
                </span>
                <span className="text-[11px] font-semibold text-orange-600 block">
                  Merchant Backoffice
                </span>
              </div>
            </Link>
            <button
              onClick={() => setSidebarOpen(false)}
              className="lg:hidden p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-50"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Business & Outlet Card */}
          <div className="p-4 border-b border-slate-100 bg-slate-50/60 space-y-2.5">
            {isSuperAdmin && allBusinesses.length > 0 ? (
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-[10px] font-bold text-orange-600 uppercase tracking-wider flex items-center gap-1">
                    <Sparkles className="w-3 h-3" />
                    <span>Mode Admin: Pilih Toko</span>
                  </label>
                  <span className="text-[9px] bg-orange-100 text-orange-800 font-black px-1.5 py-0.5 rounded">
                    Super
                  </span>
                </div>
                <div className="relative">
                  <select
                    value={business?.id || ''}
                    onChange={(e) => handleSelectBusiness(e.target.value)}
                    className="w-full text-xs font-bold py-1.5 pl-2.5 pr-7 bg-white border border-orange-300 rounded-lg text-slate-900 focus:outline-none focus:border-orange-500 appearance-none shadow-xs"
                  >
                    {allBusinesses.map((b) => (
                      <option key={b.id} value={b.id}>
                        {b.name}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-400 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
                </div>
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <Store className="w-4 h-4 text-orange-600 flex-shrink-0" />
                <h2 className="text-xs font-bold text-slate-900 truncate">
                  {business?.name || 'Memuat Bisnis...'}
                </h2>
              </div>
            )}

            {/* Outlet Selector Dropdown */}
            {outlets.length > 0 && (
              <div>
                <label className="block text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                  Filter Outlet
                </label>
                <div className="relative">
                  <select
                    value={selectedOutletId}
                    onChange={(e) => setSelectedOutletId(e.target.value)}
                    className="w-full text-xs font-semibold py-1.5 pl-2.5 pr-7 bg-white border border-slate-200 rounded-lg text-slate-800 focus:outline-none focus:border-orange-500 appearance-none shadow-xs"
                  >
                    <option value="all">Semua Outlet ({outlets.length})</option>
                    {outlets.map((outlet) => (
                      <option key={outlet.id} value={outlet.id}>
                        {outlet.name} {outlet.code === 'main' ? '(Utama)' : ''}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-400 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
                </div>
              </div>
            )}
          </div>

          {/* Nav Items */}
          <nav className="flex-1 p-3 space-y-3.5 overflow-y-auto">
            {navSections.map((section, idx) => (
              <div key={section.title} className="space-y-1">
                <div className={`flex items-center gap-2 px-3 pb-1 ${idx === 0 ? 'pt-0.5' : 'pt-2'}`}>
                  <span className="text-[10px] font-extrabold tracking-wider text-slate-400 uppercase">
                    {section.title}
                  </span>
                  <div className="h-px flex-1 bg-slate-200/70" />
                </div>
                <div className="space-y-1">
                  {section.items.map((item) => {
                    const isActive =
                      item.href === '/merchant'
                        ? pathname === '/merchant'
                        : pathname === item.href || pathname?.startsWith(`${item.href}/`);
                    const Icon = item.icon;
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        onClick={() => setSidebarOpen(false)}
                        className={`flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-bold transition-all ${
                          isActive
                            ? 'bg-orange-500 text-white shadow-sm shadow-orange-500/20'
                            : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <Icon className={`w-4 h-4 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                          <span>{item.name}</span>
                        </div>
                        {item.badge && (
                          <span
                            className={`text-[9px] px-1.5 py-0.5 rounded-full font-black ${
                              isActive
                                ? 'bg-white/20 text-white'
                                : item.badge === 'PRO'
                                ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                : 'bg-emerald-50 text-emerald-600 border border-emerald-200'
                            }`}
                          >
                            {item.badge}
                          </span>
                        )}
                      </Link>
                    );
                  })}
                </div>
              </div>
            ))}
          </nav>

          {/* Quick link to live online shop */}
          {business?.slug && (
            <div className="p-3 border-t border-slate-100">
              <a
                href={`https://pos.mudahkan.online/s/${business.slug}`}
                target="_blank"
                rel="noreferrer"
                className="flex items-center justify-between p-2.5 rounded-xl bg-orange-50/70 hover:bg-orange-100/70 border border-orange-200/80 text-orange-800 transition-all text-xs font-bold group"
              >
                <div className="flex items-center gap-2">
                  <Globe className="w-4 h-4 text-orange-600" />
                  <span>Buka Toko Online</span>
                </div>
                <ExternalLink className="w-3.5 h-3.5 text-orange-500 group-hover:translate-x-0.5 transition-transform" />
              </a>
            </div>
          )}

          {/* Super Admin Switcher Link */}
          {isSuperAdmin && (
            <div className="px-3 pb-2">
              <Link
                href="/dashboard"
                className="flex items-center justify-between p-2 rounded-xl bg-slate-900 text-white hover:bg-slate-800 text-xs font-bold transition-all shadow-xs"
              >
                <div className="flex items-center gap-2">
                  <ShieldAlert className="w-3.5 h-3.5 text-orange-400" />
                  <span>Super Admin Panel</span>
                </div>
                <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
              </Link>
            </div>
          )}

          {/* User Info & Logout */}
          <div className="p-3 border-t border-slate-100 bg-slate-50/50 flex items-center justify-between">
            <div className="flex items-center gap-2 overflow-hidden">
              <div className="w-8 h-8 rounded-full bg-slate-200 border border-slate-300 flex items-center justify-center font-bold text-xs text-slate-700 flex-shrink-0">
                {userEmail ? userEmail.charAt(0).toUpperCase() : 'U'}
              </div>
              <div className="truncate">
                <span className="text-[11px] font-bold text-slate-800 block truncate">
                  {userEmail}
                </span>
                <span className="text-[10px] text-slate-400 block">Owner / Merchant</span>
              </div>
            </div>
            <button
              onClick={handleLogout}
              title="Keluar"
              className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </aside>

        {/* Main Content Area */}
        <div className="flex-1 lg:pl-64 flex flex-col min-w-0">
          {/* Top Bar */}
          <header className="sticky top-0 z-30 bg-white/80 backdrop-blur-md border-b border-slate-200/90 h-16 flex items-center justify-between px-4 sm:px-6">
            <div className="flex items-center gap-3">
              <button
                onClick={() => setSidebarOpen(true)}
                className="lg:hidden p-2 rounded-xl text-slate-600 hover:bg-slate-100"
              >
                <Menu className="w-5 h-5" />
              </button>
              <div>
                <h1 className="text-base sm:text-lg font-black text-slate-900 tracking-tight flex items-center gap-2">
                  <span>{business?.name || 'Backoffice Toko'}</span>
                  {business?.business_type && (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-bold uppercase">
                      {business.business_type}
                    </span>
                  )}
                </h1>
              </div>
            </div>

            <div className="flex items-center gap-2.5">
              <button
                onClick={fetchMerchantData}
                disabled={loading}
                title="Refresh Data"
                className="p-2 rounded-xl text-slate-500 hover:text-slate-900 hover:bg-slate-100 transition-colors"
              >
                <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-orange-500' : ''}`} />
              </button>

              {business?.slug && (
                <a
                  href={`https://pos.mudahkan.online/s/${business.slug}`}
                  target="_blank"
                  rel="noreferrer"
                  className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl bg-orange-50 text-orange-700 hover:bg-orange-100 border border-orange-200 transition-colors"
                >
                  <Globe className="w-3.5 h-3.5" />
                  <span>Lihat Toko Online</span>
                  <ExternalLink className="w-3 h-3 ml-0.5" />
                </a>
              )}
            </div>
          </header>

          {/* Page Body */}
          <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto relative">
            {children}

            {pathname !== '/merchant/ai' && (
              <Link
                href="/merchant/ai"
                className="fixed bottom-6 right-6 z-40 flex items-center gap-2.5 px-4 py-3 bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white rounded-2xl shadow-xl shadow-orange-500/30 font-black text-xs transition-all hover:scale-105 active:scale-95 group border border-white/20"
              >
                <div className="relative">
                  <Sparkles className="w-4 h-4" />
                  <span className="absolute -top-1 -right-1 w-2 h-2 rounded-full bg-white animate-ping" />
                </div>
                <span>Tanya AI Copilot</span>
              </Link>
            )}
          </main>
        </div>
      </div>
    </MerchantContext.Provider>
  );
}
