import { notFound } from 'next/navigation';
import { createClient } from '@supabase/supabase-js';
import OnlineStoreClient from './OnlineStoreClient';
import type { Metadata } from 'next';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const cleanSlug = decodeURIComponent(slug).trim().toLowerCase();

  return {
    title: `Toko Online ${cleanSlug} | Syupeo POS`,
    description: `Pesan produk langsung dari katalog toko online resmi mitra Syupeo dengan mudah dan cepat.`,
  };
}

export default async function OnlineStorePage({ params }: PageProps) {
  const { slug } = await params;
  const cleanSlug = decodeURIComponent(slug).trim().toLowerCase();

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  const supabase = createClient(supabaseUrl, supabaseKey);

  // 1. Coba ambil data bisnis via query langsung atau RPC
  let business: any = null;

  // Direct select berdasarkan slug
  const { data: bData } = await supabase
    .from('businesses')
    .select('id, name, slug, phone, address, business_type')
    .eq('slug', cleanSlug)
    .maybeSingle();
  business = bData;

  // Fallback via RPC get_public_store_by_slug jika direct select kosong
  if (!business) {
    try {
      const { data: rpcData } = await supabase.rpc('get_public_store_by_slug', {
        p_slug: cleanSlug,
      });
      if (rpcData) business = rpcData;
    } catch (_) {}
  }

  // Jika tetap belum ketemu, coba cari berdasarkan UUID jika URL menggunakan business ID
  if (!business) {
    const { data: byId } = await supabase
      .from('businesses')
      .select('id, name, slug, phone, address, business_type')
      .eq('id', cleanSlug)
      .maybeSingle();
    business = byId;
  }

  if (!business) {
    notFound();
  }

  // 2. Ambil produk yang tersedia, kategori, dan varian
  const [itemsRes, catRes, variantsRes] = await Promise.all([
    supabase
      .from('menu_items')
      .select('id, name, price, description, image_url, is_active, stock_available, stock_quantity, unit, category_id, barcode')
      .eq('business_id', business.id)
      .eq('is_active', true)
      .order('name'),
    supabase
      .from('menu_categories')
      .select('id, name, sort_order')
      .eq('business_id', business.id)
      .order('sort_order', { ascending: true }),
    supabase
      .from('menu_item_variants')
      .select('id, menu_item_id, name, price, stock_available, unit_ratio')
      .eq('business_id', business.id),
  ]);

  const rawItems = itemsRes.data || [];
  const categories = catRes.data || [];
  const rawVariants = variantsRes.data || [];

  // Hubungkan varian ke masing-masing produk
  const variantsMap: Record<string, any[]> = {};
  rawVariants.forEach((v) => {
    if (!variantsMap[v.menu_item_id]) {
      variantsMap[v.menu_item_id] = [];
    }
    variantsMap[v.menu_item_id].push(v);
  });

  const items = rawItems.map((item) => ({
    ...item,
    variants: variantsMap[item.id] || [],
  }));

  return (
    <OnlineStoreClient
      store={business}
      items={items}
      categories={categories}
    />
  );
}

