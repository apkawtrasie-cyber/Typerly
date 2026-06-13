import type { Metadata, Viewport } from "next";
import { Archivo, Manrope } from "next/font/google";
import "./globals.css";
import { LangProvider } from "@/contexts/LangContext";

const archivo = Archivo({ subsets: ["latin"], variable: "--font-archivo", weight: ["400","700","900"] });
const manrope = Manrope({ subsets: ["latin"], variable: "--font-manrope" });

export const metadata: Metadata = {
  title: "Typerly",
  description: "Typuj · Rywalizuj · Wygrywaj",
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
      </head>
      <body className="bg-[#0A0A0A] text-white min-h-screen font-manrope antialiased">
        <LangProvider>{children}</LangProvider>
      </body>
    </html>
  );
}
