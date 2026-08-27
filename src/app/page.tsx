import Landing from "@/components/Landing";
import { getIgPosts } from "@/lib/ig";
import { getMenu } from "@/lib/menu";

// ISR: regenera la página (menú + feed de IG) cada 5 min sin necesidad de deploy.
export const revalidate = 300;

// Datos estructurados para SEO local (Google rich results / Maps).
const jsonLd = {
  "@context": "https://schema.org",
  "@type": "CafeOrCoffeeShop",
  name: "Morandana",
  description:
    "Café & desayunos en Monterrey. Desayunos, comidas y bebidas con mucho amor.",
  image: "https://www.morandana.com.mx/og.jpg",
  url: "https://www.morandana.com.mx",
  telephone: "+528119872608",
  priceRange: "$$",
  servesCuisine: ["Café", "Desayunos", "Comida"],
  address: {
    "@type": "PostalAddress",
    streetAddress: "Padre Mier 653, local 107",
    addressLocality: "Monterrey",
    addressRegion: "Nuevo León",
    postalCode: "64000",
    addressCountry: "MX",
  },
  geo: {
    "@type": "GeoCoordinates",
    latitude: 25.6707176,
    longitude: -100.3251116,
  },
  hasMap: "https://maps.app.goo.gl/dJ3bJ94CWrmuBi5u6",
  sameAs: ["https://www.instagram.com/morandanamx"],
  openingHoursSpecification: [
    {
      "@type": "OpeningHoursSpecification",
      dayOfWeek: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
      opens: "07:30",
      closes: "19:00",
    },
    {
      "@type": "OpeningHoursSpecification",
      dayOfWeek: "Sunday",
      opens: "07:30",
      closes: "16:00",
    },
  ],
};

export default async function Home() {
  const [igPosts, menu] = await Promise.all([getIgPosts(), getMenu()]);
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <Landing igPosts={igPosts ?? undefined} menu={menu ?? undefined} />
    </>
  );
}
