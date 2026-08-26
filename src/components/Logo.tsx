type LogoProps = {
  className?: string;
  showWordmark?: boolean;
  wordmarkClassName?: string;
};

/**
 * Morandana brand lockup — a sunrise-over-peaks "M" mark plus the wordmark.
 * NOTE: placeholder recreation of the mark; swap for the client's official
 * logo asset when provided. `currentColor` drives the mark color.
 */
export function LogoMark({ className = "" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 88 72"
      fill="none"
      className={className}
      role="img"
      aria-label="Morandana"
    >
      <g
        stroke="currentColor"
        strokeWidth="7"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        {/* twin peaks forming an M */}
        <path d="M6 64 L26 28 L44 48 L62 28 L82 64" />
        {/* sunrise rays in the notch */}
        <path d="M44 8 V16" strokeWidth="6" />
        <path d="M33 13 L37 20" strokeWidth="6" />
        <path d="M55 13 L51 20" strokeWidth="6" />
      </g>
    </svg>
  );
}

export function Logo({
  className = "",
  showWordmark = true,
  wordmarkClassName = "",
}: LogoProps) {
  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <LogoMark className="h-6 w-auto" />
      {showWordmark && (
        <span
          className={`font-display text-xl lowercase tracking-tight ${wordmarkClassName}`}
        >
          morandana
        </span>
      )}
    </span>
  );
}
