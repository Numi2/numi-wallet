import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { WalletProvider } from "@/context/WalletContext";
import { PWAInstall } from "@/components/PWAInstall";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Numi Wallet - Secure Cryptocurrency Wallet",
  description: "A beautiful, secure, and modern cryptocurrency wallet built with Next.js and ethers.js. Send, receive, and manage your ETH with ease.",
  keywords: "cryptocurrency, wallet, ethereum, ETH, blockchain, secure, modern",
  authors: [{ name: "Numi Wallet Team" }],
  openGraph: {
    title: "Numi Wallet - Secure Cryptocurrency Wallet",
    description: "A beautiful, secure, and modern cryptocurrency wallet built with Next.js and ethers.js.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Numi Wallet - Secure Cryptocurrency Wallet",
    description: "A beautiful, secure, and modern cryptocurrency wallet built with Next.js and ethers.js.",
  },
  manifest: "/manifest.json",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#3B82F6",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased h-full liquid-bg bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900`}
      >
        <WalletProvider>
          {children}
        </WalletProvider>
        <PWAInstall />
      </body>
    </html>
  );
}
