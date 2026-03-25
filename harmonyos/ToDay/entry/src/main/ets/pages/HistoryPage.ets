import { AppContainer } from '../app/AppContainer';
import { ContentCard } from '../common/components/ContentCard';
import { EyebrowLabel } from '../common/components/EyebrowLabel';
import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';
import { CalendarDayCell } from '../components/history/CalendarDayCell';
import { WeeklyInsightView } from '../components/history/WeeklyInsightView';
import {
  DayTimeline,
  EventKind,
  InferredEvent,
  inferMoodKeyFromText,
  moodByKey,
  startOfDay
} from '../model/SharedDataTypes';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

class MonthCellModel {
  id: string;
  date: number;
  isCurrentMonth: boolean;

  constructor(id: string, date: number, isCurrentMonth: boolean) {
    this.id = id;
    this.date = date;
    this.isCurrentMonth = isCurrentMonth;
  }
}

const WEEKDAY_TITLES: Array<string> = ['日', '一', '二', '三', '四', '五', '六'];

@Component
export struct HistoryPage {
  @Prop mode: ThemeMode = ThemeMode.Light;

  private readonly viewModel: TodayViewModel = AppContainer.shared.todayViewModel;

  @State private visibleMonth: number = Date.now();
  @State private monthTimelines: Array<DayTimeline> = [];
  @State private isLoading: boolean = false;

  aboutToAppear(): void {
    this.visibleMonth = this.monthStart(Date.now());
    this.syncHistory();
  }

  private async syncHistory(forceReload: boolean = false): Promise<void> {
    this.isLoading = true;
    await this.viewModel.initialize();
    await this.viewModel.loadIfNeeded();
    await this.loadMonthTimelines(forceReload);
    this.isLoading = false;
  }

  private async loadMonthTimelines(forceReload: boolean = false): Promise<void> {
    const dates = this.currentMonthDates();
    this.monthTimelines = await this.viewModel.loadTimelines(dates, forceReload);
  }

  private monthStart(date: number): number {
    const value = new Date(date);
    value.setDate(1);
    value.setHours(0, 0, 0, 0);
    return value.getTime();
  }

  private shiftMonth(delta: number): void {
    const value = new Date(this.visibleMonth);
    value.setMonth(value.getMonth() + delta, 1);
    value.setHours(0, 0, 0, 0);
    if (value.getTime() > this.monthStart(Date.now())) {
      return;
    }
    this.visibleMonth = value.getTime();
    this.syncHistory();
  }

  private currentMonthDates(): Array<number> {
    const dates: Array<number> = [];
    const start = new Date(this.visibleMonth);
    const year = start.getFullYear();
    const month = start.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();

    for (let day = 1; day <= daysInMonth; day += 1) {
      dates.push(new Date(year, month, day, 12, 0, 0, 0).getTime());
    }
    return dates;
  }

  private monthGrid(): Array<MonthCellModel> {
    const result: Array<MonthCellModel> = [];
    const start = new Date(this.visibleMonth);
    const year = start.getFullYear();
    const month = start.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const firstWeekday = new Date(year, month, 1).getDay();

    if (firstWeekday > 0) {
      const previousMonthDays = new Date(year, month, 0).getDate();
      for (let index = firstWeekday - 1; index >= 0; index -= 1) {
        const date = new Date(year, month - 1, previousMonthDays - index, 12, 0, 0, 0).getTime();
        result.push(new MonthCellModel(`prev-${date}`, date, false));
      }
    }

    for (let day = 1; day <= daysInMonth; day += 1) {
      const date = new Date(year, month, day, 12, 0, 0, 0).getTime();
      result.push(new MonthCellModel(`current-${date}`, date, true));
    }

    while (result.length % 7 !== 0) {
      const index = result.length - (firstWeekday + daysInMonth) + 1;
      const date = new Date(year, month + 1, index, 12, 0, 0, 0).getTime();
      result.push(new MonthCellModel(`next-${date}`, date, false));
    }

    return result;
  }

  private monthTitle(): string {
    const value = new Date(this.visibleMonth);
    return `${value.getFullYear()} 年 ${value.getMonth() + 1} 月`;
  }

  private timelineForDate(date: number): DayTimeline | undefined {
    const day = startOfDay(date);
    return this.monthTimelines.find((item: DayTimeline) => startOfDay(item.date) === day);
  }

  private dayMoodEmoji(date: number): string | undefined {
    const timeline = this.timelineForDate(date);
    if (!timeline) {
      return undefined;
    }

    const moodEntry = timeline.entries.find((entry: InferredEvent) => entry.kind === EventKind.MOOD);
    if (!moodEntry) {
      return undefined;
    }

    const moodKey = inferMoodKeyFromText(moodEntry.displayName) ?? inferMoodKeyFromText(moodEntry.subtitle ?? '');
    if (!moodKey) {
      return undefined;
    }
    return moodByKey(moodKey).emoji;
  }

  private dayEventKinds(date: number): Array<EventKind> {
    const timeline = this.timelineForDate(date);
    if (!timeline) {
      return [];
    }

    return timeline.entries
      .filter((entry: InferredEvent) => entry.kind !== EventKind.MOOD)
      .sort((left: InferredEvent, right: InferredEvent) => left.startDate - right.startDate)
      .slice(0, 6)
      .map((entry: InferredEvent) => entry.kind);
  }

  @Builder
  private buildMonthHeader(): void {
    Row() {
      Button() {
        Text('‹')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TodayTheme.color('inkSoft', this.mode));
      }
      .width(34)
      .height(34)
      .backgroundColor(TodayTheme.alpha(TodayTheme.color('elevatedCard', this.mode), 0.72))
      .borderRadius(999)
      .onClick(() => {
        this.shiftMonth(-1);
      });

      Blank();

      Column({ space: 4 }) {
        Text(this.monthTitle())
          .fontSize(23)
          .fontStyle(FontStyle.Italic)
          .fontColor(TodayTheme.color('ink', this.mode));

        Text('每天的色块会先预览当天事件分布，再点进单日画卷。')
          .fontSize(12)
          .fontColor(TodayTheme.color('inkMuted', this.mode));
      }
      .alignItems(HorizontalAlign.Center);

      Blank();

      Button() {
        Text('›')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.visibleMonth < this.monthStart(Date.now())
            ? TodayTheme.color('inkSoft', this.mode)
            : TodayTheme.color('inkFaint', this.mode));
      }
      .width(34)
      .height(34)
      .backgroundColor(TodayTheme.alpha(TodayTheme.color('elevatedCard', this.mode), 0.72))
      .borderRadius(999)
      .enabled(this.visibleMonth < this.monthStart(Date.now()))
      .onClick(() => {
        this.shiftMonth(1);
      });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('回看')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(TodayTheme.color('ink', this.mode));

        WeeklyInsightView({ insight: this.viewModel.weeklyInsight, mode: this.mode })

        ContentCard({ mode: this.mode }) {
          EyebrowLabel({ text: 'MONTHLY SCROLL', mode: this.mode });
          this.buildMonthHeader();

          Row() {
            ForEach(WEEKDAY_TITLES, (title: string) => {
              Text(title)
                .layoutWeight(1)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontFamily('monospace')
                .fontColor(TodayTheme.color('inkMuted', this.mode))
                .textAlign(TextAlign.Center);
            }, (title: string): string => title);
          }
          .width('100%');

          GridRow({ columns: 7 }) {
            ForEach(this.monthGrid(), (cell: MonthCellModel) => {
              GridCol({ span: 1 }) {
                CalendarDayCell({
                  date: cell.date,
                  moodEmoji: this.dayMoodEmoji(cell.date),
                  eventKinds: this.dayEventKinds(cell.date),
                  isCurrentMonth: cell.isCurrentMonth,
                  isToday: startOfDay(cell.date) === startOfDay(Date.now()),
                  mode: this.mode
                })
              }
            }, (cell: MonthCellModel): string => cell.id);
          }

          if (this.isLoading) {
            Text('正在整理这个月的画卷...')
              .width('100%')
              .fontSize(12)
              .fontColor(TodayTheme.color('inkMuted', this.mode))
              .textAlign(TextAlign.Center);
          }
        }
      }
      .padding({
        left: TodayTheme.pagePadding(),
        right: TodayTheme.pagePadding(),
        top: TodayTheme.pagePadding(),
        bottom: 140
      })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(TodayTheme.background(this.mode))
  }
}
