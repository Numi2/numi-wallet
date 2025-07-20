import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { WalletProvider } from "@/context/WalletContext";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "NumiCoin - The People's Coin",
  description: "Easy to mine, fair to earn. Mine NumiCoin with your device's computational power.",
  manifest: "/manifest.json",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.className} dark`} style={{ 
        background: 'linear-gradient(135deg, rgba(15, 15, 35, 0.8) 0%, rgba(26, 26, 46, 0.9) 100%), url("/dong-zhang-ILYVeUgPkmI-unsplash.jpg") no-repeat center center fixed',
        backgroundSize: 'cover',
        backgroundAttachment: 'fixed',
        minHeight: '100vh',
        color: 'white'
      }}>
        <WalletProvider>
          {children}
        </WalletProvider>
      </body>
    </html>
  );
}
