import Link from 'next/link';
import { ExternalLink, Store } from 'lucide-react';
import NotificationBell from '@/components/NotificationBell';

export default function Navbar({ title, description }: { title: string; description?: string }) {
  return (
    <header className="sticky top-0 z-30 flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-4 sm:px-6 lg:px-8 py-3 sm:py-4 bg-white/90 border-b border-slate-200/90 backdrop-blur-md shadow-xs">
      <div className="min-w-0">
        <h1 className="text-lg sm:text-xl font-bold tracking-tight text-slate-900 truncate sm:whitespace-normal">{title}</h1>
        {description && <p className="text-xs text-slate-500 mt-0.5 line-clamp-2 sm:line-clamp-none">{description}</p>}
      </div>

      <div className="flex items-center gap-2 sm:gap-3 flex-wrap">
        {/* Lonceng Notifikasi Toko Pending & Pesanan Baru */}
        <NotificationBell />

        {/* Merchant Portal Quick Switcher */}
        <Link
          href="/merchant"
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-md bg-primary hover:bg-primary-hover text-white text-[11px] sm:text-xs font-bold transition-all shadow-sm shadow-primary/20"
        >
          <Store className="w-3.5 h-3.5 flex-shrink-0" />
          <span>Buka Portal Toko</span>
        </Link>

        {/* Supabase Status Badge */}
        <div className="flex items-center gap-1.5 sm:gap-2 px-2.5 sm:px-3 py-1 sm:py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[11px] sm:text-xs font-semibold">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse flex-shrink-0" />
          <span>Supabase Terhubung</span>
        </div>

        {/* Portal Info */}
        <a
          href={process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fgzmwmtssrviptflsjqy.supabase.co'}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-1.5 px-2.5 sm:px-3 py-1 sm:py-1.5 rounded-md bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 text-[11px] sm:text-xs font-semibold transition-colors"
        >
          <ExternalLink className="w-3.5 h-3.5 flex-shrink-0" />
          <span className="hidden xs:inline sm:inline">Supabase Console</span>
          <span className="xs:hidden sm:hidden">Console</span>
        </a>
      </div>
    </header>
  );
}
