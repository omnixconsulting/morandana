import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import localFont from "next/font/local";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import Trackers from "@/components/Trackers";
import "./globals.css";

// Display serif — MADE Avenue (PERSONAL USE license; purchase commercial
// license from MadeType before production launch). Adapted onto the page in
// place of the design's original Playfair Display.
const madeAvenue = localFont({
  src: "./fonts/MADEAvenue-Regular.otf",
  variable: "--font-made",
  display: "swap",
});

// Body / UI — DM Sans, the sans the design was built around.
const dmSans = DM_Sans({
  variable: "--font-dm",
  subsets: ["latin"],
  display: "swap",
});

const SITE_DESC =
  "Café & desayunos en Morandana, Monterrey. Desayunos, comidas y bebidas con mucho amor. Lunes a domingo desde las 7:30 am.";

export const metadata: Metadata = {
  metadataBase: new URL("https://www.morandana.com.mx"),
  title: "Morandana — El café de tus mañanas",
  description: SITE_DESC,
  applicationName: "Morandana",
  alternates: { canonical: "/" },
  keywords: [
    "café Monterrey",
    "desayunos Monterrey",
    "Morandana",
    "café y desayunos",
    "brunch Monterrey",
    "Centro Monterrey",
  ],
  openGraph: {
    type: "website",
    locale: "es_MX",
    url: "/",
    siteName: "Morandana",
    title: "Morandana — El café de tus mañanas",
    description: SITE_DESC,
    images: [
      { url: "/og.jpg", width: 1200, height: 630, alt: "Morandana — Café & Desayunos" },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Morandana — El café de tus mañanas",
    description: SITE_DESC,
    images: ["/og.jpg"],
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${madeAvenue.variable} ${dmSans.variable} h-full antialiased`}
    >
      <body className="min-h-full bg-brand-cream font-sans text-brand-dark">
        {children}
        <Trackers />
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
