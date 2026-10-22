import type { NextConfig } from "next";

// ---------------------------------------------------------------------------
// Cabeceras de seguridad
// ---------------------------------------------------------------------------
// El sitio es público y habla con Supabase por la llave `anon` del bundle, así
// que el navegador del visitante es la superficie. Estas cabeceras no dependen
// de RLS ni de la app: las emite el borde.
const CABECERAS_ABSOLUTAS = [
  // Un MIME mal adivinado convierte un archivo servido en script ejecutable.
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "X-Frame-Options", value: "SAMEORIGIN" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=(), usb=()" },
];

// CSP en Report-Only: MIDE, no bloquea.
//
// El sitio carga Google Tag Manager con un script EN LÍNEA, y GTM existe
// justamente para inyectar terceros decididos fuera del repo. Con
// `script-src 'self'` estricta, GTM reporta violaciones — eso era el dato, no un
// defecto de la política. El reporte funcionaba como INVENTARIO: decir qué carga
// GTM de verdad en el navegador de un visitante, que nadie sabía.
//
// EL INVENTARIO YA SE LEVANTÓ (21-oct-2026), MIDIENDO EN UN NAVEGADOR REAL
//
// Una carga de la portada, tras aceptar cookies, produjo ~20 violaciones. GTM
// resultó cargar GA4 (G-3108JWT196) y Google Ads (AW-11153340548), y esos dos
// hablan con seis hosts que esta lista no declaraba. Están abajo, cada uno con
// la ruta por la que se le vio.
//
// Y ese era el problema de dejarlos sin declarar: con veinte líneas conocidas en
// cada reporte, **un tercero NUEVO no se distingue**. Declarar lo ya medido
// convierte el inventario en un DETECTOR DE CAMBIOS, que es para lo que sirve de
// aquí en adelante: cualquier host que aparezca ahora es uno que nadie decidió.
//
// LO QUE SIGUE SIN PODERSE ACTIVAR, Y POR QUÉ
//
// `script-src` se queda en report-only. Las únicas violaciones que deben quedar
// son los scripts EN LÍNEA —cuatro por carga: los de arranque de Next y el de
// GTM— y para permitirlos sin `'unsafe-inline'` hacen falta nonce o hash:
//
//   - **nonce**: lo genera un proxy por petición, y un nonce no se puede cachear,
//     así que **vuelve dinámicas todas las rutas que cubra**. En un sitio de
//     marketing que vive de cargar rápido, y que ya tuvo trabajo de LCP móvil,
//     ese precio es mayor que lo que compra.
//   - **hash**: el del script de GTM es estable, pero los de arranque de Next
//     cambian en cada build.
//   - `'unsafe-inline'` dejaría la CSP sin la única propiedad por la que vale la
//     pena tenerla.
//
// **El siguiente paso, cuando el reporte salga limpio:** partir en dos cabeceras
// —una ACTIVA con todo salvo `script-src`, y esta en report-only con la política
// completa—. `object-src 'none'`, `base-uri`, `frame-ancestors` y `form-action`
// bloquean clases de ataque reales y no tienen nada que ver con GTM. No se hace
// en el mismo cambio: primero se comprueba en vivo que la lista de abajo está
// completa.
const CSP = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'self'",
  // `googleads.g.doubleclick.net` sirve el script de conversión de Google Ads:
  // medido el 21-oct en /pagead/viewthroughconversion/11153340548/.
  "script-src 'self' https://www.googletagmanager.com https://googleads.g.doubleclick.net",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  // Feed e imágenes del menú vienen de Supabase Storage; el optimizador de Next
  // las sirve desde el propio origen, pero el fallback puede ir directo.
  "img-src 'self' data: blob: https:",
  // Los cuatro hosts de Google se agregaron el 21-oct-2026 con la ruta por la
  // que se les vio. `analytics.google.com` NO lo cubre `*.google-analytics.com`:
  // es otro dominio, no un subdominio.
  //   www.google.com          /ccm/collect y /rmkt/collect  (Ads)
  //   analytics.google.com    /g/collect                    (GA4)
  //   ad.doubleclick.net      /ccm/s/collect                (Ads)
  //   stats.g.doubleclick.net /g/collect                    (GA4)
  "connect-src 'self' https://*.supabase.co https://www.googletagmanager.com https://*.google-analytics.com https://analytics.google.com https://www.google.com https://ad.doubleclick.net https://stats.g.doubleclick.net https://va.vercel-scripts.com",
  // Mapa de Google y el iframe noscript de GTM.
  "frame-src https://maps.google.com https://www.google.com https://www.googletagmanager.com",
  "form-action 'self'",
  // SIN `upgrade-insecure-requests`: en una política report-only **se ignora**, y
  // el navegador lo dice con un error en consola en cada carga —medido—. Lo que
  // esa directiva compraría ya lo da el `Strict-Transport-Security` que Vercel
  // emite (max-age de dos años, includeSubDomains, preload). Vuelve el día que
  // haya una cabecera activa.
].join("; ");

const nextConfig: NextConfig = {
  images: {
    // Prefer modern formats; the optimizer serves AVIF/WebP with fallback.
    formats: ["image/avif", "image/webp"],
    // Permite optimizar imágenes del feed subidas a Supabase Storage.
    remotePatterns: [
      {
        protocol: "https",
        hostname: "*.supabase.co",
        pathname: "/storage/v1/object/public/**",
      },
    ],
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          ...CABECERAS_ABSOLUTAS,
          { key: "Content-Security-Policy-Report-Only", value: CSP },
        ],
      },
    ];
  },
};

export default nextConfig;
