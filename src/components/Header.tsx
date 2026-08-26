"use client";

import { useEffect, useState } from "react";
import { Logo } from "./Logo";

export function Header() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-colors duration-300 ${
        scrolled
          ? "bg-coral-soft/85 shadow-[0_1px_0_rgba(0,0,0,0.04)] backdrop-blur-md"
          : "bg-transparent"
      }`}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4 sm:px-8">
        <a href="#top" aria-label="Morandana — inicio">
          <Logo
            className={scrolled ? "text-coral" : "text-white"}
            wordmarkClassName={scrolled ? "text-ink" : "text-white"}
          />
        </a>
        <a
          href="#menu"
          className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
            scrolled
              ? "bg-coral text-white hover:bg-coral-deep"
              : "bg-white/90 text-coral hover:bg-white"
          }`}
        >
          Pide aquí
        </a>
      </div>
    </header>
  );
}
