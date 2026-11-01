'use client';

import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Search, Check, ChevronDown, Plus, Sparkles, Tag } from 'lucide-react';

export interface StandardUnit {
  code: string;
  label: string;
  category: 'eceran' | 'kemasan_besar' | 'timbangan' | 'khusus';
  description?: string;
}

export const STANDARDIZED_UNITS: StandardUnit[] = [
  // Eceran Terpopuler
  { code: 'Pcs', label: 'Pcs', category: 'eceran', description: 'Pieces / Buah eceran umum' },
  { code: 'Bungkus', label: 'Bungkus', category: 'eceran', description: 'Mie instan, biskuit, rokok, snack' },
  { code: 'Botol', label: 'Botol', category: 'eceran', description: 'Minuman botol, kecap, sirup, obat' },
  { code: 'Sachet', label: 'Sachet', category: 'eceran', description: 'Kopi sachet, bumbu, sampo sachet' },
  { code: 'Kaleng', label: 'Kaleng', category: 'eceran', description: 'Susu kental manis, minuman kaleng, sarden' },
  { code: 'Pouch', label: 'Pouch', category: 'eceran', description: 'Minyak goreng pouch, deterjen cair refill' },
  { code: 'Kotak', label: 'Kotak', category: 'eceran', description: 'Teh celup, susu UHT kotak, pasta gigi' },
  { code: 'Cup', label: 'Cup', category: 'eceran', description: 'Air mineral gelas, mie cup, es teh' },
  { code: 'Batang', label: 'Batang', category: 'eceran', description: 'Rokok batangan' },
  { code: 'Lembar', label: 'Lembar', category: 'eceran', description: 'Kertas, kantong plastik, materai' },
  { code: 'Pasang', label: 'Pasang', category: 'eceran', description: 'Sandal, kaos kaki, sarung tangan' },

  // Kemasan Grosir / Dus
  { code: 'Karton', label: 'Karton', category: 'kemasan_besar', description: 'Karton pabrik standar distributor' },
  { code: 'Dus', label: 'Dus', category: 'kemasan_besar', description: 'Kardus mie, sabun, minuman, popok' },
  { code: 'Lusin', label: 'Lusin', category: 'kemasan_besar', description: '1 Lusin = 12 Pcs' },
  { code: 'Renceng', label: 'Renceng', category: 'kemasan_besar', description: '1 Renceng = 10-12 sachet kopi/snack' },
  { code: 'Bal', label: 'Bal', category: 'kemasan_besar', description: 'Bal kerupuk, rokok, karpet, pakaian' },
  { code: 'Slop', label: 'Slop', category: 'kemasan_besar', description: '1 Slop rokok = 10 bungkus' },
  { code: 'Pack', label: 'Pack', category: 'kemasan_besar', description: 'Kemasan multi-pack isi 3-10' },
  { code: 'Peti', label: 'Peti', category: 'kemasan_besar', description: 'Peti kayu telur (10-15 kg), buah' },
  { code: 'Karung', label: 'Karung', category: 'kemasan_besar', description: 'Karung beras, gula, tepung (25-50 kg)' },
  { code: 'Koli', label: 'Koli', category: 'kemasan_besar', description: 'Koli paket kargo ekspedisi' },

  // Timbangan / Volume
  { code: 'Kg', label: 'Kilogram (Kg)', category: 'timbangan', description: 'Beras, gula, telur, daging timbangan' },
  { code: 'Gram', label: 'Gram (gr)', category: 'timbangan', description: 'Bumbu timbang, kopi bubuk, rempah' },
  { code: 'Liter', label: 'Liter (L)', category: 'timbangan', description: 'Minyak curah, bensin, cairan' },
  { code: 'Ml', label: 'Mililiter (ml)', category: 'timbangan', description: 'Sirup, esens, cairan kecil' },

  // Jasa / Kuliner
  { code: 'Porsi', label: 'Porsi', category: 'khusus', description: 'Makanan piring siap saji' },
  { code: 'Paket', label: 'Paket', category: 'khusus', description: 'Bundling kombo beberapa item' },
];

const CATEGORY_LABELS: Record<string, string> = {
  eceran: 'Satuan Eceran Terpopuler',
  kemasan_besar: 'Satuan Grosir / Kemasan Besar',
  timbangan: 'Timbangan & Volume',
  khusus: 'Kuliner & Khusus',
};

interface UnitSelectorProps {
  value: string;
  onChange: (unit: string) => void;
  placeholder?: string;
  categoryFilter?: 'eceran' | 'kemasan_besar' | 'all';
  label?: string;
  helperText?: string;
}

export default function UnitSelector({
  value,
  onChange,
  placeholder = 'Pilih satuan...',
  categoryFilter = 'all',
  label,
  helperText,
}: UnitSelectorProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const containerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Close when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Filtered units
  const filteredUnits = useMemo(() => {
    let list = STANDARDIZED_UNITS;
    if (categoryFilter !== 'all') {
      list = list.filter((u) => u.category === categoryFilter);
    }
    if (!search.trim()) return list;

    const query = search.toLowerCase().trim();
    return list.filter(
      (u) =>
        u.code.toLowerCase().includes(query) ||
        u.label.toLowerCase().includes(query) ||
        (u.description && u.description.toLowerCase().includes(query))
    );
  }, [search, categoryFilter]);

  // Group by category
  const groupedUnits = useMemo(() => {
    const groups: Record<string, StandardUnit[]> = {};
    filteredUnits.forEach((u) => {
      if (!groups[u.category]) groups[u.category] = [];
      groups[u.category].push(u);
    });
    return groups;
  }, [filteredUnits]);

  const handleSelect = (code: string) => {
    onChange(code);
    setIsOpen(false);
    setSearch('');
  };

  const handleCustomAdd = () => {
    if (search.trim()) {
      onChange(search.trim());
      setIsOpen(false);
      setSearch('');
    }
  };

  const selectedItem = useMemo(() => {
    return STANDARDIZED_UNITS.find((u) => u.code.toLowerCase() === (value || '').toLowerCase());
  }, [value]);

  return (
    <div className="relative w-full" ref={containerRef}>
      {label && (
        <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5 flex items-center justify-between">
          <span>{label}</span>
          {value && (
            <span className="text-[10px] font-mono text-[#0070fc] bg-blue-50 px-1.5 py-0.5 rounded border border-blue-200/60 lowercase">
              terpilih: {value}
            </span>
          )}
        </label>
      )}

      {/* Trigger Button */}
      <button
        type="button"
        onClick={() => {
          setIsOpen(!isOpen);
          setTimeout(() => inputRef.current?.focus(), 100);
        }}
        className={`w-full px-3.5 py-2.5 rounded-xl border text-left flex items-center justify-between transition-all bg-white text-sm ${
          isOpen
            ? 'border-[#0070fc] ring-2 ring-[#0070fc]/15 shadow-sm'
            : 'border-slate-200 hover:border-slate-300'
        }`}
      >
        <div className="flex items-center gap-2 truncate">
          <Tag className="w-4 h-4 text-slate-400 shrink-0" />
          {value ? (
            <span className="font-semibold text-slate-900 truncate">
              {selectedItem ? selectedItem.code : value}
              {selectedItem?.description && (
                <span className="text-xs text-slate-400 font-normal ml-2">({selectedItem.description})</span>
              )}
            </span>
          ) : (
            <span className="text-slate-400">{placeholder}</span>
          )}
        </div>
        <ChevronDown
          className={`w-4 h-4 text-slate-400 shrink-0 transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-[#0070fc]' : ''
          }`}
        />
      </button>

      {helperText && <p className="text-[11px] text-slate-400 mt-1">{helperText}</p>}

      {/* Dropdown Popover */}
      {isOpen && (
        <div className="absolute left-0 right-0 top-full mt-1.5 z-50 bg-white rounded-2xl border border-slate-200 shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-150 max-h-80 flex flex-col">
          {/* Live Search Input */}
          <div className="p-2.5 border-b border-slate-100 bg-slate-50/70">
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                ref={inputRef}
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Cari satuan (cth: pcs, dus, kg)..."
                className="w-full pl-8 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-hidden focus:border-[#0070fc] font-medium"
              />
            </div>
          </div>

          {/* Unit List */}
          <div className="overflow-y-auto p-1.5 divide-y divide-slate-100 flex-1">
            {Object.keys(groupedUnits).length === 0 ? (
              <div className="p-4 text-center">
                <p className="text-xs text-slate-500 mb-2">Satuan standar "{search}" tidak ditemukan.</p>
                <button
                  type="button"
                  onClick={handleCustomAdd}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[#0070fc] text-white text-xs font-bold hover:bg-[#005cd0]"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Gunakan "{search}"</span>
                </button>
              </div>
            ) : (
              Object.entries(groupedUnits).map(([catKey, items]) => (
                <div key={catKey} className="py-1">
                  <div className="px-2.5 py-1 text-[10px] font-bold text-slate-400 uppercase tracking-wider bg-slate-50/50 rounded-md mb-1">
                    {CATEGORY_LABELS[catKey] || catKey}
                  </div>
                  <div className="space-y-0.5">
                    {items.map((u) => {
                      const isSelected = (value || '').toLowerCase() === u.code.toLowerCase();
                      return (
                        <button
                          key={u.code}
                          type="button"
                          onClick={() => handleSelect(u.code)}
                          className={`w-full px-2.5 py-1.5 rounded-lg text-left text-xs flex items-center justify-between transition-colors ${
                            isSelected
                              ? 'bg-blue-50 text-[#0070fc] font-bold'
                              : 'hover:bg-slate-50 text-slate-700'
                          }`}
                        >
                          <div>
                            <span className="font-semibold">{u.code}</span>
                            {u.description && (
                              <span className="text-[11px] text-slate-400 font-normal ml-2">
                                — {u.description}
                              </span>
                            )}
                          </div>
                          {isSelected && <Check className="w-3.5 h-3.5 text-[#0070fc] shrink-0" />}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}

