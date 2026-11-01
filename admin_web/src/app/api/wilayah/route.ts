import { NextRequest, NextResponse } from 'next/server';

// In-memory memory cache untuk meminimalkan beban ke wilayah.id
const cache = new Map<string, { timestamp: number; data: any }>();
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 jam cache

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const type = searchParams.get('type'); // 'provinces' | 'regencies' | 'districts' | 'villages'
  const code = searchParams.get('code');

  if (!type) {
    return NextResponse.json({ error: 'Parameter "type" wajib diisi' }, { status: 400 });
  }

  let targetUrl = '';
  switch (type) {
    case 'provinces':
      targetUrl = 'https://wilayah.id/api/provinces.json';
      break;
    case 'regencies':
      if (!code) {
        return NextResponse.json({ error: 'Parameter "code" provinsi wajib diisi untuk mencari kabupaten/kota' }, { status: 400 });
      }
      targetUrl = `https://wilayah.id/api/regencies/${code}.json`;
      break;
    case 'districts':
      if (!code) {
        return NextResponse.json({ error: 'Parameter "code" kabupaten/kota wajib diisi untuk mencari kecamatan' }, { status: 400 });
      }
      targetUrl = `https://wilayah.id/api/districts/${code}.json`;
      break;
    case 'villages':
      if (!code) {
        return NextResponse.json({ error: 'Parameter "code" kecamatan wajib diisi untuk mencari kelurahan/desa' }, { status: 400 });
      }
      targetUrl = `https://wilayah.id/api/villages/${code}.json`;
      break;
    default:
      return NextResponse.json({ error: 'Tipe wilayah tidak valid' }, { status: 400 });
  }

  // Cek cache
  const cacheKey = `${type}_${code || 'all'}`;
  const cached = cache.get(cacheKey);
  const now = Date.now();
  if (cached && (now - cached.timestamp < CACHE_TTL_MS)) {
    return NextResponse.json(cached.data);
  }

  try {
    const res = await fetch(targetUrl, {
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Syupeo-SaaS/1.0 (https://syupeo.com)',
      },
      next: { revalidate: 86400 }, // 1 hari Next.js cache
    });

    if (!res.ok) {
      throw new Error(`Gagal mengambil data dari wilayah.id: ${res.statusText}`);
    }

    const json = await res.json();
    cache.set(cacheKey, { timestamp: now, data: json });

    return NextResponse.json(json);
  } catch (err: any) {
    console.error('[Wilayah API Error]:', err);
    return NextResponse.json(
      { error: err.message || 'Gagal mengambil data wilayah' },
      { status: 500 }
    );
  }
}

