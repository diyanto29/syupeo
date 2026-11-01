import { NextRequest, NextResponse } from 'next/server';

const GOOGLE_API_KEY =
  process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ||
  process.env.GOOGLE_MAPS_API_KEY ||
  'AIzaSyBJz3CrmMd25JeLm4HuMkCyR63lIX-3fjg';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const query = searchParams.get('q')?.trim() || '';
  const lat = searchParams.get('lat') ? parseFloat(searchParams.get('lat')!) : null;
  const lng = searchParams.get('lng') ? parseFloat(searchParams.get('lng')!) : null;

  if (query.length < 2) {
    return NextResponse.json({ suggestions: [] });
  }

  // 1. Coba gunakan Google Places API (New) jika API Key ada
  if (GOOGLE_API_KEY) {
    try {
      const requestBody: any = {
        input: query,
        includedRegionCodes: ['id'],
        languageCode: 'id',
      };

      if (lat !== null && lng !== null && !isNaN(lat) && !isNaN(lng)) {
        requestBody.locationBias = {
          circle: {
            center: { latitude: lat, longitude: lng },
            radius: 50000.0,
          },
        };
      }

      const gResponse = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': GOOGLE_API_KEY,
        },
        body: JSON.stringify(requestBody),
      });

      if (gResponse.ok) {
        const gData = await gResponse.json();
        const suggestions = (gData.suggestions || []).map((s: any) => {
          const pred = s.placePrediction;
          if (!pred) return null;
          return {
            placeId: pred.placeId,
            displayName: pred.text?.text || '',
            title: pred.structuredFormat?.mainText?.text || pred.text?.text || '',
            subtitle: pred.structuredFormat?.secondaryText?.text || '',
            source: 'google',
          };
        }).filter(Boolean);

        if (suggestions.length > 0) {
          return NextResponse.json({ suggestions });
        }
      } else {
        const errText = await gResponse.text();
        console.warn('[Places API] Google Places returned non-200, falling back to OSM:', errText);
      }
    } catch (err) {
      console.warn('[Places API] Error calling Google Places API, falling back to OSM:', err);
    }
  }

  // 2. Seamless Fallback: OpenStreetMap Nominatim
  try {
    const osmUrl = new URL('https://nominatim.openstreetmap.org/search');
    osmUrl.searchParams.set('q', query);
    osmUrl.searchParams.set('format', 'json');
    osmUrl.searchParams.set('addressdetails', '1');
    osmUrl.searchParams.set('limit', '8');
    osmUrl.searchParams.set('countrycodes', 'id');

    const osmRes = await fetch(osmUrl.toString(), {
      headers: {
        'User-Agent': 'Syupeo-SaaS/1.0 (admin@syupeo.com)',
        'Accept': 'application/json',
      },
    });

    if (osmRes.ok) {
      const osmList: any[] = await osmRes.json();
      const suggestions = osmList.map((item) => {
        const parts = (item.display_name || '').split(',');
        const title = parts[0]?.trim() || item.display_name;
        const subtitle = parts.slice(1).join(',').trim();
        return {
          placeId: `osm_${item.place_id}`,
          displayName: item.display_name,
          title,
          subtitle,
          latitude: parseFloat(item.lat),
          longitude: parseFloat(item.lon),
          source: 'osm',
        };
      });

      return NextResponse.json({ suggestions });
    }
  } catch (osmErr) {
    console.error('[Places API] Fallback OSM also failed:', osmErr);
  }

  return NextResponse.json({ suggestions: [] });
}

