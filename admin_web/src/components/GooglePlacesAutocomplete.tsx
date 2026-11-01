'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Search, MapPin, Loader2, Navigation, ExternalLink, X, CheckCircle2 } from 'lucide-react';

export interface PlaceResult {
  placeId: string;
  name?: string;
  formattedAddress: string;
  latitude: number;
  longitude: number;
  source?: string;
}

interface GooglePlacesAutocompleteProps {
  initialAddress?: string;
  initialLat?: number | null;
  initialLng?: number | null;
  onSelectPlace: (place: PlaceResult) => void;
  placeholder?: string;
}

export default function GooglePlacesAutocomplete({
  initialAddress = '',
  initialLat = null,
  initialLng = null,
  onSelectPlace,
  placeholder = 'Ketik nama jalan, komplek pergudangan, patokan...',
}: GooglePlacesAutocompleteProps) {
  const [query, setQuery] = useState(initialAddress);
  const [suggestions, setSuggestions] = useState<any[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedPlace, setSelectedPlace] = useState<PlaceResult | null>(
    initialLat && initialLng
      ? {
          placeId: 'initial',
          formattedAddress: initialAddress,
          latitude: initialLat,
          longitude: initialLng,
        }
      : null
  );

  const [manualLat, setManualLat] = useState<string>(initialLat ? String(initialLat) : '');
  const [manualLng, setManualLng] = useState<string>(initialLng ? String(initialLng) : '');
  const [showManualCoord, setShowManualCoord] = useState(false);

  const containerRef = useRef<HTMLDivElement>(null);
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Close dropdown when clicked outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Handle Query Changes with Debounce
  const handleInputChange = (val: string) => {
    setQuery(val);
    if (val.trim().length < 2) {
      setSuggestions([]);
      setIsOpen(false);
      return;
    }

    if (debounceTimerRef.current) clearTimeout(debounceTimerRef.current);
    debounceTimerRef.current = setTimeout(async () => {
      setIsLoading(true);
      try {
        const res = await fetch(`/api/places/autocomplete?q=${encodeURIComponent(val)}`);
        const data = await res.json();
        if (data.suggestions) {
          setSuggestions(data.suggestions);
          setIsOpen(true);
        }
      } catch (err) {
        console.error('Error fetching autocomplete:', err);
      } finally {
        setIsLoading(false);
      }
    }, 300);
  };

  // Select a suggestion and fetch coordinates
  const handleSelectSuggestion = async (item: any) => {
    setIsLoading(true);
    setIsOpen(false);
    try {
      if (item.latitude && item.longitude) {
        // Direct coordinates from OSM fallback
        const result: PlaceResult = {
          placeId: item.placeId,
          name: item.title,
          formattedAddress: item.displayName,
          latitude: item.latitude,
          longitude: item.longitude,
          source: 'osm',
        };
        setSelectedPlace(result);
        setQuery(item.displayName);
        setManualLat(String(item.latitude));
        setManualLng(String(item.longitude));
        onSelectPlace(result);
      } else {
        // Resolve via Google Places Details API
        const res = await fetch(`/api/places/details?placeId=${encodeURIComponent(item.placeId)}`);
        const details = await res.json();
        if (details.latitude && details.longitude) {
          const result: PlaceResult = {
            placeId: details.placeId,
            name: details.name || item.title,
            formattedAddress: details.formattedAddress || item.displayName,
            latitude: details.latitude,
            longitude: details.longitude,
            source: 'google',
          };
          setSelectedPlace(result);
          setQuery(result.formattedAddress);
          setManualLat(String(result.latitude));
          setManualLng(String(result.longitude));
          onSelectPlace(result);
        }
      }
    } catch (err) {
      console.error('Error selecting place details:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // Use Current Browser Location (GPS)
  const handleUseCurrentLocation = () => {
    if (!navigator.geolocation) {
      alert('Browser Anda tidak mendukung Geolocation');
      return;
    }
    setIsLoading(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        setManualLat(String(lat));
        setManualLng(String(lng));
        const res: PlaceResult = {
          placeId: 'gps_current',
          formattedAddress: `GPS Device (${lat.toFixed(6)}, ${lng.toFixed(6)})`,
          latitude: lat,
          longitude: lng,
          source: 'gps',
        };
        setSelectedPlace(res);
        onSelectPlace(res);
        setIsLoading(false);
      },
      (err) => {
        console.warn('Geolocation error:', err);
        setIsLoading(false);
        alert('Tidak dapat mendeteksi lokasi otomatis. Silakan ketik nama lokasi.');
      },
      { timeout: 8000 }
    );
  };

  // Update manual coordinates
  const handleApplyManualCoord = () => {
    const lat = parseFloat(manualLat);
    const lng = parseFloat(manualLng);
    if (isNaN(lat) || isNaN(lng)) return;

    const updated: PlaceResult = {
      placeId: selectedPlace?.placeId || 'manual',
      formattedAddress: selectedPlace?.formattedAddress || query || 'Lokasi Kustom',
      latitude: lat,
      longitude: lng,
      source: 'manual',
    };
    setSelectedPlace(updated);
    onSelectPlace(updated);
  };

  return (
    <div className="space-y-2.5" ref={containerRef}>
      <div className="flex items-center justify-between">
        <label className="block text-xs font-semibold text-slate-700">
          Cari Lokasi / Patokan (Google Places API)
        </label>
        <button
          type="button"
          onClick={handleUseCurrentLocation}
          className="inline-flex items-center gap-1 text-[11px] font-medium text-[#0070fc] hover:underline"
        >
          <Navigation className="w-3 h-3" />
          <span>Gunakan Lokasi Saat Ini</span>
        </button>
      </div>

      {/* Input Search Field */}
      <div className="relative">
        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-400">
          {isLoading ? (
            <Loader2 className="w-4 h-4 animate-spin text-[#0070fc]" />
          ) : (
            <Search className="w-4 h-4" />
          )}
        </div>

        <input
          type="text"
          value={query}
          onChange={(e) => handleInputChange(e.target.value)}
          onFocus={() => {
            if (suggestions.length > 0) setIsOpen(true);
          }}
          placeholder={placeholder}
          className="w-full pl-9 pr-8 py-2.5 bg-white border border-slate-300 rounded-lg text-xs font-medium text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0070fc] focus:border-transparent transition-all shadow-sm"
        />

        {query && (
          <button
            type="button"
            onClick={() => {
              setQuery('');
              setSuggestions([]);
              setIsOpen(false);
            }}
            className="absolute inset-y-0 right-0 pr-2.5 flex items-center text-slate-400 hover:text-slate-600"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}

        {/* Dropdown Suggestions */}
        {isOpen && suggestions.length > 0 && (
          <div className="absolute z-50 left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-xl max-h-64 overflow-y-auto divide-y divide-slate-100">
            {suggestions.map((item, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => handleSelectSuggestion(item)}
                className="w-full text-left px-3 py-2.5 hover:bg-blue-50 transition-colors flex items-start gap-2.5 text-xs"
              >
                <MapPin className="w-4 h-4 text-[#0070fc] mt-0.5 shrink-0" />
                <div className="min-w-0 flex-1">
                  <div className="font-semibold text-slate-800 truncate">{item.title}</div>
                  {item.subtitle && (
                    <div className="text-[11px] text-slate-500 truncate">{item.subtitle}</div>
                  )}
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Selected Coordinates Pin Card */}
      {selectedPlace && (
        <div className="bg-blue-50/80 border border-blue-200 rounded-lg p-2.5 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
            <div>
              <div className="font-semibold text-slate-800">
                Koordinat GPS Terkunci
              </div>
              <div className="font-mono text-[11px] text-slate-600">
                Lat: <span className="font-medium text-blue-700">{selectedPlace.latitude.toFixed(6)}</span>,{' '}
                Lng: <span className="font-medium text-blue-700">{selectedPlace.longitude.toFixed(6)}</span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <a
              href={`https://www.google.com/maps/search/?api=1&query=${selectedPlace.latitude},${selectedPlace.longitude}`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 px-2.5 py-1 bg-white border border-slate-200 rounded-md text-[11px] font-medium text-slate-700 hover:bg-slate-50 transition-colors shadow-2xs"
            >
              <ExternalLink className="w-3 h-3 text-[#0070fc]" />
              <span>Cek di Google Maps</span>
            </a>
            <button
              type="button"
              onClick={() => setShowManualCoord(!showManualCoord)}
              className="text-[11px] text-slate-500 hover:text-slate-800 underline"
            >
              {showManualCoord ? 'Tutup' : 'Ubah Manual'}
            </button>
          </div>
        </div>
      )}

      {/* Manual Lat/Long Input (Collapsible) */}
      {showManualCoord && (
        <div className="grid grid-cols-2 gap-2 bg-slate-100 p-2.5 rounded-lg border border-slate-200 text-xs">
          <div>
            <label className="block text-[11px] font-medium text-slate-600 mb-1">Latitude</label>
            <input
              type="text"
              value={manualLat}
              onChange={(e) => setManualLat(e.target.value)}
              placeholder="-6.328186"
              className="w-full px-2.5 py-1.5 bg-white border border-slate-300 rounded font-mono text-xs"
            />
          </div>
          <div>
            <label className="block text-[11px] font-medium text-slate-600 mb-1">Longitude</label>
            <input
              type="text"
              value={manualLng}
              onChange={(e) => setManualLng(e.target.value)}
              placeholder="108.326526"
              className="w-full px-2.5 py-1.5 bg-white border border-slate-300 rounded font-mono text-xs"
            />
          </div>
          <div className="col-span-2 flex justify-end">
            <button
              type="button"
              onClick={handleApplyManualCoord}
              className="px-3 py-1 bg-[#0070fc] text-white rounded text-xs font-semibold hover:bg-blue-600"
            >
              Terapkan Koordinat
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

