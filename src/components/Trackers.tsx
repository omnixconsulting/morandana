"use client";

import Script from "next/script";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";
import { useConsent } from "@/lib/analytics";

// IDs públicos de tracking. Se configuran como variables de entorno en Vercel
// (Production). Si faltan, no se renderiza nada — cero impacto.
//   NEXT_PUBLIC_META_PIXEL_ID   → Meta/Facebook Pixel (solo dígitos)
//   NEXT_PUBLIC_GOOGLE_ADS_ID   → Google Ads / Google tag (AW-XXXXXXXXX o G-XXXX)
const META_PIXEL_ID = process.env.NEXT_PUBLIC_META_PIXEL_ID;
const GOOGLE_ADS_ID = process.env.NEXT_PUBLIC_GOOGLE_ADS_ID;

export default function Trackers() {
  const { consent } = useConsent();
  const granted = consent === "granted";
  const pathname = usePathname();
  const lastPath = useRef<string | null>(null);

  // La carga inicial ya dispara PageView desde cada script; aquí cubrimos las
  // navegaciones del App Router (SPA). lastPath evita el doble disparo cuando
  // el consentimiento se concede después del montaje.
  useEffect(() => {
    if (!granted) return;
    if (lastPath.current === null) {
      lastPath.current = pathname;
      return;
    }
    if (lastPath.current !== pathname) {
      lastPath.current = pathname;
      if (META_PIXEL_ID) window.fbq?.("track", "PageView");
      if (GOOGLE_ADS_ID) window.gtag?.("event", "page_view");
    }
  }, [pathname, granted]);

  if (!granted) return null;

  return (
    <>
      {META_PIXEL_ID && (
        <>
          <Script id="meta-pixel" strategy="afterInteractive">
            {`!function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;
n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;
t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,
document,'script','https://connect.facebook.net/en_US/fbevents.js');
fbq('init','${META_PIXEL_ID}');fbq('track','PageView');`}
          </Script>
          <noscript>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              height="1"
              width="1"
              style={{ display: "none" }}
              src={`https://www.facebook.com/tr?id=${META_PIXEL_ID}&ev=PageView&noscript=1`}
              alt=""
            />
          </noscript>
        </>
      )}

      {GOOGLE_ADS_ID && (
        <>
          <Script
            src={`https://www.googletagmanager.com/gtag/js?id=${GOOGLE_ADS_ID}`}
            strategy="afterInteractive"
          />
          <Script id="google-ads" strategy="afterInteractive">
            {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
gtag('js',new Date());gtag('config','${GOOGLE_ADS_ID}');`}
          </Script>
        </>
      )}
    </>
  );
}
