'use client';

import Navbar from '@/components/Navbar';
import {
  ShieldCheck,
  Database,
  Globe,
  CheckCircle2,
  Copy,
} from 'lucide-react';
import { useState } from 'react';

export default function SettingsPage() {
  const [copied, setCopied] = useState<string | null>(null);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopied(key);
    setTimeout(() => setCopied(null), 2000);
  };

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://kjekiseloobdxomicolo.supabase.co';
  const adminEmail = process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAIL || 'diyanto2911@gmail.com';
  const googleClientId = '617929816223-g6fo9dk64r0nc20gnfaqiqjutlcjotuq.apps.googleusercontent.com';

  return (
    <div>
      <Navbar
        title="Pengaturan Sistem"
        description="Informasi environment, integrasi Supabase, Google SSO, dan petunjuk deployment ke Vercel"
      />

      <div className="space-y-6 mt-6 max-w-4xl">
        {/* Super Admin Info */}
        <div className="bg-white rounded-[12px] p-6 border border-[rgba(26,26,26,0.12)] shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-[8px] bg-[#eff6ff] text-[#0070fc] flex items-center justify-center font-bold">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-base">Super Admin Whitelist</h3>
              <p className="text-xs text-slate-500">Akun dengan hak akses mutlak kontrol platform Syupeo HQ</p>
            </div>
          </div>

          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between">
            <div>
              <div className="text-xs text-slate-500 font-semibold">Email Super Admin:</div>
              <div className="text-sm font-bold text-slate-900 mt-0.5">{adminEmail}</div>
            </div>
            <div className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 border border-emerald-200 text-emerald-700 flex items-center gap-1.5">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
              Tervalidasi Database RLS
            </div>
          </div>
        </div>

        {/* Database & Cloud Config */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-bold">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-base">Koneksi Backend Supabase</h3>
              <p className="text-xs text-slate-500">Database PostgreSQL & Row Level Security (RLS)</p>
            </div>
          </div>

          <div className="space-y-3">
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between">
              <div>
                <span className="text-[11px] text-slate-400 font-bold uppercase tracking-wider block">Supabase Endpoint URL</span>
                <span className="font-mono text-xs text-slate-800 font-semibold">{supabaseUrl}</span>
              </div>
              <button
                onClick={() => copyToClipboard(supabaseUrl, 'url')}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-800 hover:bg-slate-200 transition-colors"
                title="Salin"
              >
                {copied === 'url' ? <CheckCircle2 className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
              </button>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between">
              <div>
                <span className="text-[11px] text-slate-400 font-bold uppercase tracking-wider block">Google OAuth Client ID</span>
                <span className="font-mono text-xs text-slate-800 font-semibold truncate max-w-md block">
                  {googleClientId}
                </span>
              </div>
              <button
                onClick={() => copyToClipboard(googleClientId, 'client_id')}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-800 hover:bg-slate-200 transition-colors"
                title="Salin"
              >
                {copied === 'client_id' ? <CheckCircle2 className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
              </button>
            </div>
          </div>
        </div>

        {/* Vercel Deployment Instructions */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-50 text-orange-600 border border-orange-200 flex items-center justify-center font-bold">
              <Globe className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-base">Panduan Deployment ke Vercel</h3>
              <p className="text-xs text-slate-500">Langkah mudah untuk mempublikasikan Admin Web ini</p>
            </div>
          </div>

          <div className="space-y-3 text-xs text-slate-600 leading-relaxed">
            <div className="p-4 rounded-[8px] bg-slate-50 border border-slate-200">
              <strong className="text-[#0070fc] block mb-1">1. Hubungkan ke Vercel</strong>
              Push repository Syupeo ini ke GitHub. Di dashboard Vercel, pilih <strong>Import Project</strong>, lalu atur <strong>Root Directory</strong> ke folder <code className="text-[#0070fc] font-mono bg-[#eff6ff] px-1.5 py-0.5 rounded">admin_web</code>.
            </div>

            <div className="p-4 rounded-[8px] bg-slate-50 border border-slate-200">
              <strong className="text-[#0070fc] block mb-1">2. Environment Variables di Vercel</strong>
              Tambahkan 3 variable berikut di menu Settings &gt; Environment Variables di project Vercel:
              <ul className="list-disc pl-5 mt-1.5 space-y-1 font-mono text-[11px] text-slate-700">
                <li>NEXT_PUBLIC_SUPABASE_URL</li>
                <li>NEXT_PUBLIC_SUPABASE_ANON_KEY</li>
                <li>NEXT_PUBLIC_SUPER_ADMIN_EMAIL=diyanto2911@gmail.com</li>
              </ul>
            </div>

            <div className="p-4 rounded-[8px] bg-slate-50 border border-slate-200">
              <strong className="text-[#0070fc] block mb-1">3. Tambahkan Domain Vercel ke Google OAuth &amp; Supabase</strong>
              Setelah Vercel memberikan domain (misal: <code className="text-[#0070fc] font-mono bg-[#eff6ff] px-1.5 py-0.5 rounded">https://syupeo-admin.vercel.app</code>):
              <ul className="list-disc pl-5 mt-1.5 space-y-1">
                <li>Buka <strong>Supabase Dashboard &gt; Authentication &gt; URL Configuration &gt; Redirect URLs</strong> dan tambahkan <code className="text-[#0070fc] font-mono bg-[#eff6ff] px-1.5 py-0.5 rounded">https://syupeo-admin.vercel.app/auth/callback</code></li>
                <li>Buka <strong>Google Cloud Console &gt; Credentials &gt; OAuth 2.0 Client IDs</strong> dan tambahkan origin serta redirect URI yang sama.</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
