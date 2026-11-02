'use client';

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

export interface WarehouseData {
  id: string;
  code: string;
  name: string;
  warehouse_type: string | null;
  address: string | null;
  city: string | null;
  province: string | null;
  latitude: number | null;
  longitude: number | null;
  is_active: boolean;
  pic_name: string | null;
  pic_phone: string | null;
  coverage_radius_km: number | null;
}

export interface BusinessData {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  business_type: string | null;
  status: string | null;
  address: string | null;
  city: string | null;
  district: string | null;
  latitude: number | null;
  longitude: number | null;
}

const CITY_COORDS: Record<string, { lat: number; lng: number }> = {
  'Jakarta': { lat: -6.2088, lng: 106.8456 },
  'Jakarta Selatan': { lat: -6.2615, lng: 106.8106 },
  'Jakarta Pusat': { lat: -6.1862, lng: 106.8347 },
  'Jakarta Timur': { lat: -6.2251, lng: 106.9004 },
  'Jakarta Barat': { lat: -6.1688, lng: 106.7637 },
  'Jakarta Utara': { lat: -6.1213, lng: 106.9001 },
  'Indramayu': { lat: -6.3264, lng: 108.3200 },
  'Arahan': { lat: -6.3811, lng: 108.2661 },
  'Surabaya': { lat: -7.2575, lng: 112.7521 },
  'Bandung': { lat: -6.9175, lng: 107.6191 },
  'Medan': { lat: 3.5952, lng: 98.6722 },
  'Semarang': { lat: -6.9932, lng: 110.4203 },
  'Makassar': { lat: -5.1477, lng: 119.4327 },
  'Yogyakarta': { lat: -7.7956, lng: 110.3695 },
  'Denpasar': { lat: -8.6705, lng: 115.2126 },
  'Palembang': { lat: -2.9761, lng: 104.7754 },
  'Tangerang': { lat: -6.1783, lng: 106.6319 },
  'Depok': { lat: -6.4025, lng: 106.7942 },
  'Bekasi': { lat: -6.2383, lng: 106.9756 },
  'Bogor': { lat: -6.5971, lng: 106.8060 },
};

function getWarehouseCoords(w: WarehouseData): { lat: number; lng: number } {
  if (w.latitude && w.longitude) return { lat: w.latitude, lng: w.longitude };
  const city = (w.city || '') + ' ' + (w.address || '');
  for (const [key, coords] of Object.entries(CITY_COORDS)) {
    if (city.toLowerCase().includes(key.toLowerCase())) return coords;
  }
  return {
    lat: -6.2088 + (Math.random() - 0.5) * 1.5,
    lng: 106.8456 + (Math.random() - 0.5) * 1.5,
  };
}

function getBusinessCoords(b: BusinessData): { lat: number; lng: number } {
  if (b.latitude && b.longitude) return { lat: b.latitude, lng: b.longitude };
  const loc = (b.city || '') + ' ' + (b.district || '') + ' ' + (b.address || '');
  for (const [key, coords] of Object.entries(CITY_COORDS)) {
    if (loc.toLowerCase().includes(key.toLowerCase())) return coords;
  }
  return {
    lat: -6.2088 + (Math.random() - 0.5) * 2,
    lng: 106.8456 + (Math.random() - 0.5) * 2,
  };
}

interface LeafletMapProps {
  warehouses: WarehouseData[];
  businesses: BusinessData[];
  showWarehouses: boolean;
  showBusinesses: boolean;
}

export default function LeafletMap({
  warehouses,
  businesses,
  showWarehouses,
  showBusinesses,
}: LeafletMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const markersLayerRef = useRef<L.LayerGroup | null>(null);

  // Inisialisasi Peta
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    // Titik pusat Indonesia (Pulau Jawa / Jabodetabek fokus awal, bisa zoom out)
    const map = L.map(mapContainerRef.current, {
      center: [-6.40, 107.50],
      zoom: 7,
      zoomControl: true,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map);

    const layerGroup = L.layerGroup().addTo(map);
    markersLayerRef.current = layerGroup;
    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, []);

  // Update Markers saat data / toggle filter berubah
  useEffect(() => {
    const map = mapInstanceRef.current;
    const layer = markersLayerRef.current;
    if (!map || !layer) return;

    layer.clearLayers();

    const bounds: [number, number][] = [];

    // 1. Gudang Markers (Biru dengan ripple kelip-kelip)
    if (showWarehouses) {
      warehouses.forEach((w) => {
        const coords = getWarehouseCoords(w);
        bounds.push([coords.lat, coords.lng]);

        const iconHtml = `
          <div class="syupeo-marker-wrapper" style="width:40px;height:40px;">
            <div class="syupeo-pulse-ring" style="background:rgba(0,112,252,0.4);"></div>
            <div class="syupeo-marker-icon" style="width:36px;height:36px;background:#0070fc;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22"/>
              </svg>
            </div>
          </div>`;

        const icon = L.divIcon({
          html: iconHtml,
          className: '',
          iconSize: [40, 40],
          iconAnchor: [20, 20],
          popupAnchor: [0, -22],
        });

        const warehouseTypeBadge = {
          syupeo_hub: 'Hub Nasional',
          distribution_center: 'Pusat Distribusi Regional',
          agent_node: 'Node Agen Lokal',
        }[(w.warehouse_type as string) || ''] ?? w.warehouse_type ?? 'Gudang Syupeo';

        const popupContent = `
          <div style="font-family:Inter,sans-serif;padding:4px 0;min-width:200px;">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
              <span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:#0070fc;"></span>
              <strong style="font-size:14px;color:#0f172a;">${w.name}</strong>
            </div>
            <div style="margin-bottom:8px;">
              <span style="background:#eff6ff;color:#0070fc;padding:2px 8px;border-radius:6px;font-size:11px;font-weight:700;">${warehouseTypeBadge}</span>
              <span style="margin-left:6px;font-size:12px;color:#64748b;font-weight:600;">#${w.code}</span>
            </div>
            ${w.address ? `<p style="font-size:12px;color:#475569;margin:3px 0;">📍 ${w.address}${w.city ? `, ${w.city}` : ''}</p>` : ''}
            ${w.pic_name ? `<p style="font-size:12px;color:#475569;margin:3px 0;">👤 PIC: <strong>${w.pic_name}</strong> (${w.pic_phone || '-'})</p>` : ''}
            ${w.coverage_radius_km ? `<p style="font-size:12px;color:#0284c7;margin:3px 0;font-weight:600;">📡 Radius Layanan: ${w.coverage_radius_km} km</p>` : ''}
          </div>`;

        const marker = L.marker([coords.lat, coords.lng], { icon }).bindPopup(popupContent);
        layer.addLayer(marker);

        // Radius Lingkaran Jangkauan Pengiriman
        if (w.coverage_radius_km) {
          const circle = L.circle([coords.lat, coords.lng], {
            radius: w.coverage_radius_km * 1000,
            color: '#0070fc',
            weight: 1.5,
            opacity: 0.5,
            fillColor: '#0070fc',
            fillOpacity: 0.08,
            dashArray: '6 4',
          });
          layer.addLayer(circle);
        }
      });
    }

    // 2. Mitra Toko Retail Markers (Oranye dengan kelip-kelip)
    if (showBusinesses) {
      businesses.forEach((b) => {
        const coords = getBusinessCoords(b);
        bounds.push([coords.lat, coords.lng]);

        const iconHtml = `
          <div class="syupeo-marker-wrapper" style="width:36px;height:36px;">
            <div class="syupeo-pulse-ring syupeo-pulse-ring-slow" style="background:rgba(249,115,22,0.45);"></div>
            <div class="syupeo-marker-icon" style="width:32px;height:32px;background:#f97316;">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22"/>
              </svg>
            </div>
          </div>`;

        const icon = L.divIcon({
          html: iconHtml,
          className: '',
          iconSize: [36, 36],
          iconAnchor: [18, 18],
          popupAnchor: [0, -20],
        });

        const bizType = b.business_type === 'fnb' ? 'Warung Makan & F&B' : b.business_type === 'service' ? 'Jasa & Layanan' : 'Toko Kelontong & Retail';

        const popupContent = `
          <div style="font-family:Inter,sans-serif;padding:4px 0;min-width:200px;">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
              <span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:#f97316;"></span>
              <strong style="font-size:14px;color:#0f172a;">${b.name}</strong>
            </div>
            <div style="margin-bottom:8px;">
              <span style="background:#fff7ed;color:#ea580c;padding:2px 8px;border-radius:6px;font-size:11px;font-weight:700;">${bizType}</span>
            </div>
            ${b.city || b.district ? `<p style="font-size:12px;color:#475569;margin:3px 0;">📍 ${b.district ? b.district + ', ' : ''}${b.city || ''}</p>` : ''}
            ${b.phone ? `<p style="font-size:12px;color:#475569;margin:3px 0;">📞 WA/Telp: <strong>${b.phone}</strong></p>` : ''}
            ${b.latitude && b.longitude ? `<p style="font-size:11px;color:#94a3b8;margin:3px 0;">🌐 GPS: ${b.latitude.toFixed(4)}, ${b.longitude.toFixed(4)}</p>` : ''}
          </div>`;

        const marker = L.marker([coords.lat, coords.lng], { icon }).bindPopup(popupContent);
        layer.addLayer(marker);
      });
    }

    // Auto-fit view jika ada titik
    if (bounds.length > 0) {
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 14 });
    }
  }, [warehouses, businesses, showWarehouses, showBusinesses]);

  return <div ref={mapContainerRef} className="w-full h-full" style={{ minHeight: '100%' }} />;
}
