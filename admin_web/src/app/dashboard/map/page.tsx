'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import { createClient } from '@/lib/supabase/client';
import { MapPin, Warehouse, Users, Eye, EyeOff, Loader2, AlertCircle, RefreshCw } from 'lucide-react';
import type { WarehouseData, BusinessData } from './LeafletMap';

// Dynamic import LeafletMap tanpa SSR agar window terjamin ada di client
const LeafletMap = dynamic(() => import('./LeafletMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex flex-col items-center justify-center bg-slate-50">
      <Loader2 className="animate-spin text-[#0070fc] mb-3" size={36} />
      <p className="text-sm font-semibold text-slate-600">Memuat peta sebaran...</p>
    </div>
  ),
});

const PULSE_CSS = `
@keyframes syupeo-pulse {
  0%   { transform: scale(0.85); opacity: 0.95; }
  65%  { transform: scale(2.4);  opacity: 0;   }
  100% { transform: scale(2.4);  opacity: 0;   }
}
.syupeo-marker-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}
.syupeo-pulse-ring {
  position: absolute;
  inset: -6px;
  border-radius: 50%;
  animation: syupeo-pulse 1.8s ease-out infinite;
}
.syupeo-pulse-ring-slow {
  animation-duration: 2.6s;
  animation-delay: 0.5s;
}
.syupeo-marker-icon {
  position: relative;
  z-index: 2;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2.5px solid white;
  box-shadow: 0 4px 14px rgba(0,0,0,0.3);
  transition: transform 0.2s ease;
}
.syupeo-marker-icon:hover {
  transform: scale(1.12);
}
`;

export default function MapPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [warehouses, setWarehouses] = useState<WarehouseData[]>([]);
  const [businesses, setBusinesses] = useState<BusinessData[]>([]);
  const [showWarehouses, setShowWarehouses] = useState(true);
  const [showBusinesses, setShowBusinesses] = useState(true);

  const supabase = createClient();

  // Inject Pulse CSS
  useEffect(() => {
    if (document.getElementById('syupeo-pulse-css')) return;
    const style = document.createElement('style');
    style.id = 'syupeo-pulse-css';
    style.textContent = PULSE_CSS;
    document.head.appendChild(style);
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [{ data: warehouseData, error: wErr }, { data: businessData, error: bErr }] =
        await Promise.all([
          supabase
            .from('warehouses')
            .select('id, code, name, warehouse_type, address, city, province, latitude, longitude, is_active, pic_name, pic_phone, coverage_radius_km')
            .eq('is_active', true),
          supabase
            .from('businesses')
            .select('id, name, phone, email, business_type, status, address, city, district, latitude, longitude')
            .eq('status', 'active'),
        ]);

      if (wErr) throw wErr;
      if (bErr) throw bErr;

      setWarehouses((warehouseData as WarehouseData[]) || []);
      setBusinesses((businessData as BusinessData[]) || []);
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat data sebaran ekosistem.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const activeWarehouses = warehouses.length;
  const activeBusinesses = businesses.filter((b) => b.status === 'active').length;

  return (
    <div className="relative w-full overflow-hidden" style={{ height: 'calc(100vh - 64px)' }}>
      {/* Peta Utama Leaflet */}
      <LeafletMap
        warehouses={warehouses}
        businesses={businesses}
        showWarehouses={showWarehouses}
        showBusinesses={showBusinesses}
      />

      {/* Loading Overlay */}
      {loading && (
        <div className="absolute inset-0 bg-white/70 backdrop-blur-sm flex flex-col items-center justify-center z-[1000]">
          <Loader2 className="animate-spin text-[#0070fc] mb-3" size={40} />
          <p className="text-sm font-semibold text-slate-700">Memuat data gudang & toko mitra...</p>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="absolute inset-0 flex items-center justify-center z-[1000] bg-white/95">
          <div className="text-center p-8 max-w-md bg-white rounded-2xl shadow-xl border border-red-100">
            <AlertCircle className="text-red-500 mx-auto mb-3" size={48} />
            <h3 className="text-lg font-bold text-gray-800 mb-2">Gagal Memuat Data</h3>
            <p className="text-sm text-gray-500 mb-4">{error}</p>
            <button
              onClick={fetchData}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-[#0070fc] text-white rounded-xl text-sm font-bold hover:bg-blue-600 transition-all shadow-md shadow-blue-500/20"
            >
              <RefreshCw size={15} /> Coba Muat Ulang
            </button>
          </div>
        </div>
      )}

      {/* Control Panel Filter - Kiri Atas */}
      <div className="absolute top-4 left-4 z-[500] bg-white/95 backdrop-blur-md rounded-2xl shadow-xl border border-slate-200/80 p-4 min-w-[240px]">
        <div className="flex items-center justify-between pb-3 mb-3 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-blue-50 flex items-center justify-center">
              <MapPin size={16} className="text-[#0070fc]" />
            </div>
            <div>
              <h3 className="font-bold text-slate-800 text-xs">Peta Sebaran Nasional</h3>
              <p className="text-[10px] text-slate-400">Gudang & Mitra Toko</p>
            </div>
          </div>
        </div>

        {/* Toggle Gudang */}
        <button
          onClick={() => setShowWarehouses((v) => !v)}
          className="flex items-center justify-between w-full mb-2 p-2 rounded-xl hover:bg-slate-50 transition-colors text-left"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-blue-50 flex items-center justify-center">
              <Warehouse size={15} className="text-[#0070fc]" />
            </div>
            <div>
              <p className="text-xs font-bold text-slate-700">Gudang & Hub</p>
              <p className="text-[11px] text-slate-400">{activeWarehouses} aktif</p>
            </div>
          </div>
          {showWarehouses ? (
            <Eye size={17} className="text-[#0070fc]" />
          ) : (
            <EyeOff size={17} className="text-slate-300" />
          )}
        </button>

        {/* Toggle Mitra Toko Retail */}
        <button
          onClick={() => setShowBusinesses((v) => !v)}
          className="flex items-center justify-between w-full mb-3 p-2 rounded-xl hover:bg-slate-50 transition-colors text-left"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-orange-50 flex items-center justify-center">
              <Users size={15} className="text-orange-500" />
            </div>
            <div>
              <p className="text-xs font-bold text-slate-700">Mitra Toko Retail</p>
              <p className="text-[11px] text-slate-400">{activeBusinesses} aktif</p>
            </div>
          </div>
          {showBusinesses ? (
            <Eye size={17} className="text-orange-500" />
          ) : (
            <EyeOff size={17} className="text-slate-300" />
          )}
        </button>

        {/* Ringkasan Status */}
        <div className="border-t border-slate-100 pt-2.5 flex items-center justify-between text-[11px]">
          <span className="font-bold text-[#0070fc]">{activeWarehouses} Gudang</span>
          <span className="text-slate-300">•</span>
          <span className="font-bold text-orange-500">{activeBusinesses} Toko Mitra</span>
        </div>
      </div>

      {/* Legenda - Kanan Bawah */}
      <div className="absolute bottom-6 right-4 z-[500] bg-white/95 backdrop-blur-md rounded-xl shadow-lg border border-slate-200/80 px-4 py-3">
        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Legenda Peta</p>
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2.5">
            <div className="w-3.5 h-3.5 rounded-full bg-[#0070fc] shadow-sm shadow-blue-400 ring-2 ring-blue-100" />
            <span className="text-xs font-medium text-slate-700">Gudang & Hub Syupeo</span>
          </div>
          <div className="flex items-center gap-2.5">
            <div className="w-3.5 h-3.5 rounded-full bg-[#f97316] shadow-sm shadow-orange-400 ring-2 ring-orange-100" />
            <span className="text-xs font-medium text-slate-700">Mitra Toko Retail</span>
          </div>
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-0 border-t-2 border-dashed border-[#0070fc] opacity-60" />
            <span className="text-xs font-medium text-slate-500">Radius Jangkauan Gudang</span>
          </div>
        </div>
      </div>
    </div>
  );
}
