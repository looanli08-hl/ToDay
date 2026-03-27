import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';

@Component
export struct HistoryDayDetail {
  @Prop mode: ThemeMode = ThemeMode.Light;
  @Prop title: string = '某一天的详情';

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TodayTheme.textPrimary(this.mode));

      Text('这个详情页会在手机端主流程跑通后继续扩展，未来用于承接日视图、事件详情和手表同步回看。')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(TodayTheme.textSecondary(this.mode));
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
    .padding(TodayTheme.pagePadding())
    .backgroundColor(TodayTheme.background(this.mode))
  }
}
