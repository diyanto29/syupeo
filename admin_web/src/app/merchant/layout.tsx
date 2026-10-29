import MerchantShell from '@/components/merchant/MerchantShell';

export const metadata = {
  title: 'Merchant Backoffice | Mangga POS',
  description: 'Portal Analitik & Manajemen Bisnis Pemilik Toko Mangga POS',
};

export default function MerchantLayout({ children }: { children: React.ReactNode }) {
  return <MerchantShell>{children}</MerchantShell>;
}
