'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import { MenuItem, MenuItemVariant, MenuItemTieredPrice, Category, InventoryIngredient, MenuItemRecipe } from '@/types/database';
import * as XLSX from 'xlsx';
import {
  Package,
  Search,
  Filter,
  Plus,
  Download,
  Upload,
  Edit2,
  Trash2,
  AlertCircle,
  CheckCircle2,
  X,
  FileSpreadsheet,
  Tag,
  Barcode,
  RefreshCw,
  TrendingUp,
  Boxes,
  Zap,
  DollarSign,
  Minus,
  Sparkles,
  ChevronDown,
  ChevronUp,
  Layers,
  Layers3,
  Percent,
  Check,
  Info,
  ChefHat,
  UtensilsCrossed,
} from 'lucide-react';

interface VariantFormItem {
  id?: string;
  name: string;
  price: number;
  sku?: string;
  barcode?: string;
  stock_available: boolean;
}

interface TieredPriceFormItem {
  id?: string;
  min_quantity: number;
  price: number;
}

export default function MerchantProductsPage() {
  const { business } = useMerchant();

  const [products, setProducts] = useState<MenuItem[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [activeFilter, setActiveFilter] = useState<'all' | 'variants' | 'tiered' | 'low' | 'out'>('all');
  const [expandedProductId, setExpandedProductId] = useState<string | null>(null);

  // Modal State
  const [modalOpen, setModalOpen] = useState(false);
  const [modalTab, setModalTab] = useState<'basic' | 'variants' | 'tiered'>('basic');
  const [editingProduct, setEditingProduct] = useState<MenuItem | null>(null);
  
  // Basic Form State
  const [formName, setFormName] = useState('');
  const [formPrice, setFormPrice] = useState<number>(0);
  const [formCostPrice, setFormCostPrice] = useState<number>(0);
  const [formStock, setFormStock] = useState<number>(0);
  const [formUnit, setFormUnit] = useState<string>('pcs');
  const [formCategoryId, setFormCategoryId] = useState<string>('');
  const [formNewCategoryName, setFormNewCategoryName] = useState<string>('');
  const [isCreatingCategory, setIsCreatingCategory] = useState<boolean>(false);
  const [formBarcode, setFormBarcode] = useState<string>('');
  const [formDescription, setFormDescription] = useState<string>('');
  const [formStockAvailable, setFormStockAvailable] = useState<boolean>(true);
  const [formTrackStock, setFormTrackStock] = useState<boolean>(true);

  // Variants State
  const [hasVariants, setHasVariants] = useState<boolean>(false);
  const [variantsList, setVariantsList] = useState<VariantFormItem[]>([]);

  // Tiered Pricing State
  const [hasTieredPrices, setHasTieredPrices] = useState<boolean>(false);
  const [tieredPricesList, setTieredPricesList] = useState<TieredPriceFormItem[]>([]);

  const [saving, setSaving] = useState(false);

  // Fast Import State
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [importing, setImporting] = useState(false);
  const [importProgress, setImportProgress] = useState<{ current: number; total: number; durationMs?: number } | null>(null);
  const [importMessage, setImportMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // Recipe Builder State (F&B BOM)
  const [isRecipeModalOpen, setIsRecipeModalOpen] = useState(false);
  const [recipeProduct, setRecipeProduct] = useState<MenuItem | null>(null);
  const [selectedRecipeVariantId, setSelectedRecipeVariantId] = useState<string | null>(null);
  const [productRecipes, setProductRecipes] = useState<MenuItemRecipe[]>([]);
  const [allIngredients, setAllIngredients] = useState<InventoryIngredient[]>([]);
  const [recipeLoading, setRecipeLoading] = useState(false);
  const [recipeSaving, setRecipeSaving] = useState(false);

  const handleOpenRecipeModal = async (product: MenuItem) => {
    if (!business) return;
    setRecipeProduct(product);
    setSelectedRecipeVariantId(null);
    setIsRecipeModalOpen(true);
    setRecipeLoading(true);

    try {
      const supabase = createClient();
      // 1. Fetch active ingredients
      const { data: ingData } = await supabase
        .from('inventory_ingredients')
        .select('*')
        .eq('business_id', business.id)
        .eq('is_active', true)
        .order('name');
      setAllIngredients(ingData || []);

      // 2. Fetch existing recipes for this product
      const { data: recData } = await supabase
        .from('menu_item_recipes')
        .select('*, inventory_ingredients(*)')
        .eq('menu_item_id', product.id);
      setProductRecipes(recData || []);
    } catch (err) {
      console.error('Error loading recipe data:', err);
    } finally {
      setRecipeLoading(false);
    }
  };

  const handleAddIngredientToRecipe = (ingredientId: string) => {
    if (!ingredientId || !recipeProduct || !business) return;
    const ing = allIngredients.find((i) => i.id === ingredientId);
    if (!ing) return;

    const exists = productRecipes.some(
      (r) => r.ingredient_id === ingredientId && (r.variant_id ?? null) === selectedRecipeVariantId
    );
    if (exists) return;

    const newRecipe: MenuItemRecipe = {
      id: `temp-${Date.now()}`,
      business_id: business.id,
      menu_item_id: recipeProduct.id,
      ingredient_id: ingredientId,
      variant_id: selectedRecipeVariantId,
      quantity_required: 1,
      unit: ing.base_unit || 'gram',
      inventory_ingredients: ing,
    };
    setProductRecipes((prev) => [...prev, newRecipe]);
  };

  const handleRemoveRecipeItem = (index: number) => {
    setProductRecipes((prev) => prev.filter((_, idx) => idx !== index));
  };

  const handleUpdateRecipeQty = (index: number, qty: number) => {
    setProductRecipes((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], quantity_required: Math.max(0.001, qty) };
      return copy;
    });
  };

  const handleSaveRecipe = async () => {
    if (!recipeProduct || !business) return;

    try {
      setRecipeSaving(true);
      const supabase = createClient();

      const currentVariantRecipes = productRecipes.filter(
        (r) => (r.variant_id ?? null) === selectedRecipeVariantId
      );

      // 1. Delete old recipes for this variant
      let delQuery = supabase
        .from('menu_item_recipes')
        .delete()
        .eq('menu_item_id', recipeProduct.id);

      if (selectedRecipeVariantId) {
        delQuery = delQuery.eq('variant_id', selectedRecipeVariantId);
      } else {
        delQuery = delQuery.is('variant_id', null);
      }
      await delQuery;

      // 2. Insert new recipes
      let calculatedTotalHpp = 0;
      if (currentVariantRecipes.length > 0) {
        const payload = currentVariantRecipes.map((r) => {
          const cost = Number(r.inventory_ingredients?.cost_per_base_unit || 0);
          calculatedTotalHpp += r.quantity_required * cost;
          return {
            business_id: business.id,
            menu_item_id: recipeProduct.id,
            ingredient_id: r.ingredient_id,
            variant_id: selectedRecipeVariantId,
            quantity_required: r.quantity_required,
            unit: r.unit,
          };
        });

        const { error } = await supabase.from('menu_item_recipes').insert(payload);
        if (error) throw error;
      }

      // 3. Update menu_items.recipe_cost if saving default recipe
      if (!selectedRecipeVariantId) {
        await supabase
          .from('menu_items')
          .update({ recipe_cost: calculatedTotalHpp })
          .eq('id', recipeProduct.id);

        setProducts((prev) =>
          prev.map((p) => (p.id === recipeProduct.id ? { ...p, recipe_cost: calculatedTotalHpp } : p))
        );
      }

      alert('Resep berhasil disimpan dan HPP diperbarui!');
      setIsRecipeModalOpen(false);
    } catch (err: any) {
      console.error('Error saving recipe:', err);
      alert('Gagal menyimpan resep: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setRecipeSaving(false);
    }
  };

  const formatRupiah = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const loadData = async () => {
    if (!business) return;

    try {
      setLoading(true);
      const supabase = createClient();

      // Ambil kategori dari tabel menu_categories
      const { data: catData } = await supabase
        .from('menu_categories')
        .select('*')
        .eq('business_id', business.id)
        .order('name');
      setCategories(catData || []);

      // Ambil produk lengkap dengan varian dan harga bertingkat
      const { data: prodData, error } = await supabase
        .from('menu_items')
        .select(`
          *,
          menu_categories(id, name),
          menu_item_variants(*),
          menu_item_tiered_prices(*)
        `)
        .eq('business_id', business.id)
        .order('name');

      if (!error && prodData) {
        setProducts(prodData);
      } else if (error) {
        console.error('Error fetching menu_items:', error);
      }
    } catch (err) {
      console.error('Error fetching products:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [business?.id]);

  // Export Excel
  const handleExportExcel = () => {
    if (products.length === 0) {
      alert('Tidak ada produk untuk diexport.');
      return;
    }

    const exportData = products.map((p, idx) => {
      const variantStr = p.menu_item_variants && p.menu_item_variants.length > 0
        ? p.menu_item_variants.map(v => `${v.name} (${formatRupiah(v.price)})`).join('; ')
        : '-';

      const tieredStr = p.menu_item_tiered_prices && p.menu_item_tiered_prices.length > 0
        ? p.menu_item_tiered_prices
            .sort((a, b) => a.min_quantity - b.min_quantity)
            .map(t => `>=${t.min_quantity} (${formatRupiah(t.price)})`)
            .join('; ')
        : '-';

      return {
        No: idx + 1,
        'Nama Produk': p.name,
        Kategori: p.menu_categories?.name || p.categories?.name || 'Umum',
        'Harga Jual (Rp)': p.price,
        'Harga Modal / HPP (Rp)': p.recipe_cost ?? p.cost_price ?? 0,
        'Stok': p.stock_quantity ?? p.stock ?? 0,
        'Satuan': p.unit || 'pcs',
        'Barcode / SKU': p.barcode || p.sku || '',
        'Varian': variantStr,
        'Harga Bertingkat / Grosir': tieredStr,
        'Status Aktif': p.stock_available !== false ? 'Ya' : 'Tidak',
      };
    });

    const worksheet = XLSX.utils.json_to_sheet(exportData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Katalog Produk');

    const fileName = `Katalog_Produk_${business?.name || 'DPOS'}_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  };

  // Download Sample Template
  const handleDownloadTemplate = () => {
    const templateData = [
      {
        'Nama Produk': 'Nasi Goreng Spesial',
        'Kategori': 'Makanan',
        'Harga Jual': 25000,
        'Harga Modal': 15000,
        'Stok': 50,
        'Satuan': 'porsi',
        'Barcode': '8991234567890',
      },
      {
        'Nama Produk': 'Es Teh Manis',
        'Kategori': 'Minuman',
        'Harga Jual': 5000,
        'Harga Modal': 2000,
        'Stok': 100,
        'Satuan': 'cup',
        'Barcode': '8990987654321',
      },
      {
        'Nama Produk': 'Kopi Susu Gula Aren',
        'Kategori': 'Minuman',
        'Harga Jual': 18000,
        'Harga Modal': 9000,
        'Stok': 80,
        'Satuan': 'cup',
        'Barcode': '8993456789012',
      },
    ];

    const worksheet = XLSX.utils.json_to_sheet(templateData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Template_Import');
    XLSX.writeFile(workbook, 'Template_Import_Produk_ManggaPOS.xlsx');
  };

  // Fast Batch Import
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !business) return;

    const startTime = performance.now();
    try {
      setImporting(true);
      setImportMessage(null);
      setImportProgress({ current: 0, total: 0 });

      const buffer = await file.arrayBuffer();
      const workbook = XLSX.read(buffer, { type: 'array' });
      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];
      const jsonData: any[] = XLSX.utils.sheet_to_json(worksheet);

      if (jsonData.length === 0) {
        setImportMessage({ type: 'error', text: 'File Excel kosong atau format tidak sesuai.' });
        setImporting(false);
        return;
      }

      setImportProgress({ current: 0, total: jsonData.length });
      const supabase = createClient();

      const categoryMap = new Map<string, string>();
      categories.forEach((c) => categoryMap.set(c.name.toLowerCase().trim(), c.id));

      const newCategoryNames = new Set<string>();
      jsonData.forEach((row) => {
        const catName = String(row['Kategori'] || row['kategori'] || '').trim();
        if (catName && !categoryMap.has(catName.toLowerCase())) {
          newCategoryNames.add(catName);
        }
      });

      if (newCategoryNames.size > 0) {
        const newCatRows = Array.from(newCategoryNames).map((name) => ({
          business_id: business.id,
          name,
        }));
        const { data: createdCats } = await supabase
          .from('menu_categories')
          .insert(newCatRows)
          .select('id, name');

        if (createdCats) {
          createdCats.forEach((c) => categoryMap.set(c.name.toLowerCase().trim(), c.id));
        }
      }

      const productPayloads: any[] = [];
      for (const row of jsonData) {
        const name = row['Nama Produk'] || row['nama_produk'] || row['Nama'] || row['name'];
        if (!name) continue;

        const price = Number(row['Harga Jual'] || row['harga_jual'] || row['price'] || 0);
        const costPrice = Number(row['Harga Modal'] || row['harga_modal'] || row['cost_price'] || row['HPP'] || 0);
        const stock = Number(row['Stok'] || row['stok'] || row['stock'] || 0);
        const unit = String(row['Satuan'] || row['satuan'] || row['unit'] || 'pcs').trim();
        const barcode = String(row['Barcode'] || row['barcode'] || row['SKU'] || '').trim();
        const catName = String(row['Kategori'] || row['kategori'] || '').trim();
        const catId = catName ? categoryMap.get(catName.toLowerCase()) || null : null;

        productPayloads.push({
          business_id: business.id,
          name: String(name).trim(),
          price,
          recipe_cost: costPrice,
          stock_quantity: stock,
          track_stock_quantity: stock > 0,
          stock_available: true,
          unit: unit || 'pcs',
          barcode: barcode || null,
          category_id: catId,
        });
      }

      const BATCH_SIZE = 100;
      let insertedSoFar = 0;

      for (let i = 0; i < productPayloads.length; i += BATCH_SIZE) {
        const chunk = productPayloads.slice(i, i + BATCH_SIZE);
        const { error } = await supabase.from('menu_items').insert(chunk);
        if (error) throw error;
        insertedSoFar += chunk.length;
        setImportProgress({
          current: insertedSoFar,
          total: productPayloads.length,
        });
      }

      const totalTime = ((performance.now() - startTime) / 1000).toFixed(1);

      setImportMessage({
        type: 'success',
        text: `⚡ Super Cepat! Berhasil mengimpor ${productPayloads.length} produk dalam ${totalTime} detik!`,
      });
      loadData();
    } catch (err: any) {
      console.error('Import error:', err);
      setImportMessage({ type: 'error', text: err?.message || 'Gagal mengimpor file Excel.' });
    } finally {
      setImporting(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  // Quick Stock Adjustment (+1 / -1)
  const handleQuickAdjustStock = async (p: MenuItem, delta: number) => {
    const currentStock = p.stock_quantity ?? p.stock ?? 0;
    const newStock = Math.max(0, currentStock + delta);
    if (newStock === currentStock) return;

    setProducts((prev) =>
      prev.map((item) => (item.id === p.id ? { ...item, stock_quantity: newStock } : item))
    );

    try {
      const supabase = createClient();
      await supabase
        .from('menu_items')
        .update({ stock_quantity: newStock, track_stock_quantity: true })
        .eq('id', p.id);
    } catch (err) {
      console.error('Error adjusting stock:', err);
      loadData();
    }
  };

  // Toggle Accordion
  const toggleExpand = (productId: string) => {
    setExpandedProductId((prev) => (prev === productId ? null : productId));
  };

  // Open Modal for Add/Edit
  const handleOpenModal = (prod?: MenuItem) => {
    setModalTab('basic');
    if (prod) {
      setEditingProduct(prod);
      setFormName(prod.name);
      setFormPrice(prod.price);
      setFormCostPrice(prod.recipe_cost ?? prod.cost_price ?? 0);
      setFormStock(prod.stock_quantity ?? prod.stock ?? 0);
      setFormUnit(prod.unit || 'pcs');
      setFormCategoryId(prod.category_id || '');
      setFormBarcode(prod.barcode || '');
      setFormDescription(prod.description || '');
      setFormStockAvailable(prod.stock_available !== false);
      setFormTrackStock(prod.track_stock_quantity !== false);

      // Prefill Variants
      const vList = prod.menu_item_variants || [];
      if (vList.length > 0) {
        setHasVariants(true);
        setVariantsList(
          vList.map((v) => ({
            id: v.id,
            name: v.name,
            price: v.price,
            sku: v.sku || '',
            barcode: v.barcode || '',
            stock_available: v.stock_available !== false,
          }))
        );
      } else {
        setHasVariants(false);
        setVariantsList([]);
      }

      // Prefill Tiered Prices
      const tList = prod.menu_item_tiered_prices || [];
      if (tList.length > 0) {
        setHasTieredPrices(true);
        setTieredPricesList(
          tList
            .sort((a, b) => a.min_quantity - b.min_quantity)
            .map((t) => ({
              id: t.id,
              min_quantity: t.min_quantity,
              price: t.price,
            }))
        );
      } else {
        setHasTieredPrices(false);
        setTieredPricesList([]);
      }
    } else {
      setEditingProduct(null);
      setFormName('');
      setFormPrice(0);
      setFormCostPrice(0);
      setFormStock(0);
      setFormUnit('pcs');
      setFormCategoryId(categories[0]?.id || '');
      setFormBarcode('');
      setFormDescription('');
      setFormStockAvailable(true);
      setFormTrackStock(true);
      setHasVariants(false);
      setVariantsList([]);
      setHasTieredPrices(false);
      setTieredPricesList([]);
    }
    setIsCreatingCategory(false);
    setFormNewCategoryName('');
    setModalOpen(true);
  };

  // Helper Variant Management
  const handleAddVariant = () => {
    setVariantsList((prev) => [
      ...prev,
      {
        name: '',
        price: formPrice || 0,
        sku: '',
        barcode: '',
        stock_available: true,
      },
    ]);
  };

  const handleRemoveVariant = (idx: number) => {
    setVariantsList((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleUpdateVariant = (idx: number, field: keyof VariantFormItem, val: any) => {
    setVariantsList((prev) =>
      prev.map((item, i) => (i === idx ? { ...item, [field]: val } : item))
    );
  };

  const handleQuickAddVariants = (preset: 'sizes' | 'temps' | 'spicy') => {
    setHasVariants(true);
    const baseP = formPrice || 10000;
    if (preset === 'sizes') {
      setVariantsList([
        { name: 'Reguler', price: baseP, stock_available: true },
        { name: 'Large (Jumbo)', price: baseP + 5000, stock_available: true },
      ]);
    } else if (preset === 'temps') {
      setVariantsList([
        { name: 'Dingin (Ice)', price: baseP, stock_available: true },
        { name: 'Panas (Hot)', price: baseP, stock_available: true },
      ]);
    } else if (preset === 'spicy') {
      setVariantsList([
        { name: 'Tidak Pedas', price: baseP, stock_available: true },
        { name: 'Sedang', price: baseP, stock_available: true },
        { name: 'Ekstra Pedas', price: baseP + 2000, stock_available: true },
      ]);
    }
  };

  // Helper Tiered Price Management
  const handleAddTieredPrice = () => {
    const nextQty = tieredPricesList.length > 0
      ? tieredPricesList[tieredPricesList.length - 1].min_quantity + 5
      : 5;
    const discountedPrice = Math.max(0, (formPrice || 10000) - 1000);
    setTieredPricesList((prev) => [
      ...prev,
      {
        min_quantity: nextQty,
        price: discountedPrice,
      },
    ]);
  };

  const handleRemoveTieredPrice = (idx: number) => {
    setTieredPricesList((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleUpdateTieredPrice = (idx: number, field: keyof TieredPriceFormItem, val: any) => {
    setTieredPricesList((prev) =>
      prev.map((item, i) => (i === idx ? { ...item, [field]: val } : item))
    );
  };

  // Save Product with Variants and Tiered Prices
  const handleSaveProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!business || !formName.trim()) return;

    try {
      setSaving(true);
      const supabase = createClient();

      let targetCatId = formCategoryId;

      // Buat Kategori Baru jika dipilih
      if (isCreatingCategory && formNewCategoryName.trim()) {
        const { data: newCat } = await supabase
          .from('menu_categories')
          .insert({ business_id: business.id, name: formNewCategoryName.trim() })
          .select('id, name, business_id')
          .single();

        if (newCat) {
          targetCatId = newCat.id;
          setCategories((prev) => [...prev, newCat as Category]);
        }
      }

      const payload = {
        name: formName.trim(),
        price: Number(formPrice),
        recipe_cost: Number(formCostPrice),
        stock_quantity: Number(formStock),
        track_stock_quantity: formTrackStock,
        stock_available: formStockAvailable,
        unit: formUnit.trim() || 'pcs',
        category_id: targetCatId || null,
        barcode: formBarcode.trim() || null,
        description: formDescription.trim() || null,
      };

      let productId = editingProduct?.id;

      // 1. Simpan Item Utama
      if (editingProduct) {
        const { error } = await supabase
          .from('menu_items')
          .update(payload)
          .eq('id', editingProduct.id);
        if (error) throw error;
      } else {
        const { data: newItem, error } = await supabase
          .from('menu_items')
          .insert({
            business_id: business.id,
            ...payload,
          })
          .select('id')
          .single();
        if (error) throw error;
        productId = newItem.id;
      }

      if (!productId) throw new Error('Gagal mendapatkan ID produk');

      // 2. Sinkronisasi Varian (menu_item_variants)
      await supabase
        .from('menu_item_variants')
        .delete()
        .eq('menu_item_id', productId);

      if (hasVariants && variantsList.length > 0) {
        const validVariants = variantsList
          .filter((v) => v.name.trim() !== '')
          .map((v) => ({
            menu_item_id: productId,
            business_id: business.id,
            name: v.name.trim(),
            price: Number(v.price || 0),
            sku: v.sku?.trim() || null,
            barcode: v.barcode?.trim() || null,
            stock_available: v.stock_available !== false,
          }));

        if (validVariants.length > 0) {
          const { error: vErr } = await supabase
            .from('menu_item_variants')
            .insert(validVariants);
          if (vErr) console.error('Error saving variants:', vErr);
        }
      }

      // 3. Sinkronisasi Harga Bertingkat / Grosir (menu_item_tiered_prices)
      await supabase
        .from('menu_item_tiered_prices')
        .delete()
        .eq('menu_item_id', productId);

      if (hasTieredPrices && tieredPricesList.length > 0) {
        const validTiers = tieredPricesList
          .filter((t) => Number(t.min_quantity) > 0 && Number(t.price) >= 0)
          .map((t) => ({
            menu_item_id: productId,
            business_id: business.id,
            min_quantity: Number(t.min_quantity),
            price: Number(t.price),
          }));

        if (validTiers.length > 0) {
          const { error: tErr } = await supabase
            .from('menu_item_tiered_prices')
            .insert(validTiers);
          if (tErr) console.error('Error saving tiered prices:', tErr);
        }
      }

      setModalOpen(false);
      loadData();
    } catch (err: any) {
      console.error('Error saving product:', err);
      alert('Gagal menyimpan produk: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteProduct = async (id: string) => {
    if (!confirm('Yakin ingin menghapus produk ini dari katalog? Semua data varian dan harga bertingkatnya juga akan dihapus.')) return;
    try {
      const supabase = createClient();
      await supabase.from('menu_items').delete().eq('id', id);
      loadData();
    } catch (err) {
      console.error('Error deleting product:', err);
    }
  };

  // Metrics calculation
  const totalItemsCount = products.length;
  const totalCostAssets = products.reduce(
    (sum, p) => sum + (p.recipe_cost ?? p.cost_price ?? 0) * (p.stock_quantity ?? p.stock ?? 0),
    0
  );
  const totalPotentialRevenue = products.reduce(
    (sum, p) => sum + p.price * (p.stock_quantity ?? p.stock ?? 0),
    0
  );
  const lowStockCount = products.filter(
    (p) => (p.stock_quantity ?? p.stock ?? 0) <= 5 && (p.stock_quantity ?? p.stock ?? 0) > 0
  ).length;
  const outOfStockCount = products.filter((p) => (p.stock_quantity ?? p.stock ?? 0) === 0).length;
  const variantProductsCount = products.filter((p) => p.menu_item_variants && p.menu_item_variants.length > 0).length;
  const tieredProductsCount = products.filter((p) => p.menu_item_tiered_prices && p.menu_item_tiered_prices.length > 0).length;

  // Filtered Products
  const filteredProducts = products.filter((p) => {
    const matchSearch =
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      (p.barcode && p.barcode.toLowerCase().includes(search.toLowerCase())) ||
      (p.menu_item_variants && p.menu_item_variants.some(v => v.name.toLowerCase().includes(search.toLowerCase()) || (v.barcode && v.barcode.toLowerCase().includes(search.toLowerCase()))));

    const matchCategory = selectedCategory === 'all' || p.category_id === selectedCategory;

    const s = p.stock_quantity ?? p.stock ?? 0;
    let matchFilter = true;
    if (activeFilter === 'low') matchFilter = s <= 5 && s > 0;
    else if (activeFilter === 'out') matchFilter = s === 0;
    else if (activeFilter === 'variants') matchFilter = Boolean(p.menu_item_variants && p.menu_item_variants.length > 0);
    else if (activeFilter === 'tiered') matchFilter = Boolean(p.menu_item_tiered_prices && p.menu_item_tiered_prices.length > 0);

    return matchSearch && matchCategory && matchFilter;
  });

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <span>Katalog Produk & Varian</span>
            <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-orange-100 text-orange-700">
              POS & Online
            </span>
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Kelola harga jual, harga modal (HPP), varian produk (ukuran/rasa), dan harga bertingkat grosir
          </p>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Download Template */}
          <button
            onClick={handleDownloadTemplate}
            title="Download Template Format Excel"
            className="px-3 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
          >
            <FileSpreadsheet className="w-4 h-4 text-emerald-600" />
            <span>Format Excel</span>
          </button>

          {/* Import Excel */}
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleFileChange}
            accept=".xlsx, .xls, .csv"
            className="hidden"
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={importing}
            className="px-3.5 py-2 text-xs font-bold rounded-xl bg-blue-50 hover:bg-blue-100 border border-blue-200 text-blue-700 flex items-center gap-1.5 transition-all shadow-xs"
          >
            <Zap className="w-4 h-4 text-blue-600" />
            <span>{importing ? 'Mengimpor Cepat...' : 'Import Kilat Excel'}</span>
          </button>

          {/* Export Excel */}
          <button
            onClick={handleExportExcel}
            className="px-3 py-2 text-xs font-bold rounded-xl border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
          >
            <Download className="w-4 h-4 text-purple-600" />
            <span>Export Excel</span>
          </button>

          {/* Tambah Produk */}
          <button
            onClick={() => handleOpenModal()}
            className="px-4 py-2 text-xs font-bold rounded-xl bg-orange-600 hover:bg-orange-700 text-white flex items-center gap-1.5 shadow-sm shadow-orange-600/20 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Tambah Produk</span>
          </button>
        </div>
      </div>

      {/* Financial & Inventory Summary Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        {/* Total Produk & Varian */}
        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center flex-shrink-0">
            <Package className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Total Katalog
            </span>
            <div className="text-lg sm:text-xl font-black text-slate-900">{totalItemsCount} Produk</div>
            <span className="text-[10px] sm:text-[11px] text-slate-500">
              {variantProductsCount} bervarian • {tieredProductsCount} grosir
            </span>
          </div>
        </div>

        {/* Nilai Total Modal / Aset */}
        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center flex-shrink-0">
            <DollarSign className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Nilai Aset Modal (HPP)
            </span>
            <div className="text-lg sm:text-xl font-black text-blue-600">{formatRupiah(totalCostAssets)}</div>
            <span className="text-[10px] sm:text-[11px] text-slate-500">Total modal stok tersedia</span>
          </div>
        </div>

        {/* Potensi Omzet Jual */}
        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center flex-shrink-0">
            <TrendingUp className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Potensi Nilai Jual
            </span>
            <div className="text-lg sm:text-xl font-black text-emerald-600">
              {formatRupiah(totalPotentialRevenue)}
            </div>
            <span className="text-[10px] sm:text-[11px] text-slate-500">Jika semua stok terjual</span>
          </div>
        </div>

        {/* Peringatan Stok Menipis & Habis */}
        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center flex-shrink-0">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Perhatian Stok
            </span>
            <div className="text-lg sm:text-xl font-black text-amber-600">
              {lowStockCount + outOfStockCount} Item
            </div>
            <span className="text-[10px] sm:text-[11px] text-slate-500">
              {outOfStockCount} Habis • {lowStockCount} Menipis
            </span>
          </div>
        </div>
      </div>

      {/* Import Notification Banner */}
      {importMessage && (
        <div
          className={`p-4 rounded-xl flex items-center justify-between text-xs font-bold ${
            importMessage.type === 'success'
              ? 'bg-emerald-50 text-emerald-800 border border-emerald-200'
              : 'bg-red-50 text-red-800 border border-red-200'
          }`}
        >
          <div className="flex items-center gap-2">
            {importMessage.type === 'success' ? (
              <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
            ) : (
              <AlertCircle className="w-4 h-4 text-red-600 flex-shrink-0" />
            )}
            <span>{importMessage.text}</span>
          </div>
          <button onClick={() => setImportMessage(null)} className="p-1 hover:opacity-75">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Filter & Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col md:flex-row items-center justify-between gap-3">
        {/* Search Input */}
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama produk, varian, atau barcode..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 font-medium"
          />
        </div>

        {/* Filter Chips & Category Dropdown */}
        <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
          {/* Quick Filter Chips */}
          <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-xl text-xs font-bold text-slate-600 overflow-x-auto max-w-full">
            <button
              onClick={() => setActiveFilter('all')}
              className={`px-2.5 py-1 rounded-lg transition-all text-[11px] whitespace-nowrap ${
                activeFilter === 'all' ? 'bg-white text-slate-900 shadow-xs' : 'hover:text-slate-900'
              }`}
            >
              Semua ({products.length})
            </button>
            <button
              onClick={() => setActiveFilter('variants')}
              className={`px-2.5 py-1 rounded-lg transition-all text-[11px] whitespace-nowrap flex items-center gap-1 ${
                activeFilter === 'variants' ? 'bg-white text-purple-700 shadow-xs' : 'hover:text-slate-900'
              }`}
            >
              <Layers className="w-3 h-3 text-purple-600" />
              <span>Varian ({variantProductsCount})</span>
            </button>
            <button
              onClick={() => setActiveFilter('tiered')}
              className={`px-2.5 py-1 rounded-lg transition-all text-[11px] whitespace-nowrap flex items-center gap-1 ${
                activeFilter === 'tiered' ? 'bg-white text-blue-700 shadow-xs' : 'hover:text-slate-900'
              }`}
            >
              <Tag className="w-3 h-3 text-blue-600" />
              <span>Grosir ({tieredProductsCount})</span>
            </button>
            <button
              onClick={() => setActiveFilter('low')}
              className={`px-2.5 py-1 rounded-lg transition-all text-[11px] whitespace-nowrap ${
                activeFilter === 'low' ? 'bg-white text-amber-700 shadow-xs' : 'hover:text-slate-900'
              }`}
            >
              Menipis (≤5)
            </button>
            <button
              onClick={() => setActiveFilter('out')}
              className={`px-2.5 py-1 rounded-lg transition-all text-[11px] whitespace-nowrap ${
                activeFilter === 'out' ? 'bg-white text-red-700 shadow-xs' : 'hover:text-slate-900'
              }`}
            >
              Habis (0)
            </button>
          </div>

          {/* Category Dropdown */}
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="text-xs font-bold py-2 px-3 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-orange-500"
          >
            <option value="all">Semua Kategori</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Products Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/75 text-slate-400 uppercase text-[10px] tracking-wider">
                <th className="py-3 px-4 w-10"></th>
                <th className="py-3 px-4">Nama Produk & Barcode</th>
                <th className="py-3 px-4">Kategori</th>
                <th className="py-3 px-4 text-right">Harga Jual</th>
                <th className="py-3 px-4 text-right">Harga Modal (HPP)</th>
                <th className="py-3 px-4 text-center">Stok & Cepat Edit</th>
                <th className="py-3 px-4 text-center">Fitur Khusus</th>
                <th className="py-3 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-orange-500" />
                    <span>Memuat data produk...</span>
                  </td>
                </tr>
              ) : filteredProducts.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-400">
                    Tidak ada produk ditemukan sesuai filter.
                  </td>
                </tr>
              ) : (
                filteredProducts.map((p) => {
                  const s = p.stock_quantity ?? p.stock ?? 0;
                  const vList = p.menu_item_variants || [];
                  const tList = p.menu_item_tiered_prices || [];
                  const isExpanded = expandedProductId === p.id;

                  // Hitung rentang harga jika ada varian
                  let priceDisplay = formatRupiah(p.price);
                  if (vList.length > 0) {
                    const prices = vList.map((v) => Number(v.price || 0));
                    const minP = Math.min(...prices);
                    const maxP = Math.max(...prices);
                    if (minP !== maxP) {
                      priceDisplay = `${formatRupiah(minP)} - ${formatRupiah(maxP)}`;
                    } else if (prices.length > 0 && prices[0] > 0) {
                      priceDisplay = formatRupiah(prices[0]);
                    }
                  }

                  return (
                    <React.Fragment key={p.id}>
                      <tr className={`hover:bg-slate-50/70 transition-colors ${isExpanded ? 'bg-orange-50/20' : ''}`}>
                        {/* Expand Toggle */}
                        <td className="py-3.5 px-3 text-center">
                          {vList.length > 0 || tList.length > 0 ? (
                            <button
                              onClick={() => toggleExpand(p.id)}
                              title={isExpanded ? 'Tutup Rincian' : 'Lihat Varian & Harga Bertingkat'}
                              className="p-1 rounded-lg text-slate-400 hover:text-orange-600 hover:bg-orange-100/50 transition-colors"
                            >
                              {isExpanded ? (
                                <ChevronUp className="w-4 h-4 text-orange-600" />
                              ) : (
                                <ChevronDown className="w-4 h-4" />
                              )}
                            </button>
                          ) : (
                            <span className="w-4 h-4 inline-block text-slate-300">•</span>
                          )}
                        </td>

                        {/* Nama Produk */}
                        <td className="py-3.5 px-4">
                          <div>
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="font-bold text-slate-900 text-xs sm:text-sm">
                                {p.name}
                              </span>
                              {p.stock_available === false && (
                                <span className="bg-red-50 text-red-600 border border-red-200 px-1.5 py-0.2 rounded text-[9px] font-bold">
                                  Non-Aktif
                                </span>
                              )}
                            </div>
                            <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                              {p.barcode ? (
                                <span className="text-[10px] text-slate-400 font-mono flex items-center gap-1">
                                  <Barcode className="w-3 h-3 text-slate-400" />
                                  {p.barcode}
                                </span>
                              ) : null}
                              {p.unit && (
                                <span className="text-[10px] text-slate-500 bg-slate-100 px-1.5 py-0.2 rounded font-medium">
                                  Satuan: {p.unit}
                                </span>
                              )}
                            </div>
                            {p.description && (
                              <p className="text-[10px] text-slate-400 line-clamp-1 mt-0.5">{p.description}</p>
                            )}
                          </div>
                        </td>

                        {/* Kategori */}
                        <td className="py-3.5 px-4">
                          <span className="inline-block px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-700 font-bold text-[10px]">
                            {p.menu_categories?.name || p.categories?.name || 'Umum'}
                          </span>
                        </td>

                        {/* Harga Jual */}
                        <td className="py-3.5 px-4 text-right">
                          <div className="font-black text-slate-900">{priceDisplay}</div>
                          {vList.length > 0 && (
                            <span className="text-[9px] text-purple-600 font-bold block mt-0.5">
                              {vList.length} varian harga
                            </span>
                          )}
                        </td>

                        {/* Harga Modal / HPP */}
                        <td className="py-3.5 px-4 text-right">
                          <div className="font-semibold text-slate-500">
                            {formatRupiah(p.recipe_cost ?? p.cost_price ?? 0)}
                          </div>
                          {p.price > 0 && (p.recipe_cost ?? p.cost_price ?? 0) > 0 && (
                            <span className="text-[9px] text-emerald-600 font-bold block mt-0.5">
                              Margin {Math.round(((p.price - (p.recipe_cost ?? p.cost_price ?? 0)) / p.price) * 100)}%
                            </span>
                          )}
                        </td>

                        {/* Interactive Stock & Quick Adjust */}
                        <td className="py-3.5 px-4 text-center">
                          <div className="inline-flex items-center gap-1.5 bg-slate-50 p-1 rounded-xl border border-slate-100">
                            <button
                              onClick={() => handleQuickAdjustStock(p, -1)}
                              title="Kurangi 1"
                              className="w-5 h-5 rounded-lg bg-white border border-slate-200 text-slate-600 hover:bg-slate-100 flex items-center justify-center font-bold text-xs transition-colors"
                            >
                              <Minus className="w-3 h-3" />
                            </button>
                            <span
                              className={`min-w-[60px] text-center font-black text-[11px] px-2 py-0.5 rounded-md ${
                                s <= 0
                                  ? 'bg-red-50 text-red-700'
                                  : s <= 5
                                  ? 'bg-amber-50 text-amber-700'
                                  : 'text-slate-800'
                              }`}
                            >
                              {s} {p.unit || 'unit'}
                            </span>
                            <button
                              onClick={() => handleQuickAdjustStock(p, 1)}
                              title="Tambah 1"
                              className="w-5 h-5 rounded-lg bg-white border border-slate-200 text-slate-600 hover:bg-slate-100 flex items-center justify-center font-bold text-xs transition-colors"
                            >
                              <Plus className="w-3 h-3" />
                            </button>
                          </div>
                        </td>

                        {/* Fitur Khusus: Badges Varian & Grosir */}
                        <td className="py-3.5 px-4 text-center">
                          <div className="flex flex-col items-center gap-1">
                            {vList.length > 0 ? (
                              <button
                                onClick={() => toggleExpand(p.id)}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-purple-50 text-purple-700 border border-purple-200 font-bold text-[10px] hover:bg-purple-100 transition-colors"
                              >
                                <Layers className="w-3 h-3 text-purple-600" />
                                <span>{vList.length} Varian</span>
                              </button>
                            ) : null}

                            {tList.length > 0 ? (
                              <button
                                onClick={() => toggleExpand(p.id)}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-blue-50 text-blue-700 border border-blue-200 font-bold text-[10px] hover:bg-blue-100 transition-colors"
                              >
                                <Tag className="w-3 h-3 text-blue-600" />
                                <span>{tList.length} Tingkat Grosir</span>
                              </button>
                            ) : null}

                            {vList.length === 0 && tList.length === 0 && (
                              <span className="text-[10px] text-slate-400">Standar</span>
                            )}
                          </div>
                        </td>

                        {/* Aksi */}
                        <td className="py-3.5 px-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => handleOpenRecipeModal(p)}
                              title="Atur Resep Bahan (BOM) & HPP"
                              className="p-1.5 text-slate-400 hover:text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors"
                            >
                              <ChefHat className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleOpenModal(p)}
                              title="Edit Detail Produk"
                              className="p-1.5 text-slate-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                            >
                              <Edit2 className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleDeleteProduct(p.id)}
                              title="Hapus Produk"
                              className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>

                      {/* Expandable Sub-Detail: Varian & Tiered Prices */}
                      {isExpanded && (
                        <tr className="bg-slate-50/60 border-b border-slate-200/80 animate-in fade-in duration-150">
                          <td colSpan={8} className="p-4 sm:p-5">
                            <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs space-y-4">
                              <div className="flex items-center justify-between border-b border-slate-100 pb-2.5">
                                <div className="flex items-center gap-2">
                                  <Sparkles className="w-4 h-4 text-orange-500" />
                                  <h4 className="font-black text-xs sm:text-sm text-slate-900">
                                    Rincian Varian & Harga Grosir: {p.name}
                                  </h4>
                                </div>
                                <button
                                  onClick={() => handleOpenModal(p)}
                                  className="text-xs font-bold text-orange-600 hover:text-orange-700 flex items-center gap-1"
                                >
                                  <Edit2 className="w-3 h-3" />
                                  <span>Ubah di Form Edit</span>
                                </button>
                              </div>

                              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {/* Daftar Varian */}
                                <div>
                                  <div className="flex items-center justify-between mb-2">
                                    <span className="text-[11px] font-bold text-slate-700 flex items-center gap-1.5">
                                      <Layers className="w-3.5 h-3.5 text-purple-600" />
                                      <span>Varian Produk ({vList.length})</span>
                                    </span>
                                  </div>
                                  {vList.length === 0 ? (
                                    <div className="p-4 bg-slate-50 rounded-xl text-center text-[11px] text-slate-400 border border-slate-100">
                                      Belum ada varian untuk produk ini.
                                    </div>
                                  ) : (
                                    <div className="border border-slate-200/80 rounded-xl overflow-hidden">
                                      <table className="w-full text-left text-[11px]">
                                        <thead className="bg-slate-50 text-slate-400 uppercase text-[9px] font-bold border-b border-slate-100">
                                          <tr>
                                            <th className="py-2 px-3">Nama Varian</th>
                                            <th className="py-2 px-3 text-right">Harga Jual</th>
                                            <th className="py-2 px-3">Barcode/SKU</th>
                                            <th className="py-2 px-3 text-center">Status</th>
                                          </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                          {vList.map((v) => (
                                            <tr key={v.id} className="hover:bg-slate-50/50">
                                              <td className="py-2 px-3 font-bold text-slate-800">{v.name}</td>
                                              <td className="py-2 px-3 text-right font-black text-purple-700">
                                                {formatRupiah(v.price)}
                                              </td>
                                              <td className="py-2 px-3 text-slate-400 font-mono text-[10px]">
                                                {v.barcode || v.sku || '-'}
                                              </td>
                                              <td className="py-2 px-3 text-center">
                                                <span
                                                  className={`px-1.5 py-0.5 rounded text-[9px] font-bold ${
                                                    v.stock_available !== false
                                                      ? 'bg-emerald-50 text-emerald-700'
                                                      : 'bg-red-50 text-red-600'
                                                  }`}
                                                >
                                                  {v.stock_available !== false ? 'Tersedia' : 'Habis'}
                                                </span>
                                              </td>
                                            </tr>
                                          ))}
                                        </tbody>
                                      </table>
                                    </div>
                                  )}
                                </div>

                                {/* Daftar Harga Bertingkat / Grosir */}
                                <div>
                                  <div className="flex items-center justify-between mb-2">
                                    <span className="text-[11px] font-bold text-slate-700 flex items-center gap-1.5">
                                      <Tag className="w-3.5 h-3.5 text-blue-600" />
                                      <span>Harga Bertingkat / Grosir ({tList.length})</span>
                                    </span>
                                  </div>
                                  {tList.length === 0 ? (
                                    <div className="p-4 bg-slate-50 rounded-xl text-center text-[11px] text-slate-400 border border-slate-100">
                                      Belum ada harga bertingkat untuk produk ini.
                                    </div>
                                  ) : (
                                    <div className="border border-slate-200/80 rounded-xl overflow-hidden">
                                      <table className="w-full text-left text-[11px]">
                                        <thead className="bg-slate-50 text-slate-400 uppercase text-[9px] font-bold border-b border-slate-100">
                                          <tr>
                                            <th className="py-2 px-3">Min. Pembelian</th>
                                            <th className="py-2 px-3 text-right">Harga Satuan</th>
                                            <th className="py-2 px-3 text-right">Hemat / Item</th>
                                            <th className="py-2 px-3 text-right">Contoh Subtotal</th>
                                          </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                          {tList
                                            .sort((a, b) => a.min_quantity - b.min_quantity)
                                            .map((t) => {
                                              const diff = p.price - t.price;
                                              const sub = t.min_quantity * t.price;
                                              return (
                                                <tr key={t.id} className="hover:bg-slate-50/50">
                                                  <td className="py-2 px-3 font-bold text-slate-800">
                                                    ≥ {t.min_quantity} {p.unit || 'pcs'}
                                                  </td>
                                                  <td className="py-2 px-3 text-right font-black text-blue-700">
                                                    {formatRupiah(t.price)}
                                                  </td>
                                                  <td className="py-2 px-3 text-right text-[10px] font-bold text-emerald-600">
                                                    {diff > 0 ? `Hemat ${formatRupiah(diff)}` : '-'}
                                                  </td>
                                                  <td className="py-2 px-3 text-right font-bold text-slate-900">
                                                    {formatRupiah(sub)}
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
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Add / Edit Product (Full Detail: Basic, Variants, Tiered Pricing) */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-slate-900/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-white w-full max-w-3xl rounded-3xl border border-slate-200 shadow-2xl overflow-hidden my-6 flex flex-col max-h-[92vh] animate-in fade-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="p-4 sm:p-5 border-b border-slate-100 flex items-center justify-between bg-gradient-to-r from-orange-50/60 to-slate-50/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-orange-600 text-white flex items-center justify-center shadow-xs">
                  <Package className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-black text-slate-900 text-base sm:text-lg">
                    {editingProduct ? `Edit Produk: ${editingProduct.name}` : 'Tambah Produk Baru'}
                  </h3>
                  <p className="text-xs text-slate-500">
                    Konfigurasi katalog, harga jual, varian, dan harga grosir
                  </p>
                </div>
              </div>
              <button
                onClick={() => setModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Tabs Navigation */}
            <div className="flex items-center border-b border-slate-200/80 px-4 sm:px-6 bg-slate-50/70 text-xs font-bold gap-2 sm:gap-4 overflow-x-auto">
              <button
                type="button"
                onClick={() => setModalTab('basic')}
                className={`py-3 px-2 border-b-2 flex items-center gap-1.5 transition-all whitespace-nowrap ${
                  modalTab === 'basic'
                    ? 'border-orange-600 text-orange-600'
                    : 'border-transparent text-slate-500 hover:text-slate-900'
                }`}
              >
                <Package className="w-3.5 h-3.5" />
                <span>1. Info Dasar & Stok</span>
              </button>
              <button
                type="button"
                onClick={() => setModalTab('variants')}
                className={`py-3 px-2 border-b-2 flex items-center gap-1.5 transition-all whitespace-nowrap ${
                  modalTab === 'variants'
                    ? 'border-purple-600 text-purple-600'
                    : 'border-transparent text-slate-500 hover:text-slate-900'
                }`}
              >
                <Layers className="w-3.5 h-3.5" />
                <span>2. Varian Produk</span>
                {hasVariants && variantsList.length > 0 && (
                  <span className="bg-purple-100 text-purple-700 px-1.5 py-0.2 rounded-full text-[10px]">
                    {variantsList.length}
                  </span>
                )}
              </button>
              <button
                type="button"
                onClick={() => setModalTab('tiered')}
                className={`py-3 px-2 border-b-2 flex items-center gap-1.5 transition-all whitespace-nowrap ${
                  modalTab === 'tiered'
                    ? 'border-blue-600 text-blue-600'
                    : 'border-transparent text-slate-500 hover:text-slate-900'
                }`}
              >
                <Tag className="w-3.5 h-3.5" />
                <span>3. Harga Bertingkat (Grosir)</span>
                {hasTieredPrices && tieredPricesList.length > 0 && (
                  <span className="bg-blue-100 text-blue-700 px-1.5 py-0.2 rounded-full text-[10px]">
                    {tieredPricesList.length}
                  </span>
                )}
              </button>
            </div>

            {/* Modal Form Body */}
            <form onSubmit={handleSaveProduct} className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-5">
              {/* TAB 1: INFO DASAR & STOK */}
              {modalTab === 'basic' && (
                <div className="space-y-4">
                  {/* Nama Produk */}
                  <div>
                    <label className="text-xs font-bold text-slate-700 block mb-1">
                      Nama Produk <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      required
                      value={formName}
                      onChange={(e) => setFormName(e.target.value)}
                      placeholder="Contoh: Kopi Susu Aren, Nasi Goreng Spesial, Kaos Polos"
                      className="w-full text-xs font-semibold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                    />
                  </div>

                  {/* Kategori with inline Add New */}
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <label className="text-xs font-bold text-slate-700">Kategori</label>
                      <button
                        type="button"
                        onClick={() => setIsCreatingCategory(!isCreatingCategory)}
                        className="text-[11px] font-bold text-orange-600 hover:text-orange-700"
                      >
                        {isCreatingCategory ? 'Pilih yang Ada' : '+ Kategori Baru'}
                      </button>
                    </div>

                    {isCreatingCategory ? (
                      <input
                        type="text"
                        value={formNewCategoryName}
                        onChange={(e) => setFormNewCategoryName(e.target.value)}
                        placeholder="Ketik nama kategori baru..."
                        className="w-full text-xs font-medium px-3.5 py-2.5 rounded-xl border border-orange-300 focus:outline-none focus:border-orange-500 bg-orange-50/20"
                      />
                    ) : (
                      <select
                        value={formCategoryId}
                        onChange={(e) => setFormCategoryId(e.target.value)}
                        className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 bg-white"
                      >
                        <option value="">-- Tanpa Kategori / Umum --</option>
                        {categories.map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.name}
                          </option>
                        ))}
                      </select>
                    )}
                  </div>

                  {/* Harga Jual Standar & Harga Modal */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="text-xs font-bold text-slate-700 block mb-1">
                        Harga Jual Standar (Rp) <span className="text-red-500">*</span>
                      </label>
                      <input
                        type="number"
                        min="0"
                        required
                        value={formPrice}
                        onChange={(e) => setFormPrice(Number(e.target.value))}
                        className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                      />
                      <span className="text-[10px] text-slate-400 mt-1 block">
                        Harga default saat tidak memilih varian
                      </span>
                    </div>
                    <div>
                      <label className="text-xs font-bold text-slate-700 block mb-1">
                        Harga Modal / HPP (Rp)
                      </label>
                      <input
                        type="number"
                        min="0"
                        value={formCostPrice}
                        onChange={(e) => setFormCostPrice(Number(e.target.value))}
                        className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                      />
                      <span className="text-[10px] text-slate-400 mt-1 block">
                        Biaya pembuatan/kulakan untuk hitung laba bersih
                      </span>
                    </div>
                  </div>

                  {/* Stok & Satuan */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <div className="flex items-center justify-between mb-1">
                        <label className="text-xs font-bold text-slate-700">Jumlah Stok</label>
                        <label className="flex items-center gap-1 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={formTrackStock}
                            onChange={(e) => setFormTrackStock(e.target.checked)}
                            className="rounded text-orange-600 focus:ring-0 w-3 h-3"
                          />
                          <span className="text-[10px] text-slate-500 font-medium">Lacak Stok</span>
                        </label>
                      </div>
                      <input
                        type="number"
                        min="0"
                        disabled={!formTrackStock}
                        value={formStock}
                        onChange={(e) => setFormStock(Number(e.target.value))}
                        className="w-full text-xs font-bold px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 disabled:bg-slate-50 disabled:text-slate-400"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-bold text-slate-700 block mb-1">
                        Satuan Unit
                      </label>
                      <div className="flex gap-2">
                        <input
                          type="text"
                          value={formUnit}
                          onChange={(e) => setFormUnit(e.target.value)}
                          placeholder="pcs, porsi, cup, kg..."
                          className="w-full text-xs font-medium px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                        />
                      </div>
                      <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                        {['pcs', 'porsi', 'cup', 'botol', 'pack', 'kg'].map((u) => (
                          <button
                            key={u}
                            type="button"
                            onClick={() => setFormUnit(u)}
                            className="text-[10px] bg-slate-100 hover:bg-slate-200 text-slate-600 px-2 py-0.5 rounded-md font-medium"
                          >
                            {u}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Barcode / SKU */}
                  <div>
                    <label className="text-xs font-bold text-slate-700 block mb-1">
                      Barcode / Kode SKU <span className="text-slate-400 font-normal">(Opsional)</span>
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={formBarcode}
                        onChange={(e) => setFormBarcode(e.target.value)}
                        placeholder="Scan atau ketik nomor barcode produk..."
                        className="w-full pl-9 pr-3.5 py-2.5 font-mono text-xs font-medium rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500"
                      />
                      <Barcode className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                    </div>
                  </div>

                  {/* Deskripsi */}
                  <div>
                    <label className="text-xs font-bold text-slate-700 block mb-1">
                      Deskripsi / Keterangan Produk <span className="text-slate-400 font-normal">(Opsional)</span>
                    </label>
                    <textarea
                      rows={2}
                      value={formDescription}
                      onChange={(e) => setFormDescription(e.target.value)}
                      placeholder="Catatan komposisi, varian rasa, atau detail produk..."
                      className="w-full text-xs font-medium px-3.5 py-2 rounded-xl border border-slate-200 focus:outline-none focus:border-orange-500 resize-none"
                    />
                  </div>

                  {/* Status Ketersediaan */}
                  <div className="pt-2">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formStockAvailable}
                        onChange={(e) => setFormStockAvailable(e.target.checked)}
                        className="rounded text-orange-600 focus:ring-0 w-4 h-4"
                      />
                      <span className="text-xs font-bold text-slate-700">
                        Produk Tersedia & Aktif Dijual di Kasir POS / Self-Order
                      </span>
                    </label>
                  </div>
                </div>
              )}

              {/* TAB 2: VARIAN PRODUK */}
              {modalTab === 'variants' && (
                <div className="space-y-4">
                  {/* Toggle Varian */}
                  <div className="bg-purple-50/70 p-4 rounded-2xl border border-purple-200/80 flex items-start justify-between gap-4">
                    <div className="flex items-start gap-3">
                      <div className="w-9 h-9 rounded-xl bg-purple-600 text-white flex items-center justify-center flex-shrink-0 mt-0.5">
                        <Layers className="w-4 h-4" />
                      </div>
                      <div>
                        <h4 className="font-black text-slate-900 text-xs sm:text-sm">
                          Aktifkan Varian Produk
                        </h4>
                        <p className="text-[11px] text-slate-500 mt-0.5">
                          Aktifkan jika produk memiliki opsi ukuran (Small/Large), suhu (Ice/Hot), rasa, atau tipe kemasan yang memiliki harga atau barcode sendiri.
                        </p>
                      </div>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer flex-shrink-0 mt-1">
                      <input
                        type="checkbox"
                        checked={hasVariants}
                        onChange={(e) => {
                          const checked = e.target.checked;
                          setHasVariants(checked);
                          if (checked && variantsList.length === 0) {
                            handleAddVariant();
                          }
                        }}
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
                    </label>
                  </div>

                  {hasVariants && (
                    <div className="space-y-3 animate-in fade-in duration-150">
                      {/* Presets Cepat */}
                      <div className="flex items-center justify-between flex-wrap gap-2 pt-1">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="text-[10px] font-bold text-slate-400">Template Cepat:</span>
                          <button
                            type="button"
                            onClick={() => handleQuickAddVariants('sizes')}
                            className="text-[10px] font-bold px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors"
                          >
                            + Ukuran (Reguler & Large)
                          </button>
                          <button
                            type="button"
                            onClick={() => handleQuickAddVariants('temps')}
                            className="text-[10px] font-bold px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors"
                          >
                            + Suhu (Ice & Hot)
                          </button>
                          <button
                            type="button"
                            onClick={() => handleQuickAddVariants('spicy')}
                            className="text-[10px] font-bold px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors"
                          >
                            + Level Pedas
                          </button>
                        </div>
                        <button
                          type="button"
                          onClick={handleAddVariant}
                          className="px-3 py-1.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-bold text-xs flex items-center gap-1 transition-all shadow-xs"
                        >
                          <Plus className="w-3.5 h-3.5" />
                          <span>Tambah Varian</span>
                        </button>
                      </div>

                      {/* Tabel Daftar Varian */}
                      <div className="border border-slate-200 rounded-2xl overflow-hidden shadow-2xs">
                        <div className="overflow-x-auto">
                          <table className="w-full text-left text-xs">
                            <thead className="bg-slate-50 text-slate-500 uppercase text-[9px] font-bold border-b border-slate-200">
                              <tr>
                                <th className="py-2.5 px-3">Nama Varian <span className="text-red-500">*</span></th>
                                <th className="py-2.5 px-3 w-36">Harga Jual (Rp)</th>
                                <th className="py-2.5 px-3 w-36">Barcode / SKU</th>
                                <th className="py-2.5 px-3 text-center w-24">Tersedia</th>
                                <th className="py-2.5 px-2 text-center w-12">Hapus</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                              {variantsList.map((v, idx) => (
                                <tr key={idx} className="hover:bg-slate-50/50">
                                  <td className="py-2.5 px-3">
                                    <input
                                      type="text"
                                      required
                                      value={v.name}
                                      onChange={(e) => handleUpdateVariant(idx, 'name', e.target.value)}
                                      placeholder="Misal: Regular, Large, Level 1"
                                      className="w-full text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-slate-200 focus:outline-none focus:border-purple-500"
                                    />
                                  </td>
                                  <td className="py-2.5 px-3">
                                    <input
                                      type="number"
                                      min="0"
                                      required
                                      value={v.price}
                                      onChange={(e) => handleUpdateVariant(idx, 'price', Number(e.target.value))}
                                      className="w-full text-xs font-bold px-2.5 py-1.5 rounded-lg border border-slate-200 focus:outline-none focus:border-purple-500 text-right"
                                    />
                                  </td>
                                  <td className="py-2.5 px-3">
                                    <input
                                      type="text"
                                      value={v.barcode || v.sku || ''}
                                      onChange={(e) => handleUpdateVariant(idx, 'barcode', e.target.value)}
                                      placeholder="Barcode unik..."
                                      className="w-full text-xs font-mono px-2.5 py-1.5 rounded-lg border border-slate-200 focus:outline-none focus:border-purple-500"
                                    />
                                  </td>
                                  <td className="py-2.5 px-3 text-center">
                                    <input
                                      type="checkbox"
                                      checked={v.stock_available}
                                      onChange={(e) => handleUpdateVariant(idx, 'stock_available', e.target.checked)}
                                      className="rounded text-purple-600 focus:ring-0 w-4 h-4 cursor-pointer"
                                    />
                                  </td>
                                  <td className="py-2.5 px-2 text-center">
                                    <button
                                      type="button"
                                      onClick={() => handleRemoveVariant(idx)}
                                      title="Hapus Varian Ini"
                                      className="p-1 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                                    >
                                      <Trash2 className="w-3.5 h-3.5" />
                                    </button>
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* TAB 3: HARGA BERTINGKAT / GROSIR (TIERED PRICING) */}
              {modalTab === 'tiered' && (
                <div className="space-y-4">
                  {/* Toggle Tiered Pricing */}
                  <div className="bg-blue-50/70 p-4 rounded-2xl border border-blue-200/80 flex items-start justify-between gap-4">
                    <div className="flex items-start gap-3">
                      <div className="w-9 h-9 rounded-xl bg-blue-600 text-white flex items-center justify-center flex-shrink-0 mt-0.5">
                        <Tag className="w-4 h-4" />
                      </div>
                      <div>
                        <h4 className="font-black text-slate-900 text-xs sm:text-sm">
                          Aktifkan Harga Bertingkat / Grosir
                        </h4>
                        <p className="text-[11px] text-slate-500 mt-0.5">
                          Berikan harga khusus otomatis jika pelanggan membeli dalam jumlah banyak (misal beli ≥ 5 diskon jadi Rp 13.000/pcs, beli ≥ 10 jadi Rp 11.000/pcs).
                        </p>
                      </div>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer flex-shrink-0 mt-1">
                      <input
                        type="checkbox"
                        checked={hasTieredPrices}
                        onChange={(e) => {
                          const checked = e.target.checked;
                          setHasTieredPrices(checked);
                          if (checked && tieredPricesList.length === 0) {
                            handleAddTieredPrice();
                          }
                        }}
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                    </label>
                  </div>

                  {hasTieredPrices && (
                    <div className="space-y-3 animate-in fade-in duration-150">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] text-slate-500">
                          Harga reguler satuan saat ini: <strong className="text-slate-900">{formatRupiah(formPrice)}</strong>
                        </span>
                        <button
                          type="button"
                          onClick={handleAddTieredPrice}
                          className="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs flex items-center gap-1 transition-all shadow-xs"
                        >
                          <Plus className="w-3.5 h-3.5" />
                          <span>Tambah Tingkatan Harga</span>
                        </button>
                      </div>

                      {/* Tabel Harga Bertingkat */}
                      <div className="border border-slate-200 rounded-2xl overflow-hidden shadow-2xs">
                        <div className="overflow-x-auto">
                          <table className="w-full text-left text-xs">
                            <thead className="bg-slate-50 text-slate-500 uppercase text-[9px] font-bold border-b border-slate-200">
                              <tr>
                                <th className="py-2.5 px-3 w-40">Min. Pembelian (Qty)</th>
                                <th className="py-2.5 px-3">Harga Satuan Grosir (Rp)</th>
                                <th className="py-2.5 px-3 text-right">Potongan / Item</th>
                                <th className="py-2.5 px-2 text-center w-12">Hapus</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                              {tieredPricesList.map((t, idx) => {
                                const diff = formPrice - t.price;
                                const pct = formPrice > 0 ? Math.round((diff / formPrice) * 100) : 0;
                                return (
                                  <tr key={idx} className="hover:bg-slate-50/50">
                                    <td className="py-2.5 px-3">
                                      <div className="flex items-center gap-1.5">
                                        <span className="font-bold text-slate-400 text-xs">≥</span>
                                        <input
                                          type="number"
                                          min="1"
                                          required
                                          value={t.min_quantity}
                                          onChange={(e) => handleUpdateTieredPrice(idx, 'min_quantity', Number(e.target.value))}
                                          className="w-20 text-xs font-bold px-2 py-1.5 rounded-lg border border-slate-200 focus:outline-none focus:border-blue-500"
                                        />
                                        <span className="text-slate-500 text-xs">{formUnit || 'pcs'}</span>
                                      </div>
                                    </td>
                                    <td className="py-2.5 px-3">
                                      <input
                                        type="number"
                                        min="0"
                                        required
                                        value={t.price}
                                        onChange={(e) => handleUpdateTieredPrice(idx, 'price', Number(e.target.value))}
                                        className="w-full max-w-xs text-xs font-bold px-2.5 py-1.5 rounded-lg border border-slate-200 focus:outline-none focus:border-blue-500 text-right"
                                      />
                                    </td>
                                    <td className="py-2.5 px-3 text-right">
                                      {diff > 0 ? (
                                        <span className="inline-flex items-center gap-1 text-[11px] font-black text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md">
                                          Hemat {formatRupiah(diff)} ({pct}%)
                                        </span>
                                      ) : (
                                        <span className="text-slate-400 text-[11px]">-</span>
                                      )}
                                    </td>
                                    <td className="py-2.5 px-2 text-center">
                                      <button
                                        type="button"
                                        onClick={() => handleRemoveTieredPrice(idx)}
                                        title="Hapus Tingkat Ini"
                                        className="p-1 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                                      >
                                        <Trash2 className="w-3.5 h-3.5" />
                                      </button>
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Modal Footer */}
              <div className="flex items-center justify-between pt-4 border-t border-slate-100 flex-wrap gap-2">
                <div className="flex items-center gap-2">
                  {modalTab !== 'basic' && (
                    <button
                      type="button"
                      onClick={() => setModalTab('basic')}
                      className="px-3 py-1.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                    >
                      ← Kembali ke Info Dasar
                    </button>
                  )}
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setModalOpen(false)}
                    className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    disabled={saving}
                    className="px-5 py-2 text-xs font-bold text-white bg-orange-600 hover:bg-orange-700 rounded-xl shadow-sm shadow-orange-600/20 transition-all flex items-center gap-1.5"
                  >
                    {saving && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                    <span>{editingProduct ? 'Simpan Perubahan' : 'Tambah Produk'}</span>
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL ATUR RESEP MENU (BOM & FOOD COST HPP) */}
      {isRecipeModalOpen && recipeProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-xs p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl border border-slate-100 overflow-hidden">
            {/* Modal Header */}
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold">
                  <ChefHat className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-black text-slate-900">
                    Resep Bahan (BOM) & Food Cost HPP
                  </h3>
                  <p className="text-xs text-slate-500">
                    Produk: <span className="font-bold text-slate-800">{recipeProduct.name}</span> • Harga Jual: {formatRupiah(recipeProduct.price)}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsRecipeModalOpen(false)}
                className="w-8 h-8 rounded-full hover:bg-slate-200/60 flex items-center justify-center text-slate-400 hover:text-slate-600 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-6 overflow-y-auto space-y-5 flex-1">
              {/* Variant Selector (if product has variants) */}
              {recipeProduct.menu_item_variants && recipeProduct.menu_item_variants.length > 0 && (
                <div>
                  <label className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-2">
                    Pilih Varian Menu yang Diatur
                  </label>
                  <div className="flex items-center gap-2 flex-wrap">
                    <button
                      type="button"
                      onClick={() => setSelectedRecipeVariantId(null)}
                      className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all ${
                        selectedRecipeVariantId === null
                          ? 'bg-slate-900 text-white shadow-xs'
                          : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                      }`}
                    >
                      Resep Dasar (Default)
                    </button>
                    {recipeProduct.menu_item_variants.map((v) => (
                      <button
                        key={v.id || v.name}
                        type="button"
                        onClick={() => setSelectedRecipeVariantId(v.id || null)}
                        className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all ${
                          selectedRecipeVariantId === (v.id || null)
                            ? 'bg-emerald-600 text-white shadow-xs'
                            : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                        }`}
                      >
                        Varian: {v.name}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Profitability Calculation Box */}
              {(() => {
                const currentVariantRecipes = productRecipes.filter(
                  (r) => (r.variant_id ?? null) === selectedRecipeVariantId
                );
                const totalHpp = currentVariantRecipes.reduce(
                  (sum, r) => sum + r.quantity_required * Number(r.inventory_ingredients?.cost_per_base_unit || 0),
                  0
                );
                const sellingPrice = recipeProduct.price;
                const marginRp = sellingPrice - totalHpp;
                const marginPercent = sellingPrice > 0 ? Math.round((marginRp / sellingPrice) * 100) : 0;

                return (
                  <div className="grid grid-cols-3 gap-3 bg-slate-900 text-white p-4 rounded-2xl">
                    <div>
                      <span className="text-[10px] text-slate-400 font-bold uppercase block">Total Modal HPP</span>
                      <span className="text-base font-black text-emerald-400">{formatRupiah(totalHpp)}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-400 font-bold uppercase block">Laba Kotor (Margin)</span>
                      <span className="text-base font-black text-white">{formatRupiah(marginRp)}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-400 font-bold uppercase block">Persentase Margin</span>
                      <span className={`text-base font-black ${marginPercent >= 50 ? 'text-emerald-400' : 'text-amber-400'}`}>
                        {marginPercent}%
                      </span>
                    </div>
                  </div>
                );
              })()}

              {/* Add Ingredient Bar */}
              <div className="flex items-center gap-2">
                <select
                  id="recipe-ingredient-select"
                  className="flex-1 px-3.5 py-2.5 text-xs font-medium rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                  defaultValue=""
                  onChange={(e) => {
                    if (e.target.value) {
                      handleAddIngredientToRecipe(e.target.value);
                      e.target.value = '';
                    }
                  }}
                >
                  <option value="" disabled>+ Pilih Bahan Baku untuk Ditambahkan ke Resep...</option>
                  {allIngredients.map((ing) => (
                    <option key={ing.id} value={ing.id}>
                      {ing.name} ({formatRupiah(ing.cost_per_base_unit)}/{ing.base_unit}) • Stok: {ing.current_stock} {ing.base_unit}
                    </option>
                  ))}
                </select>
              </div>

              {/* Recipe Items Table */}
              {(() => {
                const currentVariantRecipes = productRecipes.filter(
                  (r) => (r.variant_id ?? null) === selectedRecipeVariantId
                );

                if (recipeLoading) {
                  return <div className="text-center py-8 text-xs text-slate-400">Memuat resep...</div>;
                }

                if (currentVariantRecipes.length === 0) {
                  return (
                    <div className="text-center py-8 bg-slate-50 rounded-2xl border border-dashed border-slate-200">
                      <UtensilsCrossed className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                      <p className="text-xs font-bold text-slate-600">Belum ada bahan baku di resep ini</p>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Pilih bahan baku pada dropdown di atas untuk mulai menyusun resep.
                      </p>
                    </div>
                  );
                }

                return (
                  <div className="border border-slate-200 rounded-2xl overflow-hidden">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 font-bold">
                        <tr>
                          <th className="py-2.5 px-3">Bahan Baku</th>
                          <th className="py-2.5 px-3 text-right">Biaya Satuan</th>
                          <th className="py-2.5 px-3 text-center">Takaran Porsi</th>
                          <th className="py-2.5 px-3 text-right">Subtotal HPP</th>
                          <th className="py-2.5 px-3 text-center w-10"></th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {currentVariantRecipes.map((r, idx) => {
                          const unitCost = Number(r.inventory_ingredients?.cost_per_base_unit || 0);
                          const subtotal = r.quantity_required * unitCost;

                          return (
                            <tr key={r.id || idx} className="hover:bg-slate-50/50">
                              <td className="py-2.5 px-3 font-bold text-slate-800">
                                {r.inventory_ingredients?.name || 'Bahan'}
                                <span className="text-[10px] text-slate-400 font-normal block">
                                  {r.inventory_ingredients?.category || 'Umum'}
                                </span>
                              </td>
                              <td className="py-2.5 px-3 text-right text-slate-500">
                                {formatRupiah(unitCost)}/{r.unit}
                              </td>
                              <td className="py-2.5 px-3 text-center">
                                <div className="inline-flex items-center gap-1.5">
                                  <input
                                    type="number"
                                    step="any"
                                    min="0.001"
                                    value={r.quantity_required}
                                    onChange={(e) => {
                                      const globalIdx = productRecipes.findIndex((item) => item === r);
                                      if (globalIdx !== -1) {
                                        handleUpdateRecipeQty(globalIdx, parseFloat(e.target.value) || 0);
                                      }
                                    }}
                                    className="w-20 px-2 py-1 text-center font-bold text-slate-900 border border-slate-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-emerald-500"
                                  />
                                  <span className="text-slate-400 font-bold text-[11px]">{r.unit}</span>
                                </div>
                              </td>
                              <td className="py-2.5 px-3 text-right font-black text-slate-900">
                                {formatRupiah(subtotal)}
                              </td>
                              <td className="py-2.5 px-3 text-center">
                                <button
                                  type="button"
                                  onClick={() => {
                                    const globalIdx = productRecipes.findIndex((item) => item === r);
                                    if (globalIdx !== -1) {
                                      handleRemoveRecipeItem(globalIdx);
                                    }
                                  }}
                                  className="p-1 text-slate-300 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                );
              })()}
            </div>

            {/* Modal Footer */}
            <div className="px-6 py-4 border-t border-slate-100 flex items-center justify-between bg-slate-50/50">
              <span className="text-xs text-slate-400">
                Resep otomatis memotong bahan saat kasir transaksi & mengupdate HPP produk
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setIsRecipeModalOpen(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-200/60 rounded-xl transition-colors"
                >
                  Batal
                </button>
                <button
                  type="button"
                  disabled={recipeSaving}
                  onClick={handleSaveRecipe}
                  className="px-5 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-sm transition-all flex items-center gap-1.5"
                >
                  {recipeSaving && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  <span>Simpan Resep</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
