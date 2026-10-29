'use client';

import { useState, useEffect } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { InventoryIngredient, StockOpnameSession, StockOpnameItem } from '@/types/database';
import * as XLSX from 'xlsx';
import {
  Boxes,
  Plus,
  Search,
  Filter,
  Download,
  AlertTriangle,
  RefreshCw,
  Edit2,
  Trash2,
  X,
  PackagePlus,
  CheckCircle2,
  TrendingDown,
  Warehouse,
  ClipboardCheck,
  Eye,
  EyeOff,
  Save,
  Calculator,
  Sparkles,
  History,
  FileSpreadsheet,
} from 'lucide-react';

export default function MerchantInventoryPage() {
  const { business, selectedOutletId, outlets } = useMerchant();

  const [ingredients, setIngredients] = useState<InventoryIngredient[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');

  // Modals
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isAdjustOpen, setIsAdjustOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<InventoryIngredient | null>(null);
  const [adjustingItem, setAdjustingItem] = useState<InventoryIngredient | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Stock Opname Sheet State
  interface OpnameRow {
    ingredientId: string;
    name: string;
    sku?: string | null;
    storageType: string;
    unit: string;
    systemStock: number;
    physicalStock: string;
    costPerUnit: number;
    reason: string;
    notes: string;
  }
  const [isOpnameOpen, setIsOpnameOpen] = useState(false);
  const [opnameRows, setOpnameRows] = useState<OpnameRow[]>([]);
  const [opnameType, setOpnameType] = useState<'daily_closing' | 'weekly' | 'full_monthly'>('daily_closing');
  const [isBlindCount, setIsBlindCount] = useState(false);
  const [opnameFilterStorage, setOpnameFilterStorage] = useState('all');
  const [opnameSearch, setOpnameSearch] = useState('');
  const [opnameNotes, setOpnameNotes] = useState('');
  const [opnameSubmitting, setOpnameSubmitting] = useState(false);

  // Tab State
  const [activeTab, setActiveTab] = useState<'inventory' | 'history'>('inventory');

  // Opname History State
  const [historySessions, setHistorySessions] = useState<StockOpnameSession[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyFilterType, setHistoryFilterType] = useState('all');
  const [selectedHistorySession, setSelectedHistorySession] = useState<StockOpnameSession | null>(null);
  const [historyDetailItems, setHistoryDetailItems] = useState<StockOpnameItem[]>([]);
  const [isHistoryDetailOpen, setIsHistoryDetailOpen] = useState(false);
  const [historyDetailLoading, setHistoryDetailLoading] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    sku: '',
    category: 'Bahan Pokok',
    base_unit: 'gram',
    current_stock: '',
    min_stock_alert: '100',
    cost_per_base_unit: '',
    storage_type: 'dry' as 'dry' | 'chilled' | 'frozen',
    outlet_id: '',
  });

  // Adjust State
  const [adjustDelta, setAdjustDelta] = useState('');
  const [adjustType, setAdjustType] = useState<'add' | 'subtract'>('add');
  const [adjustNote, setAdjustNote] = useState('');

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadIngredients = async () => {
    if (!business) return;
    try {
      setLoading(true);
      const supabase = createClient();

      let query = supabase
        .from('inventory_ingredients')
        .select('*')
        .eq('business_id', business.id)
        .order('name');

      if (selectedOutletId !== 'all') {
        query = query.or(`outlet_id.eq.${selectedOutletId},outlet_id.is.null`);
      }

      const { data, error } = await query;
      if (!error) {
        setIngredients(data || []);
      }
    } catch (err) {
      console.error('Error fetching ingredients:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadHistorySessions = async () => {
    if (!business) return;
    try {
      setHistoryLoading(true);
      const supabase = createClient();
      let query = supabase
        .from('stock_opname_sessions')
        .select('*')
        .eq('business_id', business.id)
        .order('created_at', { ascending: false });

      if (selectedOutletId !== 'all') {
        query = query.eq('outlet_id', selectedOutletId);
      }

      const { data, error } = await query;
      if (!error) {
        setHistorySessions(data || []);
      }
    } catch (err) {
      console.error('Error fetching opname history:', err);
    } finally {
      setHistoryLoading(false);
    }
  };

  const openHistoryDetailModal = async (session: StockOpnameSession) => {
    setSelectedHistorySession(session);
    setIsHistoryDetailOpen(true);
    setHistoryDetailLoading(true);
    try {
      const supabase = createClient();
      const { data, error } = await supabase
        .from('stock_opname_items')
        .select('*')
        .eq('session_id', session.id)
        .order('storage_location')
        .order('item_name');

      if (!error) {
        setHistoryDetailItems(data || []);
      }
    } catch (err) {
      console.error('Error loading session detail:', err);
    } finally {
      setHistoryDetailLoading(false);
    }
  };

  const exportHistorySessionExcel = (session: StockOpnameSession, items: StockOpnameItem[]) => {
    if (items.length === 0) {
      alert('Tidak ada data rincian bahan untuk diekspor.');
      return;
    }
    const data = items.map((it) => ({
      'Nama Bahan': it.item_name,
      'Lokasi Penyimpanan': it.storage_location || 'General',
      Satuan: it.unit,
      'Stok Sistem': it.system_stock,
      'Stok Fisik': it.physical_stock,
      Selisih: it.discrepancy_quantity,
      'Biaya Satuan': it.unit_cost,
      'Nilai Selisih (Rp)': it.discrepancy_value,
      'Alasan Selisih': it.discrepancy_reason || 'Normal',
      Catatan: it.notes || '-',
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, `Opname_${session.session_number}`);
    XLSX.writeFile(wb, `Berita_Acara_Opname_${session.session_number}.xlsx`);
  };

  useEffect(() => {
    loadIngredients();
    loadHistorySessions();
    if (outlets.length > 0 && !formData.outlet_id) {
      setFormData((prev) => ({
        ...prev,
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0].id,
      }));
    }
  }, [business?.id, selectedOutletId]);

  // Calculations
  const totalItems = ingredients.length;
  const lowStockItems = ingredients.filter(
    (it) => Number(it.current_stock) <= Number(it.min_stock_alert)
  ).length;

  const totalValue = ingredients.reduce(
    (sum, it) => sum + Number(it.current_stock || 0) * Number(it.cost_per_base_unit || 0),
    0
  );

  // Open Add/Edit Modal
  const openFormModal = (item?: InventoryIngredient) => {
    if (item) {
      setEditingItem(item);
      setFormData({
        name: item.name,
        sku: item.sku || '',
        category: item.category || 'Bahan Pokok',
        base_unit: item.base_unit || 'gram',
        current_stock: String(item.current_stock || 0),
        min_stock_alert: String(item.min_stock_alert || 0),
        cost_per_base_unit: String(item.cost_per_base_unit || 0),
        storage_type: item.storage_type || 'dry',
        outlet_id: item.outlet_id || (selectedOutletId !== 'all' ? selectedOutletId : outlets[0]?.id || ''),
      });
    } else {
      setEditingItem(null);
      setFormData({
        name: '',
        sku: `BHN-${Date.now().toString().slice(-5)}`,
        category: 'Bahan Pokok',
        base_unit: 'gram',
        current_stock: '0',
        min_stock_alert: '100',
        cost_per_base_unit: '0',
        storage_type: 'dry',
        outlet_id: selectedOutletId !== 'all' ? selectedOutletId : outlets[0]?.id || '',
      });
    }
    setIsFormOpen(true);
  };

  // Save Ingredient
  const handleSaveIngredient = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business) return;

    if (!formData.name.trim()) {
      alert('Nama bahan baku wajib diisi.');
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();

      const payload = {
        business_id: business.id,
        outlet_id: formData.outlet_id || null,
        name: formData.name.trim(),
        sku: formData.sku.trim() || null,
        category: formData.category,
        base_unit: formData.base_unit,
        current_stock: parseFloat(formData.current_stock) || 0,
        min_stock_alert: parseFloat(formData.min_stock_alert) || 0,
        cost_per_base_unit: parseFloat(formData.cost_per_base_unit) || 0,
        storage_type: formData.storage_type,
        is_active: true,
        updated_at: new Date().toISOString(),
      };

      if (editingItem) {
        const { error } = await supabase
          .from('inventory_ingredients')
          .update(payload)
          .eq('id', editingItem.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('inventory_ingredients').insert([payload]);
        if (error) throw error;
      }

      setIsFormOpen(false);
      loadIngredients();
    } catch (err: any) {
      console.error('Error saving ingredient:', err);
      alert('Gagal menyimpan bahan: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Open Stock Adjust Modal
  const openAdjustModal = (item: InventoryIngredient) => {
    setAdjustingItem(item);
    setAdjustDelta('');
    setAdjustType('add');
    setAdjustNote('');
    setIsAdjustOpen(true);
  };

  // Save Stock Adjustment
  const handleSaveAdjustment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!adjustingItem || !business) return;

    const deltaNum = parseFloat(adjustDelta);
    if (!deltaNum || deltaNum <= 0) {
      alert('Masukkan jumlah stok yang valid.');
      return;
    }

    try {
      setSubmitting(true);
      const supabase = createClient();

      const current = Number(adjustingItem.current_stock || 0);
      const change = adjustType === 'add' ? deltaNum : -deltaNum;
      const newBalance = Math.max(0, current + change);

      // 1. Update stok di inventory_ingredients
      const { error: updateErr } = await supabase
        .from('inventory_ingredients')
        .update({
          current_stock: newBalance,
          updated_at: new Date().toISOString(),
        })
        .eq('id', adjustingItem.id);

      if (updateErr) throw updateErr;

      // 2. Catat mutasi di ingredient_movements
      await supabase.from('ingredient_movements').insert([
        {
          business_id: business.id,
          outlet_id: adjustingItem.outlet_id || null,
          ingredient_id: adjustingItem.id,
          movement_type: adjustType === 'add' ? 'in_purchase' : 'waste',
          quantity_delta: change,
          balance_after: newBalance,
          note: adjustNote || (adjustType === 'add' ? 'Restock Bahan' : 'Penyesuaian Stok / Rusak'),
          created_at: new Date().toISOString(),
        },
      ]);

      setIsAdjustOpen(false);
      setAdjustingItem(null);
      loadIngredients();
    } catch (err: any) {
      console.error('Error adjusting stock:', err);
      alert('Gagal memperbarui stok: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSubmitting(false);
    }
  };

  // Delete Ingredient
  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Hapus bahan baku "${name}"? Tindakan ini tidak dapat dibatalkan.`)) return;
    try {
      const supabase = createClient();
      const { error } = await supabase.from('inventory_ingredients').delete().eq('id', id);
      if (error) throw error;
      loadIngredients();
    } catch (err: any) {
      console.error('Error deleting ingredient:', err);
      alert('Gagal menghapus bahan: ' + (err.message || 'Terjadi kesalahan'));
    }
  };

  // Export Excel
  const handleExportExcel = () => {
    if (ingredients.length === 0) {
      alert('Tidak ada data bahan untuk diekspor.');
      return;
    }
    const data = ingredients.map((it) => ({
      SKU: it.sku || '-',
      'Nama Bahan': it.name,
      Kategori: it.category || '-',
      'Satuan Dasar': it.base_unit,
      'Stok Saat Ini': it.current_stock,
      'Batas Minimum Alert': it.min_stock_alert,
      'Biaya per Satuan': it.cost_per_base_unit,
      'Estimasi Nilai Stok': Number(it.current_stock) * Number(it.cost_per_base_unit),
      Penyimpanan: it.storage_type,
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Inventaris Bahan');
    XLSX.writeFile(wb, `Inventaris_${business?.name || 'DPOS'}_${new Date().toISOString().split('T')[0]}.xlsx`);
  };

  // Filter Categories
  const categories = Array.from(new Set(ingredients.map((it) => it.category).filter(Boolean)));

  const filteredItems = ingredients.filter((it) => {
    const q = search.toLowerCase();
    const matchSearch =
      it.name.toLowerCase().includes(q) || (it.sku && it.sku.toLowerCase().includes(q));
    const matchCat = categoryFilter === 'all' || it.category === categoryFilter;
    return matchSearch && matchCat;
  });

  // Opname Handlers
  const openOpnameModal = () => {
    const rows: OpnameRow[] = ingredients.map((it) => ({
      ingredientId: it.id,
      name: it.name,
      sku: it.sku,
      storageType: it.storage_type || 'dry',
      unit: it.base_unit || 'gram',
      systemStock: Number(it.current_stock || 0),
      physicalStock: '',
      costPerUnit: Number(it.cost_per_base_unit || 0),
      reason: 'none',
      notes: '',
    }));
    setOpnameRows(rows);
    setOpnameNotes('');
    setIsBlindCount(false);
    setOpnameFilterStorage('all');
    setOpnameSearch('');
    setIsOpnameOpen(true);
  };

  const updateOpnameRow = (ingredientId: string, patch: Partial<OpnameRow>) => {
    setOpnameRows((prev) =>
      prev.map((r) => (r.ingredientId === ingredientId ? { ...r, ...patch } : r))
    );
  };

  const fillAllWithSystem = () => {
    setOpnameRows((prev) =>
      prev.map((r) => ({
        ...r,
        physicalStock: r.systemStock.toString(),
        reason: 'none',
      }))
    );
  };

  const clearAllPhysical = () => {
    setOpnameRows((prev) =>
      prev.map((r) => ({
        ...r,
        physicalStock: '',
        reason: 'none',
      }))
    );
  };

  const handleSaveOpname = async () => {
    if (!business) return;
    const countedRows = opnameRows.filter((r) => r.physicalStock.trim() !== '');
    if (countedRows.length === 0) {
      alert('Harap isi minimal 1 bahan pada kolom Stok Fisik sebelum menyimpan hasil opname.');
      return;
    }

    const targetOutletId = selectedOutletId !== 'all' ? selectedOutletId : (outlets[0]?.id || null);
    if (!targetOutletId) {
      alert('Harap pilih outlet terlebih dahulu.');
      return;
    }

    const confirmMsg = `Selesaikan Stock Opname untuk ${countedRows.length} bahan?\n` +
      `Stok sistem di inventaris akan langsung direkonsiliasi dan diperbarui sesuai fisik.`;
    if (!confirm(confirmMsg)) return;

    try {
      setOpnameSubmitting(true);
      const supabase = createClient();
      const datePart = new Date().toISOString().slice(2, 10).split('-').join('');
      const randPart = Math.floor(100 + Math.random() * 900);
      const sessionNumber = `OPN-${datePart}-${randPart}`;

      let totalSysVal = 0;
      let totalPhysVal = 0;
      let totalDiscrepancyVal = 0;

      countedRows.forEach((r) => {
        const phys = Number(r.physicalStock) || 0;
        totalSysVal += r.systemStock * r.costPerUnit;
        totalPhysVal += phys * r.costPerUnit;
        totalDiscrepancyVal += (phys - r.systemStock) * r.costPerUnit;
      });

      // 1. Create stock_opname_sessions
      const { data: sessionData, error: sessionErr } = await supabase
        .from('stock_opname_sessions')
        .insert([
          {
            business_id: business.id,
            outlet_id: targetOutletId,
            session_number: sessionNumber,
            status: 'completed',
            opname_type: opnameType,
            notes: opnameNotes || `Stock Opname Web Admin (${opnameType})`,
            total_system_value: totalSysVal,
            total_physical_value: totalPhysVal,
            total_discrepancy_value: totalDiscrepancyVal,
            started_at: new Date().toISOString(),
            completed_at: new Date().toISOString(),
          },
        ])
        .select('id')
        .single();

      if (sessionErr) throw sessionErr;
      const sessionId = sessionData.id;

      // 2. Batch insert stock_opname_items
      // discrepancy_quantity & discrepancy_value are generated columns in postgres
      const opnameItemsPayload = countedRows.map((r) => ({
        session_id: sessionId,
        ingredient_id: r.ingredientId,
        item_name: r.name,
        storage_location: r.storageType,
        unit: r.unit,
        system_stock: r.systemStock,
        physical_stock: Number(r.physicalStock) || 0,
        unit_cost: r.costPerUnit,
        discrepancy_reason: r.reason || 'none',
        notes: r.notes || null,
        counted_at: new Date().toISOString(),
      }));

      const { error: itemsErr } = await supabase
        .from('stock_opname_items')
        .insert(opnameItemsPayload);

      if (itemsErr) throw itemsErr;

      // 3. Update current_stock in inventory_ingredients & record in ingredient_movements
      for (const r of countedRows) {
        const phys = Number(r.physicalStock) || 0;
        const diff = phys - r.systemStock;

        if (Math.abs(diff) > 0.0001) {
          // Update current stock
          await supabase
            .from('inventory_ingredients')
            .update({
              current_stock: phys,
              updated_at: new Date().toISOString(),
            })
            .eq('id', r.ingredientId);

          // Record movement audit log
          await supabase.from('ingredient_movements').insert([
            {
              business_id: business.id,
              outlet_id: targetOutletId,
              ingredient_id: r.ingredientId,
              movement_type: 'adjustment',
              quantity_delta: diff,
              balance_after: phys,
              note: `Rekonsiliasi Opname #${sessionNumber} [${r.reason}]: ${r.notes || 'Penyesuaian stok opname'}`,
              created_at: new Date().toISOString(),
            },
          ]);
        }
      }

      setIsOpnameOpen(false);
      await loadIngredients();
      await loadHistorySessions();
      alert(`Berhasil menyelesaikan Stock Opname #${sessionNumber}!\nStok bahan baku telah disinkronkan.`);
    } catch (err: any) {
      console.error('Error saving stock opname:', err);
      alert('Gagal menyimpan hasil stock opname: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setOpnameSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <span className="text-xs font-bold text-orange-600 uppercase tracking-wider block">
            Manajemen Bahan Baku & Stok
          </span>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Inventaris & Bahan Baku
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Kontrol stok bahan baku, batas minimum alert, dan biaya modal HPP bahan
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <button
            onClick={openOpnameModal}
            className="px-3.5 py-2 text-xs font-bold rounded-xl border border-indigo-200 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 flex items-center gap-1.5 transition-colors shadow-xs"
          >
            <ClipboardCheck className="w-4 h-4 text-indigo-600" />
            <span>Lembar Stock Opname</span>
          </button>
          <button
            onClick={handleExportExcel}
            className="px-3.5 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
          >
            <Download className="w-4 h-4 text-emerald-600" />
            <span>Export Excel</span>
          </button>
          <button
            onClick={() => openFormModal()}
            className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Tambah Bahan</span>
          </button>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="flex items-center gap-2 border-b border-slate-200 pb-2">
        <button
          onClick={() => setActiveTab('inventory')}
          className={`px-4 py-2 text-xs font-bold rounded-xl flex items-center gap-2 transition-all ${
            activeTab === 'inventory'
              ? 'bg-slate-900 text-white shadow-xs'
              : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 bg-white border border-slate-200'
          }`}
        >
          <Boxes className="w-4 h-4" />
          <span>Daftar Bahan Baku</span>
          <span
            className={`text-[10px] px-1.5 py-0.5 rounded-full ${
              activeTab === 'inventory'
                ? 'bg-slate-800 text-slate-300'
                : 'bg-slate-100 text-slate-600'
            }`}
          >
            {ingredients.length}
          </span>
        </button>
        <button
          onClick={() => {
            setActiveTab('history');
            loadHistorySessions();
          }}
          className={`px-4 py-2 text-xs font-bold rounded-xl flex items-center gap-2 transition-all ${
            activeTab === 'history'
              ? 'bg-indigo-600 text-white shadow-xs'
              : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 bg-white border border-slate-200'
          }`}
        >
          <History className="w-4 h-4" />
          <span>Riwayat & Audit Opname</span>
          {historySessions.length > 0 && (
            <span
              className={`text-[10px] px-1.5 py-0.5 rounded-full ${
                activeTab === 'history'
                  ? 'bg-indigo-700 text-indigo-100'
                  : 'bg-indigo-50 text-indigo-700'
              }`}
            >
              {historySessions.length}
            </span>
          )}
        </button>
      </div>

      {/* TAB 1: DAFTAR BAHAN BAKU */}
      {activeTab === 'inventory' && (
        <div className="space-y-6">
          {/* KPI Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Total Item */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Total Jenis Bahan
            </span>
            <span className="text-xl font-black text-slate-900">
              {totalItems} <span className="text-xs font-normal text-slate-500">Item</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Bahan baku aktif terdaftar
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Boxes className="w-5 h-5" />
          </div>
        </div>

        {/* Bahan Menipis */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Perlu Restock Segera
            </span>
            <span className={`text-xl font-black ${lowStockItems > 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
              {lowStockItems} <span className="text-xs font-normal text-slate-500">Item Menipis</span>
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Stok berada di bawah batas minimum
            </span>
          </div>
          <div className={`w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0 ${
            lowStockItems > 0 ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'
          }`}>
            <AlertTriangle className="w-5 h-5" />
          </div>
        </div>

        {/* Total Nilai Stok */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Estimasi Nilai Stok
            </span>
            <span className="text-xl font-black text-slate-900">
              {formatRupiah(totalValue)}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">
              Total aset bahan baku di gudang
            </span>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center flex-shrink-0">
            <Warehouse className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Filter & Search */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari bahan baku atau SKU..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-slate-400" />
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="w-full sm:w-48 text-xs font-bold py-2 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="all">Semua Kategori</option>
            {categories.map((c) => (
              <option key={c} value={c as string}>
                {c}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4">Bahan Baku</th>
                <th className="py-3 px-4">Kategori</th>
                <th className="py-3 px-4">Penyimpanan</th>
                <th className="py-3 px-4 text-right">Stok Saat Ini</th>
                <th className="py-3 px-4 text-right">Min. Alert</th>
                <th className="py-3 px-4 text-right">Biaya / Satuan</th>
                <th className="py-3 px-4 text-right">Nilai Aset</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={9} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat bahan baku...</span>
                  </td>
                </tr>
              ) : filteredItems.length === 0 ? (
                <tr>
                  <td colSpan={9} className="py-12 text-center text-slate-400">
                    Tidak ada bahan baku ditemukan.
                  </td>
                </tr>
              ) : (
                filteredItems.map((item) => {
                  const isLow = Number(item.current_stock) <= Number(item.min_stock_alert);
                  const isOut = Number(item.current_stock) <= 0;

                  return (
                    <tr key={item.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-900">{item.name}</div>
                        <div className="font-mono text-[10px] text-slate-400">{item.sku || '-'}</div>
                      </td>
                      <td className="py-3.5 px-4 text-slate-600 font-medium">
                        {item.category || 'Bahan Pokok'}
                      </td>
                      <td className="py-3.5 px-4">
                        <span className="capitalize px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 text-[10px] font-semibold">
                          {item.storage_type === 'chilled'
                            ? 'Dingin / Chiller'
                            : item.storage_type === 'frozen'
                            ? 'Beku / Freezer'
                            : 'Kering'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right font-black text-slate-900">
                        {Number(item.current_stock).toLocaleString('id-ID')} {item.base_unit}
                      </td>
                      <td className="py-3.5 px-4 text-right text-slate-500">
                        {Number(item.min_stock_alert).toLocaleString('id-ID')} {item.base_unit}
                      </td>
                      <td className="py-3.5 px-4 text-right font-medium text-slate-700">
                        {formatRupiah(item.cost_per_base_unit)} / {item.base_unit}
                      </td>
                      <td className="py-3.5 px-4 text-right font-bold text-slate-900">
                        {formatRupiah(Number(item.current_stock) * Number(item.cost_per_base_unit))}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${
                            isOut
                              ? 'bg-red-50 text-red-700 border border-red-200'
                              : isLow
                              ? 'bg-amber-50 text-amber-700 border border-amber-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}
                        >
                          {isOut ? 'Habis' : isLow ? 'Menipis' : 'Aman'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Sesuaikan Stok */}
                          <button
                            onClick={() => openAdjustModal(item)}
                            title="Penyesuaian Stok Cepat"
                            className="px-2.5 py-1 text-xs font-bold rounded-lg border border-slate-200 hover:bg-orange-50 hover:text-orange-600 hover:border-orange-200 transition-colors inline-flex items-center gap-1"
                          >
                            <PackagePlus className="w-3.5 h-3.5" />
                            <span>Stok</span>
                          </button>
                          {/* Edit */}
                          <button
                            onClick={() => openFormModal(item)}
                            title="Edit Bahan"
                            className="p-1 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 transition-colors"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                          </button>
                          {/* Delete */}
                          <button
                            onClick={() => handleDelete(item.id, item.name)}
                            title="Hapus Bahan"
                            className="p-1 rounded-lg border border-slate-200 text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )}

      {/* TAB 2: RIWAYAT & AUDIT OPNAME */}
      {activeTab === 'history' && (
        <div className="space-y-6">
          {/* Opname KPI Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {/* Total Sesi */}
            <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
              <div>
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
                  Total Sesi Opname
                </span>
                <span className="text-xl font-black text-slate-900">
                  {historySessions.length} <span className="text-xs font-normal text-slate-500">Sesi Terlaksana</span>
                </span>
                <span className="text-[10px] text-slate-400 block mt-1">
                  Audit fisik stok bahan tercatat
                </span>
              </div>
              <div className="w-11 h-11 rounded-2xl bg-indigo-50 text-indigo-600 flex items-center justify-center flex-shrink-0">
                <ClipboardCheck className="w-5 h-5" />
              </div>
            </div>

            {/* Net Kerugian / Surplus Finansial */}
            {(() => {
              const totalNetLoss = historySessions.reduce(
                (sum, s) => sum + Number(s.total_discrepancy_value || 0),
                0
              );
              const isLoss = totalNetLoss < -0.0001;
              const isSurplus = totalNetLoss > 0.0001;
              return (
                <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center justify-between">
                  <div>
                    <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
                      Net Kerugian / Surplus Selisih
                    </span>
                    <span
                      className={`text-xl font-black ${
                        isLoss ? 'text-rose-600' : isSurplus ? 'text-emerald-600' : 'text-slate-900'
                      }`}
                    >
                      {isLoss ? '-' : isSurplus ? '+' : ''}
                      {formatRupiah(Math.abs(totalNetLoss))}
                    </span>
                    <span className="text-[10px] text-slate-400 block mt-1">
                      Akumulasi selisih nilai fisik vs sistem
                    </span>
                  </div>
                  <div
                    className={`w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0 ${
                      isLoss ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'
                    }`}
                  >
                    <TrendingDown className="w-5 h-5" />
                  </div>
                </div>
              );
            })()}

            {/* Aksi Cepat Opname */}
            <div className="bg-gradient-to-br from-indigo-900 to-slate-900 text-white p-5 rounded-2xl shadow-xs flex items-center justify-between">
              <div>
                <span className="text-[11px] font-bold text-indigo-300 uppercase tracking-wider block mb-1">
                  Jadwal Audit Stok
                </span>
                <span className="text-sm font-black text-white block">
                  Lakukan Opname Rutin
                </span>
                <span className="text-[11px] text-slate-400 block mt-0.5">
                  Cegah selisih misterius dan kontrol food cost
                </span>
              </div>
              <button
                onClick={openOpnameModal}
                className="px-3.5 py-2 text-xs font-bold rounded-xl bg-indigo-500 hover:bg-indigo-600 text-white transition-all shadow-xs flex items-center gap-1.5 flex-shrink-0"
              >
                <Plus className="w-4 h-4" />
                <span>Opname Baru</span>
              </button>
            </div>
          </div>

          {/* History Sessions Table */}
          <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
            <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-slate-700">Filter Tipe:</span>
                <select
                  value={historyFilterType}
                  onChange={(e) => setHistoryFilterType(e.target.value)}
                  className="text-xs font-medium py-1.5 px-3 rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:border-indigo-500"
                >
                  <option value="all">Semua Tipe Sesi</option>
                  <option value="daily_closing">Closing Harian</option>
                  <option value="weekly">Mingguan</option>
                  <option value="full_monthly">Bulanan Penuh</option>
                </select>
              </div>

              <button
                onClick={loadHistorySessions}
                className="px-3 py-1.5 text-xs font-bold rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 flex items-center gap-1.5 transition-colors self-end sm:self-auto"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${historyLoading ? 'animate-spin' : ''}`} />
                <span>Muat Ulang</span>
              </button>
            </div>

            {historyLoading ? (
              <div className="p-12 text-center text-xs text-slate-400">Memuat riwayat sesi opname...</div>
            ) : historySessions.length === 0 ? (
              <div className="p-12 text-center">
                <ClipboardCheck className="w-10 h-10 text-slate-300 mx-auto mb-2" />
                <p className="text-xs font-bold text-slate-600">Belum ada riwayat stock opname</p>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Klik tombol &quot;Lembar Stock Opname&quot; untuk menjalankan sesi audit fisik pertama.
                </p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-50/75 border-b border-slate-100 text-slate-400 uppercase text-[10px] tracking-wider font-bold">
                    <tr>
                      <th className="py-3 px-4">Tanggal & Waktu</th>
                      <th className="py-3 px-4">Nomor Sesi</th>
                      <th className="py-3 px-4">Tipe Sesi</th>
                      <th className="py-3 px-4 text-right">Nilai Sistem</th>
                      <th className="py-3 px-4 text-right">Nilai Fisik</th>
                      <th className="py-3 px-4 text-right">Selisih Finansial</th>
                      <th className="py-3 px-4 text-center">Status</th>
                      <th className="py-3 px-4 text-right">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-medium">
                    {historySessions
                      .filter((s) => historyFilterType === 'all' || s.opname_type === historyFilterType)
                      .map((session) => {
                        const dateFormatted = session.completed_at
                          ? new Date(session.completed_at).toLocaleDateString('id-ID', {
                              day: '2-digit',
                              month: 'short',
                              year: 'numeric',
                              hour: '2-digit',
                              minute: '2-digit',
                            })
                          : new Date(session.created_at || '').toLocaleDateString('id-ID');

                        const isLoss = Number(session.total_discrepancy_value || 0) < -0.0001;
                        const isSurplus = Number(session.total_discrepancy_value || 0) > 0.0001;

                        return (
                          <tr key={session.id} className="hover:bg-slate-50/50 transition-colors">
                            <td className="py-3.5 px-4 font-bold text-slate-800">{dateFormatted}</td>
                            <td className="py-3.5 px-4">
                              <span className="font-mono text-[11px] font-bold text-slate-700 bg-slate-100 px-2 py-0.5 rounded-md">
                                #{session.session_number}
                              </span>
                            </td>
                            <td className="py-3.5 px-4">
                              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700 border border-indigo-100">
                                {session.opname_type === 'daily_closing'
                                  ? 'Closing Harian'
                                  : session.opname_type === 'weekly'
                                  ? 'Mingguan'
                                  : 'Bulanan'}
                              </span>
                            </td>
                            <td className="py-3.5 px-4 text-right text-slate-500">
                              {formatRupiah(Number(session.total_system_value || 0))}
                            </td>
                            <td className="py-3.5 px-4 text-right font-medium text-slate-800">
                              {formatRupiah(Number(session.total_physical_value || 0))}
                            </td>
                            <td className="py-3.5 px-4 text-right font-black">
                              <span
                                className={
                                  isLoss
                                    ? 'text-rose-600'
                                    : isSurplus
                                    ? 'text-emerald-600'
                                    : 'text-slate-700'
                                }
                              >
                                {isLoss ? '-' : isSurplus ? '+' : ''}
                                {formatRupiah(Math.abs(Number(session.total_discrepancy_value || 0)))}
                              </span>
                            </td>
                            <td className="py-3.5 px-4 text-center">
                              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                                Selesai
                              </span>
                            </td>
                            <td className="py-3.5 px-4 text-right">
                              <button
                                onClick={() => openHistoryDetailModal(session)}
                                className="px-3 py-1.5 text-xs font-bold rounded-xl bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border border-indigo-200 transition-colors inline-flex items-center gap-1.5"
                              >
                                <Eye className="w-3.5 h-3.5 text-indigo-600" />
                                <span>Lihat Berita Acara</span>
                              </button>
                            </td>
                          </tr>
                        );
                      })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Modal Tambah / Edit Bahan */}
      {isFormOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Inventaris Bahan
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  {editingItem ? 'Edit Bahan Baku' : 'Tambah Bahan Baku Baru'}
                </h3>
              </div>
              <button
                onClick={() => setIsFormOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveIngredient} className="py-4 space-y-3.5 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Nama Bahan Baku *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Contoh: Biji Kopi Arabika, Susu Segar"
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Kode SKU</label>
                  <input
                    type="text"
                    value={formData.sku}
                    onChange={(e) => setFormData({ ...formData, sku: e.target.value })}
                    placeholder="BHN-001"
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-mono focus:outline-none focus:border-orange-500"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Kategori</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                  >
                    <option value="Bahan Pokok">Bahan Pokok</option>
                    <option value="Susu & Dairy">Susu & Dairy</option>
                    <option value="Sirup & Perasa">Sirup & Perasa</option>
                    <option value="Kemasan & Cup">Kemasan & Cup</option>
                    <option value="Bumbu & Saus">Bumbu & Saus</option>
                    <option value="Lainnya">Lainnya</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Satuan Dasar *</label>
                  <select
                    value={formData.base_unit}
                    onChange={(e) => setFormData({ ...formData, base_unit: e.target.value })}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                  >
                    <option value="gram">gram (g)</option>
                    <option value="ml">mililiter (ml)</option>
                    <option value="pcs">pieces (pcs)</option>
                    <option value="lembar">lembar</option>
                    <option value="porsi">porsi</option>
                    <option value="kg">kilogram (kg)</option>
                    <option value="liter">liter (L)</option>
                  </select>
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Penyimpanan</label>
                  <select
                    value={formData.storage_type}
                    onChange={(e: any) => setFormData({ ...formData, storage_type: e.target.value })}
                    className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                  >
                    <option value="dry">Kering (Suhu Ruang)</option>
                    <option value="chilled">Dingin (Kulkas/Chiller)</option>
                    <option value="frozen">Beku (Freezer)</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Stok Awal</label>
                  <input
                    type="number"
                    step="any"
                    value={formData.current_stock}
                    onChange={(e) => setFormData({ ...formData, current_stock: e.target.value })}
                    className="w-full py-2 px-2.5 rounded-xl border border-slate-200 font-bold focus:outline-none focus:border-orange-500"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Min. Alert</label>
                  <input
                    type="number"
                    step="any"
                    value={formData.min_stock_alert}
                    onChange={(e) => setFormData({ ...formData, min_stock_alert: e.target.value })}
                    className="w-full py-2 px-2.5 rounded-xl border border-slate-200 font-bold text-amber-600 focus:outline-none focus:border-orange-500"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Biaya (Rp)/Unit</label>
                  <input
                    type="number"
                    step="any"
                    value={formData.cost_per_base_unit}
                    onChange={(e) => setFormData({ ...formData, cost_per_base_unit: e.target.value })}
                    placeholder="Contoh: 150"
                    className="w-full py-2 px-2.5 rounded-xl border border-slate-200 font-bold focus:outline-none focus:border-orange-500"
                  />
                </div>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsFormOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Bahan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Penyesuaian Stok Cepat */}
      {isAdjustOpen && adjustingItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Penyesuaian Stok
                </span>
                <h3 className="font-black text-slate-900 text-base">
                  {adjustingItem.name}
                </h3>
              </div>
              <button
                onClick={() => setIsAdjustOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-3 my-4 bg-slate-50 rounded-xl flex items-center justify-between text-xs">
              <span className="text-slate-500">Stok Saat Ini:</span>
              <span className="font-black text-base text-slate-900">
                {Number(adjustingItem.current_stock).toLocaleString('id-ID')} {adjustingItem.base_unit}
              </span>
            </div>

            <form onSubmit={handleSaveAdjustment} className="space-y-4 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Aksi Penyesuaian</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setAdjustType('add')}
                    className={`p-2.5 rounded-xl border font-bold flex items-center justify-center gap-1.5 transition-all ${
                      adjustType === 'add'
                        ? 'border-emerald-600 bg-emerald-50 text-emerald-700'
                        : 'border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span>+ Masuk (Restock)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setAdjustType('subtract')}
                    className={`p-2.5 rounded-xl border font-bold flex items-center justify-center gap-1.5 transition-all ${
                      adjustType === 'subtract'
                        ? 'border-rose-600 bg-rose-50 text-rose-700'
                        : 'border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span>- Keluar (Rusak/Buang)</span>
                  </button>
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">
                  Jumlah ({adjustingItem.base_unit}) *
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  value={adjustDelta}
                  onChange={(e) => setAdjustDelta(e.target.value)}
                  placeholder={`Contoh: 500`}
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-black text-base focus:outline-none focus:border-orange-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Keterangan / Alasan</label>
                <input
                  type="text"
                  value={adjustNote}
                  onChange={(e) => setAdjustNote(e.target.value)}
                  placeholder="Contoh: Belanja pasar pagi, tumpah, opname..."
                  className="w-full py-2 px-3 rounded-xl border border-slate-200 font-medium focus:outline-none focus:border-orange-500"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsAdjustOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold hover:bg-slate-50"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl bg-orange-600 hover:bg-orange-700 text-white font-bold disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Perbarui Stok'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Stock Opname Sheet Modal */}
      {isOpnameOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl w-full max-w-5xl h-[92vh] flex flex-col shadow-2xl border border-slate-200 overflow-hidden animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/60">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-indigo-50 border border-indigo-100 text-indigo-600 flex items-center justify-center flex-shrink-0">
                  <ClipboardCheck className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-lg font-black text-slate-900">
                      Lembar Stock Opname Masal (F&B)
                    </h3>
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-800">
                      {opnameType === 'daily_closing' ? 'Closing Harian' : opnameType === 'weekly' ? 'Mingguan' : 'Bulanan'}
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Hitung fisik bahan baku di bar, kitchen, chiller, & gudang untuk rekonsiliasi otomatis
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setIsBlindCount(!isBlindCount)}
                  className={`px-3 py-1.5 text-xs font-bold rounded-xl border flex items-center gap-1.5 transition-all ${
                    isBlindCount
                      ? 'bg-amber-500 text-white border-amber-600 shadow-xs'
                      : 'border-slate-200 text-slate-700 hover:bg-white bg-slate-100/80'
                  }`}
                  title="Blind Count menyembunyikan angka sistem agar staf menghitung secara objektif"
                >
                  {isBlindCount ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  <span>{isBlindCount ? 'Blind Count: AKTIF' : 'Mode Blind Count'}</span>
                </button>
                <button
                  onClick={() => setIsOpnameOpen(false)}
                  className="p-2 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-white transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Sub-Header KPI & Quick Tools */}
            <div className="p-4 bg-white border-b border-slate-100 grid grid-cols-1 sm:grid-cols-4 gap-3">
              {/* Type selector */}
              <div>
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
                  Tipe Sesi
                </label>
                <select
                  value={opnameType}
                  onChange={(e) => setOpnameType(e.target.value as any)}
                  className="w-full text-xs font-bold py-1.5 px-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:border-indigo-500"
                >
                  <option value="daily_closing">Closing Harian (Bar & Kitchen)</option>
                  <option value="weekly">Mingguan (Weekly Check)</option>
                  <option value="full_monthly">Bulanan Penuh (Full Audit)</option>
                </select>
              </div>

              {/* KPI 1: Terhitung */}
              {(() => {
                const counted = opnameRows.filter((r) => r.physicalStock.trim() !== '').length;
                return (
                  <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Progress Hitung
                    </span>
                    <span className="text-sm font-black text-slate-900">
                      {counted} <span className="text-xs font-medium text-slate-400">/ {opnameRows.length} Bahan</span>
                    </span>
                  </div>
                );
              })()}

              {/* KPI 2: Selisih Items */}
              {(() => {
                const discrepant = opnameRows.filter(
                  (r) =>
                    r.physicalStock.trim() !== '' &&
                    Math.abs(Number(r.physicalStock) - r.systemStock) > 0.0001
                ).length;
                return (
                  <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Bahan Selisih
                    </span>
                    <span
                      className={`text-sm font-black ${
                        discrepant > 0 ? 'text-rose-600' : 'text-emerald-600'
                      }`}
                    >
                      {discrepant} <span className="text-xs font-medium text-slate-400">Item Selisih</span>
                    </span>
                  </div>
                );
              })()}

              {/* KPI 3: Estimasi Loss/Gain Nilai */}
              {(() => {
                let diffVal = 0;
                opnameRows.forEach((r) => {
                  if (r.physicalStock.trim() !== '') {
                    const phys = Number(r.physicalStock) || 0;
                    diffVal += (phys - r.systemStock) * r.costPerUnit;
                  }
                });
                return (
                  <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Total Selisih (Rp)
                    </span>
                    <span
                      className={`text-sm font-black ${
                        diffVal < -0.0001
                          ? 'text-rose-600'
                          : diffVal > 0.0001
                          ? 'text-emerald-600'
                          : 'text-slate-700'
                      }`}
                    >
                      {diffVal < 0 ? '-' : diffVal > 0 ? '+' : ''}
                      {formatRupiah(Math.abs(diffVal))}
                    </span>
                  </div>
                );
              })()}
            </div>

            {/* Filter Bar */}
            <div className="px-5 py-3 bg-slate-50/40 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
                <span className="text-xs font-bold text-slate-400 mr-1 flex items-center gap-1">
                  <Filter className="w-3.5 h-3.5" />
                  Lokasi:
                </span>
                {[
                  { id: 'all', label: 'Semua' },
                  { id: 'dry', label: 'Kering / Suhu Ruang' },
                  { id: 'chilled', label: 'Chiller / Dingin' },
                  { id: 'frozen', label: 'Freezer / Beku' },
                ].map((st) => (
                  <button
                    key={st.id}
                    onClick={() => setOpnameFilterStorage(st.id)}
                    className={`px-3 py-1 rounded-xl text-xs font-bold whitespace-nowrap transition-colors ${
                      opnameFilterStorage === st.id
                        ? 'bg-indigo-600 text-white shadow-xs'
                        : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    {st.label}
                  </button>
                ))}
              </div>

              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    value={opnameSearch}
                    onChange={(e) => setOpnameSearch(e.target.value)}
                    placeholder="Cari bahan..."
                    className="w-40 sm:w-48 text-xs pl-8 pr-3 py-1.5 rounded-xl border border-slate-200 bg-white focus:outline-none focus:border-indigo-500"
                  />
                </div>
                <button
                  type="button"
                  onClick={fillAllWithSystem}
                  className="px-2.5 py-1.5 text-xs font-bold rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 whitespace-nowrap transition-colors"
                  title="Isi seluruh kolom stok fisik dengan angka sistem"
                >
                  Isi Sesuai Sistem
                </button>
                <button
                  type="button"
                  onClick={clearAllPhysical}
                  className="px-2.5 py-1.5 text-xs font-bold rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-500 whitespace-nowrap transition-colors"
                  title="Reset seluruh input fisik"
                >
                  Kosongkan
                </button>
              </div>
            </div>

            {/* Table Area */}
            <div className="flex-1 overflow-y-auto p-5">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 text-slate-400 uppercase text-[10px] tracking-wider sticky top-0 bg-white z-10">
                    <th className="py-2.5 px-3 font-bold">Bahan Baku</th>
                    <th className="py-2.5 px-3 font-bold">Lokasi</th>
                    <th className="py-2.5 px-3 font-bold">Stok Sistem</th>
                    <th className="py-2.5 px-3 font-bold w-48">Stok Fisik (Hasil Hitung)</th>
                    <th className="py-2.5 px-3 font-bold text-center">Selisih</th>
                    <th className="py-2.5 px-3 font-bold">Nilai Selisih</th>
                    <th className="py-2.5 px-3 font-bold w-40">Alasan Discrepancy</th>
                    <th className="py-2.5 px-3 font-bold">Catatan</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {opnameRows
                    .filter((r) => {
                      const matchStorage =
                        opnameFilterStorage === 'all' || r.storageType === opnameFilterStorage;
                      const matchSearch =
                        !opnameSearch ||
                        r.name.toLowerCase().includes(opnameSearch.toLowerCase()) ||
                        (r.sku && r.sku.toLowerCase().includes(opnameSearch.toLowerCase()));
                      return matchStorage && matchSearch;
                    })
                    .map((row) => {
                      const hasCount = row.physicalStock.trim() !== '';
                      const physNum = Number(row.physicalStock) || 0;
                      const diff = hasCount ? physNum - row.systemStock : 0;
                      const diffVal = hasCount ? diff * row.costPerUnit : 0;

                      return (
                        <tr
                          key={row.ingredientId}
                          className={`hover:bg-slate-50/80 transition-colors ${
                            hasCount && Math.abs(diff) > 0.0001
                              ? 'bg-amber-50/30'
                              : ''
                          }`}
                        >
                          {/* Nama */}
                          <td className="py-3 px-3">
                            <span className="font-bold text-slate-900 block">{row.name}</span>
                            <span className="text-[10px] text-slate-400">
                              {row.sku || 'Tanpa SKU'} • {row.unit}
                            </span>
                          </td>

                          {/* Lokasi */}
                          <td className="py-3 px-3">
                            <span
                              className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                row.storageType === 'chilled'
                                  ? 'bg-cyan-50 text-cyan-700 border border-cyan-100'
                                  : row.storageType === 'frozen'
                                  ? 'bg-blue-50 text-blue-700 border border-blue-100'
                                  : 'bg-amber-50 text-amber-700 border border-amber-100'
                              }`}
                            >
                              {row.storageType === 'chilled'
                                ? 'Chiller'
                                : row.storageType === 'frozen'
                                ? 'Freezer'
                                : 'Kering'}
                            </span>
                          </td>

                          {/* Stok Sistem */}
                          <td className="py-3 px-3 font-medium">
                            {isBlindCount ? (
                              <span className="text-slate-400 italic">*** Dirahasiakan</span>
                            ) : (
                              <span className="text-slate-700 font-bold">
                                {row.systemStock.toLocaleString('id-ID')} {row.unit}
                              </span>
                            )}
                          </td>

                          {/* Input Stok Fisik */}
                          <td className="py-3 px-3">
                            <div className="flex items-center gap-1.5">
                              <input
                                type="number"
                                step="any"
                                value={row.physicalStock}
                                onChange={(e) =>
                                  updateOpnameRow(row.ingredientId, {
                                    physicalStock: e.target.value,
                                  })
                                }
                                placeholder="0"
                                className={`w-28 text-xs font-black px-2.5 py-1.5 rounded-xl border text-right focus:outline-none ${
                                  hasCount && Math.abs(diff) > 0.0001
                                    ? 'border-amber-400 bg-amber-50/50 text-amber-900'
                                    : 'border-slate-200 bg-white text-slate-900 focus:border-indigo-500'
                                }`}
                              />
                              <span className="text-[10px] font-bold text-slate-500 w-10">
                                {row.unit}
                              </span>
                            </div>
                          </td>

                          {/* Selisih */}
                          <td className="py-3 px-3 text-center">
                            {hasCount ? (
                              <span
                                className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-black ${
                                  diff < -0.0001
                                    ? 'bg-rose-100 text-rose-700'
                                    : diff > 0.0001
                                    ? 'bg-emerald-100 text-emerald-700'
                                    : 'bg-slate-100 text-slate-600'
                                }`}
                              >
                                {diff > 0 ? `+${diff}` : diff} {row.unit}
                              </span>
                            ) : (
                              <span className="text-slate-300">-</span>
                            )}
                          </td>

                          {/* Nilai Selisih */}
                          <td className="py-3 px-3">
                            {hasCount ? (
                              <span
                                className={`font-bold ${
                                  diffVal < -0.0001
                                    ? 'text-rose-600'
                                    : diffVal > 0.0001
                                    ? 'text-emerald-600'
                                    : 'text-slate-400'
                                }`}
                              >
                                {diffVal < 0 ? '-' : diffVal > 0 ? '+' : ''}
                                {formatRupiah(Math.abs(diffVal))}
                              </span>
                            ) : (
                              <span className="text-slate-300">-</span>
                            )}
                          </td>

                          {/* Alasan */}
                          <td className="py-3 px-3">
                            <select
                              value={row.reason}
                              onChange={(e) =>
                                updateOpnameRow(row.ingredientId, { reason: e.target.value })
                              }
                              disabled={!hasCount || Math.abs(diff) <= 0.0001}
                              className="w-full text-[11px] font-medium py-1 px-2 rounded-lg border border-slate-200 bg-white disabled:opacity-40 disabled:bg-slate-50 focus:outline-none focus:border-indigo-500"
                            >
                              <option value="none">Sesuai / Normal</option>
                              <option value="spoilage">Basi / Expired</option>
                              <option value="damaged">Rusak / Tumpah</option>
                              <option value="unrecorded_use">Pemakaian Tak Tercatat</option>
                              <option value="theft">Kehilangan / Selisih</option>
                              <option value="count_error">Kesalahan Hitung</option>
                            </select>
                          </td>

                          {/* Catatan */}
                          <td className="py-3 px-3">
                            <input
                              type="text"
                              value={row.notes}
                              onChange={(e) =>
                                updateOpnameRow(row.ingredientId, { notes: e.target.value })
                              }
                              placeholder="Catatan..."
                              className="w-full text-[11px] py-1 px-2 rounded-lg border border-slate-200 bg-white focus:outline-none focus:border-indigo-500"
                            />
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </div>

            {/* Modal Footer */}
            <div className="p-4 bg-slate-50 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex-1 max-w-md">
                <input
                  type="text"
                  value={opnameNotes}
                  onChange={(e) => setOpnameNotes(e.target.value)}
                  placeholder="Catatan umum sesi opname (contoh: Closing malam, verifikasi bersama SPV)..."
                  className="w-full text-xs py-2 px-3 rounded-xl border border-slate-200 bg-white focus:outline-none focus:border-indigo-500"
                />
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setIsOpnameOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold text-xs hover:bg-white"
                >
                  Batal
                </button>
                <button
                  type="button"
                  onClick={handleSaveOpname}
                  disabled={opnameSubmitting}
                  className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs shadow-sm flex items-center gap-2 disabled:opacity-50 transition-all"
                >
                  <Save className="w-4 h-4" />
                  <span>
                    {opnameSubmitting ? 'Menyimpan & Rekonsiliasi...' : 'Selesaikan & Rekonsiliasi Otomatis'}
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      {/* Modal Detail Berita Acara Opname */}
      {isHistoryDetailOpen && selectedHistorySession && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl w-full max-w-4xl h-[88vh] flex flex-col shadow-2xl border border-slate-200 overflow-hidden animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/70">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-indigo-50 border border-indigo-100 text-indigo-600 flex items-center justify-center flex-shrink-0">
                  <FileSpreadsheet className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-black text-slate-900">
                      Berita Acara Stock Opname #{selectedHistorySession.session_number}
                    </h3>
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                      Terverifikasi
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Tanggal Audit:{' '}
                    {selectedHistorySession.completed_at
                      ? new Date(selectedHistorySession.completed_at).toLocaleDateString('id-ID', {
                          day: '2-digit',
                          month: 'long',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : '-'}
                  </p>
                </div>
              </div>

              <button
                onClick={() => setIsHistoryDetailOpen(false)}
                className="p-2 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Financial Summary Card */}
            <div className="p-4 bg-white border-b border-slate-100 grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Total Nilai Sistem
                </span>
                <span className="text-base font-black text-slate-800">
                  {formatRupiah(Number(selectedHistorySession.total_system_value || 0))}
                </span>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Total Nilai Fisik
                </span>
                <span className="text-base font-black text-slate-900">
                  {formatRupiah(Number(selectedHistorySession.total_physical_value || 0))}
                </span>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Total Selisih Finansial
                </span>
                {(() => {
                  const val = Number(selectedHistorySession.total_discrepancy_value || 0);
                  const isLoss = val < -0.0001;
                  const isSurplus = val > 0.0001;
                  return (
                    <span
                      className={`text-base font-black ${
                        isLoss ? 'text-rose-600' : isSurplus ? 'text-emerald-600' : 'text-slate-800'
                      }`}
                    >
                      {isLoss ? '-' : isSurplus ? '+' : ''}
                      {formatRupiah(Math.abs(val))}
                    </span>
                  );
                })()}
              </div>
            </div>

            {/* Items Table */}
            <div className="flex-1 overflow-y-auto p-5">
              {historyDetailLoading ? (
                <div className="p-12 text-center text-xs text-slate-400">Memuat rincian bahan...</div>
              ) : historyDetailItems.length === 0 ? (
                <div className="p-12 text-center text-xs text-slate-400">Tidak ada item rincian</div>
              ) : (
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="border-b border-slate-200 text-slate-400 uppercase text-[10px] tracking-wider sticky top-0 bg-white z-10">
                      <th className="py-2.5 px-3 font-bold">Bahan Baku</th>
                      <th className="py-2.5 px-3 font-bold">Lokasi</th>
                      <th className="py-2.5 px-3 font-bold text-right">Stok Sistem</th>
                      <th className="py-2.5 px-3 font-bold text-right">Stok Fisik</th>
                      <th className="py-2.5 px-3 font-bold text-center">Selisih</th>
                      <th className="py-2.5 px-3 font-bold text-right">Nilai Selisih</th>
                      <th className="py-2.5 px-3 font-bold">Alasan</th>
                      <th className="py-2.5 px-3 font-bold">Catatan</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {historyDetailItems.map((it) => {
                      const diff = Number(it.discrepancy_quantity || 0);
                      const diffVal = Number(it.discrepancy_value || 0);
                      const hasDiff = Math.abs(diff) > 0.0001;

                      return (
                        <tr
                          key={it.id}
                          className={`hover:bg-slate-50/50 ${hasDiff ? 'bg-amber-50/20' : ''}`}
                        >
                          <td className="py-2.5 px-3 font-bold text-slate-800">{it.item_name}</td>
                          <td className="py-2.5 px-3">
                            <span className="text-[10px] font-semibold text-slate-500 uppercase">
                              {it.storage_location || 'General'}
                            </span>
                          </td>
                          <td className="py-2.5 px-3 text-right text-slate-600">
                            {it.system_stock} {it.unit}
                          </td>
                          <td className="py-2.5 px-3 text-right font-bold text-slate-900">
                            {it.physical_stock} {it.unit}
                          </td>
                          <td className="py-2.5 px-3 text-center">
                            <span
                              className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                diff < -0.0001
                                  ? 'bg-rose-100 text-rose-700'
                                  : diff > 0.0001
                                  ? 'bg-emerald-100 text-emerald-700'
                                  : 'bg-slate-100 text-slate-600'
                              }`}
                            >
                              {diff > 0 ? `+${diff}` : diff} {it.unit}
                            </span>
                          </td>
                          <td className="py-2.5 px-3 text-right font-bold">
                            <span
                              className={
                                diffVal < -0.0001
                                  ? 'text-rose-600'
                                  : diffVal > 0.0001
                                  ? 'text-emerald-600'
                                  : 'text-slate-400'
                              }
                            >
                              {diffVal < 0 ? '-' : diffVal > 0 ? '+' : ''}
                              {formatRupiah(Math.abs(diffVal))}
                            </span>
                          </td>
                          <td className="py-2.5 px-3 text-[11px] text-slate-600">
                            {it.discrepancy_reason && it.discrepancy_reason !== 'none'
                              ? it.discrepancy_reason === 'spoilage'
                                ? 'Basi / Expired'
                                : it.discrepancy_reason === 'damaged'
                                ? 'Rusak / Tumpah'
                                : it.discrepancy_reason === 'unrecorded_use'
                                ? 'Pemakaian Tak Tercatat'
                                : it.discrepancy_reason === 'theft'
                                ? 'Kehilangan'
                                : it.discrepancy_reason
                              : '-'}
                          </td>
                          <td className="py-2.5 px-3 text-[11px] text-slate-400">
                            {it.notes || '-'}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>

            {/* Modal Footer */}
            <div className="p-4 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
              <span className="text-xs text-slate-400">
                {historyDetailItems.length} bahan terverifikasi pada sesi ini
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setIsHistoryDetailOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-200 text-slate-600 font-bold text-xs hover:bg-white"
                >
                  Tutup
                </button>
                <button
                  type="button"
                  onClick={() =>
                    exportHistorySessionExcel(selectedHistorySession, historyDetailItems)
                  }
                  className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 transition-colors"
                >
                  <Download className="w-4 h-4" />
                  <span>Download Berita Acara Excel</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
