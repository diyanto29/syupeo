import Link from 'next/link';
import { Store, ArrowLeft } from 'lucide-react';

export default function NotFoundStore() {
  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4 text-center font-sans">
      <div className="bg-white max-w-md w-full rounded-3xl p-8 border border-slate-200/90 shadow-xl space-y-4">
        <div className="w-16 h-16 rounded-2xl bg-blue-50 text-[#0070fc] flex items-center justify-center mx-auto shadow-inner">
          <Store className="w-8 h-8" />
        </div>

        <div className="space-y-1">
          <h2 className="text-xl font-black text-slate-900 tracking-tight">
            Toko Tidak Ditemukan
          </h2>
          <p className="text-xs text-slate-500 leading-relaxed">
            Tautan toko online yang Anda tuju mungkin salah ketik atau pemilik toko belum mengatur tautan slug tokonya.
          </p>
        </div>

        <div className="pt-2">
          <Link
            href="https://syupeo.mudahkan.online"
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#0070fc] hover:bg-[#005ecc] text-white text-xs font-bold shadow-md transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Kembali ke Syupeo</span>
          </Link>
        </div>
      </div>
    </div>
  );
}

