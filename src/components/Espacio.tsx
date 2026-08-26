import { Photo } from "./Photo";

export function Espacio() {
  return (
    <section className="bg-cream-bg py-20 sm:py-28">
      <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 sm:px-8 md:grid-cols-2 md:gap-14">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.25em] text-coral">
            Ven y quédate
          </p>
          <h2 className="mt-3 font-display text-5xl leading-[1.05] text-ink sm:text-6xl">
            Un espacio
            <br />
            para quedarse.
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-muted">
            Morandana es más que café. Es el lugar donde los desayunos se
            convierten en pláticas largas y las tardes se estiran sin querer.
          </p>
          <p className="mt-4 max-w-md text-lg leading-relaxed text-muted">
            Un espacio cálido, bien iluminado y lleno de buena energía. Para
            trabajar, para salir con amigas, para celebrar lo cotidiano.
          </p>
        </div>
        <Photo
          label="Foto: cliente con cookie y café Morandana"
          from="#c9a2c4"
          to="#8f6f9e"
          className="aspect-[4/5] w-full"
        />
      </div>
    </section>
  );
}
