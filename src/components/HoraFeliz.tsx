export function HoraFeliz() {
  return (
    <section className="relative overflow-hidden bg-coral text-white">
      <div className="texture-hearts absolute inset-0 opacity-70" />
      <div className="relative mx-auto max-w-3xl px-5 py-20 text-center sm:py-24">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-white/80">
          Hora feliz
        </p>
        <h2 className="mt-4 font-display text-5xl leading-tight sm:text-6xl">
          3×2 en bebidas
          <br />
          <span className="italic text-accent">con café</span>
        </h2>
        <p className="mt-6 text-lg font-semibold">
          Lunes a viernes · 4:00 pm – 6:00 pm
        </p>
        <p className="mt-2 text-white/85">
          Aplica en bebidas con café. Aprovecha con quien más quieras.
        </p>
      </div>
    </section>
  );
}
