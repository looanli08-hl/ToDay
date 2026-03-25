import { ThemeMode, TodayTheme } from '../theme/TodayTheme';

@Component
export struct FlexibleBadgeRow {
  badges: string[] = [];
  tone: string = 'accent';
  mode: ThemeMode = ThemeMode.Light;

  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
      ForEach(this.badges, (badge: string) => {
        Text(badge)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(TodayTheme.color('inkSoft', this.mode))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(TodayTheme.color(`${this.tone}Soft`, this.mode))
          .borderRadius(TodayTheme.radius('capsule'))
          .margin({ right: 8, bottom: 8 });
      });
    }
    .width('100%')
  }
}
