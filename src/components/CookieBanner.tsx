"use client";

import { useConsent } from "@/lib/analytics";

export default function CookieBanner() {
  const { consent, ready, accept, decline } = useConsent();

  // No mostrar hasta leer localStorage, ni si ya hay una decisión.
  if (!ready || consent !== null) return null;

  return (
    <div
      role="dialog"
      aria-label="Aviso de cookies"
      aria-live="polite"
      className="fixed inset-x-0 bottom-0 z-[100] p-4 sm:p-5"
    >
      <div className="mx-auto max-w-lg rounded-2xl bg-white shadow-xl ring-1 ring-brand-dark/10 p-4 sm:p-5">
        <p className="text-sm text-brand-dark/80 leading-relaxed">
          Usamos cookies para medir el tráfico y mejorar tu experiencia con
          herramientas de Meta y Google. Puedes aceptarlas o rechazarlas.
        </p>
        <div className="mt-4 flex items-center justify-end gap-2">
          <button
            type="button"
            onClick={decline}
            className="px-4 py-2 rounded-full text-sm font-semibold text-brand-dark/70 hover:bg-brand-dark/5 transition-colors"
          >
            Rechazar
          </button>
          <button
            type="button"
            onClick={accept}
            className="px-5 py-2 rounded-full text-sm font-semibold text-white bg-brand-pink hover:opacity-90 transition-opacity"
          >
            Aceptar
          </button>
        </div>
      </div>
    </div>
  );
}
