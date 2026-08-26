import type { Metadata } from "next";
import { Hanken_Grotesk } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";

// Display serif — MADE Avenue (PERSONAL USE license; purchase commercial
// license from MadeType before production launch).
const madeAvenue = localFont({
  src: "./fonts/MADEAvenue-Regular.otf",
  variable: "--font-display",
  display: "swap",
});

// Body / UI — Hanken Grotesk pairs a warm humanist grotesque with the serif.
const hanken = Hanken_Grotesk({
  variable: "--font-sans",
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
      className={`${madeAvenue.variable} ${hanken.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-cream-bg text-ink font-sans">
        {children}
      </body>
    </html>
  );
}
