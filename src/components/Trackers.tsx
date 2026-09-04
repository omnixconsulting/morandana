"use client";

import Script from "next/script";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";
import { useConsent } from "@/lib/analytics";

// Contenedor de Google Tag Manager. Un solo ID; Meta Pixel, Google Ads, GA4,
// etc. se configuran DENTRO de GTM (sin tocar código). Se activa por env var
// pública en Vercel (Production): NEXT_PUBLIC_GTM_ID = GTM-XXXXXXX
// Es NEXT_PUBLIC_ → se hornea en build; requiere redeploy al cambiarla.
const GTM_ID = process.env.NEXT_PUBLIC_GTM_ID || "GTM-5G75G6WC";

export default function Trackers() {
  const { consent } = useConsent();
  const granted = consent === "granted";
  const pathname = usePathname();
  const lastPath = useRef<string | null>(null);

  // GTM dispara su vista inicial al cargar; aquí empujamos un page_view en las
  // navegaciones del App Router (SPA). lastPath evita el doble disparo cuando
  // el consentimiento se concede después del montaje.
  useEffect(() => {
    if (!granted || !GTM_ID) return;
    if (lastPath.current === null) {
      lastPath.current = pathname;
      return;
    }
    if (lastPath.current !== pathname) {
      lastPath.current = pathname;
      window.dataLayer = window.dataLayer || [];
      window.dataLayer.push({ event: "page_view", page_path: pathname });
    }
  }, [pathname, granted]);

  if (!granted || !GTM_ID) return null;

  return (
    <>
      <Script id="gtm" strategy="afterInteractive">
        {`(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','${GTM_ID}');`}
      </Script>
      <noscript>
        <iframe
          src={`https://www.googletagmanager.com/ns.html?id=${GTM_ID}`}
          height="0"
          width="0"
          style={{ display: "none", visibility: "hidden" }}
          title="Google Tag Manager"
        />
      </noscript>
    </>
  );
}
