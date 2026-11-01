'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Bell, CheckCircle2, UserCheck, Store, ExternalLink, X, Clock, ShoppingBag } from 'lucide-react';

interface PendingBusiness {
  id: string;
  name: string;
  phone: string | null;
  status: string;
  created_at: string;
  starter_kit_id: string | null;
  province?: string | null;
  city?: string | null;
}

export default function NotificationBell() {
  const [pendingBusinesses, setPendingBusinesses] = useState<PendingBusiness[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isActivatingId, setIsActivatingId] = useState<string | null>(null);
  const [hasNewAlert, setHasNewAlert] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);
  const supabase = createClient();

  const playChime = () => {
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
      osc.frequency.setValueAtTime(880, ctx.currentTime + 0.12); // A5
      gain.gain.setValueAtTime(0.12, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.6);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.6);
    } catch (_) {}
  };

  const fetchPending = async (playAudioOnNew = false) => {
    try {
      const { data, error } = await supabase
        .from('businesses')
        .select('id, name, phone, status, created_at, starter_kit_id, province, city')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(10);

      if (!error && data) {
        if (playAudioOnNew && data.length > pendingBusinesses.length) {
          playChime();
          setHasNewAlert(true);
        }
        setPendingBusinesses(data);
      }
    } catch (e) {
      console.warn('[NotificationBell] failed to fetch pending businesses:', e);
    }
  };

  useEffect(() => {
    fetchPending(false);

    // Subscribe to realtime changes on businesses
    const channel = supabase
      .channel('admin-businesses-notifications')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'businesses' },
        (payload) => {
          fetchPending(true);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  // Close popover on click outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  const handleQuickActivate = async (biz: PendingBusiness) => {
    try {
      setIsActivatingId(biz.id);

      // Coba aktivasi melalui RPC activate_business terlebih dahulu
      const { error: rpcErr } = await supabase.rpc('activate_business', {
        p_business_id: biz.id,
      });

      if (rpcErr) {
        console.warn('RPC activate_business warning, fallback direct update:', rpcErr);
        const { error: bizErr } = await supabase
          .from('businesses')
          .update({
            status: 'active',
            subscription_status: 'active',
          })
          .eq('id', biz.id);

        if (bizErr) throw bizErr;

        if (biz.phone) {
          await supabase
            .from('package_fulfillment_orders')
            .update({ status: 'packing' })
            .eq('recipient_phone', biz.phone)
            .eq('status', 'pending_dispatch');
        }
      }

      setPendingBusinesses((prev) => prev.filter((b) => b.id !== biz.id));
    } catch (err: any) {
      alert(`Gagal aktivasi toko: ${err?.message || err}`);
    } finally {
      setIsActivatingId(null);
    }
  };

  const count = pendingBusinesses.length;

  return (
    <div className="relative" ref={popoverRef}>
      {/* Bell Trigger Button */}
      <button
        onClick={() => {
          setIsOpen(!isOpen);
          setHasNewAlert(false);
        }}
        className={`relative p-2 rounded-lg border transition-all ${
          count > 0
            ? 'bg-amber-50 hover:bg-amber-100 border-amber-200 text-amber-800'
            : 'bg-slate-50 hover:bg-slate-100 border-slate-200 text-slate-600'
        }`}
        title={count > 0 ? `${count} Toko Menunggu Aktivasi` : 'Notifikasi'}
        aria-label="Notifikasi Pendaftaran"
      >
        <Bell className={`w-4 h-4 ${hasNewAlert ? 'animate-bounce text-amber-600' : ''}`} />
        {count > 0 && (
          <span className="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 px-1 items-center justify-center rounded-full bg-red-600 text-[10px] font-bold text-white shadow-xs">
            {count > 9 ? '9+' : count}
          </span>
        )}
      </button>

      {/* Popover Dropdown */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 sm:w-96 rounded-xl bg-white border border-slate-200 shadow-xl z-50 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-150">
          {/* Header */}
          <div className="px-4 py-3 bg-slate-50/80 border-b border-slate-200 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="p-1.5 rounded-md bg-amber-100 text-amber-800">
                <Store className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-xs font-bold text-slate-900">Pendaftaran Mitra Toko</h3>
                <p className="text-[11px] text-slate-500">
                  {count > 0 ? `${count} pesanan menunggu aktivasi` : 'Tidak ada antrean baru'}
                </p>
              </div>
            </div>
            <button
              onClick={() => setIsOpen(false)}
              className="text-slate-400 hover:text-slate-600 p-1 rounded-md"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* List of Pending Stores */}
          <div className="max-h-80 overflow-y-auto divide-y divide-slate-100">
            {count === 0 ? (
              <div className="px-4 py-8 text-center">
                <div className="w-10 h-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mx-auto mb-2 border border-emerald-200">
                  <CheckCircle2 className="w-5 h-5" />
                </div>
                <p className="text-xs font-semibold text-slate-800">Semua Toko Telah Aktif</p>
                <p className="text-[11px] text-slate-500 mt-0.5">
                  Belum ada pesanan kemitraan baru yang memerlukan aktivasi.
                </p>
              </div>
            ) : (
              pendingBusinesses.map((biz) => {
                const dateStr = new Date(biz.created_at).toLocaleTimeString('id-ID', {
                  hour: '2-digit',
                  minute: '2-digit',
                });

                return (
                  <div
                    key={biz.id}
                    className="p-3.5 hover:bg-slate-50/80 transition-colors flex flex-col gap-2"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className="font-bold text-xs text-slate-900 truncate">{biz.name}</span>
                          <span className="px-1.5 py-0.5 rounded text-[9px] font-extrabold bg-amber-100 text-amber-800 border border-amber-200">
                            PENDING
                          </span>
                        </div>
                        <p className="text-[11px] text-slate-500 truncate mt-0.5">
                          {biz.city || biz.province ? `${biz.city || ''}, ${biz.province || ''}` : 'Lokasi mitra'}
                          {biz.phone ? ` • WA: ${biz.phone}` : ''}
                        </p>
                      </div>
                      <span className="text-[10px] text-slate-400 flex items-center gap-1 flex-shrink-0">
                        <Clock className="w-3 h-3" />
                        {dateStr}
                      </span>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center justify-between gap-2 pt-1 border-t border-slate-100">
                      <Link
                        href={`/dashboard/businesses/${biz.id}`}
                        onClick={() => setIsOpen(false)}
                        className="text-[11px] font-semibold text-primary hover:underline flex items-center gap-1"
                      >
                        <ExternalLink className="w-3 h-3" />
                        <span>Detail Toko</span>
                      </Link>

                      <button
                        onClick={() => handleQuickActivate(biz)}
                        disabled={isActivatingId === biz.id}
                        className="px-2.5 py-1 rounded-md text-[11px] font-bold bg-emerald-600 hover:bg-emerald-700 text-white transition-all flex items-center gap-1 shadow-2xs disabled:opacity-50"
                      >
                        {isActivatingId === biz.id ? (
                          <span>Mengaktivasi...</span>
                        ) : (
                          <>
                            <UserCheck className="w-3 h-3" />
                            <span>Aktivasi Akun</span>
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Footer */}
          <div className="p-2.5 bg-slate-50 border-t border-slate-200 text-center">
            <Link
              href="/dashboard/businesses?status=pending"
              onClick={() => setIsOpen(false)}
              className="text-xs font-bold text-primary hover:text-primary-hover transition-colors block"
            >
              Lihat Semua Toko di Manajemen Mitra →
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}

