"use client";

import { useEffect, useState } from "react";

// Consentimiento de cookies (Meta + Google) + helper de eventos.
// El consentimiento vive en localStorage; los componentes se sincronizan por
// un evento del window. Sin consentimiento, los scripts no cargan y track()
// es no-op (fbq/gtag no existen).

export type Consent = "granted" | "denied";
const KEY = "mrd_cookie_consent";
const EVENT = "mrd-consent-change";

declare global {
  interface Window {
    dataLayer?: unknown[];
  }
}

export function getConsent(): Consent | null {
  if (typeof window === "undefined") return null;
  try {
    const v = window.localStorage.getItem(KEY);
    return v === "granted" || v === "denied" ? v : null;
  } catch {
    return null;
  }
}

export function setConsent(c: Consent): void {
  try {
    window.localStorage.setItem(KEY, c);
  } catch {
    /* almacenamiento no disponible: seguimos, el estado en memoria basta */
  }
  window.dispatchEvent(new Event(EVENT));
}

// Hook: estado de consentimiento reactivo + acciones aceptar/rechazar.
export function useConsent() {
  const [consent, setC] = useState<Consent | null>(null);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    setC(getConsent());
    setReady(true);
    const handler = () => setC(getConsent());
    window.addEventListener(EVENT, handler);
    return () => window.removeEventListener(EVENT, handler);
  }, []);
  return {
    consent,
    ready,
    accept: () => setConsent("granted"),
    decline: () => setConsent("denied"),
  };
}

// Empuja un evento al dataLayer de GTM. Google Tag Manager (cargado tras el
// consentimiento) escucha estos eventos y dispara los tags configurados
// (Meta Pixel, Google Ads, GA4, …). Sin GTM, el push solo llena el array.
export function track(event: string, params?: Record<string, unknown>): void {
  if (typeof window === "undefined") return;
  try {
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({ event, ...params });
  } catch {
    /* nunca romper la navegación por un error de tracking */
  }
}
