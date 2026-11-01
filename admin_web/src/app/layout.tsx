import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Syupeo - Super Admin Portal & Supply Chain Hub',
  description: 'Control center for retail supply chain, business catalog, accounts, and system configuration for Syupeo',
  icons: {
    icon: [
      { url: '/syupeo-icon.svg', type: 'image/svg+xml' },
      { url: '/logo.png', type: 'image/png' },
      { url: '/favicon.ico' },
    ],
    shortcut: '/syupeo-icon.svg',
    apple: '/syupeo-icon.svg',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="font-sans min-h-screen bg-[#F8FAFC] text-[#1a1a1a] antialiased">
        {children}
      </body>
    </html>
  );
}
