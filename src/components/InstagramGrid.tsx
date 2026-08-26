import { Photo } from "./Photo";

const POSTS = [
  { label: "Chilaquiles con chorizo", from: "#d7b17a", to: "#a9763f" },
  { label: "Brindis con vasos rosas", from: "#f2949c", to: "#e05f73" },
  { label: "Matcha helado", from: "#aecb8a", to: "#6f9a4c" },
  { label: "Cliente con café", from: "#c9a2c4", to: "#8f6f9e" },
  { label: "French toast con miel", from: "#e9b06a", to: "#c47f3d" },
  { label: "Waffles con frutos rojos", from: "#eda093", to: "#d16b62" },
];

export function InstagramGrid() {
  return (
    <section className="bg-cream-bg py-16 sm:py-20">
      <div className="mx-auto max-w-6xl px-5 sm:px-8">
        <div className="flex items-end justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.25em] text-coral">
              Síguenos
            </p>
            <h2 className="mt-2 font-display text-4xl text-ink sm:text-5xl">
              @morandanamx
            </h2>
          </div>
          <a
            href="https://instagram.com/morandanamx"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm font-semibold text-muted hover:text-coral"
          >
            Seguir →
          </a>
        </div>

        <div className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4">
          {POSTS.map((p) => (
            <a
              key={p.label}
              href="https://instagram.com/morandanamx"
              target="_blank"
              rel="noopener noreferrer"
              className="group"
            >
              <Photo
                from={p.from}
                to={p.to}
                rounded="rounded-2xl"
                className="aspect-square w-full transition group-hover:brightness-105"
              />
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
