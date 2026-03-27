import { FlexibleBadgeRow } from '../../common/components/FlexibleBadgeRow';
import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { formatDateHeader, moodByKey, RecentDayDigest } from '../../model/SharedDataTypes';

@Component
export struct RecentDayCard {
  digest: RecentDayDigest = {
    id: '',
    date: 0,
    summary: '',
    eventColors: [],
    eventCount: 0,
    recordCount: 0
  };
  mode: ThemeMode = ThemeMode.Light;

  private dominantMoodLabel(): string {
    if (!this.digest.dominantMood) {
      return '';
    }
    const mood = moodByKey(this.digest.dominantMood);
    return `${mood.emoji} ${mood.label}`;
  }

  private dominantMoodColor(): string {
    if (!this.digest.dominantMood) {
      return TodayTheme.color('inkMuted', this.mode);
    }
    return TodayTheme.color(moodByKey(this.digest.dominantMood).tone, this.mode);
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(formatDateHeader(this.digest.date))
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkMuted', this.mode))
          .layoutWeight(1);

        if (this.digest.dominantMood) {
          Text(this.dominantMoodLabel())
            .fontSize(12)
            .fontColor(this.dominantMoodColor());
        }
      }
      .width('100%');

      Text(this.digest.summary)
        .fontSize(14)
        .fontColor(TodayTheme.color('inkSoft', this.mode))
        .lineHeight(20);

      FlexibleBadgeRow({
        badges: [
          `${this.digest.eventCount} 个片段`,
          `${this.digest.recordCount} 次记录`
        ],
        tone: 'accent',
        mode: this.mode
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(TodayTheme.color('background', this.mode))
    .borderRadius(16)
  }
}
