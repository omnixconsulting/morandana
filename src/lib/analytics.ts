"use client";

import { useSyncExternalStore } from "react";

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

function subscribe(onChange: () => void): () => void {
  window.addEventListener(EVENT, onChange);
  return () => window.removeEventListener(EVENT, onChange);
}

// El "ready" no tiene suscripción: solo distingue el render del servidor
// —donde no hay localStorage— del primero del navegador.
const noSubscribe = () => () => {};

// Hook: estado de consentimiento reactivo + acciones aceptar/rechazar.
// El consentimiento vive fuera de React (localStorage + un evento del window),
// así que se lee con useSyncExternalStore y no dentro de un efecto: leerlo en
// un efecto provoca un render en cascada y deja el banner parpadeando entre la
// hidratación y la primera lectura.
export function useConsent() {
  const consent = useSyncExternalStore(subscribe, getConsent, () => null);
  const ready = useSyncExternalStore(noSubscribe, () => true, () => false);
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
