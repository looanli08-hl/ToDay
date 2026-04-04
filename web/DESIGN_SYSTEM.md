# ToDay Design System

This document defines every visual parameter. All new code MUST reference these values.
When in doubt, use CSS variables (`var(--*)`) instead of hardcoded colors.

## Colors

Use CSS variables exclusively. Never hardcode hex values in components.

| Token | Variable | Value | Usage |
|-------|----------|-------|-------|
| Background | `var(--background)` | `#F5F1EB` | Page backgrounds |
| Foreground | `var(--foreground)` | `#2C2418` | Primary text |
| Card | `var(--card)` | `#FFFFFF` | Card/panel backgrounds |
| Primary | `var(--primary)` | `#C4713E` | Brand accent, CTAs |
| Muted | `var(--muted)` | `#EAE5DC` | Subtle backgrounds |
| Muted fg | `var(--muted-foreground)` | `#8A7D6B` | Secondary text |
| Border | `var(--border)` | `#E6DFD3` | All borders |
| Sidebar | `var(--sidebar)` | `#EFEBE4` | Sidebar background |

**Semantic colors (Tailwind only):**
- Success indicator: `bg-emerald-500` (only for status dots)
- Error text: `text-destructive`

## Typography

### Font Families
- **Display** (`.font-display`): `ui-serif, Georgia, Cambria, "Times New Roman", Times, serif`
  - Used for: Page headings, greeting, stat card values, section titles, brand name
- **UI** (`font-sans`): `Inter, system-ui, -apple-system, sans-serif`
  - Used for: Buttons, labels, nav items, body text, inputs

### Font Scale (only these sizes, nothing else)

| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| `display-lg` | `text-4xl` (36px) | `font-normal` | Page greeting |
| `display-md` | `text-2xl` (24px) | `font-normal` | Page titles, empty state headings |
| `display-sm` | `text-lg` (18px) | `font-normal` | Section headers |
| `heading` | `text-base` (16px) | `font-semibold` | Card headers (sans-serif) |
| `body` | `text-sm` (14px) | `font-normal` | Body text, inputs |
| `caption` | `text-xs` (12px) | `font-medium` | Labels, secondary text |
| `micro` | `text-[11px]` | `font-normal` | Timestamps, metadata |

**Rule: No arbitrary pixel values** like `text-[13px]`, `text-[15px]`, `text-[17px]`. Use the scale above.

## Spacing

### Page Layout
- Page horizontal padding: `px-12`
- Page top padding: `pt-12`
- Page bottom padding: `pb-12`
- Section gap: `space-y-8`

### Cards
- Card padding: `p-6` (always, no exceptions)
- Card gap in grids: `gap-4`

### Within Components
- Tight: `gap-2`
- Standard: `gap-3`
- Relaxed: `gap-4`

## Border Radius

Only these values:

| Token | Class | Usage |
|-------|-------|-------|
| Small | `rounded-lg` | Buttons, inputs, small elements |
| Medium | `rounded-xl` | Cards, panels, containers |
| Full | `rounded-full` | Pills, avatars, status dots |

**Rule: No `rounded-md`, `rounded-2xl`, `rounded-sm`.** Three values only.

## Shadows

No custom shadows. Only:
- `shadow-none` (default for most elements)
- `shadow-sm` (hover states only)

**Cards use borders, not shadows:** `border border-border/40`

## Buttons

### Primary
```
bg-primary text-primary-foreground rounded-lg px-4 py-2 text-sm font-medium
hover:opacity-90 transition-opacity
```

### Secondary (outline)
```
border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm
hover:text-foreground hover:border-border transition-colors
```

### Ghost
```
text-muted-foreground hover:text-foreground hover:bg-accent rounded-lg px-3 py-2 text-sm
transition-colors
```

## Inputs
```
rounded-lg border border-border bg-background px-4 py-2.5 text-sm
placeholder:text-muted-foreground/50
outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40
transition-all
```

## Cards
```
border border-border/40 bg-card rounded-xl p-6
```
Hover state (optional): `hover:shadow-sm transition-shadow`

## Icons
- Size: `h-4 w-4` (16px) everywhere
- Stroke: `strokeWidth={1.5}`
- Color: `text-muted-foreground` (inactive), `text-foreground` (active)
- Never use colored icons. One exception: EchoSymbol uses `text-primary`.

## Sidebar
- Width: `w-[260px]`
- Nav item: `rounded-lg px-3 py-2 text-sm`
- Active: `bg-accent text-foreground`
- Inactive: `text-muted-foreground hover:bg-accent/60`

## Status Indicators
- Connected: `bg-emerald-500` (dot only, no text color variation)
- Disconnected: `bg-muted-foreground/30`
- Pulsing: add `animate-pulse` to connected dots

## Code Blocks
```
bg-foreground text-background rounded-xl p-4 text-xs font-mono
```
Uses foreground/background inversion — always in-system.
