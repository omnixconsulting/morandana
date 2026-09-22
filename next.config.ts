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
// Y aquí hay algo que conviene decir de frente en vez de esconderlo: el sitio
// carga Google Tag Manager con un script EN LÍNEA, y GTM existe justamente para
// inyectar terceros decididos fuera del repo. Con `script-src 'self'` estricta,
// GTM va a reportar violaciones — eso es el dato, no un defecto de la política.
//
// El reporte funciona entonces como INVENTARIO: dice qué carga GTM de verdad en
// el navegador de un visitante, que hoy nadie sabe y que importa para LFPDPPP.
//
// Promover esta CSP a activa exige una decisión real: nonce para el script de
// GTM, o prescindir de GTM. Poner 'unsafe-inline' para que "pase" dejaría la
// CSP sin la única propiedad por la que vale la pena tenerla.
const CSP = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'self'",
  "script-src 'self' https://www.googletagmanager.com",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  // Feed e imágenes del menú vienen de Supabase Storage; el optimizador de Next
  // las sirve desde el propio origen, pero el fallback puede ir directo.
  "img-src 'self' data: blob: https:",
  "connect-src 'self' https://*.supabase.co https://www.googletagmanager.com https://*.google-analytics.com https://va.vercel-scripts.com",
  // Mapa de Google, QR de pickup y el iframe noscript de GTM.
  "frame-src https://maps.google.com https://www.google.com https://menuqr.ubtracker.com https://www.googletagmanager.com",
  "form-action 'self'",
  "upgrade-insecure-requests",
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
