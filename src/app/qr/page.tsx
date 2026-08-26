import type { Metadata } from "next";

const QR_URL = "https://menuqr.ubtracker.com/pickup.php?slug=morandana";

export const metadata: Metadata = {
  title: "Pide en Morandana",
};

export default function QRPage() {
  return (
    <div className="fixed inset-0 bg-brand-cream">
      <iframe
        src={QR_URL}
        title="Pide en Morandana"
        className="w-full h-full border-none"
        allow="payment"
      />
    </div>
  );
}
