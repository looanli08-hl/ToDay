import { ThemeMode, TodayTheme } from '../theme/TodayTheme';

@Component
export struct EyebrowLabel {
  text: string = '';
  mode: ThemeMode = ThemeMode.Light;

  build() {
    Text(this.text)
      .fontSize(TodayTheme.font('eyebrow').size)
      .fontWeight(FontWeight.Medium)
      .fontFamily('monospace')
      .fontColor(TodayTheme.color('inkMuted', this.mode))
      .letterSpacing(TodayTheme.font('eyebrow').tracking ?? 2.4)
  }
}
