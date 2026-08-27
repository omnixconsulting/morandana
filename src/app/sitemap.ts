import type { MetadataRoute } from "next";

const BASE = "https://www.morandana.com.mx";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: BASE, lastModified: new Date(), changeFrequency: "weekly", priority: 1 },
    { url: `${BASE}/qr`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.6 },
  ];
}
