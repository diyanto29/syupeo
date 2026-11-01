import { NextRequest, NextResponse } from 'next/server';

const GOOGLE_API_KEY =
  process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ||
  process.env.GOOGLE_MAPS_API_KEY ||
  'AIzaSyBJz3CrmMd25JeLm4HuMkCyR63lIX-3fjg';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const placeId = searchParams.get('placeId');

  if (!placeId) {
    return NextResponse.json({ error: 'Parameter "placeId" wajib diisi' }, { status: 400 });
  }

  // Jika item berasal dari OSM (placeId diawali 'osm_')
  if (placeId.startsWith('osm_')) {
    // Parameter latitude / longitude biasanya sudah tersedia di client
    return NextResponse.json({
      placeId,
      source: 'osm',
    });
  }

  // Google Places API (New) Place Details
  try {
    const url = `https://places.googleapis.com/v1/places/${placeId}?languageCode=id`;
    const response = await fetch(url, {
      headers: {
        'X-Goog-Api-Key': GOOGLE_API_KEY,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,addressComponents',
      },
    });

    if (!response.ok) {
      const errText = await response.text();
      return NextResponse.json({ error: `Google Places Details error: ${errText}` }, { status: response.status });
    }

    const data = await response.json();
    const latitude = data.location?.latitude ?? null;
    const longitude = data.location?.longitude ?? null;
    const formattedAddress = data.formattedAddress ?? '';
    const name = data.displayName?.text ?? '';

    return NextResponse.json({
      placeId: data.id,
      name,
      formattedAddress,
      latitude,
      longitude,
      addressComponents: data.addressComponents || [],
      source: 'google',
    });
  } catch (err: any) {
    console.error('[Place Details Error]:', err);
    return NextResponse.json({ error: err.message || 'Gagal mengambil detail tempat' }, { status: 500 });
  }
}

