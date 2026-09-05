"use client";

import { useState } from "react";
import { track } from "@/lib/analytics";

// Número de Morandana (lada país 52 + 10 dígitos, solo dígitos).
const WHATSAPP = {
  number: "528119872608",
  greeting: "¡Hola! 👋 ¿Te ayudamos con un pedido o una pregunta?",
  prefill: "¡Hola Morandana! Quisiera hacer una pregunta.",
};

const WA_GREEN = "#25D366";

function WhatsAppIcon({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" fill="currentColor" className={className} aria-hidden>
      <path d="M16.04 4c-6.63 0-12 5.37-12 12 0 2.11.55 4.17 1.6 5.99L4 28l6.18-1.62A11.9 11.9 0 0 0 16.04 28c6.63 0 12-5.37 12-12s-5.37-12-12-12Zm0 21.8c-1.86 0-3.68-.5-5.27-1.44l-.38-.22-3.67.96.98-3.58-.25-.37a9.76 9.76 0 0 1-1.5-5.15c0-5.4 4.4-9.8 9.8-9.8s9.8 4.4 9.8 9.8-4.4 9.8-9.8 9.8Zm5.38-7.34c-.29-.15-1.74-.86-2.01-.96-.27-.1-.47-.15-.66.15-.2.29-.76.96-.93 1.16-.17.2-.34.22-.63.07-.29-.15-1.24-.46-2.36-1.46-.87-.78-1.46-1.74-1.63-2.03-.17-.29-.02-.45.13-.6.13-.13.29-.34.44-.51.15-.17.2-.29.29-.49.1-.2.05-.37-.02-.51-.07-.15-.66-1.59-.9-2.18-.24-.57-.48-.49-.66-.5l-.56-.01c-.2 0-.51.07-.78.37-.27.29-1.02 1-1.02 2.43s1.05 2.82 1.19 3.02c.15.2 2.06 3.14 4.99 4.4.7.3 1.24.48 1.66.62.7.22 1.33.19 1.83.12.56-.08 1.74-.71 1.98-1.4.24-.68.24-1.27.17-1.4-.07-.13-.27-.2-.56-.34Z" />
    </svg>
  );
}

export function WhatsAppChat() {
  const [open, setOpen] = useState(false);
  const waLink = `https://wa.me/${WHATSAPP.number}?text=${encodeURIComponent(WHATSAPP.prefill)}`;

  return (
    <div className="fixed bottom-5 right-5 z-40 flex flex-col items-end gap-3">
      {/* Tarjeta de chat */}
      {open && (
        <div className="w-[min(20rem,calc(100vw-2.5rem))] overflow-hidden rounded-2xl bg-white shadow-2xl ring-1 ring-black/5">
          <div className="flex items-center gap-3 px-4 py-3" style={{ background: WA_GREEN }}>
            <span className="flex h-9 w-9 items-center justify-center rounded-full bg-white/20 text-white">
              <WhatsAppIcon className="h-5 w-5" />
            </span>
            <div className="flex-1 leading-tight text-white">
              <p className="font-serif font-bold">Morandana</p>
              <p className="text-[11px] text-white/85">Normalmente responde en minutos</p>
            </div>
            <button
              onClick={() => setOpen(false)}
              aria-label="Cerrar chat"
              className="flex h-7 w-7 items-center justify-center rounded-full text-white/90 hover:bg-white/20"
            >
              ×
            </button>
          </div>
          <div className="px-4 py-4" style={{ background: "#ECE5DD" }}>
            <div className="max-w-[85%] rounded-xl rounded-tl-sm bg-white px-3 py-2 text-sm text-brand-dark shadow-sm">
              {WHATSAPP.greeting}
            </div>
          </div>
          <div className="px-4 pb-4 pt-2 bg-white">
            <a
              href={waLink}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => track("ClicWhatsApp", { source: "chat_card" })}
              className="flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              style={{ background: WA_GREEN }}
            >
              <WhatsAppIcon className="h-5 w-5" />
              Abrir WhatsApp
            </a>
          </div>
        </div>
      )}

      {/* Botón flotante */}
      <button
        onClick={() => setOpen((o) => !o)}
        aria-label="Escríbenos por WhatsApp"
        aria-expanded={open}
        className="flex h-14 w-14 items-center justify-center rounded-full text-white shadow-lg transition-transform hover:scale-105 active:scale-95"
        style={{ background: WA_GREEN }}
      >
        <WhatsAppIcon className="h-8 w-8" />
      </button>
    </div>
  );
}
