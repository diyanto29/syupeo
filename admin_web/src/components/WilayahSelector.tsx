'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Loader2, MapPin, ChevronDown, Search, Check, X } from 'lucide-react';

export interface WilayahSelection {
  provinceCode: string;
  provinceName: string;
  regencyCode: string;
  regencyName: string;
  districtCode: string;
  districtName: string;
  villageCode: string;
  villageName: string;
  formattedText: string;
}

interface WilayahItem {
  code: string;
  name: string;
}

interface SearchableSelectProps {
  label: string;
  items: WilayahItem[];
  selectedItem: WilayahItem | null;
  onSelect: (item: WilayahItem | null) => void;
  placeholder: string;
  disabledPlaceholder?: string;
  loading?: boolean;
  disabled?: boolean;
}

function SearchableWilayahSelect({
  label,
  items,
  selectedItem,
  onSelect,
  placeholder,
  disabledPlaceholder = 'Pilih tingkat sebelumnya dulu',
  loading = false,
  disabled = false,
}: SearchableSelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const containerRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);

  // Close when clicked outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Auto focus input when opened
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => {
        searchInputRef.current?.focus();
      }, 50);
    } else {
      setSearchQuery('');
    }
  }, [isOpen]);

  const filteredItems = items.filter((item) =>
    item.name.toLowerCase().includes(searchQuery.toLowerCase().trim())
  );

  return (
    <div className="relative" ref={containerRef}>
      <div className="flex items-center justify-between mb-1">
        <label className="block text-xs font-semibold text-slate-700">{label}</label>
        {loading && (
          <span className="flex items-center gap-1 text-[11px] font-normal text-[#0070fc]">
            <Loader2 className="w-3 h-3 animate-spin" /> Memuat...
          </span>
        )}
      </div>

      {/* Trigger Button */}
      <button
        type="button"
        disabled={disabled || loading}
        onClick={() => setIsOpen(!isOpen)}
        className={`w-full flex items-center justify-between px-3 py-2 text-xs font-medium rounded-lg border text-left transition-all ${
          disabled
            ? 'bg-slate-100 border-slate-200 text-slate-400 cursor-not-allowed'
            : isOpen
            ? 'bg-white border-[#0070fc] ring-2 ring-blue-100 text-slate-900 shadow-xs'
            : selectedItem
            ? 'bg-white border-slate-300 text-slate-900 hover:border-slate-400 shadow-2xs'
            : 'bg-white border-slate-300 text-slate-400 hover:border-slate-400 shadow-2xs'
        }`}
      >
        <span className="truncate pr-2">
          {disabled
            ? disabledPlaceholder
            : selectedItem
            ? selectedItem.name
            : placeholder}
        </span>
        <div className="flex items-center gap-1 shrink-0 text-slate-400">
          {selectedItem && !disabled && (
            <span
              role="button"
              tabIndex={0}
              onClick={(e) => {
                e.stopPropagation();
                onSelect(null);
              }}
              className="p-0.5 hover:text-slate-600 rounded transition-colors"
            >
              <X className="w-3.5 h-3.5" />
            </span>
          )}
          <ChevronDown
            className={`w-3.5 h-3.5 transition-transform duration-200 ${
              isOpen ? 'rotate-180 text-[#0070fc]' : ''
            }`}
          />
        </div>
      </button>

      {/* Dropdown Popover */}
      {isOpen && !disabled && (
        <div className="absolute z-50 left-0 right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-100">
          {/* Search Input Box */}
          <div className="p-2 border-b border-slate-100 bg-slate-50/70">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400" />
              <input
                ref={searchInputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder={`Ketik untuk cari ${label.toLowerCase()}...`}
                className="w-full pl-8 pr-7 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-medium text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-1 focus:ring-[#0070fc] focus:border-[#0070fc]"
              />
              {searchQuery && (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-0.5"
                >
                  <X className="w-3 h-3" />
                </button>
              )}
            </div>
            <div className="flex items-center justify-between px-1 mt-1.5 text-[10px] text-slate-400 font-mono">
              <span>{filteredItems.length} pilihan</span>
              <span>Filter instan</span>
            </div>
          </div>

          {/* List Options */}
          <div className="max-h-52 overflow-y-auto divide-y divide-slate-50 p-1">
            {filteredItems.length === 0 ? (
              <div className="py-6 text-center text-xs text-slate-400">
                Tidak ada hasil untuk &ldquo;<span className="text-slate-600 font-semibold">{searchQuery}</span>&rdquo;
              </div>
            ) : (
              filteredItems.map((item) => {
                const isSelected = selectedItem?.code === item.code;
                return (
                  <button
                    key={item.code}
                    type="button"
                    onClick={() => {
                      onSelect(item);
                      setIsOpen(false);
                    }}
                    className={`w-full flex items-center justify-between px-2.5 py-2 text-xs rounded-lg text-left transition-colors ${
                      isSelected
                        ? 'bg-blue-50 text-[#0070fc] font-bold'
                        : 'text-slate-700 hover:bg-slate-100/80 font-medium'
                    }`}
                  >
                    <span className="truncate pr-2">{item.name}</span>
                    {isSelected && <Check className="w-3.5 h-3.5 text-[#0070fc] shrink-0" />}
                  </button>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
}

interface WilayahSelectorProps {
  initialProvince?: string;
  initialCity?: string;
  initialDistrict?: string;
  initialVillage?: string;
  onChange: (selection: WilayahSelection) => void;
  disabled?: boolean;
}

export default function WilayahSelector({
  initialProvince = '',
  initialCity = '',
  initialDistrict = '',
  initialVillage = '',
  onChange,
  disabled = false,
}: WilayahSelectorProps) {
  // Lists
  const [provinces, setProvinces] = useState<WilayahItem[]>([]);
  const [regencies, setRegencies] = useState<WilayahItem[]>([]);
  const [districts, setDistricts] = useState<WilayahItem[]>([]);
  const [villages, setVillages] = useState<WilayahItem[]>([]);

  // Selected values
  const [selectedProvince, setSelectedProvince] = useState<WilayahItem | null>(null);
  const [selectedRegency, setSelectedRegency] = useState<WilayahItem | null>(null);
  const [selectedDistrict, setSelectedDistrict] = useState<WilayahItem | null>(null);
  const [selectedVillage, setSelectedVillage] = useState<WilayahItem | null>(null);

  // Loading states
  const [loadingProvinces, setLoadingProvinces] = useState(false);
  const [loadingRegencies, setLoadingRegencies] = useState(false);
  const [loadingDistricts, setLoadingDistricts] = useState(false);
  const [loadingVillages, setLoadingVillages] = useState(false);

  // 1. Fetch Provinces on Mount
  useEffect(() => {
    let isMounted = true;
    async function loadProvinces() {
      setLoadingProvinces(true);
      try {
        const res = await fetch('/api/wilayah?type=provinces');
        const json = await res.json();
        if (isMounted && json.data) {
          setProvinces(json.data);
          if (initialProvince) {
            const match = json.data.find(
              (p: WilayahItem) => p.name.toLowerCase() === initialProvince.toLowerCase()
            );
            if (match) setSelectedProvince(match);
          }
        }
      } catch (err) {
        console.error('Gagal mengambil daftar provinsi:', err);
      } finally {
        if (isMounted) setLoadingProvinces(false);
      }
    }
    loadProvinces();
    return () => {
      isMounted = false;
    };
  }, [initialProvince]);

  // 2. Fetch Regencies when selectedProvince changes
  useEffect(() => {
    if (!selectedProvince) {
      setRegencies([]);
      setSelectedRegency(null);
      return;
    }

    let isMounted = true;
    async function loadRegencies() {
      setLoadingRegencies(true);
      try {
        const res = await fetch(`/api/wilayah?type=regencies&code=${selectedProvince?.code}`);
        const json = await res.json();
        if (isMounted && json.data) {
          setRegencies(json.data);
          if (initialCity) {
            const match = json.data.find(
              (r: WilayahItem) =>
                r.name.toLowerCase().includes(initialCity.toLowerCase()) ||
                initialCity.toLowerCase().includes(r.name.toLowerCase())
            );
            if (match) setSelectedRegency(match);
          }
        }
      } catch (err) {
        console.error('Gagal mengambil daftar kota/kabupaten:', err);
      } finally {
        if (isMounted) setLoadingRegencies(false);
      }
    }
    loadRegencies();
    return () => {
      isMounted = false;
    };
  }, [selectedProvince]);

  // 3. Fetch Districts when selectedRegency changes
  useEffect(() => {
    if (!selectedRegency) {
      setDistricts([]);
      setSelectedDistrict(null);
      return;
    }

    let isMounted = true;
    async function loadDistricts() {
      setLoadingDistricts(true);
      try {
        const res = await fetch(`/api/wilayah?type=districts&code=${selectedRegency?.code}`);
        const json = await res.json();
        if (isMounted && json.data) {
          setDistricts(json.data);
          if (initialDistrict) {
            const match = json.data.find(
              (d: WilayahItem) => d.name.toLowerCase() === initialDistrict.toLowerCase()
            );
            if (match) setSelectedDistrict(match);
          }
        }
      } catch (err) {
        console.error('Gagal mengambil daftar kecamatan:', err);
      } finally {
        if (isMounted) setLoadingDistricts(false);
      }
    }
    loadDistricts();
    return () => {
      isMounted = false;
    };
  }, [selectedRegency]);

  // 4. Fetch Villages when selectedDistrict changes
  useEffect(() => {
    if (!selectedDistrict) {
      setVillages([]);
      setSelectedVillage(null);
      return;
    }

    let isMounted = true;
    async function loadVillages() {
      setLoadingVillages(true);
      try {
        const res = await fetch(`/api/wilayah?type=villages&code=${selectedDistrict?.code}`);
        const json = await res.json();
        if (isMounted && json.data) {
          setVillages(json.data);
          if (initialVillage) {
            const match = json.data.find(
              (v: WilayahItem) => v.name.toLowerCase() === initialVillage.toLowerCase()
            );
            if (match) setSelectedVillage(match);
          }
        }
      } catch (err) {
        console.error('Gagal mengambil daftar kelurahan:', err);
      } finally {
        if (isMounted) setLoadingVillages(false);
      }
    }
    loadVillages();
    return () => {
      isMounted = false;
    };
  }, [selectedDistrict]);

  // Emit changes to parent
  useEffect(() => {
    const pName = selectedProvince?.name || '';
    const rName = selectedRegency?.name || '';
    const dName = selectedDistrict?.name || '';
    const vName = selectedVillage?.name || '';

    const parts = [vName, dName ? `Kec. ${dName}` : '', rName, pName].filter(Boolean);
    const formattedText = parts.join(', ');

    onChange({
      provinceCode: selectedProvince?.code || '',
      provinceName: pName,
      regencyCode: selectedRegency?.code || '',
      regencyName: rName,
      districtCode: selectedDistrict?.code || '',
      districtName: dName,
      villageCode: selectedVillage?.code || '',
      villageName: vName,
      formattedText,
    });
  }, [selectedProvince, selectedRegency, selectedDistrict, selectedVillage]);

  return (
    <div className="space-y-3 bg-slate-50 border border-slate-200 rounded-xl p-3.5">
      <div className="flex items-center justify-between pb-1.5 border-b border-slate-200">
        <div className="flex items-center gap-1.5 text-xs font-bold text-slate-800">
          <MapPin className="w-3.5 h-3.5 text-[#0070fc]" />
          <span>Standarisasi Wilayah Administratif (wilayah.id)</span>
        </div>
        <span className="text-[10px] text-blue-700 bg-blue-50 px-2 py-0.5 rounded font-semibold border border-blue-200">
          Searchable Dropdown
        </span>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {/* 1. Provinsi */}
        <SearchableWilayahSelect
          label="Provinsi"
          items={provinces}
          selectedItem={selectedProvince}
          loading={loadingProvinces}
          disabled={disabled || loadingProvinces}
          placeholder="-- Cari / Pilih Provinsi --"
          onSelect={(item) => {
            setSelectedProvince(item);
            setSelectedRegency(null);
            setSelectedDistrict(null);
            setSelectedVillage(null);
          }}
        />

        {/* 2. Kota / Kabupaten */}
        <SearchableWilayahSelect
          label="Kota / Kabupaten"
          items={regencies}
          selectedItem={selectedRegency}
          loading={loadingRegencies}
          disabled={disabled || !selectedProvince || loadingRegencies}
          placeholder="-- Cari / Pilih Kota/Kabupaten --"
          disabledPlaceholder="Pilih Provinsi terlebih dahulu"
          onSelect={(item) => {
            setSelectedRegency(item);
            setSelectedDistrict(null);
            setSelectedVillage(null);
          }}
        />

        {/* 3. Kecamatan */}
        <SearchableWilayahSelect
          label="Kecamatan"
          items={districts}
          selectedItem={selectedDistrict}
          loading={loadingDistricts}
          disabled={disabled || !selectedRegency || loadingDistricts}
          placeholder="-- Cari / Pilih Kecamatan --"
          disabledPlaceholder="Pilih Kota/Kabupaten terlebih dahulu"
          onSelect={(item) => {
            setSelectedDistrict(item);
            setSelectedVillage(null);
          }}
        />

        {/* 4. Kelurahan / Desa */}
        <SearchableWilayahSelect
          label="Kelurahan / Desa"
          items={villages}
          selectedItem={selectedVillage}
          loading={loadingVillages}
          disabled={disabled || !selectedDistrict || loadingVillages}
          placeholder="-- Cari / Pilih Kelurahan/Desa --"
          disabledPlaceholder="Pilih Kecamatan terlebih dahulu"
          onSelect={(item) => {
            setSelectedVillage(item);
          }}
        />
      </div>
    </div>
  );
}
