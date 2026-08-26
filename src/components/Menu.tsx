"use client";

import { useState } from "react";
import { Photo } from "./Photo";

type Item = {
  name: string;
  desc: string;
  price: string;
  from: string;
  to: string;
};

const MENU: Record<string, Item[]> = {
  "A.M.": [
    {
      name: "Chilaquiles Morandana",
      desc: "Totopo en salsa a elegir, frijoles negros, queso, crema, aguacate.",
      price: "$150",
      from: "#e7b36a",
      to: "#c67b3e",
    },
    {
      name: "French Toast",
      desc: "Pan brioche con azúcar, canela y frutos rojos del bosque.",
      price: "$160",
      from: "#f0a89a",
      to: "#d76a63",
    },
    {
      name: "Waffles Morandana",
      desc: "Tres waffles con huevo, aguacate, tocino crujiente y miel de maple.",
      price: "$160",
      from: "#e9c07a",
      to: "#c98a4a",
    },
    {
      name: "Avo Toast",
      desc: "Pan de masa madre, aguacate, huevo pochado y queso feta.",
      price: "$165",
      from: "#bcc98a",
      to: "#7f9a4f",
    },
  ],
  "P.M.": [
    {
      name: "Sándwich Morandana",
      desc: "Pan artesanal, pollo, aguacate, tocino y aderezo de la casa.",
      price: "$170",
      from: "#e9b884",
      to: "#c07f4a",
    },
    {
      name: "Ensalada de la casa",
      desc: "Mezcla verde, fresa, nuez, queso de cabra y vinagreta.",
      price: "$155",
      from: "#c3cf8c",
      to: "#84a052",
    },
    {
      name: "Panini caprese",
      desc: "Jitomate, mozzarella fresca, pesto y reducción balsámica.",
      price: "$150",
      from: "#eeae94",
      to: "#cf6f5f",
    },
    {
      name: "Bowl de temporada",
      desc: "Base de arroz, vegetales asados y proteína a elegir.",
      price: "$175",
      from: "#e6bd78",
      to: "#bd8340",
    },
  ],
  Bebidas: [
    {
      name: "Latte de la casa",
      desc: "Espresso doble, leche sedosa y un toque de vainilla.",
      price: "$75",
      from: "#d9b48c",
      to: "#a9764a",
    },
    {
      name: "Matcha helado",
      desc: "Matcha ceremonial, leche de tu elección y mucho hielo.",
      price: "$85",
      from: "#aecb8a",
      to: "#6f9a4c",
    },
    {
      name: "Cold brew",
      desc: "Doce horas de extracción en frío, suave y aromático.",
      price: "$70",
      from: "#b98a63",
      to: "#7c4f30",
    },
    {
      name: "Chai caliente",
      desc: "Especias de la casa, leche vaporizada y una cucharada de miel.",
      price: "$75",
      from: "#e0ad7c",
      to: "#b97a45",
    },
  ],
};

const TABS = Object.keys(MENU);

export function Menu() {
  const [tab, setTab] = useState(TABS[0]);

  return (
    <section id="menu" className="scroll-mt-24 bg-cream-bg py-20 sm:py-28">
      <div className="mx-auto max-w-6xl px-5 sm:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.25em] text-coral">
          Lo que nos encanta
        </p>
        <h2 className="mt-3 font-display text-5xl text-ink sm:text-6xl">
          Nuestra carta
        </h2>

        {/* Tabs */}
        <div className="mt-8 inline-flex rounded-full bg-coral-soft p-1">
          {TABS.map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`rounded-full px-6 py-2 text-sm font-semibold transition ${
                tab === t
                  ? "bg-coral text-white shadow-sm"
                  : "text-coral/80 hover:text-coral"
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* Cards carousel */}
      <div className="no-scrollbar mt-10 flex snap-x snap-mandatory gap-6 overflow-x-auto px-5 pb-2 sm:px-8">
        <div className="hidden sm:block sm:w-[max(0px,calc((100%-72rem)/2))] sm:shrink-0" />
        {MENU[tab].map((item) => (
          <article
            key={item.name}
            className="w-[280px] shrink-0 snap-start"
          >
            <Photo
              from={item.from}
              to={item.to}
              rounded="rounded-2xl"
              className="aspect-[4/3] w-full"
            />
            <h3 className="mt-4 font-display text-xl text-ink">{item.name}</h3>
            <p className="mt-1 text-sm leading-relaxed text-muted">
              {item.desc}
            </p>
            <p className="mt-3 font-display text-lg text-coral">{item.price}</p>
          </article>
        ))}
        <div className="w-1 shrink-0 sm:w-[max(0px,calc((100%-72rem)/2))]" />
      </div>

      <div className="mx-auto mt-8 flex max-w-6xl flex-col gap-2 px-5 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <p className="text-sm text-muted">
          Todos los precios incluyen IVA. Avísanos si tienes alguna alergia.
        </p>
        <a
          href="#menu"
          className="text-sm font-semibold text-coral hover:text-coral-deep"
        >
          Ver menú completo →
        </a>
      </div>
    </section>
  );
}
