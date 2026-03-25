import { ThemeMode, TodayTheme } from '../theme/TodayTheme';

@Component
export struct ContentCard {
  mode: ThemeMode = ThemeMode.Light;
  backgroundToken: string = 'card';
  @BuilderParam content: () => void;

  build() {
    Column({ space: TodayTheme.spacing('md') }) {
      this.content();
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(TodayTheme.padding('cardInner'))
    .backgroundColor(TodayTheme.color(this.backgroundToken, this.mode))
    .borderRadius(TodayTheme.radius('card'))
    .border({
      width: 1,
      color: TodayTheme.color('border', this.mode)
    })
  }
}
