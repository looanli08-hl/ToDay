import { ThemeMode, TodayTheme } from '../theme/TodayTheme';

@Component
export struct IntensityBar {
  minutes: number = 5;
  tone: string = 'accent';
  mode: ThemeMode = ThemeMode.Light;

  build() {
    const normalized = Math.sqrt(Math.min(Math.max(this.minutes, 5), 240) / 240);
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(56)
        .height(3)
        .backgroundColor(TodayTheme.color('border', this.mode))
        .borderRadius(TodayTheme.radius('capsule'));

      Row()
        .width(56 * normalized)
        .height(3)
        .backgroundColor(TodayTheme.color(this.tone, this.mode))
        .borderRadius(TodayTheme.radius('capsule'));
    }
    .width(56)
    .height(3)
  }
}
