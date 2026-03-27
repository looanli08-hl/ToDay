import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import {
  createStableId,
  durationMinutes,
  eventTintColor,
  EventConfidence,
  EventKind,
  formatClock,
  InferredEvent,
  startOfDay
} from '../../model/SharedDataTypes';
import { EventCardView } from './EventCardView';

type TimelineRowKind = 'event' | 'gap';

interface TimelineRowModel {
  id: string;
  kind: TimelineRowKind;
  entry: InferredEvent;
  startMinute: number;
  endMinute: number;
  height: number;
  startLabel: string;
  endLabel: string;
  gapLabel?: string;
}

const DAY_MINUTES = 24 * 60;
const OUTER_PADDING = 14;
const TOP_PADDING = 16;
const BOTTOM_PADDING = 16;
const TIME_COLUMN_WIDTH = 44;
const INDICATOR_COLUMN_WIDTH = 20;
const MIN_GAP_MINUTES = 15;

@Component
export struct DayScrollView {
  entries: InferredEvent[] = [];
  mode: ThemeMode = ThemeMode.Light;
  onEventTap: (event: InferredEvent) => void = () => {};
  onBlankTap: (event: InferredEvent) => void = () => {};

  @State private currentMinute: number = this.minuteOfDay(Date.now());
  private timerId: number = -1;

  aboutToAppear(): void {
    this.currentMinute = this.minuteOfDay(Date.now());
    this.startTicker();
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTicker(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
    this.timerId = setInterval(() => {
      this.currentMinute = this.minuteOfDay(Date.now());
    }, 60 * 1000);
  }

  private timelineRows(): TimelineRowModel[] {
    const rows: TimelineRowModel[] = [];
    const sorted = this.entries.slice().sort((left, right) => left.startDate - right.startDate);

    for (let index = 0; index < sorted.length; index += 1) {
      const entry = sorted[index];
      const previous = index > 0 ? sorted[index - 1] : undefined;

      if (previous) {
        const gapMinutes = durationMinutes(previous.endDate, entry.startDate);
        if (gapMinutes >= MIN_GAP_MINUTES) {
          rows.push(this.buildGapRow(previous, entry, gapMinutes));
        }
      }

      rows.push(this.buildEventRow(entry));
    }

    return rows;
  }

  private buildGapRow(previous: InferredEvent, next: InferredEvent, gapMinutes: number): TimelineRowModel {
    const quietEvent: InferredEvent = {
      id: createStableId(`${previous.id}|gap|${next.id}`),
      kind: EventKind.QUIET_TIME,
      startDate: previous.endDate,
      endDate: next.startDate,
      confidence: EventConfidence.LOW,
      isLive: false,
      displayName: '留白',
      subtitle: this.formatGapDuration(gapMinutes),
      photoAttachments: []
    };

    return {
      id: quietEvent.id,
      kind: 'gap',
      entry: quietEvent,
      startMinute: this.minuteOfDay(quietEvent.startDate),
      endMinute: this.minuteOfDay(quietEvent.endDate),
      height: this.gapHeight(gapMinutes),
      startLabel: formatClock(quietEvent.startDate),
      endLabel: '',
      gapLabel: `留白 · ${this.formatGapDuration(gapMinutes)}`
    };
  }

  private buildEventRow(entry: InferredEvent): TimelineRowModel {
    return {
      id: entry.id,
      kind: 'event',
      entry: entry,
      startMinute: this.minuteOfDay(entry.startDate),
      endMinute: this.minuteOfDay(Math.max(entry.endDate, entry.startDate + 60 * 1000)),
      height: this.eventRowHeight(entry),
      startLabel: formatClock(entry.startDate),
      endLabel: entry.kind === EventKind.MOOD ? '' : formatClock(entry.endDate)
    };
  }

  private eventRowHeight(entry: InferredEvent): number {
    if (entry.kind === EventKind.MOOD) {
      return 42;
    }
    if (entry.kind === EventKind.SLEEP && entry.associatedMetrics?.sleepStages && entry.associatedMetrics.sleepStages.length > 0) {
      return 92;
    }
    if (entry.subtitle && entry.subtitle.trim().length > 0) {
      return 84;
    }
    return 74;
  }

  private gapHeight(gapMinutes: number): number {
    if (gapMinutes < 60) {
      return 24;
    }
    if (gapMinutes < 180) {
      return 36;
    }
    return 48;
  }

  private formatGapDuration(gapMinutes: number): string {
    if (gapMinutes >= 60) {
      const hours = Math.floor(gapMinutes / 60);
      const minutes = gapMinutes % 60;
      if (minutes === 0) {
        return `${hours}h`;
      }
      return `${hours}h ${minutes}m`;
    }
    return `${gapMinutes}m`;
  }

  private minuteOfDay(value: number): number {
    const date = new Date(value);
    return Math.max(0, Math.min(DAY_MINUTES, date.getHours() * 60 + date.getMinutes()));
  }

  private totalRowHeight(rows: TimelineRowModel[]): number {
    let total = 0;
    rows.forEach((row) => {
      total += row.height;
    });
    return total;
  }

  private showsCurrentNeedle(): boolean {
    if (this.entries.length === 0) {
      return false;
    }
    return startOfDay(this.entries[0].startDate) === startOfDay(Date.now());
  }

  private currentNeedleOffset(rows: TimelineRowModel[]): number {
    let offset = 0;
    for (let index = 0; index < rows.length; index += 1) {
      const row = rows[index];
      const rowEndMinute = Math.max(row.startMinute + 1, row.endMinute);
      if (this.currentMinute >= row.startMinute && this.currentMinute <= rowEndMinute) {
        const progress = (this.currentMinute - row.startMinute) / Math.max(rowEndMinute - row.startMinute, 1);
        return offset + row.height * progress;
      }
      offset += row.height;
    }
    return offset;
  }

  private verticalLineHeight(): number {
    return Math.max(8, this.totalRowHeight(this.timelineRows()) - 8);
  }

  private currentNeedleOffsetValue(): number {
    return this.currentNeedleOffset(this.timelineRows());
  }

  @Builder
  private buildEventRowView(row: TimelineRowModel): void {
    Row({ space: 0 }) {
      Column({ space: 2 }) {
        Text(row.startLabel)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontFamily('monospace')
          .fontColor(TodayTheme.alpha('#FFFFFF', 0.72));

        if (row.endLabel.length > 0) {
          Text(row.endLabel)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontFamily('monospace')
            .fontColor(TodayTheme.alpha('#FFFFFF', 0.38));
        }
      }
      .width(TIME_COLUMN_WIDTH)
      .alignItems(HorizontalAlign.End);

      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(999)
          .backgroundColor(eventTintColor(row.entry, this.mode));
      }
      .width(INDICATOR_COLUMN_WIDTH)
      .height(row.height);

      EventCardView({ event: row.entry, mode: this.mode })
        .layoutWeight(1)
        .onClick(() => {
          this.onEventTap(row.entry);
        });
    }
    .width('100%')
    .height(row.height)
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private buildGapRowView(row: TimelineRowModel): void {
    Row({ space: 0 }) {
      Text(row.startLabel)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontFamily('monospace')
        .fontColor(TodayTheme.alpha('#FFFFFF', 0.34))
        .width(TIME_COLUMN_WIDTH)
        .textAlign(TextAlign.End);

      Stack({ alignContent: Alignment.Center }) {
      }
      .width(INDICATOR_COLUMN_WIDTH)
      .height(row.height);

      Text(row.gapLabel ?? '留白')
        .fontSize(12)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.alpha('#FFFFFF', 0.42))
        .layoutWeight(1);
    }
    .width('100%')
    .height(row.height)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onBlankTap(row.entry);
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        ForEach(this.timelineRows(), (row: TimelineRowModel) => {
          if (row.kind === 'gap') {
            this.buildGapRowView(row);
          } else {
            this.buildEventRowView(row);
          }
        }, (row: TimelineRowModel): string => row.id)
      }
      .width('100%')
      .padding({ left: OUTER_PADDING, right: OUTER_PADDING, top: TOP_PADDING, bottom: BOTTOM_PADDING });

      Column()
        .width(1.5)
        .height(this.verticalLineHeight())
        .backgroundColor(TodayTheme.alpha('#FFFFFF', 0.25))
        .borderRadius(999)
        .margin({
          left: OUTER_PADDING + TIME_COLUMN_WIDTH + (INDICATOR_COLUMN_WIDTH - 1.5) / 2,
          top: TOP_PADDING + 4
        });

      if (this.showsCurrentNeedle()) {
        Row({ space: 4 }) {
          Row()
            .width(6)
            .height(6)
            .borderRadius(999)
            .backgroundColor('#FFFFFF');

          Row()
            .height(1.5)
            .layoutWeight(1)
            .backgroundColor(TodayTheme.alpha('#FFFFFF', 0.6));
        }
        .width('100%')
        .padding({ right: OUTER_PADDING })
        .margin({
          left: OUTER_PADDING + TIME_COLUMN_WIDTH + 3,
          top: TOP_PADDING + this.currentNeedleOffsetValue()
        });
      }
    }
    .width('100%')
    .linearGradient({
      angle: 90,
      colors: [
        [TodayTheme.color('scrollNight', this.mode), 0],
        [TodayTheme.color('scrollSunrise', this.mode), 0.18],
        [TodayTheme.color('scrollGold', this.mode), 0.38],
        [TodayTheme.color('scrollNoon', this.mode), 0.58],
        [TodayTheme.color('scrollSunset', this.mode), 0.78],
        [TodayTheme.color('scrollViolet', this.mode), 1]
      ]
    })
    .borderRadius(20)
    .border({
      width: 0.5,
      color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.65)
    })
  }
}
