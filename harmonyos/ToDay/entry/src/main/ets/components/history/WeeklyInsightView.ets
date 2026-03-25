import { ContentCard } from '../../common/components/ContentCard';
import { EyebrowLabel } from '../../common/components/EyebrowLabel';
import { FlexibleBadgeRow } from '../../common/components/FlexibleBadgeRow';
import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { WeeklyInsight } from '../../model/SharedDataTypes';

@Component
export struct WeeklyInsightView {
  insight?: WeeklyInsight = undefined;
  mode: ThemeMode = ThemeMode.Light;

  build() {
    ContentCard({ mode: this.mode, backgroundToken: 'tealSoft' }) {
      EyebrowLabel({ text: '七日节律', mode: this.mode });
      Text('最近 7 天')
        .fontSize(23)
        .fontWeight(FontWeight.Medium)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.color('ink', this.mode));
      Text(this.insight?.headline ?? '最近 7 天还没有足够数据')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(TodayTheme.color('inkSoft', this.mode));
      Text(this.insight?.narrative ?? '等你积累更多时间轴之后，这里会开始总结周节律。')
        .fontSize(14)
        .fontColor(TodayTheme.color('inkMuted', this.mode))
        .lineHeight(20);
      FlexibleBadgeRow({
        badges: this.insight?.badges ?? ['等待更多数据'],
        tone: 'teal',
        mode: this.mode
      });
    }
  }
}
