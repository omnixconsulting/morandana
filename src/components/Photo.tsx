import type { ReactNode } from "react";

type PhotoProps = {
  /** Short caption of what real photo goes here (client photography pending). */
  label?: string;
  className?: string;
  /** CSS gradient stops for the branded placeholder fill. */
  from?: string;
  to?: string;
  rounded?: string;
  children?: ReactNode;
};

/**
 * Branded image placeholder. Real Morandana photography is pending from the
 * client — every instance is a swap-in point for a <next/image>. Keeping the
 * label makes it obvious in the layout what shot belongs here.
 */
export function Photo({
  label,
  className = "",
  from = "#f7a6ac",
  to = "#ef6a7d",
  rounded = "rounded-3xl",
  children,
}: PhotoProps) {
  return (
    <div
      className={`relative overflow-hidden ${rounded} ${className}`}
      style={{ backgroundImage: `linear-gradient(135deg, ${from}, ${to})` }}
    >
      {/* subtle sheen */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/10 to-white/10" />
      {label && (
        <span className="absolute bottom-3 left-3 rounded-full bg-black/25 px-3 py-1 text-[11px] font-medium tracking-wide text-white/90 backdrop-blur-sm">
          {label}
        </span>
      )}
      {children}
    </div>
  );
}
