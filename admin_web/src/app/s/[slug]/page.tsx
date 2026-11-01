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

  // 1. Coba ambil data bisnis via RPC get_public_store_by_slug
  let business: any = null;
  try {
    const { data: rpcData, error: rpcErr } = await supabase.rpc('get_public_store_by_slug', {
      p_slug: cleanSlug,
    });
    if (rpcData && !rpcErr) {
      business = rpcData;
    }
  } catch (_) {}

  // Fallback direct select jika RPC belum dipasang
  if (!business) {
    const { data: bData } = await supabase
      .from('businesses')
      .select('id, name, slug, phone, address, logo_url, banner_url, business_type, district, regency, province')
      .eq('slug', cleanSlug)
      .maybeSingle();
    business = bData;
  }

  // Jika tetap belum ketemu, coba cari berdasarkan UUID jika URL menggunakan business ID
  if (!business) {
    const { data: byId } = await supabase
      .from('businesses')
      .select('id, name, slug, phone, address, logo_url, banner_url, business_type, district, regency, province')
      .eq('id', cleanSlug)
      .maybeSingle();
    business = byId;
  }

  if (!business) {
    notFound();
  }

  // 2. Ambil produk yang tersedia dan kategorinya
  const [itemsRes, catRes] = await Promise.all([
    supabase
      .from('menu_items')
      .select('id, name, price, description, image_url, is_available, category_id, barcode')
      .eq('business_id', business.id)
      .eq('is_available', true)
      .order('name'),
    supabase
      .from('menu_categories')
      .select('id, name, sort_order')
      .eq('business_id', business.id)
      .order('sort_order', { ascending: true }),
  ]);

  const items = itemsRes.data || [];
  const categories = catRes.data || [];

  return (
    <OnlineStoreClient
      store={business}
      items={items}
      categories={categories}
    />
  );
}

