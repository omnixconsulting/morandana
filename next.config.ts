import type { NextConfig } from "next";

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
};

export default nextConfig;
