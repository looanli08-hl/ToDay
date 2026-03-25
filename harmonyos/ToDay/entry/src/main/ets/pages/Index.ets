import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';
import { HistoryPage } from './HistoryPage';
import { SettingsPage } from './SettingsPage';
import { TodayPage } from './TodayPage';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State themeMode: ThemeMode = ThemeMode.Light;

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentTab
    }) {
      TabContent() {
        TodayPage({ mode: this.themeMode })
      }
      .tabBar('今日');

      TabContent() {
        HistoryPage({ mode: this.themeMode })
      }
      .tabBar('回看');

      TabContent() {
        SettingsPage({ mode: $themeMode })
      }
      .tabBar('设置');
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TodayTheme.background(this.themeMode))
    .onChange((index: number) => {
      this.currentTab = index;
    })
  }
}
