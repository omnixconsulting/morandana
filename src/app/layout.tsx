import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import localFont from "next/font/local";
import { Analytics } from "@vercel/analytics/next";
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

export const metadata: Metadata = {
  title: "Morandana — El café de tus mañanas",
  description:
    "Café & desayunos en Morandana. Desayunos, comidas y bebidas con mucho amor. Lunes a domingo desde las 7:30 am.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${madeAvenue.variable} ${dmSans.variable} h-full antialiased`}
    >
      <body className="min-h-full bg-brand-cream font-sans text-brand-dark">
        {children}
        <Analytics />
      </body>
    </html>
  );
}
