'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function HardwarePackagesRedirect() {
  const router = useRouter();

  useEffect(() => {
    router.replace('/dashboard/starter-kits');
  }, [router]);

  return (
    <div className="min-h-[300px] flex items-center justify-center text-sm text-slate-500">
      Mengalihkan ke Paket Usaha Retail Syupeo...
    </div>
  );
}
