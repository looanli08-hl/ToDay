import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { TimelineStat } from '../../model/SharedDataTypes';

@Component
export struct OverviewStatCard {
  stat: TimelineStat = {
    id: '',
    title: '',
    label: '',
    value: '',
    tone: 'accent',
    softTone: 'accentSoft'
  };
  mode: ThemeMode = ThemeMode.Light;

  build() {
    Column({ space: 7 }) {
      Text(this.stat.label)
        .fontSize(11)
        .fontColor(TodayTheme.color('inkMuted', this.mode));

      Text(this.stat.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontFamily('monospace')
        .fontColor(TodayTheme.color('ink', this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .alignItems(HorizontalAlign.Start)
    .width(92)
    .padding({ left: 14, right: 14, top: 16, bottom: 16 })
    .backgroundColor(TodayTheme.color(this.stat.softTone, this.mode))
    .borderRadius(16)
    .border({
      width: 1,
      color: TodayTheme.alpha(TodayTheme.color(this.stat.tone, this.mode), 0.3)
    })
  }
}
