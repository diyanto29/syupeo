'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Navbar from '@/components/Navbar';
import { createClient } from '@/lib/supabase/client';
import { MasterCatalogItem } from '@/types/database';
import {
  Barcode,
  Search,
  Plus,
  Edit2,
  Trash2,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Copy,
  Check,
  Package,
  Layers,
  AlertCircle,
  CheckCircle,
  X,
  Upload,
  FileSpreadsheet,
  Download,
  Info,
} from 'lucide-react';

const PAGE_SIZE = 25;

interface ParsedProduct {
  barcode: string;
  name: string;
  category: string;
  unit: string;
  base_price: number;
  selling_price: number;
}

export default function MasterCatalogPage() {
  const [items, setItems] = useState<MasterCatalogItem[]>([]);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [page, setPage] = useState<number>(1);
  const [loading, setLoading] = useState<boolean>(true);

  // Filters
  const [searchInput, setSearchInput] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedCategory, setSelectedCategory] = useState<string>('ALL');
  const [categories, setCategories] = useState<string[]>([]);

  // Modals
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const [editingItem, setEditingItem] = useState<MasterCatalogItem | null>(null);
  const [deletingItem, setDeletingItem] = useState<MasterCatalogItem | null>(null);

  // Form states
  const [formBarcode, setFormBarcode] = useState<string>('');
  const [formName, setFormName] = useState<string>('');
  const [formCategory, setFormCategory] = useState<string>('');
  const [formUnit, setFormUnit] = useState<string>('PCs');
  const [formBasePrice, setFormBasePrice] = useState<string>('0');
  const [formSellingPrice, setFormSellingPrice] = useState<string>('0');

  const [saving, setSaving] = useState<boolean>(false);
  const [copiedBarcode, setCopiedBarcode] = useState<string | null>(null);
  const [alertSuccess, setAlertSuccess] = useState<string | null>(null);
  const [alertError, setAlertError] = useState<string | null>(null);

  // CSV Import States
  const [isImportModalOpen, setIsImportModalOpen] = useState<boolean>(false);
  const [importFile, setImportFile] = useState<File | null>(null);
  const [parsedProducts, setParsedProducts] = useState<ParsedProduct[]>([]);
  const [isParsing, setIsParsing] = useState<boolean>(false);
  const [isImporting, setIsImporting] = useState<boolean>(false);
  const [importProgress, setImportProgress] = useState<{ current: number; total: number; step: string } | null>(null);
  const [importSummary, setImportSummary] = useState<{ imported: number; skipped: number; total: number } | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const supabase = createClient();

  // Debounce search input
  useEffect(() => {
    const handler = setTimeout(() => {
      setSearchQuery(searchInput);
      setPage(1);
    }, 400);

    return () => clearTimeout(handler);
  }, [searchInput]);

  // Load distinct categories for filter
  const loadCategories = async () => {
    try {
      const { data } = await supabase
        .from('master_catalog')
        .select('category')
        .not('category', 'is', null)
        .limit(1000);

      if (data) {
        const unique = Array.from(new Set(data.map((d) => d.category?.trim()).filter(Boolean))) as string[];
        unique.sort();
        setCategories(unique);
      }
    } catch (e) {
      console.error('Error fetching categories:', e);
    }
  };

  useEffect(() => {
    loadCategories();
  }, []);

  // Fetch paginated catalog data
  const fetchCatalog = useCallback(async () => {
    try {
      setLoading(true);
      setAlertError(null);

      let query = supabase.from('master_catalog').select('*', { count: 'exact' });

      if (searchQuery.trim()) {
        const q = searchQuery.trim();
        query = query.or(`barcode.ilike.%${q}%,name.ilike.%${q}%`);
      }

      if (selectedCategory !== 'ALL') {
        query = query.eq('category', selectedCategory);
      }

      const from = (page - 1) * PAGE_SIZE;
      const to = from + PAGE_SIZE - 1;

      const { data, count, error } = await query
        .order('created_at', { ascending: false })
        .range(from, to);

      if (error) throw error;

      setItems(data || []);
      setTotalCount(count || 0);
    } catch (err: any) {
      console.error('Error loading catalog:', err);
      setAlertError(err?.message || 'Gagal memuat katalog produk.');
    } finally {
      setLoading(false);
    }
  }, [page, searchQuery, selectedCategory]);

  useEffect(() => {
    fetchCatalog();
  }, [fetchCatalog]);

  const copyToClipboard = (barcode: string) => {
    navigator.clipboard.writeText(barcode);
    setCopiedBarcode(barcode);
    setTimeout(() => setCopiedBarcode(null), 2000);
  };

  const openAddModal = () => {
    setEditingItem(null);
    setFormBarcode('');
    setFormName('');
    setFormCategory('');
    setFormUnit('PCs');
    setFormBasePrice('0');
    setFormSellingPrice('0');
    setIsModalOpen(true);
  };

  const openEditModal = (item: MasterCatalogItem) => {
    setEditingItem(item);
    setFormBarcode(item.barcode || '');
    setFormName(item.name);
    setFormCategory(item.category || '');
    setFormUnit(item.unit || 'PCs');
    setFormBasePrice(String(item.base_price || 0));
    setFormSellingPrice(String(item.selling_price || 0));
    setIsModalOpen(true);
  };

  const handleSaveProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim()) {
      setAlertError('Nama produk wajib diisi.');
      return;
    }

    try {
      setSaving(true);
      setAlertError(null);

      const basePriceNum = parseFloat(formBasePrice) || 0;
      const sellingPriceNum = parseFloat(formSellingPrice) || 0;
      const cleanBarcode = formBarcode.trim() || null;

      if (editingItem) {
        const { error } = await supabase
          .from('master_catalog')
          .update({
            barcode: cleanBarcode,
            name: formName.trim(),
            category: formCategory.trim() || null,
            unit: formUnit.trim() || 'PCs',
            base_price: basePriceNum,
            selling_price: sellingPriceNum,
          })
          .eq('id', editingItem.id);

        if (error) {
          if (error.code === '23505') {
            throw new Error(`Barcode ${cleanBarcode} sudah digunakan oleh produk lain.`);
          }
          throw error;
        }
        setAlertSuccess(`Produk "${formName}" berhasil diperbarui!`);
      } else {
        const { error } = await supabase.from('master_catalog').insert({
          barcode: cleanBarcode,
          name: formName.trim(),
          category: formCategory.trim() || null,
          unit: formUnit.trim() || 'PCs',
          base_price: basePriceNum,
          selling_price: sellingPriceNum,
        });

        if (error) {
          if (error.code === '23505') {
            throw new Error(`Barcode ${cleanBarcode} sudah terdaftar di master katalog.`);
          }
          throw error;
        }
        setAlertSuccess(`Produk baru "${formName}" berhasil ditambahkan ke master katalog!`);
      }

      setIsModalOpen(false);
      fetchCatalog();
      loadCategories();
    } catch (err: any) {
      setAlertError(err?.message || 'Gagal menyimpan produk.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteProduct = async () => {
    if (!deletingItem) return;

    try {
      setSaving(true);
      const { error } = await supabase
        .from('master_catalog')
        .delete()
        .eq('id', deletingItem.id);

      if (error) throw error;

      setAlertSuccess(`Produk "${deletingItem.name}" berhasil dihapus.`);
      setDeletingItem(null);
      fetchCatalog();
      loadCategories();
    } catch (err: any) {
      alert(`Gagal menghapus produk: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // CSV Parsing Engine
  const parseCSVFile = (file: File) => {
    setIsParsing(true);
    setImportSummary(null);

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const text = e.target?.result as string;
        const lines = text.split(/\r?\n/).filter((l) => l.trim().length > 0);

        if (lines.length < 2) {
          alert('File CSV kosong atau tidak memiliki baris data.');
          setIsParsing(false);
          return;
        }

        // Detect delimiter (tab, semicolon, or comma)
        const firstLine = lines[0];
        let delimiter = ',';
        if (firstLine.includes('\t')) delimiter = '\t';
        else if (firstLine.split(';').length > firstLine.split(',').length) delimiter = ';';

        const parseLine = (line: string): string[] => {
          const result: string[] = [];
          let current = '';
          let inQuotes = false;
          for (let i = 0; i < line.length; i++) {
            const char = line[i];
            if (char === '"') {
              if (inQuotes && line[i + 1] === '"') {
                current += '"';
                i++;
              } else {
                inQuotes = !inQuotes;
              }
            } else if (char === delimiter && !inQuotes) {
              result.push(current.trim());
              current = '';
            } else {
              current += char;
            }
          }
          result.push(current.trim());
          return result;
        };

        const headers = parseLine(lines[0]).map((h) =>
          h.toLowerCase().replace(/[^a-z0-9_]/g, '')
        );

        // Find index of columns
        const barcodeIdx = headers.findIndex((h) =>
          ['barcode', 'id', 'kode', 'kode_barang', 'code', 'barcode_id'].includes(h)
        );
        const nameIdx = headers.findIndex((h) =>
          ['name', 'nama', 'nama_produk', 'nama_barang', 'item_name', 'product_name'].includes(h)
        );
        const categoryIdx = headers.findIndex((h) =>
          ['category', 'kategori', 'cat', 'golongan'].includes(h)
        );
        const unitIdx = headers.findIndex((h) =>
          ['unit', 'satuan', 'uom', 'satuan_jual'].includes(h)
        );
        const basePriceIdx = headers.findIndex((h) =>
          ['base_price', 'modal', 'hpp', 'harga_modal', 'cost'].includes(h)
        );
        const sellingPriceIdx = headers.findIndex((h) =>
          ['selling_price', 'harga', 'harga_jual', 'price'].includes(h)
        );

        const productsMap = new Map<string, ParsedProduct>();

        for (let i = 1; i < lines.length; i++) {
          const values = parseLine(lines[i]);
          if (values.length === 0 || values.every((v) => !v)) continue;

          const barcode = (barcodeIdx >= 0 ? values[barcodeIdx] : values[0] || '').trim();
          const name = (nameIdx >= 0 ? values[nameIdx] : values[1] || '').trim();
          const category = (categoryIdx >= 0 ? values[categoryIdx] : 'UMUM').trim().toUpperCase() || 'UMUM';
          const unit = (unitIdx >= 0 ? values[unitIdx] : 'PCs').trim() || 'PCs';
          const base_price = parseFloat(basePriceIdx >= 0 ? values[basePriceIdx] : '0') || 0;
          const selling_price = parseFloat(sellingPriceIdx >= 0 ? values[sellingPriceIdx] : '0') || 0;

          if (barcode && name && !productsMap.has(barcode)) {
            productsMap.set(barcode, {
              barcode,
              name,
              category,
              unit,
              base_price,
              selling_price,
            });
          }
        }

        const validProducts = Array.from(productsMap.values());
        setParsedProducts(validProducts);
        setImportFile(file);
      } catch (err: any) {
        alert(`Gagal membaca file CSV: ${err.message}`);
      } finally {
        setIsParsing(false);
      }
    };
    reader.readAsText(file);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      parseCSVFile(file);
    }
  };

  // Process Import with Deduplication against Supabase
  const handleExecuteImport = async () => {
    if (parsedProducts.length === 0) return;

    try {
      setIsImporting(true);
      setImportProgress({ current: 0, total: parsedProducts.length, step: 'Mengecek duplikasi barcode di database...' });

      const allBarcodes = parsedProducts.map((p) => p.barcode);
      const existingBarcodeSet = new Set<string>();

      // 1. Query existing barcodes in chunks of 500
      const CHECK_CHUNK = 500;
      for (let i = 0; i < allBarcodes.length; i += CHECK_CHUNK) {
        const batchCodes = allBarcodes.slice(i, i + CHECK_CHUNK);
        const { data: existingData, error: checkError } = await supabase
          .from('master_catalog')
          .select('barcode')
          .in('barcode', batchCodes);

        if (!checkError && existingData) {
          existingData.forEach((row) => {
            if (row.barcode) existingBarcodeSet.add(row.barcode);
          });
        }
      }

      // 2. Filter items: ONLY insert products whose barcode does not exist yet
      const itemsToInsert = parsedProducts.filter((p) => !existingBarcodeSet.has(p.barcode));
      const skippedCount = parsedProducts.length - itemsToInsert.length;

      // 3. Insert in batches of 200
      const INSERT_CHUNK = 200;
      let insertedCount = 0;

      for (let i = 0; i < itemsToInsert.length; i += INSERT_CHUNK) {
        const chunk = itemsToInsert.slice(i, i + INSERT_CHUNK);
        setImportProgress({
          current: i,
          total: itemsToInsert.length,
          step: `Menyimpan batch produk baru (${i + 1} - ${Math.min(i + INSERT_CHUNK, itemsToInsert.length)})...`,
        });

        const { error: insertError } = await supabase.from('master_catalog').insert(chunk);
        if (insertError) throw insertError;

        insertedCount += chunk.length;
      }

      setImportSummary({
        imported: insertedCount,
        skipped: skippedCount,
        total: parsedProducts.length,
      });

      setAlertSuccess(
        `Import selesai! Berhasil menambahkan ${insertedCount.toLocaleString('id-ID')} produk baru. ${skippedCount.toLocaleString('id-ID')} produk dilewati karena barcode sudah terdaftar di master katalog.`
      );

      fetchCatalog();
      loadCategories();
    } catch (err: any) {
      alert(`Terjadi kesalahan saat import: ${err.message}`);
    } finally {
      setIsImporting(false);
      setImportProgress(null);
    }
  };

  const closeImportModal = () => {
    setIsImportModalOpen(false);
    setImportFile(null);
    setParsedProducts([]);
    setImportSummary(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const totalPages = Math.ceil(totalCount / PAGE_SIZE) || 1;
  const fromRecord = totalCount === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const toRecord = Math.min(page * PAGE_SIZE, totalCount);

  return (
    <div className="space-y-8 pb-12">
      <Navbar
        title="Master Katalog Produk"
        description="Kelola referensi barcode nasional, nama barang, kategori, rekomendasi harga, dan import massal CSV"
      />

      {/* Action Alerts */}
      {alertSuccess && (
        <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-between text-emerald-800 text-sm animate-in fade-in">
          <div className="flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-emerald-600 flex-shrink-0" />
            <span className="font-semibold">{alertSuccess}</span>
          </div>
          <button
            onClick={() => setAlertSuccess(null)}
            className="p-1 text-emerald-600 hover:text-emerald-800 rounded-lg hover:bg-emerald-100/50"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {alertError && (
        <div className="p-4 rounded-2xl bg-red-50 border border-red-200 flex items-center justify-between text-red-800 text-sm animate-in fade-in">
          <div className="flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0" />
            <span className="font-semibold">{alertError}</span>
          </div>
          <button
            onClick={() => setAlertError(null)}
            className="p-1 text-red-600 hover:text-red-800 rounded-lg hover:bg-red-100/50"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-orange-50 border border-orange-200 flex items-center justify-center text-orange-600 flex-shrink-0">
            <Barcode className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">
              {totalCount.toLocaleString('id-ID')}
            </div>
            <div className="text-xs font-semibold text-slate-500">Total Barcode Terdaftar</div>
          </div>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-blue-50 border border-blue-200 flex items-center justify-center text-blue-600 flex-shrink-0">
            <Layers className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{categories.length || '50+'}</div>
            <div className="text-xs font-semibold text-slate-500">Kategori Barang</div>
          </div>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600 flex-shrink-0">
            <Package className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">Instan</div>
            <div className="text-xs font-semibold text-slate-500">Auto-Fill Scanner Mobile</div>
          </div>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200/90 shadow-xs space-y-4">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          {/* Search Box */}
          <div className="relative flex-1 max-w-lg">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Cari barcode (cth: 8992...) atau nama barang (cth: Indomie, Bodrex)..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm"
            />
            {searchInput && (
              <button
                onClick={() => setSearchInput('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Action buttons */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Category Dropdown */}
            <select
              value={selectedCategory}
              onChange={(e) => {
                setSelectedCategory(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2.5 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 focus:outline-hidden max-w-[200px]"
            >
              <option value="ALL">Semua Kategori</option>
              {categories.map((cat) => (
                <option key={cat} value={cat}>
                  {cat}
                </option>
              ))}
            </select>

            {/* Refresh Button */}
            <button
              onClick={() => fetchCatalog()}
              title="Refresh Data"
              className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>

            {/* Import CSV Button */}
            <button
              onClick={() => setIsImportModalOpen(true)}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-900 text-white font-bold text-xs shadow-xs hover:shadow-md transition-all duration-200"
            >
              <Upload className="w-4 h-4" />
              <span>Import CSV</span>
            </button>

            {/* Add Product Button */}
            <button
              onClick={openAddModal}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold text-xs shadow-xs hover:shadow-md transition-all duration-200"
            >
              <Plus className="w-4 h-4" />
              <span>Tambah Produk Master</span>
            </button>
          </div>
        </div>
      </div>

      {/* Catalog Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50/80 border-b border-slate-200/80 text-[11px] uppercase tracking-wider text-slate-500 font-bold">
              <tr>
                <th className="py-4 px-6">Barcode</th>
                <th className="py-4 px-6">Nama Produk</th>
                <th className="py-4 px-6">Kategori</th>
                <th className="py-4 px-6">Satuan</th>
                <th className="py-4 px-6 text-right">Modal (HPP)</th>
                <th className="py-4 px-6 text-right">Harga Jual</th>
                <th className="py-4 px-6 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-14 text-center text-slate-400">
                    <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                    <span>Mencari di database master katalog...</span>
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-14 text-center text-slate-400">
                    <Barcode className="w-10 h-10 text-slate-300 mx-auto mb-2" />
                    <p className="font-semibold text-slate-600">Tidak ada produk ditemukan</p>
                    <p className="text-xs text-slate-400 mt-1">
                      Coba ganti kata kunci pencarian barcode atau pilih kategori lain.
                    </p>
                  </td>
                </tr>
              ) : (
                items.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/70 transition-colors">
                    {/* Barcode */}
                    <td className="py-4 px-6">
                      {item.barcode ? (
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 border border-slate-200/80 font-mono text-xs font-semibold text-slate-800">
                          <span>{item.barcode}</span>
                          <button
                            onClick={() => copyToClipboard(item.barcode!)}
                            title="Salin Barcode"
                            className="text-slate-400 hover:text-slate-700 ml-0.5"
                          >
                            {copiedBarcode === item.barcode ? (
                              <Check className="w-3.5 h-3.5 text-emerald-600" />
                            ) : (
                              <Copy className="w-3.5 h-3.5" />
                            )}
                          </button>
                        </div>
                      ) : (
                        <span className="text-xs text-slate-400 italic">Tanpa Barcode</span>
                      )}
                    </td>

                    {/* Name */}
                    <td className="py-4 px-6">
                      <div className="font-bold text-slate-900 leading-snug">{item.name}</div>
                      {item.brand && (
                        <div className="text-xs text-slate-400 mt-0.5">Brand: {item.brand}</div>
                      )}
                    </td>

                    {/* Category */}
                    <td className="py-4 px-6">
                      <span className="inline-block px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700">
                        {item.category || 'UMUM'}
                      </span>
                    </td>

                    {/* Unit */}
                    <td className="py-4 px-6">
                      <span className="text-xs font-medium text-slate-600">{item.unit || 'PCs'}</span>
                    </td>

                    {/* Base Price */}
                    <td className="py-4 px-6 text-right font-mono text-xs text-slate-700">
                      {item.base_price && item.base_price > 0 ? (
                        `Rp ${Number(item.base_price).toLocaleString('id-ID')}`
                      ) : (
                        <span className="text-slate-400">-</span>
                      )}
                    </td>

                    {/* Selling Price */}
                    <td className="py-4 px-6 text-right font-mono font-bold text-xs text-orange-600">
                      {item.selling_price && item.selling_price > 0 ? (
                        `Rp ${Number(item.selling_price).toLocaleString('id-ID')}`
                      ) : (
                        <span className="text-slate-400 font-normal">-</span>
                      )}
                    </td>

                    {/* Actions */}
                    <td className="py-4 px-6 text-right">
                      <div className="inline-flex items-center gap-1.5">
                        <button
                          onClick={() => openEditModal(item)}
                          title="Edit Produk"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-orange-600 hover:bg-orange-50 transition-colors"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => setDeletingItem(item)}
                          title="Hapus Produk"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="p-4 sm:p-5 border-t border-slate-100 bg-slate-50/50 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-xs text-slate-500 font-medium">
            Menampilkan <span className="font-bold text-slate-900">{fromRecord}</span> -{' '}
            <span className="font-bold text-slate-900">{toRecord}</span> dari{' '}
            <span className="font-bold text-slate-900">{totalCount.toLocaleString('id-ID')}</span> item
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage((p) => Math.max(p - 1, 1))}
              disabled={page <= 1 || loading}
              className="inline-flex items-center gap-1 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed shadow-2xs"
            >
              <ChevronLeft className="w-4 h-4" />
              <span>Sebelumnya</span>
            </button>

            <span className="text-xs font-bold text-slate-700 px-2">
              Halaman {page} dari {totalPages}
            </span>

            <button
              onClick={() => setPage((p) => Math.min(p + 1, totalPages))}
              disabled={page >= totalPages || loading}
              className="inline-flex items-center gap-1 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed shadow-2xs"
            >
              <span>Berikutnya</span>
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Modal Import CSV */}
      {isImportModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-white rounded-3xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 my-8 max-h-[90vh] flex flex-col animate-in fade-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 flex-shrink-0">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-slate-100 text-slate-800 flex items-center justify-center">
                  <FileSpreadsheet className="w-5 h-5 text-orange-600" />
                </div>
                <div>
                  <h3 className="font-bold text-base sm:text-lg text-slate-900">
                    Import CSV Master Katalog
                  </h3>
                  <p className="text-xs text-slate-500">
                    Upload file CSV produk. Sistem otomatis mendeteksi barcode yang sudah ada agar tidak duplikat.
                  </p>
                </div>
              </div>
              <button
                onClick={closeImportModal}
                disabled={isImporting}
                className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="mt-5 space-y-5 overflow-y-auto pr-1 flex-1">
              {/* Sample Template Download */}
              <div className="p-4 rounded-2xl bg-orange-50/70 border border-orange-200/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
                <div className="flex items-start gap-2.5 text-orange-950 font-medium">
                  <Info className="w-4 h-4 text-orange-600 flex-shrink-0 mt-0.5" />
                  <span>
                    Format CSV mendukung kolom: <strong>barcode</strong>, <strong>name</strong>,{' '}
                    <strong>category</strong>, <strong>unit</strong>, <strong>base_price</strong>,{' '}
                    <strong>selling_price</strong>.
                  </span>
                </div>
                <div className="flex flex-wrap items-center gap-2 flex-shrink-0">
                  <a
                    href="/database_lengkap_kopi_dan_teh.csv"
                    download="database_lengkap_kopi_dan_teh.csv"
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-orange-600 text-white hover:bg-orange-700 font-bold shadow-2xs transition-colors"
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Download CSV Kopi & Teh</span>
                  </a>
                  <a
                    href="/barcode_produk_1000.csv"
                    download="contoh_master_catalog_1000.csv"
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-orange-200 text-orange-700 hover:bg-orange-100/50 font-bold shadow-2xs transition-colors"
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Sample Ritel 1.000</span>
                  </a>
                </div>
              </div>

              {/* Upload Dropzone */}
              {!importSummary && (
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className="p-8 rounded-2xl border-2 border-dashed border-slate-300 hover:border-orange-500 bg-slate-50/50 hover:bg-orange-50/30 transition-all cursor-pointer text-center group"
                >
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".csv,.txt"
                    onChange={handleFileChange}
                    className="hidden"
                  />
                  <div className="w-12 h-12 rounded-2xl bg-white border border-slate-200 flex items-center justify-center text-slate-400 group-hover:text-orange-600 group-hover:border-orange-200 mx-auto mb-3 shadow-xs transition-colors">
                    <Upload className="w-6 h-6" />
                  </div>
                  <div className="text-sm font-bold text-slate-800">
                    {importFile ? importFile.name : 'Pilih file CSV dari komputer'}
                  </div>
                  <p className="text-xs text-slate-500 mt-1">
                    Klik untuk memilih file CSV atau seret dan lepas file di sini (.csv atau .txt)
                  </p>
                </div>
              )}

              {/* Parsing Indicator */}
              {isParsing && (
                <div className="text-center py-6 text-xs text-slate-500 flex items-center justify-center gap-2">
                  <div className="w-4 h-4 border-2 border-orange-500 border-t-transparent rounded-full animate-spin" />
                  <span>Membaca dan memvalidasi baris CSV...</span>
                </div>
              )}

              {/* Preview Box */}
              {parsedProducts.length > 0 && !importSummary && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-xs font-bold text-slate-700">
                    <span>Preview Data Terdeteksi ({parsedProducts.length.toLocaleString('id-ID')} produk):</span>
                    <span className="text-emerald-600">Barcode Unik Tervalidasi</span>
                  </div>

                  <div className="rounded-xl border border-slate-200 overflow-hidden max-h-48 overflow-y-auto text-xs">
                    <table className="w-full text-left">
                      <thead className="bg-slate-50 border-b border-slate-200 text-[10px] uppercase font-bold text-slate-500 sticky top-0">
                        <tr>
                          <th className="py-2 px-3">Barcode</th>
                          <th className="py-2 px-3">Nama Produk</th>
                          <th className="py-2 px-3">Kategori</th>
                          <th className="py-2 px-3">Satuan</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {parsedProducts.slice(0, 10).map((p, idx) => (
                          <tr key={idx} className="hover:bg-slate-50">
                            <td className="py-2 px-3 font-mono text-[11px] font-semibold text-slate-800">
                              {p.barcode}
                            </td>
                            <td className="py-2 px-3 font-medium text-slate-900 truncate max-w-[200px]">
                              {p.name}
                            </td>
                            <td className="py-2 px-3 text-slate-600">{p.category}</td>
                            <td className="py-2 px-3 text-slate-600">{p.unit}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {parsedProducts.length > 10 && (
                    <p className="text-[11px] text-slate-400 italic text-center">
                      ...dan {(parsedProducts.length - 10).toLocaleString('id-ID')} produk lainnya siap diimpor.
                    </p>
                  )}
                </div>
              )}

              {/* Progress Bar */}
              {isImporting && importProgress && (
                <div className="p-4 rounded-2xl bg-orange-50 border border-orange-200 space-y-2">
                  <div className="flex items-center justify-between text-xs font-bold text-orange-900">
                    <span>{importProgress.step}</span>
                    <span>
                      {importProgress.current} / {importProgress.total}
                    </span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-orange-200 overflow-hidden">
                    <div
                      className="h-full bg-orange-600 rounded-full transition-all duration-300"
                      style={{
                        width: `${Math.round((importProgress.current / (importProgress.total || 1)) * 100)}%`,
                      }}
                    />
                  </div>
                </div>
              )}

              {/* Import Summary Results */}
              {importSummary && (
                <div className="p-6 rounded-2xl bg-emerald-50 border border-emerald-200 text-center space-y-3">
                  <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto">
                    <CheckCircle className="w-6 h-6" />
                  </div>
                  <h4 className="font-bold text-emerald-950 text-base">Import Selesai!</h4>
                  <div className="grid grid-cols-3 gap-2 text-xs pt-1 max-w-sm mx-auto">
                    <div className="p-3 bg-white rounded-xl border border-emerald-200">
                      <div className="text-[10px] text-slate-500 font-bold uppercase">Total di File</div>
                      <div className="text-base font-black text-slate-900 mt-0.5">
                        {importSummary.total.toLocaleString('id-ID')}
                      </div>
                    </div>
                    <div className="p-3 bg-white rounded-xl border border-emerald-200">
                      <div className="text-[10px] text-emerald-600 font-bold uppercase">Baru Ditambahkan</div>
                      <div className="text-base font-black text-emerald-600 mt-0.5">
                        {importSummary.imported.toLocaleString('id-ID')}
                      </div>
                    </div>
                    <div className="p-3 bg-white rounded-xl border border-emerald-200">
                      <div className="text-[10px] text-slate-400 font-bold uppercase">Sudah Ada (Skip)</div>
                      <div className="text-base font-black text-slate-600 mt-0.5">
                        {importSummary.skipped.toLocaleString('id-ID')}
                      </div>
                    </div>
                  </div>
                  <p className="text-xs text-emerald-800 font-medium">
                    Semua barcode yang sudah terdaftar di master katalog otomatis dilewati dan tidak diimpor ganda.
                  </p>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3 flex-shrink-0">
              <button
                type="button"
                onClick={closeImportModal}
                disabled={isImporting}
                className="px-4 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold transition-colors"
              >
                {importSummary ? 'Tutup' : 'Batal'}
              </button>

              {!importSummary && parsedProducts.length > 0 && (
                <button
                  type="button"
                  onClick={handleExecuteImport}
                  disabled={isImporting}
                  className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold shadow-xs hover:shadow-md transition-all disabled:opacity-50"
                >
                  {isImporting ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      <span>Mengimpor Data...</span>
                    </>
                  ) : (
                    <>
                      <Upload className="w-4 h-4" />
                      <span>Mulai Import ke Database</span>
                    </>
                  )}
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Modal Add / Edit Single Product */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-200 overflow-hidden my-8 animate-in fade-in zoom-in-95 duration-200">
            <div className="p-6 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-orange-100 text-orange-600 flex items-center justify-center">
                  <Barcode className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-lg text-slate-900">
                    {editingItem ? 'Edit Produk Master' : 'Tambah Produk Master'}
                  </h3>
                  <p className="text-xs text-slate-500">
                    {editingItem
                      ? 'Perbarui informasi referensi produk master'
                      : 'Data ini akan menjadi acuan saat kasir scan barcode baru'}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveProduct} className="p-6 space-y-4">
              {/* Barcode */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Kode Barcode (EAN / UPC / Manual)
                </label>
                <div className="relative">
                  <Barcode className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="cth: 8992388112233"
                    value={formBarcode}
                    onChange={(e) => setFormBarcode(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm font-mono"
                  />
                </div>
              </div>

              {/* Name */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Nama Barang / Produk <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="cth: INDOMIE GORENG SPESIAL 85G"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm font-medium"
                />
              </div>

              {/* Category & Unit */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Kategori
                  </label>
                  <input
                    type="text"
                    placeholder="cth: MIE, MINUMAN"
                    value={formCategory}
                    onChange={(e) => setFormCategory(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Satuan
                  </label>
                  <input
                    type="text"
                    placeholder="cth: PCs, BUNGKUS, BOX"
                    value={formUnit}
                    onChange={(e) => setFormUnit(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm"
                  />
                </div>
              </div>

              {/* Pricing (Base & Selling) */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Rekomendasi Modal (HPP)
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                      Rp
                    </span>
                    <input
                      type="number"
                      step="any"
                      placeholder="0"
                      value={formBasePrice}
                      onChange={(e) => setFormBasePrice(e.target.value)}
                      className="w-full pl-9 pr-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm font-mono"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Rekomendasi Harga Jual
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                      Rp
                    </span>
                    <input
                      type="number"
                      step="any"
                      placeholder="0"
                      value={formSellingPrice}
                      onChange={(e) => setFormSellingPrice(e.target.value)}
                      className="w-full pl-9 pr-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-sm font-mono font-bold"
                    />
                  </div>
                </div>
              </div>

              {/* Submit Buttons */}
              <div className="pt-4 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold shadow-xs hover:shadow-md transition-all disabled:opacity-50"
                >
                  {saving ? (
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  ) : (
                    <span>{editingItem ? 'Simpan Perubahan' : 'Tambahkan Produk'}</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-sm w-full p-6 shadow-2xl border border-slate-200 text-center animate-in fade-in zoom-in-95 duration-200">
            <div className="w-12 h-12 rounded-full bg-red-100 text-red-600 flex items-center justify-center mx-auto mb-4">
              <Trash2 className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-lg text-slate-900 mb-1">Hapus dari Master Katalog?</h3>
            <p className="text-xs text-slate-500 leading-relaxed mb-6">
              Produk <strong className="text-slate-800">{deletingItem.name}</strong> ({deletingItem.barcode || 'Tanpa barcode'}) akan dihapus dari referensi barcode nasional.
            </p>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setDeletingItem(null)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleDeleteProduct}
                disabled={saving}
                className="flex-1 py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-bold transition-all shadow-xs"
              >
                {saving ? 'Menghapus...' : 'Ya, Hapus'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
