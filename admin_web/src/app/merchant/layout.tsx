import MerchantShell from '@/components/merchant/MerchantShell';

export const metadata = {
  title: 'Portal Toko Retail | Syupeo',
  description: 'Portal Backoffice & Toko Retail Online Syupeo - Dari Stok Pertama Sampai ke Pelanggan',
};

export default function MerchantLayout({ children }: { children: React.ReactNode }) {
  return <MerchantShell>{children}</MerchantShell>;
}
