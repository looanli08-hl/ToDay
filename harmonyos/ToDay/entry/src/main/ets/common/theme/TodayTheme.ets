export enum ThemeMode {
  Light = 'light',
  Dark = 'dark'
}

interface FontSpec {
  size: number;
  tracking?: number;
}

interface ThemePalette {
  background: string;
  card: string;
  elevatedCard: string;
  ink: string;
  inkSoft: string;
  inkMuted: string;
  inkFaint: string;
  border: string;
  accent: string;
  accentSoft: string;
  teal: string;
  tealSoft: string;
  rose: string;
  roseSoft: string;
  blue: string;
  blueSoft: string;
  scrollNight: string;
  scrollSunrise: string;
  scrollGold: string;
  scrollNoon: string;
  scrollSunset: string;
  scrollViolet: string;
  workoutOrange: string;
  walkGreen: string;
  sleepIndigo: string;
}

interface RadiusTokens {
  card: number;
  eventCard: number;
  statCard: number;
  capsule: number;
}

interface SpacingTokens {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
}

interface PaddingTokens {
  cardInner: number;
  page: number;
}

interface FontTokens {
  eyebrow: FontSpec;
  statValue: FontSpec;
  body: FontSpec;
  title: FontSpec;
}

const LIGHT_PALETTE: ThemePalette = {
  background: '#FAFAF8',
  card: '#FFFFFF',
  elevatedCard: '#F3EFE7',
  ink: '#1A1A1A',
  inkSoft: '#3D3D3D',
  inkMuted: '#8A8A8A',
  inkFaint: '#B8B8B8',
  border: '#E2E0DC',
  accent: '#C59661',
  accentSoft: '#F5E9D8',
  teal: '#5B9A8B',
  tealSoft: '#E4F2EE',
  rose: '#C97B7B',
  roseSoft: '#F7E7E7',
  blue: '#7B9CC9',
  blueSoft: '#E8EFF9',
  scrollNight: '#202C57',
  scrollSunrise: '#D28953',
  scrollGold: '#E9D18B',
  scrollNoon: '#BFDDF3',
  scrollSunset: '#E0A16D',
  scrollViolet: '#5F4978',
  workoutOrange: '#D76F3D',
  walkGreen: '#5C9C70',
  sleepIndigo: '#4A5FA9'
};

const DARK_PALETTE: ThemePalette = {
  background: '#111412',
  card: '#1A1E1B',
  elevatedCard: '#202622',
  ink: '#F4F2ED',
  inkSoft: '#D8D3CC',
  inkMuted: '#A9A49C',
  inkFaint: '#6A6F6A',
  border: '#313731',
  accent: '#D9B27E',
  accentSoft: '#3A2E20',
  teal: '#7CC1AF',
  tealSoft: '#20352F',
  rose: '#D89898',
  roseSoft: '#392526',
  blue: '#9AB7DD',
  blueSoft: '#223043',
  scrollNight: '#17203F',
  scrollSunrise: '#A6633A',
  scrollGold: '#B39446',
  scrollNoon: '#385D7F',
  scrollSunset: '#A16A44',
  scrollViolet: '#3A2B4C',
  workoutOrange: '#F09B66',
  walkGreen: '#7CC18D',
  sleepIndigo: '#788DDB'
};

const RADII: RadiusTokens = {
  card: 20,
  eventCard: 20,
  statCard: 18,
  capsule: 999
};

const SPACING: SpacingTokens = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 18,
  xl: 20
};

const PADDING: PaddingTokens = {
  cardInner: 18,
  page: 20
};

const FONTS: FontTokens = {
  eyebrow: { size: 11, tracking: 2.4 },
  statValue: { size: 24 },
  body: { size: 14 },
  title: { size: 28 }
};

function paletteFor(mode: ThemeMode): ThemePalette {
  if (mode === ThemeMode.Dark) {
    return DARK_PALETTE;
  }
  return LIGHT_PALETTE;
}

function tokenColor(palette: ThemePalette, token: string): string {
  switch (token) {
    case 'background':
      return palette.background;
    case 'card':
      return palette.card;
    case 'elevatedCard':
      return palette.elevatedCard;
    case 'ink':
      return palette.ink;
    case 'inkSoft':
      return palette.inkSoft;
    case 'inkMuted':
      return palette.inkMuted;
    case 'inkFaint':
      return palette.inkFaint;
    case 'border':
      return palette.border;
    case 'accent':
      return palette.accent;
    case 'accentSoft':
      return palette.accentSoft;
    case 'teal':
      return palette.teal;
    case 'tealSoft':
      return palette.tealSoft;
    case 'rose':
      return palette.rose;
    case 'roseSoft':
      return palette.roseSoft;
    case 'blue':
      return palette.blue;
    case 'blueSoft':
      return palette.blueSoft;
    case 'scrollNight':
      return palette.scrollNight;
    case 'scrollSunrise':
      return palette.scrollSunrise;
    case 'scrollGold':
      return palette.scrollGold;
    case 'scrollNoon':
      return palette.scrollNoon;
    case 'scrollSunset':
      return palette.scrollSunset;
    case 'scrollViolet':
      return palette.scrollViolet;
    case 'workoutOrange':
      return palette.workoutOrange;
    case 'walkGreen':
      return palette.walkGreen;
    case 'sleepIndigo':
      return palette.sleepIndigo;
    default:
      return token;
  }
}

function clampOpacity(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function hexToRgb(hex: string): Array<number> {
  const normalized = hex.replace('#', '');
  if (normalized.length !== 6) {
    return [0, 0, 0];
  }
  return [
    parseInt(normalized.slice(0, 2), 16),
    parseInt(normalized.slice(2, 4), 16),
    parseInt(normalized.slice(4, 6), 16)
  ];
}

export class TodayTheme {
  static color(token: string, mode: ThemeMode = ThemeMode.Light): string {
    return tokenColor(paletteFor(mode), token);
  }

  static alpha(color: string, opacity: number): string {
    if (color.startsWith('rgba(') || color.startsWith('rgb(')) {
      return color;
    }
    const rgb = hexToRgb(color);
    return `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${clampOpacity(opacity)})`;
  }

  static glass(_mode: ThemeMode = ThemeMode.Light, opacity: number = 0.18): string {
    return TodayTheme.alpha('#FFFFFF', opacity);
  }

  static scrollGradient(mode: ThemeMode): Array<string> {
    return [
      TodayTheme.color('scrollNight', mode),
      TodayTheme.color('scrollSunrise', mode),
      TodayTheme.color('scrollGold', mode),
      TodayTheme.color('scrollNoon', mode),
      TodayTheme.color('scrollSunset', mode),
      TodayTheme.color('scrollViolet', mode)
    ];
  }

  static radius(token: string): number {
    switch (token) {
      case 'card':
        return RADII.card;
      case 'eventCard':
        return RADII.eventCard;
      case 'statCard':
        return RADII.statCard;
      case 'capsule':
        return RADII.capsule;
      default:
        return 16;
    }
  }

  static spacing(token: string): number {
    switch (token) {
      case 'xs':
        return SPACING.xs;
      case 'sm':
        return SPACING.sm;
      case 'md':
        return SPACING.md;
      case 'lg':
        return SPACING.lg;
      case 'xl':
        return SPACING.xl;
      default:
        return SPACING.md;
    }
  }

  static padding(token: string): number {
    switch (token) {
      case 'cardInner':
        return PADDING.cardInner;
      case 'page':
        return PADDING.page;
      default:
        return PADDING.cardInner;
    }
  }

  static font(token: string): FontSpec {
    switch (token) {
      case 'eyebrow':
        return FONTS.eyebrow;
      case 'statValue':
        return FONTS.statValue;
      case 'title':
        return FONTS.title;
      case 'body':
      default:
        return FONTS.body;
    }
  }

  static background(mode: ThemeMode): string {
    return TodayTheme.color('background', mode);
  }

  static surface(mode: ThemeMode): string {
    return TodayTheme.color('card', mode);
  }

  static surfaceMuted(mode: ThemeMode): string {
    return TodayTheme.color('elevatedCard', mode);
  }

  static textPrimary(mode: ThemeMode): string {
    return TodayTheme.color('ink', mode);
  }

  static textSecondary(mode: ThemeMode): string {
    return TodayTheme.color('inkSoft', mode);
  }

  static border(mode: ThemeMode): string {
    return TodayTheme.color('border', mode);
  }

  static accent(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('accent', mode);
  }

  static accentSoft(mode: ThemeMode): string {
    return TodayTheme.color('accentSoft', mode);
  }

  static teal(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('teal', mode);
  }

  static tealSoft(mode: ThemeMode): string {
    return TodayTheme.color('tealSoft', mode);
  }

  static indigo(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('sleepIndigo', mode);
  }

  static indigoSoft(mode: ThemeMode): string {
    return TodayTheme.color('blueSoft', mode);
  }

  static red(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('workoutOrange', mode);
  }

  static redSoft(mode: ThemeMode): string {
    return TodayTheme.color('accentSoft', mode);
  }

  static green(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('walkGreen', mode);
  }

  static greenSoft(mode: ThemeMode): string {
    return TodayTheme.color('tealSoft', mode);
  }

  static gold(mode: ThemeMode = ThemeMode.Light): string {
    return TodayTheme.color('accent', mode);
  }

  static goldSoft(mode: ThemeMode): string {
    return TodayTheme.color('accentSoft', mode);
  }

  static pagePadding(): number {
    return 20;
  }

  static sectionGap(): number {
    return 18;
  }

  static cardRadius(): number {
    return 20;
  }

  static chipRadius(): number {
    return 999;
  }

  static phoneWidth(): number {
    return 412;
  }

  static watchDiameter(): number {
    return 46;
  }
}
