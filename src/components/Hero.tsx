"use client";

import { useEffect, useState } from "react";
import { Photo } from "./Photo";

const SLIDES = [
  { label: "Foto: vasos de café Morandana", from: "#f6939b", to: "#e85f74" },
  { label: "Foto: barra y desayunos", from: "#f4a58a", to: "#e56f6a" },
  { label: "Foto: manos brindando con café", from: "#f59aa6", to: "#e76178" },
];

export function Hero() {
  const [active, setActive] = useState(0);

  useEffect(() => {
    const id = setInterval(
      () => setActive((i) => (i + 1) % SLIDES.length),
      5000,
    );
    return () => clearInterval(id);
  }, []);

  return (
    <section id="top" className="relative min-h-[92vh] w-full overflow-hidden">
      {/* Slides */}
      {SLIDES.map((s, i) => (
        <Photo
          key={i}
          from={s.from}
          to={s.to}
          rounded="rounded-none"
          className={`absolute inset-0 transition-opacity duration-1000 ${
            i === active ? "opacity-100" : "opacity-0"
          }`}
        />
      ))}
      {/* readability scrim */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/45 via-black/10 to-black/20" />

      {/* Content */}
      <div className="relative mx-auto flex min-h-[92vh] max-w-6xl flex-col justify-end px-5 pb-20 pt-32 sm:px-8">
        <p className="mb-4 text-sm font-semibold uppercase tracking-[0.25em] text-white/85">
          Café &amp; Desayunos
        </p>
        <h1 className="font-display text-6xl leading-[0.95] text-white sm:text-7xl md:text-8xl">
          El café
          <br />
          <span className="italic text-accent">de tus</span>
          <br />
          mañanas.
        </h1>
        <p className="mt-6 max-w-md text-lg text-white/90">
          Desayunos, comidas y bebidas con mucho amor. Lunes a domingo desde las
          7:30 am.
        </p>
        <div className="mt-8 flex flex-wrap items-center gap-4">
          <a
            href="#menu"
            className="rounded-full bg-white px-7 py-3 font-semibold text-ink transition hover:bg-white/90"
          >
            Ver menú
          </a>
          <a
            href="https://instagram.com/morandanamx"
            target="_blank"
            rel="noopener noreferrer"
            className="font-medium text-white/90 transition hover:text-white"
          >
            @morandanamx →
          </a>
        </div>

        {/* Carousel dots */}
        <div className="mt-10 flex items-center gap-2">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              onClick={() => setActive(i)}
              aria-label={`Ir a la imagen ${i + 1}`}
              className={`h-2 rounded-full transition-all ${
                i === active ? "w-8 bg-white" : "w-2 bg-white/50 hover:bg-white/70"
              }`}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
