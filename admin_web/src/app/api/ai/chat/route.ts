import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

const CANDIDATE_MODELS = [
  'gemini-3.8-flash',
  'gemini-3.5-flash',
  'gemini-3-flash-preview',
];

export async function POST(req: NextRequest) {
  try {
    // 1. Validasi Autentikasi Sesi (Hanya pengguna login yang boleh menggunakan API AI)
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: 'Akses ditolak: Silakan login terlebih dahulu untuk menggunakan fitur AI.' },
        { status: 401 }
      );
    }

    const body = await req.json();
    const { systemPrompt, history = [], message, apiKey } = body;

    if (!message || typeof message !== 'string') {
      return NextResponse.json(
        { error: 'Pesan pertanyaan tidak boleh kosong' },
        { status: 400 }
      );
    }

    const key = apiKey?.trim() || process.env.GEMINI_API_KEY;

    if (!key) {
      return NextResponse.json(
        { error: 'GEMINI_API_KEY belum dikonfigurasi di server.' },
        { status: 500 }
      );
    }

    // Build Gemini contents payload
    const contents: any[] = [];

    // History turns
    if (Array.isArray(history)) {
      for (const item of history) {
        const role = item.role === 'user' ? 'user' : 'model';
        const text = item.text?.trim() || '';
        if (text) {
          contents.push({
            role,
            parts: [{ text }],
          });
        }
      }
    }

    // Current user message
    contents.push({
      role: 'user',
      parts: [{ text: message.trim() }],
    });

    let lastError = '';

    for (const model of CANDIDATE_MODELS) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;

        const payload: any = {
          contents,
          generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 2048,
          },
        };

        if (systemPrompt && typeof systemPrompt === 'string') {
          payload.systemInstruction = {
            parts: [{ text: systemPrompt }],
          };
        }

        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(payload),
        });

        if (!res.ok) {
          const errText = await res.text();
          lastError = `Model ${model} gagal: ${res.status} - ${errText}`;
          console.warn(`[Gemini API] Failed on model ${model}:`, errText);
          continue; // Try next model
        }

        const data = await res.json();
        const candidate = data.candidates?.[0];
        const replyText =
          candidate?.content?.parts?.[0]?.text ||
          'Maaf, tidak dapat menghasilkan jawaban saat ini.';

        return NextResponse.json({
          reply: replyText,
          modelUsed: model,
        });
      } catch (err: any) {
        lastError = err.message || String(err);
        console.warn(`[Gemini API] Exception on model ${model}:`, err);
      }
    }

    return NextResponse.json(
      {
        error: `Gagal memanggil AI model: ${lastError}`,
      },
      { status: 500 }
    );
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || 'Internal Server Error' },
      { status: 500 }
    );
  }
}
