import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Prefer modern formats; the optimizer serves AVIF/WebP with fallback.
    formats: ["image/avif", "image/webp"],
  },
};

export default nextConfig;
