import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { EventKind, getEventVisual } from '../../model/SharedDataTypes';

@Component
export struct CalendarDayCell {
  date: number = 0;
  moodEmoji?: string = undefined;
  eventKinds: Array<EventKind> = [];
  isCurrentMonth: boolean = true;
  isToday: boolean = false;
  mode: ThemeMode = ThemeMode.Light;
  onTap: (date: number) => void = () => {};

  private dayNumber(): number {
    return new Date(this.date).getDate();
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(`${this.dayNumber()}`)
          .fontSize(15)
          .fontWeight(this.isToday ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(TodayTheme.color('ink', this.mode))
          .layoutWeight(1);

        if (this.moodEmoji) {
          Text(this.moodEmoji)
            .fontSize(15);
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Blank()
        .layoutWeight(1);

      Row({ space: 2 }) {
        ForEach(this.eventKinds.slice(0, 6), (kind: EventKind) => {
          Row()
            .layoutWeight(1)
            .height(8)
            .borderRadius(4)
            .backgroundColor(TodayTheme.color(getEventVisual(kind).tone, this.mode));
        }, (kind: EventKind, index?: number): string => `${String(kind)}-${index ?? 0}`);
      }
      .width('100%')
      .height(8);
    }
    .width('100%')
    .height(74)
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor(
      this.isToday
        ? TodayTheme.color('accentSoft', this.mode)
        : TodayTheme.alpha(TodayTheme.color('card', this.mode), this.isCurrentMonth ? 1 : 0.72)
    )
    .borderRadius(16)
    .border({
      width: this.isToday ? 1 : 0.5,
      color: this.isToday
        ? TodayTheme.color('accent', this.mode)
        : TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.7)
    })
    .opacity(this.isCurrentMonth ? 1 : 0.3)
    .onClick(() => {
      this.onTap(this.date);
    })
  }
}
