import type { Metadata, Viewport } from "next";
import { Archivo, Manrope } from "next/font/google";
import Script from "next/script";
import "./globals.css";
import { LangProvider } from "@/contexts/LangContext";

const archivo = Archivo({ subsets: ["latin"], variable: "--font-archivo", weight: ["400","700","900"] });
const manrope = Manrope({ subsets: ["latin"], variable: "--font-manrope" });

export const metadata: Metadata = {
  title: "Typerly",
  description: "Predict · Compete · Win",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Typerly",
  },
};

export const viewport: Viewport = {
  themeColor: "#F5C400",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pl" className={`${archivo.variable} ${manrope.variable}`}>
      <head>
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        {/* Google AdSense — weryfikacja + reklamy */}
        <meta name="google-adsense-account" content="ca-pub-5244367621175515" />
      </head>
      <body className="bg-[#0A0A0A] text-white min-h-screen font-manrope antialiased">
        <Script
          id="adsbygoogle-init"
          async
          strategy="afterInteractive"
          crossOrigin="anonymous"
          src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5244367621175515"
        />
        <LangProvider>{children}</LangProvider>
      </body>
    </html>
  );
}
