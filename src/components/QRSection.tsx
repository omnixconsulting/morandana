import { LogoMark } from "./Logo";

/** Decorative faux-QR block — replace with the real ordering QR code. */
function QRPlaceholder() {
  return (
    <div className="rounded-2xl bg-white p-4 shadow-lg">
      <div
        className="h-40 w-40 rounded-lg"
        style={{
          backgroundColor: "#2a1b17",
          backgroundImage:
            "repeating-conic-gradient(#2a1b17 0% 25%, #ffffff 0% 50%)",
          backgroundSize: "16px 16px",
        }}
        aria-label="Código QR para ordenar"
        role="img"
      />
    </div>
  );
}

export function QRSection() {
  return (
    <section className="bg-cream-bg px-5 pb-20 sm:px-8">
      <div className="relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] bg-cream">
        <div className="texture-marks absolute inset-0 opacity-60" />
        <div className="relative flex flex-col items-center px-6 py-16 text-center sm:py-20">
          <LogoMark className="h-10 w-auto text-coral" />
          <h2 className="mt-6 max-w-xl font-display text-4xl leading-tight text-ink sm:text-5xl">
            Pide desde tu lugar
            <br />
            con nuestro QR
          </h2>
          <p className="mt-5 max-w-md text-ink/70">
            Escanea el código, elige lo que se te antoje y… luego pasas directo
            a recoger. Así de fácil.
          </p>
          <p className="mt-2 max-w-md text-ink/55">
            También disponible desde el link en nuestra bio de Instagram.
          </p>
          <div className="mt-8">
            <QRPlaceholder />
          </div>
        </div>
      </div>
    </section>
  );
}
