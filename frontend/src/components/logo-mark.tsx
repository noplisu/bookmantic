type LogoMarkProps = {
  size?: number;
  className?: string;
};

/** Book icon in rounded gradient tile — matches app/favicon.svg */
export function LogoMark({ size = 40, className = "" }: LogoMarkProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden
    >
      <rect width="32" height="32" rx="9" fill="#1a1224" />
      <rect width="32" height="32" rx="9" fill="url(#logo-bg)" />
      <rect
        x="0.75"
        y="0.75"
        width="30.5"
        height="30.5"
        rx="8.25"
        stroke="#e8b86d"
        strokeOpacity="0.3"
        fill="none"
      />
      <g transform="translate(4 4)">
        <path
          fill="#e8b86d"
          d="M6 4h12a1 1 0 0 1 1 1v14l-4-2.5L11 19V5a1 1 0 0 0-1-1H6a1 1 0 0 0-1 1v13h2V6h1V4z"
        />
      </g>
      <defs>
        <linearGradient id="logo-bg" x1="4" y1="4" x2="28" y2="28" gradientUnits="userSpaceOnUse">
          <stop stopColor="#e8b86d" stopOpacity="0.25" />
          <stop offset="1" stopColor="#c45c6e" stopOpacity="0.15" />
        </linearGradient>
      </defs>
    </svg>
  );
}
