"use client";

import { useState, useEffect } from "react";
import Image from "next/image";

// Assets live in /public/img (see the Figma Make export). Served through
// next/image for AVIF/WebP conversion, responsive sizes, and lazy-loading.
const img = {
  logoHorizontal: "/img/logo-horizontal.png",
  logoVertical: "/img/logo-vertical.png",
  isotipo: "/img/isotipo.png",
  heroBrindis: "/img/hero-brindis.jpg",
  promoTresCafes: "/img/hero-promo-cafes.jpg",
  promoQR: "/img/hero-promo-qr.jpg",
  cafe: "/img/foto-cafe.jpg",
  chilaquiles: "/img/foto-chilaquiles.jpg",
  am: {
    chilaquiles: "/img/menu/am-000.jpg",
    avoToast: "/img/menu/am-002.jpg",
    wafflesMorandana: "/img/menu/am-008.jpg",
    bowlFruta: "/img/menu/am-014.jpg",
    frenchToast: "/img/menu/am-018.jpg",
  },
  pm: {
    enmoladas: "/img/menu/pm-002.jpg",
    sopa: "/img/menu/pm-004.jpg",
    comidaDia: "/img/menu/pm-006.jpg",
    crepas: "/img/menu/pm-008.jpg",
    panini: "/img/menu/pm-010.jpg",
  },
  beb: {
    dirtyChai: "/img/menu/beb-002.jpg",
    latte: "/img/menu/beb-004.jpg",
    matcha: "/img/menu/beb-006.jpg",
    jugoEnergia: "/img/menu/beb-008.jpg",
    tisana: "/img/menu/beb-tisana.jpg",
  },
};

const pdf = {
  am: "/img/pdf/menu-am.pdf",
  pm: "/img/pdf/menu-pm.pdf",
  bebidas: "/img/pdf/menu-bebidas.pdf",
};

type MenuItem = {
  name: string;
  desc: string;
  price: string;
  img: string | null;
  imgPosition?: string;
};
type Tab = "am" | "pm" | "bebidas";

const menuAM: MenuItem[] = [
  { name: "Chilaquiles Morandana", desc: "Totopo en salsa a elegir, frijoles negros, queso, crema, aguacate", price: "$150", img: img.am.chilaquiles },
  { name: "French Toast", desc: "Pan brioche con azúcar, canela y frutos rojos del bosque", price: "$160", img: img.am.frenchToast },
  { name: "Waffles Morandana", desc: "Tres waffles con huevo, aguacate, tocino crujiente y miel de maple", price: "$160", img: img.am.wafflesMorandana },
  { name: "Avo Toast", desc: "Masa madre, aguacate, pesto, huevo y queso parmesano", price: "$160", img: img.am.avoToast },
  { name: "Bowl de Fruta", desc: "Yogurt griego, fresa, moras, frambuesa, granola y miel de abeja", price: "$135", img: img.am.bowlFruta },
];

const menuPM: MenuItem[] = [
  { name: "Comida del Día", desc: "1 guiso + 2 guarniciones + agua fresca a elegir", price: "$190", img: img.pm.comidaDia },
  { name: "Sopa Morandana", desc: "Caldo de tomate, pollo, queso panela, aguacate y tiras de tortilla", price: "$145", img: img.pm.sopa },
  { name: "Enmoladas", desc: "Pollo en mole negro con ajonjolí y crema ácida", price: "$160", img: img.pm.enmoladas },
  { name: "Panini de Pollo", desc: "Pollo búfalo, queso, tomate, lechugas, mayonesa y papas fritas", price: "$185", img: img.pm.panini },
  { name: "Crepas", desc: "Nutella y fresas · Dulce de leche y plátano · Jamón y queso", price: "desde $90", img: img.pm.crepas },
];

const menuBebidas: MenuItem[] = [
  { name: "Matcha", desc: "Matcha japonés con leche cremosa, frío o caliente", price: "$67", img: img.beb.matcha, imgPosition: "top" },
  { name: "Latte", desc: "Espresso doble con leche vaporizada al gusto", price: "desde $66", img: img.beb.latte, imgPosition: "top" },
  { name: "Dirty Chai", desc: "Chai especiado con un shot de espresso", price: "$68", img: img.beb.dirtyChai, imgPosition: "top" },
  { name: "Jugos Cold Press", desc: "Verde · Rojo · Tropical · Energía — prensados en frío", price: "$68", img: img.beb.jugoEnergia, imgPosition: "top" },
  { name: "Tisana Frutos Rojos", desc: "Infusión de frutos del bosque, fría o caliente", price: "$70", img: img.beb.tisana, imgPosition: "top" },
];

const igGrid = [
  img.chilaquiles,
  img.heroBrindis,
  img.beb.matcha,
  img.cafe,
  img.pm.crepas,
  img.am.frenchToast,
];

// Full menu pages (rasterized from the PDFs) shown in the in-site viewer.
const fullMenu: Record<Tab, string[]> = {
  am: ["/img/menu-full/am-1.jpg", "/img/menu-full/am-2.jpg"],
  pm: ["/img/menu-full/pm-1.jpg", "/img/menu-full/pm-2.jpg"],
  bebidas: ["/img/menu-full/beb-1.jpg", "/img/menu-full/beb-2.jpg"],
};

const tabLabel: Record<Tab, string> = { am: "A.M.", pm: "P.M.", bebidas: "Bebidas" };

function MenuCard({ item }: { item: MenuItem }) {
  return (
    <div className="flex-none w-64 rounded-2xl overflow-hidden bg-white" style={{ boxShadow: "0 2px 16px rgba(43,24,16,0.07)" }}>
      <div className="h-44 overflow-hidden bg-brand-blush flex items-center justify-center relative">
        {item.img ? (
          <Image src={item.img} alt={item.name} fill sizes="256px" className="object-cover" style={{ objectPosition: item.imgPosition ?? "center" }} />
        ) : (
          <Image src={img.isotipo} alt="" width={56} height={43} className="w-14 h-14 object-contain opacity-25" />
        )}
      </div>
      <div className="p-4">
        <h3 className="font-serif font-bold text-brand-dark text-[15px] leading-snug">{item.name}</h3>
        <p className="text-brand-dark/55 text-[13px] mt-1.5 leading-snug line-clamp-2">{item.desc}</p>
        <p className="text-brand-pink font-bold mt-3 font-serif text-lg">{item.price}</p>
      </div>
    </div>
  );
}

export default function Landing() {
  const [scrolled, setScrolled] = useState(false);
  const [activeTab, setActiveTab] = useState<Tab>("am");
  const [heroSlide, setHeroSlide] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);
  const TOTAL_SLIDES = 3;

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 60);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    const timer = setInterval(() => setHeroSlide((s) => (s + 1) % TOTAL_SLIDES), 4000);
    return () => clearInterval(timer);
  }, []);

  // Lock body scroll and enable Escape-to-close while the menu viewer is open.
  useEffect(() => {
    if (!menuOpen) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenuOpen(false);
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener("keydown", onKey);
    };
  }, [menuOpen]);

  const menuItems = activeTab === "am" ? menuAM : activeTab === "pm" ? menuPM : menuBebidas;
  const menuPdf = activeTab === "am" ? pdf.am : activeTab === "pm" ? pdf.pm : pdf.bebidas;

  return (
    <div className="min-h-screen bg-brand-cream text-brand-dark">

      {/* NAVBAR */}
      <nav
        className="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
        style={{ background: scrolled ? "rgba(255,250,248,0.96)" : "transparent", backdropFilter: scrolled ? "blur(8px)" : "none", boxShadow: scrolled ? "0 1px 0 rgba(43,24,16,0.06)" : "none" }}
      >
        <div className="max-w-lg mx-auto px-5 py-3.5 flex items-center justify-between">
          <Image
            src={img.logoHorizontal}
            alt="Morandana"
            width={362}
            height={100}
            priority
            className="h-7 w-auto object-contain"
            style={{ filter: !scrolled ? "brightness(0) invert(1)" : "none", transition: "filter 0.3s" }}
          />
          <a
            href="/qr"
            className="text-sm font-semibold px-4 py-2 rounded-full transition-all duration-200"
            style={{ background: scrolled ? "#ff97a2" : "rgba(255,255,255,0.2)", color: "white", backdropFilter: !scrolled ? "blur(4px)" : "none" }}
          >
            Pide aquí
          </a>
        </div>
      </nav>

      {/* HERO SLIDER */}
      <section className="relative min-h-screen overflow-hidden">

        {/* Slide 0 — Foto brindis */}
        <div className="absolute inset-0 flex flex-col justify-end transition-opacity duration-1000" style={{ opacity: heroSlide === 0 ? 1 : 0, pointerEvents: heroSlide === 0 ? "auto" : "none" }}>
          <Image src={img.heroBrindis} alt="Brindis Morandana" fill priority sizes="100vw" className="object-cover" />
          <div className="absolute inset-0" style={{ background: "linear-gradient(to bottom, rgba(0,0,0,0.15) 0%, rgba(0,0,0,0.02) 40%, rgba(43,24,16,0.72) 100%)" }} />
          <div className="relative px-6 pb-20 pt-32 max-w-lg mx-auto w-full">
            <p className="text-white/70 text-sm font-medium tracking-widest uppercase mb-3">Café &amp; Desayunos</p>
            <h1 className="font-serif font-bold text-white leading-[1.05]" style={{ fontSize: "clamp(2.8rem, 11vw, 4rem)" }}>
              El café<br />
              <em className="italic" style={{ color: "#f6dfa4" }}>de tus</em><br />
              mañanas.
            </h1>
            <p className="mt-4 text-white/75 text-base leading-relaxed max-w-xs">
              Desayunos, comidas y bebidas con mucho amor. Lunes a domingo desde las 7:30 am.
            </p>
            <div className="mt-7 flex items-center gap-3">
              <a href="#menu" className="inline-block bg-white text-brand-dark px-6 py-3 rounded-full font-semibold text-sm hover:bg-brand-cream transition-colors">Ver menú</a>
              <a href="https://www.instagram.com/morandanamx" target="_blank" rel="noopener noreferrer" className="inline-block text-white/80 text-sm font-semibold hover:text-white transition-colors">@morandanamx →</a>
            </div>
          </div>
        </div>

        {/* Slide 1 — Promo 3×2 */}
        <div className="absolute inset-0 flex flex-col justify-end transition-opacity duration-1000" style={{ opacity: heroSlide === 1 ? 1 : 0, pointerEvents: heroSlide === 1 ? "auto" : "none" }}>
          <Image src={img.promoTresCafes} alt="Tres cafés Morandana" fill sizes="100vw" className="object-cover" />
          <div className="absolute inset-0" style={{ background: "linear-gradient(to bottom, rgba(43,24,16,0.35) 0%, rgba(43,24,16,0.1) 35%, rgba(43,24,16,0.75) 100%)" }} />
          <div className="relative px-6 pb-20 pt-32 max-w-lg mx-auto w-full">
            <p className="text-white/70 text-sm font-medium tracking-widest uppercase mb-3">Promoción</p>
            <h1 className="font-serif font-bold text-white leading-[1.05]" style={{ fontSize: "clamp(2.8rem, 11vw, 4rem)" }}>
              3×2 en<br />bebidas<br />
              <em className="italic" style={{ color: "#f6dfa4" }}>con café</em>
            </h1>
            <p className="mt-4 text-white/90 text-base font-semibold">Lunes a viernes · 4:00 pm – 6:00 pm</p>
            <p className="mt-2 text-white/65 text-sm">Aplica en todas las bebidas con café. ¡Tráete a quien quieras!</p>
            <div className="mt-7">
              <a href="#menu" className="inline-block bg-brand-pink text-white px-6 py-3 rounded-full font-semibold text-sm hover:opacity-90 transition-opacity">Ver bebidas →</a>
            </div>
          </div>
        </div>

        {/* Slide 2 — Pide por QR */}
        <div className="absolute inset-0 flex flex-col justify-end transition-opacity duration-1000" style={{ opacity: heroSlide === 2 ? 1 : 0, pointerEvents: heroSlide === 2 ? "auto" : "none" }}>
          <Image src={img.promoQR} alt="Pedido desde la app de Morandana" fill sizes="100vw" className="object-cover object-center" />
          <div className="absolute inset-0" style={{ background: "linear-gradient(to bottom, rgba(43,24,16,0.3) 0%, rgba(43,24,16,0.05) 35%, rgba(43,24,16,0.75) 100%)" }} />
          <div className="relative px-6 pb-20 pt-32 max-w-lg mx-auto w-full">
            <p className="text-white/70 text-sm font-medium tracking-widest uppercase mb-3">Pide en línea</p>
            <h1 className="font-serif font-bold text-white leading-[1.05]" style={{ fontSize: "clamp(2.8rem, 11vw, 4rem)" }}>
              Pide desde<br />
              <em className="italic" style={{ color: "#f6dfa4" }}>tu lugar</em><br />
              con el QR
            </h1>
            <p className="mt-4 text-white/75 text-base leading-relaxed max-w-xs">Escanea, elige lo que se te antoje y… luego pasas directito a recoger.</p>
            <div className="mt-7">
              <a href="/qr" className="inline-block px-6 py-3 rounded-full font-semibold text-sm text-white transition-opacity hover:opacity-90" style={{ background: "#ff97a2" }}>Pide aquí →</a>
            </div>
          </div>
        </div>

        {/* Dots */}
        <div className="absolute bottom-7 left-0 right-0 flex justify-center gap-2 z-10">
          {Array.from({ length: TOTAL_SLIDES }).map((_, i) => (
            <button key={i} onClick={() => setHeroSlide(i)} aria-label={`Ir a la imagen ${i + 1}`} className="rounded-full transition-all duration-300" style={{ width: heroSlide === i ? "24px" : "8px", height: "8px", background: heroSlide === i ? "white" : "rgba(255,255,255,0.4)" }} />
          ))}
        </div>
      </section>

      {/* HORARIOS STRIP */}
      <section className="bg-brand-pink py-4 px-4">
        <div className="max-w-lg mx-auto flex flex-wrap items-center justify-center gap-x-6 gap-y-1 text-white font-semibold text-[13px] text-center">
          <span>Lun – Sáb &nbsp; 7:30 am – 7:00 pm</span>
          <span className="opacity-40 hidden sm:inline">·</span>
          <span>Domingo &nbsp; 7:30 am – 4:00 pm</span>
        </div>
      </section>

      {/* MENÚ */}
      <section id="menu" className="pt-16 pb-4 scroll-mt-16">
        <div className="px-6 max-w-lg mx-auto mb-7">
          <p className="text-brand-pink text-xs font-semibold uppercase tracking-[0.15em] mb-2">Lo que nos encanta</p>
          <h2 className="font-serif font-bold text-brand-dark" style={{ fontSize: "clamp(2rem, 8vw, 2.8rem)", lineHeight: 1.1 }}>Nuestra carta</h2>
        </div>

        {/* Tabs */}
        <div className="px-6 max-w-lg mx-auto mb-6">
          <div className="inline-flex gap-1.5 bg-brand-blush rounded-full p-1">
            {(["am", "pm", "bebidas"] as Tab[]).map((tab) => (
              <button key={tab} onClick={() => setActiveTab(tab)} className="px-4 py-1.5 rounded-full text-sm font-semibold transition-all duration-200" style={{ background: activeTab === tab ? "#ff97a2" : "transparent", color: activeTab === tab ? "white" : "rgba(43,24,16,0.5)" }}>
                {tab === "am" ? "A.M." : tab === "pm" ? "P.M." : "Bebidas"}
              </button>
            ))}
          </div>
        </div>

        {/* Cards horizontal scroll */}
        <div className="max-w-[900px] mx-auto overflow-x-auto scrollbar-hide">
          <div className="flex gap-4 snap-x snap-mandatory pl-6 pr-6 pb-8">
            {menuItems.map((item) => (
              <div key={item.name} className="snap-start">
                <MenuCard item={item} />
              </div>
            ))}
          </div>
        </div>

        <div className="px-6 max-w-[900px] mx-auto flex items-center justify-between mt-1">
          <p className="text-brand-dark/40 text-[11px]">Todos los precios incluyen IVA. Avísanos si tienes alguna alergia.</p>
          <button type="button" onClick={() => setMenuOpen(true)} className="text-brand-pink text-[13px] font-semibold hover:underline flex-none ml-4">Ver menú completo →</button>
        </div>
      </section>

      {/* PROMO BAND */}
      <section className="relative overflow-hidden py-16 px-6 mt-10" style={{ background: "#ff97a2" }}>
        <div className="absolute inset-0 pointer-events-none" style={{ backgroundImage: `url(${img.isotipo})`, backgroundRepeat: "repeat", backgroundSize: "72px 72px", opacity: 0.13 }} />
        <div className="relative max-w-lg mx-auto text-center">
          <p className="text-white/70 text-xs font-semibold uppercase tracking-[0.15em] mb-4">Hora feliz</p>
          <h2 className="font-serif font-bold text-white leading-[1.1]" style={{ fontSize: "clamp(2rem, 9vw, 3rem)" }}>
            3×2 en bebidas<br />
            <em className="italic" style={{ color: "#f6dfa4" }}>con café</em>
          </h2>
          <p className="mt-5 text-white font-semibold text-base">Lunes a viernes · 4:00 pm – 6:00 pm</p>
          <p className="mt-2 text-white/65 text-sm">Aplica en bebidas con café. Aprovecha con quien más quieras.</p>
        </div>
      </section>

      {/* EL LUGAR */}
      <section className="py-16 px-6 max-w-lg mx-auto">
        <div className="mb-8">
          <p className="text-brand-pink text-xs font-semibold uppercase tracking-[0.15em] mb-2">Ven y quédate</p>
          <h2 className="font-serif font-bold text-brand-dark leading-[1.1]" style={{ fontSize: "clamp(2rem, 8vw, 2.8rem)" }}>Un espacio<br />para quedarse.</h2>
          <p className="mt-5 text-brand-dark/65 text-[15px] leading-relaxed">Morandana es más que café. Es el lugar donde los desayunos se convierten en pláticas largas y las tardes se estiran sin querer.</p>
          <p className="mt-3 text-brand-dark/65 text-[15px] leading-relaxed">Un espacio cálido, bien iluminado y lleno de buena energía. Para trabajar, para salir con amigas, para celebrar lo cotidiano.</p>
        </div>
        <div className="relative rounded-3xl overflow-hidden" style={{ aspectRatio: "4/5" }}>
          <Image src={img.cafe} alt="Barista de Morandana con galleta y café" fill sizes="(max-width: 640px) 100vw, 512px" className="object-cover" />
        </div>
      </section>

      {/* QR SECTION */}
      <section className="mx-4 mb-4 rounded-3xl relative overflow-hidden py-16 px-8" style={{ background: "#f6dfa4" }}>
        <div className="absolute inset-0 pointer-events-none" style={{ backgroundImage: `url(${img.isotipo})`, backgroundRepeat: "repeat", backgroundSize: "96px 96px", opacity: 0.09 }} />
        <div className="relative max-w-lg mx-auto text-center">
          <Image src={img.isotipo} alt="" width={56} height={43} className="w-14 h-14 mx-auto mb-6 object-contain" style={{ opacity: 0.75 }} />
          <h2 className="font-serif font-bold text-brand-dark leading-[1.1]" style={{ fontSize: "clamp(1.8rem, 7vw, 2.4rem)" }}>Pide desde tu lugar<br />con nuestro QR</h2>
          <p className="mt-5 text-brand-dark/70 text-[15px] leading-relaxed">Escanea el código, elige lo que se te antoje y… luego pasas directito a recoger. Así de fácil.</p>
          <p className="mt-3 text-brand-dark/45 text-sm">También disponible desde el link en nuestra bio de Instagram.</p>
        </div>
      </section>

      {/* IG STRIP */}
      <section className="pt-14 pb-16 px-6 max-w-lg mx-auto">
        <div className="flex items-end justify-between mb-6">
          <div>
            <p className="text-brand-pink text-xs font-semibold uppercase tracking-[0.15em] mb-1">Síguenos</p>
            <h2 className="font-serif font-bold text-brand-dark text-2xl">@morandanamx</h2>
          </div>
          <a href="https://www.instagram.com/morandanamx" target="_blank" rel="noopener noreferrer" className="text-brand-dark/45 text-sm font-semibold hover:text-brand-pink transition-colors">Seguir →</a>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {igGrid.map((photo, i) => (
            <div key={i} className="relative overflow-hidden rounded-xl bg-brand-blush" style={{ aspectRatio: "1/1" }}>
              <Image src={photo} alt={`Morandana ${i + 1}`} fill sizes="(max-width: 640px) 33vw, 170px" className="object-cover hover:scale-105 transition-transform duration-500" />
            </div>
          ))}
        </div>
      </section>

      {/* FOOTER */}
      <footer style={{ background: "#2b1810" }} className="py-14 px-6">
        <div className="max-w-lg mx-auto">
          <div className="flex flex-col items-center mb-10">
            <Image src={img.logoVertical} alt="Morandana" width={334} height={182} className="h-28 w-auto object-contain" />
          </div>

          <div className="grid grid-cols-2 gap-8 text-sm mb-10">
            <div>
              <p className="font-serif font-bold text-brand-vanilla mb-3 text-base">Horarios</p>
              <p className="text-white/55 leading-relaxed">Lunes a Sábado<br />7:30 am – 7:00 pm</p>
              <p className="text-white/55 leading-relaxed mt-3">Domingo<br />7:30 am – 4:00 pm</p>
            </div>
            <div>
              <p className="font-serif font-bold text-brand-vanilla mb-3 text-base">Redes</p>
              <a href="https://www.instagram.com/morandanamx" target="_blank" rel="noopener noreferrer" className="text-white/55 hover:text-brand-pink transition-colors">Instagram<br />@morandanamx</a>
            </div>
          </div>

          <div className="pt-6 border-t flex items-center justify-between" style={{ borderColor: "rgba(255,255,255,0.08)" }}>
            <p className="text-white/30 text-xs">© 2026 Morandana. Todos los derechos reservados.</p>
            <Image src={img.isotipo} alt="" width={24} height={24} className="h-6 w-6 object-contain opacity-30" />
          </div>
        </div>
      </footer>

      {/* MENU VIEWER (lightbox) */}
      {menuOpen && (
        <div className="fixed inset-0 z-[60] flex flex-col bg-brand-dark/95 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label={`Menú ${tabLabel[activeTab]}`}>
          <header className="flex items-center justify-between gap-3 px-5 py-3.5 border-b border-white/10">
            <p className="font-serif font-bold text-white text-lg">
              Menú <span className="text-brand-vanilla">{tabLabel[activeTab]}</span>
            </p>
            <div className="flex items-center gap-2">
              <a
                href={menuPdf}
                target="_blank"
                rel="noopener noreferrer"
                className="text-white/85 text-sm font-semibold hover:text-white px-3 py-1.5 rounded-full border border-white/20 hover:border-white/40 transition-colors"
              >
                Descargar PDF
              </a>
              <button
                type="button"
                onClick={() => setMenuOpen(false)}
                aria-label="Cerrar"
                className="w-9 h-9 flex items-center justify-center rounded-full bg-white/10 text-white text-2xl leading-none hover:bg-white/20 transition-colors"
              >
                ×
              </button>
            </div>
          </header>
          <div className="flex-1 overflow-y-auto overscroll-contain px-4 py-4">
            <div className="mx-auto max-w-2xl space-y-4">
              {fullMenu[activeTab].map((src, i) => (
                <Image
                  key={src}
                  src={src}
                  alt={`Menú ${tabLabel[activeTab]} — página ${i + 1}`}
                  width={1275}
                  height={1650}
                  sizes="(max-width: 768px) 100vw, 672px"
                  priority={i === 0}
                  className="w-full h-auto rounded-xl bg-white shadow-2xl"
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
