/** Fractal Soft logo mark — 3×3 fractal grid from fractalsoft.org brand assets */
export function FractalSoftMark({ size = 20, className = "" }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 3 3"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden
    >
      <rect x="0" y="0" width="1" height="1" fill="currentColor" />
      <rect x="0" y="2" width="1" height="1" fill="currentColor" />
      <rect x="2" y="0" width="1" height="1" fill="currentColor" />
      <rect x="1" y="1" width="1" height="1" fill="currentColor" />
    </svg>
  );
}
