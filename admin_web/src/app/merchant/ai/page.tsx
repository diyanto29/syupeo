'use client';

import { useState, useEffect, useRef } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { useMerchant } from '@/components/merchant/MerchantShell';
import { createClient } from '@/lib/supabase/client';
import {
  Sparkles,
  Send,
  Mic,
  MicOff,
  Volume2,
  VolumeX,
  RefreshCw,
  TrendingUp,
  AlertTriangle,
  Package,
  Clock,
  DollarSign,
  Copy,
  Check,
  Bot,
  User,
  Zap,
  ShoppingBag,
} from 'lucide-react';

interface ChatMessage {
  id: string;
  role: 'user' | 'model';
  content: string;
  timestamp: string;
  isSpoken?: boolean;
}

interface AnalyticsSnapshot {
  todayRevenue: number;
  todayOrders: number;
  todayItemsSold: number;
  todayNetProfit: number;
  monthlyRevenue: number;
  lowStockCount: number;
  criticalItems: Array<{ name: string; stock: number; daysLeft: number }>;
  peakHours: string;
  topProducts: string;
  paymentMethods: string;
}

export default function AiBusinessCopilotPage() {
  const { business, selectedOutletId, loading: merchantLoading } = useMerchant();

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Voice States
  const [isListening, setIsListening] = useState(false);
  const [ttsEnabled, setTtsEnabled] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [speakingMessageId, setSpeakingMessageId] = useState<string | null>(null);

  // Analytics Context
  const [analytics, setAnalytics] = useState<AnalyticsSnapshot | null>(null);
  const [analyticsLoading, setAnalyticsLoading] = useState(true);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const recognitionRef = useRef<any>(null);

  // Scroll to bottom
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isLoading]);

  // Load Business Analytics Data for AI Context
  useEffect(() => {
    if (!business) return;
    loadDeepAnalytics();
  }, [business, selectedOutletId]);

  // Initial welcome message
  useEffect(() => {
    if (messages.length === 0 && business) {
      const welcome: ChatMessage = {
        id: 'welcome-1',
        role: 'model',
        content: `Halo, **Owner ${business.name}**! 👋 Saya **AI Business Copilot Mangga POS** siap membantu Anda menganalisis performa toko, memprediksi stok habis, hingga merancang strategi promo yang terbukti menghasilkan omzet.\n\nAnda bisa mengetik atau menekan tombol **Mikrofon 🎙️** untuk bertanya langsung. Fitur suara otomatis menyala agar Anda bisa mendengarkan analisis sambil mengerjakan hal lain.`,
        timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages([welcome]);
    }
  }, [business]);

  const loadDeepAnalytics = async () => {
    if (!business) return;
    setAnalyticsLoading(true);

    try {
      const supabase = createClient();
      const now = new Date();
      const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

      // Query Orders Today
      let todayQuery = supabase
        .from('orders')
        .select('*')
        .eq('business_id', business.id)
        .gte('created_at', startOfToday);

      if (selectedOutletId && selectedOutletId !== 'all') {
        todayQuery = todayQuery.eq('outlet_id', selectedOutletId);
      }

      const { data: todayOrders } = await todayQuery;

      // Query Orders Month
      let monthQuery = supabase
        .from('orders')
        .select('total_amount, final_amount')
        .eq('business_id', business.id)
        .gte('created_at', startOfMonth);

      if (selectedOutletId && selectedOutletId !== 'all') {
        monthQuery = monthQuery.eq('outlet_id', selectedOutletId);
      }

      const { data: monthOrders } = await monthQuery;

      // Query Orders 7 Days for Burn Rate & Peak Hours
      let weekQuery = supabase
        .from('orders')
        .select('created_at, total_amount, order_items(name, quantity, unit_price)')
        .eq('business_id', business.id)
        .gte('created_at', sevenDaysAgo);

      if (selectedOutletId && selectedOutletId !== 'all') {
        weekQuery = weekQuery.eq('outlet_id', selectedOutletId);
      }

      const { data: weekOrders } = await weekQuery;

      // Query Menu Items & Inventory
      const { data: menuItems } = await supabase
        .from('menu_items')
        .select('id, name, price, cost, stock_quantity, is_active')
        .eq('business_id', business.id)
        .eq('is_active', true);

      // 1. Calculate Today Sales
      let todayRev = 0;
      let todayItems = 0;
      const paymentCount: Record<string, number> = {};
      const productSalesToday: Record<string, number> = {};

      (todayOrders || []).forEach((ord: any) => {
        todayRev += Number(ord.final_amount ?? ord.total_amount ?? 0);
        const method = ord.payment_method || 'Lainnya';
        paymentCount[method] = (paymentCount[method] || 0) + 1;
      });

      // 2. Monthly Revenue
      let monthRev = 0;
      (monthOrders || []).forEach((ord: any) => {
        monthRev += Number(ord.final_amount ?? ord.total_amount ?? 0);
      });

      // 3. Burn Rate Calculation (Daily sales velocity per item over 7 days)
      const itemDailyVelocity: Record<string, number> = {};
      const hourlyDistribution: Record<number, number> = {};

      (weekOrders || []).forEach((ord: any) => {
        const orderHour = new Date(ord.created_at).getHours();
        hourlyDistribution[orderHour] = (hourlyDistribution[orderHour] || 0) + 1;

        if (Array.isArray(ord.order_items)) {
          ord.order_items.forEach((item: any) => {
            const name = item.name;
            const qty = Number(item.quantity || 1);
            todayItems += qty;
            itemDailyVelocity[name] = (itemDailyVelocity[name] || 0) + qty;
            productSalesToday[name] = (productSalesToday[name] || 0) + qty;
          });
        }
      });

      // Identify Peak Hours
      const sortedHours = Object.entries(hourlyDistribution)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([h, count]) => `Pukul ${h}:00 (${count} pesanan)`)
        .join(', ');

      // Critical Stock Burn Rate
      const criticalList: Array<{ name: string; stock: number; daysLeft: number }> = [];
      let lowCount = 0;

      (menuItems || []).forEach((item: any) => {
        const stock = Number(item.stock_quantity ?? 999);
        if (stock < 15) lowCount++;

        const weeklyQty = itemDailyVelocity[item.name] || 0;
        const avgDailySales = weeklyQty > 0 ? weeklyQty / 7 : 0.5;
        const daysLeft = avgDailySales > 0 ? Math.round(stock / avgDailySales) : 99;

        if (stock <= 20 && daysLeft <= 5) {
          criticalList.push({
            name: item.name,
            stock,
            daysLeft: Math.max(daysLeft, 1),
          });
        }
      });

      criticalList.sort((a, b) => a.daysLeft - b.daysLeft);

      // Top Products Today/Week
      const topList = Object.entries(productSalesToday)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([n, q]) => `${n} (${q} terjual)`)
        .join(', ');

      const paymentStr = Object.entries(paymentCount)
        .map(([m, c]) => `${m}: ${c} transaksi`)
        .join(', ');

      setAnalytics({
        todayRevenue: todayRev,
        todayOrders: (todayOrders || []).length,
        todayItemsSold: todayItems,
        todayNetProfit: Math.round(todayRev * 0.35), // Perkiraan rata-rata profit margin 35%
        monthlyRevenue: monthRev,
        lowStockCount: lowCount,
        criticalItems: criticalList.slice(0, 6),
        peakHours: sortedHours || 'Pukul 12:00 - 14:00 & 18:00 - 20:00',
        topProducts: topList || 'Belum ada data produk terjual hari ini',
        paymentMethods: paymentStr || 'Belum ada transaksi hari ini',
      });
    } catch (err) {
      console.error('Error loading deep analytics:', err);
    } finally {
      setAnalyticsLoading(false);
    }
  };

  // Text-To-Speech Clean Text (Strips markdown formatting)
  const cleanMarkdownForVoice = (text: string) => {
    return text
      .replace(/\*\*(.*?)\*\*/g, '$1') // Bold
      .replace(/\*(.*?)\*/g, '$1') // Italic
      .replace(/#{1,6}\s?/g, '') // Headings
      .replace(/`{1,3}[^`]*`{1,3}/g, '') // Code
      .replace(/\[(.*?)\]\(.*?\)/g, '$1') // Links
      .replace(/[•\-\*]\s/g, ', ') // Bullet points to pause
      .replace(/\n+/g, '. ') // Newlines to sentences
      .trim();
  };

  const speakText = (text: string, msgId?: string) => {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;

    window.speechSynthesis.cancel(); // Stop any ongoing speech

    if (!text.trim()) return;

    const clean = cleanMarkdownForVoice(text);
    const utterance = new SpeechSynthesisUtterance(clean);
    utterance.lang = 'id-ID';
    utterance.rate = 1.05; // Slightly faster for natural feel
    utterance.pitch = 1.0;

    // Pick best Indonesian voice if available
    const voices = window.speechSynthesis.getVoices();
    const indoVoice = voices.find((v) => v.lang.includes('id') || v.lang.includes('ID'));
    if (indoVoice) utterance.voice = indoVoice;

    utterance.onstart = () => {
      setIsSpeaking(true);
      if (msgId) setSpeakingMessageId(msgId);
    };

    utterance.onend = () => {
      setIsSpeaking(false);
      setSpeakingMessageId(null);
    };

    utterance.onerror = () => {
      setIsSpeaking(false);
      setSpeakingMessageId(null);
    };

    window.speechSynthesis.speak(utterance);
  };

  const stopSpeaking = () => {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      setIsSpeaking(false);
      setSpeakingMessageId(null);
    }
  };

  // Web Speech Recognition (Mic Input)
  const toggleListening = () => {
    if (typeof window === 'undefined') return;

    const SpeechRecognition =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

    if (!SpeechRecognition) {
      alert('Browser Anda belum mendukung input suara Web Speech API. Silakan gunakan Google Chrome atau Edge.');
      return;
    }

    if (isListening) {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      setIsListening(false);
      return;
    }

    try {
      const recognition = new SpeechRecognition();
      recognition.lang = 'id-ID';
      recognition.continuous = false;
      recognition.interimResults = true;

      recognition.onstart = () => {
        setIsListening(true);
      };

      recognition.onresult = (event: any) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          transcript += event.results[i][0].transcript;
        }
        setInputText(transcript);
      };

      recognition.onerror = (event: any) => {
        console.error('Speech recognition error:', event.error);
        setIsListening(false);
      };

      recognition.onend = () => {
        setIsListening(false);
      };

      recognitionRef.current = recognition;
      recognition.start();
    } catch (err) {
      console.error('Failed to start speech recognition:', err);
      setIsListening(false);
    }
  };

  // Send Message to Gemini
  const handleSendMessage = async (textToSend?: string) => {
    const text = (textToSend || inputText).trim();
    if (!text || isLoading) return;

    if (isSpeaking) stopSpeaking();

    const userMsg: ChatMessage = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: text,
      timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputText('');
    setIsLoading(true);

    try {
      const currency = new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        maximumFractionDigits: 0,
      });

      const snap = analytics;
      const criticalStocksStr =
        snap?.criticalItems && snap.criticalItems.length > 0
          ? snap.criticalItems
              .map(
                (c) =>
                  `- ${c.name}: Sisa ${c.stock} unit (Prediksi habis dalam ${c.daysLeft} hari berdasarkan kecepatan penjualan)`
              )
              .join('\n')
          : 'Semua stok produk saat ini dalam batas aman.';

      const systemPrompt = `
Kamu adalah "AI Business Copilot Mangga POS", asisten eksekutif & konsultan analitik bisnis toko untuk Owner "${business?.name || 'Toko'}".
Outlet Terpilih: ${selectedOutletId === 'all' ? 'Semua Cabang' : 'Outlet Aktif'}

DATA PERFORMA BISNIS REAL-TIME (DARI DATABASE SUPABASE):
- Omzet Hari Ini: ${currency.format(snap?.todayRevenue || 0)}
- Total Transaksi Hari Ini: ${snap?.todayOrders || 0} transaksi
- Estimasi Laba Bersih Hari Ini (Gross-Expenses): ${currency.format(snap?.todayNetProfit || 0)}
- Total Omzet Bulan Ini: ${currency.format(snap?.monthlyRevenue || 0)}
- Jam Tersibuk (Peak Hours): ${snap?.peakHours}
- Produk Terlaris Hari Ini: ${snap?.topProducts}
- Metode Pembayaran: ${snap?.paymentMethods}
- Peringatan Stok Menipis & Prediksi Habis (Burn Rate):
${criticalStocksStr}

PANDUAN PERILAKU & ANALISIS BISNIS:
1. Jawab dengan gaya profesional, ramah, percaya diri, dan berorientasi pada profitabilitas bisnis dalam Bahasa Indonesia yang lugas.
2. PREDIKSI STOK: Jika ditanya mengenai stok atau persediaan, gunakan data burn rate di atas dan berikan estimasi hari kehabisan stok serta rekomendasi kapan harus belanja/kulak.
3. STRATEGI HARGA & PROMO BUNDLING: Gunakan prinsip menu engineering. Pasangkan produk terlaris dengan produk yang marginnya tinggi untuk meningkatkan Average Order Value (AOV).
4. ANALISIS JAM SEPI: Manfaatkan data jam sibuk untuk merekomendasikan promo Happy Hour pada jam-jam sepi toko.
5. FORMAT TAMPILAN BERSIH & RAPI:
   - JANGAN MENUMPUK SIMBOL MARKDOWN seperti "### **Judul**" atau "* **Poin:**". Cukup gunakan judul bersih (misal: "### 1. Nama Paket") dan poin rapi (misal: "- Konsep: ..." atau penomoran 1, 2, 3).
   - HINDARI penggunaan garis pemisah "---" berulang-ulang yang mengotori layar.
   - Di awal jawaban, berikan rangkuman 1 kalimat singkat yang enak didengar jika dibacakan via suara (voice).
`;

      const historyPayload = messages
        .filter((m) => m.id !== 'welcome-1')
        .slice(-8)
        .map((m) => ({
          role: m.role,
          text: m.content,
        }));

      const res = await fetch('/api/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemPrompt,
          history: historyPayload,
          message: text,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.error || 'Gagal memanggil model AI');
      }

      const botReply = data.reply;
      const modelMsg: ChatMessage = {
        id: `model-${Date.now()}`,
        role: 'model',
        content: botReply,
        timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages((prev) => [...prev, modelMsg]);

      // Voice Output if enabled
      if (ttsEnabled) {
        speakText(botReply, modelMsg.id);
      }
    } catch (err: any) {
      const errorMsg: ChatMessage = {
        id: `err-${Date.now()}`,
        role: 'model',
        content: `Mohon maaf, terjadi kendala saat memproses jawaban: ${err.message}. Silakan coba lagi.`,
        timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages((prev) => [...prev, errorMsg]);
    } finally {
      setIsLoading(false);
    }
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const clearChat = () => {
    if (isSpeaking) stopSpeaking();
    setMessages([
      {
        id: 'welcome-reset',
        role: 'model',
        content: `Percakapan telah direset. Ada yang bisa saya bantu analisa untuk bisnis **${business?.name}** hari ini?`,
        timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      },
    ]);
  };

  // Quick Action Prompts
  const quickPrompts = [
    {
      label: 'Analisis Margin & Omzet',
      icon: TrendingUp,
      prompt: 'Bagaimana analisis performa omzet dan estimasi laba toko saya hari ini? Apakah ada potensi kebocoran margin?',
    },
    {
      label: 'Prediksi Stok Habis (Burn Rate)',
      icon: AlertTriangle,
      prompt: 'Produk apa yang stoknya paling kritis dan diprediksi habis dalam 1-3 hari ke depan? Berapa perkiraan yang harus saya kulak?',
    },
    {
      label: 'Rekomendasi Bundling Promo',
      icon: Zap,
      prompt: 'Buatkan 3 ide promo bundling pintar yang menggabungkan produk terlaris dengan produk margin tinggi untuk menaikkan nilai belanja keranjang (AOV).',
    },
    {
      label: 'Analisis Jam Sibuk & Happy Hour',
      icon: Clock,
      prompt: 'Kapan jam tersibuk dan jam paling sepi toko saya? Berikan rekomendasi promo diskon Happy Hour yang tepat untuk jam sepi tersebut.',
    },
  ];

  const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(val);
  };

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)] max-w-7xl mx-auto p-4 md:p-6 space-y-4">
      {/* Top Header Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 bg-white p-4 rounded-2xl border border-slate-200/80 shadow-xs">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-500 to-amber-400 flex items-center justify-center text-white shadow-md shadow-orange-500/20">
            <Sparkles className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base font-black text-slate-900 tracking-tight">
                AI Business Copilot
              </h1>
              <span className="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-orange-100 text-orange-700 border border-orange-200">
                Live Analytics
              </span>
            </div>
            <p className="text-xs text-slate-500 font-medium">
              Konsultan pintar berbasis data riil dari outlet{' '}
              <strong className="text-slate-800">{business?.name || 'Toko'}</strong>
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          {/* TTS Toggle */}
          <button
            onClick={() => {
              if (isSpeaking) stopSpeaking();
              setTtsEnabled(!ttsEnabled);
            }}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all border ${
              ttsEnabled
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                : 'bg-slate-50 text-slate-500 border-slate-200 hover:bg-slate-100'
            }`}
            title={ttsEnabled ? 'Suara Balasan Aktif' : 'Suara Balasan Mati'}
          >
            {ttsEnabled ? (
              <>
                <Volume2 className="w-4 h-4 text-emerald-600" />
                <span>Suara Aktif</span>
              </>
            ) : (
              <>
                <VolumeX className="w-4 h-4 text-slate-400" />
                <span>Mute</span>
              </>
            )}
          </button>

          {/* Refresh Data */}
          <button
            onClick={loadDeepAnalytics}
            disabled={analyticsLoading}
            className="p-2 text-slate-500 hover:text-slate-800 hover:bg-slate-100 rounded-xl border border-slate-200 transition-colors"
            title="Sinkron Ulang Data Toko"
          >
            <RefreshCw className={`w-4 h-4 ${analyticsLoading ? 'animate-spin text-orange-500' : ''}`} />
          </button>

          {/* Reset Chat */}
          <button
            onClick={clearChat}
            className="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:text-red-600 hover:bg-red-50 rounded-xl border border-slate-200 transition-colors"
          >
            Bersihkan Chat
          </button>
        </div>
      </div>

      {/* Snapshot Analytics Bar */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="bg-white p-3.5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-orange-50 border border-orange-100 flex items-center justify-center text-orange-600 flex-shrink-0">
            <DollarSign className="w-4 h-4" />
          </div>
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">
              Omzet Hari Ini
            </span>
            <span className="text-sm font-black text-slate-900 truncate block">
              {analyticsLoading ? '...' : formatCurrency(analytics?.todayRevenue || 0)}
            </span>
          </div>
        </div>

        <div className="bg-white p-3.5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-600 flex-shrink-0">
            <ShoppingBag className="w-4 h-4" />
          </div>
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">
              Pesanan Hari Ini
            </span>
            <span className="text-sm font-black text-slate-900 truncate block">
              {analyticsLoading ? '...' : `${analytics?.todayOrders || 0} Transaksi`}
            </span>
          </div>
        </div>

        <div className="bg-white p-3.5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-emerald-600 flex-shrink-0">
            <TrendingUp className="w-4 h-4" />
          </div>
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">
              Est. Laba Bersih
            </span>
            <span className="text-sm font-black text-slate-900 truncate block">
              {analyticsLoading ? '...' : formatCurrency(analytics?.todayNetProfit || 0)}
            </span>
          </div>
        </div>

        <div className="bg-white p-3.5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-rose-50 border border-rose-100 flex items-center justify-center text-rose-600 flex-shrink-0">
            <AlertTriangle className="w-4 h-4" />
          </div>
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">
              Stok Kritis
            </span>
            <span className="text-sm font-black text-rose-600 truncate block">
              {analyticsLoading ? '...' : `${analytics?.criticalItems.length || 0} Item Kritis`}
            </span>
          </div>
        </div>
      </div>

      {/* Main Chat Box Container */}
      <div className="flex-1 bg-white rounded-2xl border border-slate-200/80 shadow-xs flex flex-col overflow-hidden">
        {/* Messages Scroll Area */}
        <div className="flex-1 overflow-y-auto p-4 md:p-6 space-y-5">
          {messages.map((msg) => {
            const isUser = msg.role === 'user';
            const isThisSpeaking = isSpeaking && speakingMessageId === msg.id;

            return (
              <div
                key={msg.id}
                className={`flex gap-3 max-w-3xl ${isUser ? 'ml-auto flex-row-reverse' : ''}`}
              >
                {/* Avatar */}
                <div
                  className={`w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 ${
                    isUser
                      ? 'bg-slate-900 text-white'
                      : 'bg-gradient-to-tr from-orange-500 to-amber-400 text-white shadow-xs'
                  }`}
                >
                  {isUser ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
                </div>

                {/* Bubble Container */}
                <div className={`space-y-1.5 ${isUser ? 'items-end' : 'items-start'}`}>
                  <div
                    className={`p-4 rounded-2xl text-xs leading-relaxed ${
                      isUser
                        ? 'bg-orange-500 text-white font-medium rounded-tr-xs shadow-xs whitespace-pre-wrap'
                        : 'bg-slate-50 border border-slate-200/80 text-slate-800 font-normal rounded-tl-xs shadow-xs'
                    }`}
                  >
                    {isUser ? (
                      msg.content
                    ) : (
                      <ReactMarkdown
                        remarkPlugins={[remarkGfm]}
                        components={{
                          h1: ({ children }: any) => (
                            <h1 className="text-sm font-black text-slate-900 mt-2.5 mb-1.5 border-b border-slate-200 pb-1">
                              {children}
                            </h1>
                          ),
                          h2: ({ children }: any) => (
                            <h2 className="text-xs font-black text-slate-900 mt-2.5 mb-1">
                              {children}
                            </h2>
                          ),
                          h3: ({ children }: any) => (
                            <h3 className="text-xs font-bold text-orange-600 mt-2 mb-1">
                              {children}
                            </h3>
                          ),
                          p: ({ children }: any) => (
                            <p className="mb-2 last:mb-0 leading-relaxed text-slate-800">
                              {children}
                            </p>
                          ),
                          ul: ({ children }: any) => (
                            <ul className="space-y-1 mb-2.5 list-disc pl-4 text-slate-700">
                              {children}
                            </ul>
                          ),
                          ol: ({ children }: any) => (
                            <ol className="space-y-1 mb-2.5 list-decimal pl-4 text-slate-700">
                              {children}
                            </ol>
                          ),
                          li: ({ children }: any) => (
                            <li className="leading-relaxed">{children}</li>
                          ),
                          strong: ({ children }: any) => (
                            <strong className="font-bold text-slate-900">{children}</strong>
                          ),
                          hr: () => <hr className="my-2.5 border-slate-200" />,
                          blockquote: ({ children }: any) => (
                            <blockquote className="border-l-2 border-orange-500 pl-3 my-2 text-slate-600 italic bg-orange-50/40 py-1 rounded-r-lg">
                              {children}
                            </blockquote>
                          ),
                          table: ({ children }: any) => (
                            <div className="overflow-x-auto my-2 rounded-xl border border-slate-200 bg-white shadow-xs">
                              <table className="w-full text-left text-[11px] divide-y divide-slate-200">
                                {children}
                              </table>
                            </div>
                          ),
                          th: ({ children }: any) => (
                            <th className="bg-slate-100 p-2 font-bold text-slate-700">
                              {children}
                            </th>
                          ),
                          td: ({ children }: any) => (
                            <td className="p-2 border-t border-slate-100 text-slate-700">
                              {children}
                            </td>
                          ),
                        }}
                      >
                        {msg.content}
                      </ReactMarkdown>
                    )}
                  </div>

                  {/* Bubble Actions */}
                  <div className={`flex items-center gap-2 px-1 text-[10px] text-slate-400 ${isUser ? 'justify-end' : 'justify-start'}`}>
                    <span>{msg.timestamp}</span>

                    {!isUser && (
                      <>
                        <span>•</span>
                        {/* Audio Speak Button */}
                        <button
                          onClick={() => {
                            if (isThisSpeaking) {
                              stopSpeaking();
                            } else {
                              speakText(msg.content, msg.id);
                            }
                          }}
                          className={`flex items-center gap-1 font-bold transition-colors ${
                            isThisSpeaking
                              ? 'text-orange-600 hover:text-orange-700'
                              : 'text-slate-500 hover:text-slate-800'
                          }`}
                          title={isThisSpeaking ? 'Hentikan Suara' : 'Dengarkan Jawaban'}
                        >
                          {isThisSpeaking ? (
                            <>
                              <VolumeX className="w-3 h-3 text-orange-600" />
                              <span className="text-orange-600 animate-pulse">Berhenti</span>
                            </>
                          ) : (
                            <>
                              <Volume2 className="w-3 h-3" />
                              <span>Putar Suara</span>
                            </>
                          )}
                        </button>

                        <span>•</span>
                        {/* Copy Button */}
                        <button
                          onClick={() => copyToClipboard(msg.content, msg.id)}
                          className="flex items-center gap-1 text-slate-500 hover:text-slate-800 transition-colors font-medium"
                          title="Salin Teks"
                        >
                          {copiedId === msg.id ? (
                            <>
                              <Check className="w-3 h-3 text-emerald-600" />
                              <span className="text-emerald-600">Tersalin</span>
                            </>
                          ) : (
                            <>
                              <Copy className="w-3 h-3" />
                              <span>Salin</span>
                            </>
                          )}
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            );
          })}

          {/* Loading Indicator */}
          {isLoading && (
            <div className="flex gap-3 max-w-2xl">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-orange-500 to-amber-400 text-white flex items-center justify-center flex-shrink-0 animate-bounce">
                <Sparkles className="w-4 h-4" />
              </div>
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/80 rounded-tl-xs flex items-center gap-2.5">
                <div className="w-2 h-2 rounded-full bg-orange-500 animate-pulse" />
                <div className="w-2 h-2 rounded-full bg-orange-500 animate-pulse delay-100" />
                <div className="w-2 h-2 rounded-full bg-orange-500 animate-pulse delay-200" />
                <span className="text-xs text-slate-500 font-medium ml-1">
                  Menganalisis data transaksi & stok...
                </span>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Quick Action Chips */}
        <div className="p-3 border-t border-slate-100 bg-slate-50/60 overflow-x-auto flex gap-2">
          {quickPrompts.map((q, idx) => {
            const Icon = q.icon;
            return (
              <button
                key={idx}
                disabled={isLoading}
                onClick={() => handleSendMessage(q.prompt)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-white border border-slate-200 hover:border-orange-300 hover:bg-orange-50/50 rounded-xl text-xs font-semibold text-slate-700 whitespace-nowrap transition-all shadow-xs flex-shrink-0 disabled:opacity-50"
              >
                <Icon className="w-3.5 h-3.5 text-orange-500" />
                <span>{q.label}</span>
              </button>
            );
          })}
        </div>

        {/* Input Bar */}
        <div className="p-3 md:p-4 border-t border-slate-200/80 bg-white">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSendMessage();
            }}
            className="flex items-center gap-2"
          >
            {/* Voice Input Button */}
            <button
              type="button"
              onClick={toggleListening}
              className={`p-2.5 rounded-xl border transition-all flex items-center justify-center ${
                isListening
                  ? 'bg-rose-500 text-white border-rose-600 shadow-md shadow-rose-500/30 animate-pulse'
                  : 'bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200'
              }`}
              title={isListening ? 'Sedang merekam suara... Klik untuk berhenti' : 'Bicara dengan Suara (Mic)'}
            >
              {isListening ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
            </button>

            {/* Text Input */}
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder={
                isListening
                  ? 'Mendengarkan suara Anda...'
                  : 'Tanyakan apa saja tentang omzet, stok habis, promo...'
              }
              disabled={isLoading}
              className="flex-1 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 transition-all font-medium"
            />

            {/* Send Button */}
            <button
              type="submit"
              disabled={isLoading || !inputText.trim()}
              className="px-4 py-2.5 bg-orange-500 hover:bg-orange-600 text-white rounded-xl text-xs font-bold transition-all shadow-sm shadow-orange-500/20 disabled:opacity-50 disabled:pointer-events-none flex items-center gap-1.5"
            >
              <Send className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Kirim</span>
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
