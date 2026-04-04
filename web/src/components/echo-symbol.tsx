import { cn } from "@/lib/utils";

/**
 * Echo brand symbol — concentric arcs representing resonance/echo.
 * Used as the identity mark across the app, similar to Claude's starburst.
 */
export function EchoSymbol({
  size = 20,
  className,
  color = "currentColor",
}: {
  size?: number;
  className?: string;
  color?: string;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      className={cn("flex-shrink-0", className)}
    >
      {/* Center dot */}
      <circle cx="12" cy="12" r="2.5" fill={color} />
      {/* Inner arc */}
      <path
        d="M8.5 15.5a5 5 0 0 1 0-7"
        stroke={color}
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      {/* Outer arc */}
      <path
        d="M5.5 18a9 9 0 0 1 0-12"
        stroke={color}
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      {/* Inner arc (right) */}
      <path
        d="M15.5 8.5a5 5 0 0 1 0 7"
        stroke={color}
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      {/* Outer arc (right) */}
      <path
        d="M18.5 6a9 9 0 0 1 0 12"
        stroke={color}
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

/**
 * Echo avatar — the brand mark in a container.
 * Used in chat messages and headers.
 */
export function EchoAvatar({ size = "sm" }: { size?: "sm" | "md" | "lg" }) {
  const config = {
    sm: { dim: "h-7 w-7", symbol: 15, rounded: "rounded-full" },
    md: { dim: "h-9 w-9", symbol: 18, rounded: "rounded-full" },
    lg: { dim: "h-12 w-12", symbol: 22, rounded: "rounded-full" },
  }[size];

  return (
    <div
      className={cn(
        config.dim,
        config.rounded,
        "flex-shrink-0 flex items-center justify-center border border-border bg-card"
      )}
    >
      <EchoSymbol size={config.symbol} className="text-primary" />
    </div>
  );
}
