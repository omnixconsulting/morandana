import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { HoursBar } from "@/components/HoursBar";
import { Menu } from "@/components/Menu";
import { HoraFeliz } from "@/components/HoraFeliz";
import { Espacio } from "@/components/Espacio";
import { QRSection } from "@/components/QRSection";
import { InstagramGrid } from "@/components/InstagramGrid";
import { Footer } from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Header />
      <main className="flex-1">
        <Hero />
        <HoursBar />
        <Menu />
        <HoraFeliz />
        <Espacio />
        <QRSection />
        <InstagramGrid />
      </main>
      <Footer />
    </>
  );
}
