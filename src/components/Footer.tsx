import { Logo, LogoMark } from "./Logo";

export function Footer() {
  return (
    <footer className="bg-espresso text-white/80">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:px-8">
        <div className="flex justify-center">
          <Logo
            className="text-coral"
            wordmarkClassName="text-coral text-2xl"
          />
        </div>

        <div className="mt-12 grid gap-10 sm:grid-cols-2">
          <div>
            <h3 className="font-display text-lg text-accent">Horarios</h3>
            <p className="mt-4 text-sm leading-relaxed">
              Lunes a Sábado
              <br />
              7:30 am – 7:00 pm
            </p>
            <p className="mt-4 text-sm leading-relaxed">
              Domingo
              <br />
              7:30 am – 4:00 pm
            </p>
          </div>
          <div>
            <h3 className="font-display text-lg text-accent">Redes</h3>
            <a
              href="https://instagram.com/morandanamx"
              target="_blank"
              rel="noopener noreferrer"
              className="mt-4 block text-sm hover:text-white"
            >
              Instagram
              <br />
              @morandanamx
            </a>
          </div>
        </div>

        <div className="mt-12 flex items-center justify-between border-t border-white/10 pt-6">
          <p className="text-xs text-white/50">
            © 2026 Morandana. Todos los derechos reservados.
          </p>
          <LogoMark className="h-5 w-auto text-coral/70" />
        </div>
      </div>
    </footer>
  );
}
