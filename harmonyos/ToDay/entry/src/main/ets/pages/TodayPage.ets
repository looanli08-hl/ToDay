import { AppContainer } from '../app/AppContainer';
import { ContentCard } from '../common/components/ContentCard';
import { EyebrowLabel } from '../common/components/EyebrowLabel';
import { FlexibleBadgeRow } from '../common/components/FlexibleBadgeRow';
import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';
import { AnnotationSheet } from '../components/today/AnnotationSheet';
import { DayScrollView } from '../components/today/DayScrollView';
import { EventDetailView } from '../components/today/EventDetailView';
import { FlowSignatureView } from '../components/today/FlowSignatureView';
import { OverviewStatCard } from '../components/today/OverviewStatCard';
import { QuickRecordSheet } from '../components/today/QuickRecordSheet';
import { RecentDayCard } from '../components/today/RecentDayCard';
import { WeeklyInsightView } from '../components/history/WeeklyInsightView';
import { MoodRecord } from '../model/MoodRecord';
import {
  DayTimeline,
  EventConfidence,
  EventKind,
  formatDateFull,
  InferredEvent,
  InsightSummary,
  RecentDayDigest,
  TimelineSource,
  TimelineStat,
  WeeklyInsight
} from '../model/SharedDataTypes';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

const EMPTY_EVENT: InferredEvent = {
  id: '',
  kind: EventKind.QUIET_TIME,
  startDate: 0,
  endDate: 0,
  confidence: EventConfidence.LOW,
  isLive: false,
  displayName: '',
  photoAttachments: []
};

@Component
export struct TodayPage {
  @Prop mode: ThemeMode = ThemeMode.Light;
  onOpenHistory: () => void = () => {};

  private readonly viewModel: TodayViewModel = AppContainer.shared.todayViewModel;

  @State isLoading: boolean = true;
  @State timeline?: DayTimeline = undefined;
  @State insightSummary?: InsightSummary = undefined;
  @State weeklyInsight?: WeeklyInsight = undefined;
  @State recentDigests: Array<RecentDayDigest> = [];
  @State overviewStats: Array<TimelineStat> = [];
  @State errorText: string = '';
  @State showQuickRecord: boolean = false;
  @State showEventDetail: boolean = false;
  @State showAnnotation: boolean = false;
  @State selectedEvent: InferredEvent = EMPTY_EVENT;

  aboutToAppear(): void {
    this.syncFromViewModel();
  }

  private async syncFromViewModel(forceReload: boolean = false): Promise<void> {
    this.isLoading = true;
    await this.viewModel.initialize();
    if (forceReload) {
      await this.viewModel.load(true);
    } else {
      await this.viewModel.loadIfNeeded();
    }

    this.timeline = this.viewModel.timeline;
    this.insightSummary = this.viewModel.insightSummary;
    this.weeklyInsight = this.viewModel.weeklyInsight;
    this.recentDigests = this.viewModel.recentDigests.slice();
    this.errorText = this.viewModel.errorMessage;
    this.overviewStats = this.buildOverviewStats();
    this.isLoading = this.viewModel.isLoading;
  }

  private buildOverviewStats(): Array<TimelineStat> {
    const eventCount = this.viewModel.timeline ? this.viewModel.timeline.entries.length : 0;
    const sourceLabel = this.sourceLabel(this.viewModel.timeline ? this.viewModel.timeline.source : undefined);
    return [
      {
        id: 'segments',
        title: '片段',
        label: '片段',
        value: String(eventCount),
        tone: 'blue',
        softTone: 'blueSoft'
      },
      {
        id: 'records',
        title: '记录',
        label: '记录',
        value: String(this.viewModel.todayManualRecordCount),
        tone: 'teal',
        softTone: 'tealSoft'
      },
      {
        id: 'notes',
        title: '备注',
        label: '备注',
        value: String(this.viewModel.todayNoteCount),
        tone: 'rose',
        softTone: 'roseSoft'
      },
      {
        id: 'source',
        title: '来源',
        label: '来源',
        value: sourceLabel,
        tone: 'accent',
        softTone: 'accentSoft'
      }
    ];
  }

  private sourceLabel(source: TimelineSource | 'mock' | 'healthKit' | undefined): string {
    if (source === TimelineSource.HEALTH_KIT) {
      return '健康';
    }
    return '模拟';
  }

  private openQuickRecord(): void {
    this.viewModel.openQuickRecordComposer();
    this.showQuickRecord = true;
  }

  private openPointComposer(): void {
    this.viewModel.openPointComposer();
    this.showQuickRecord = true;
  }

  private closeQuickRecord(): void {
    this.showQuickRecord = false;
    this.viewModel.showQuickRecord = false;
  }

  private saveRecord(record: MoodRecord): void {
    this.closeQuickRecord();
    this.persistRecord(record);
  }

  private async persistRecord(record: MoodRecord): Promise<void> {
    await this.viewModel.startMoodRecord(record);
    await this.syncFromViewModel(true);
  }

  private finishActiveRecord(): void {
    this.completeActiveRecord();
  }

  private async completeActiveRecord(): Promise<void> {
    await this.viewModel.finishActiveMoodRecord();
    await this.syncFromViewModel(true);
  }

  private openEventDetail(event: InferredEvent): void {
    this.selectedEvent = event;
    this.showEventDetail = true;
  }

  private openAnnotation(event: InferredEvent): void {
    this.selectedEvent = event;
    this.showAnnotation = true;
  }

  private saveAnnotation(title: string): void {
    this.persistAnnotation(title);
  }

  private async persistAnnotation(title: string): Promise<void> {
    await this.viewModel.annotateEvent(this.selectedEvent, title);
    this.showAnnotation = false;
    await this.syncFromViewModel(true);
  }

  @Builder
  private buildHeader(): void {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text(formatDateFull(Date.now()))
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor(TodayTheme.color('inkMuted', this.mode));

          Text('今日画卷')
            .fontSize(34)
            .fontWeight(FontWeight.Medium)
            .fontStyle(FontStyle.Italic)
            .fontColor(TodayTheme.color('ink', this.mode));
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        Row({ space: 10 }) {
          this.buildIconButton('♡', TodayTheme.color('accent', this.mode), () => {
            this.openQuickRecord();
          })

          this.buildIconButton('↗', TodayTheme.color('inkSoft', this.mode), () => {})

          this.buildIconButton('↻', TodayTheme.color('inkSoft', this.mode), () => {
            this.syncFromViewModel(true);
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Text(this.timeline ? this.timeline.summary : '这是一个完整模拟日：睡眠、通勤、跑步、照片、地点和心情都会落到一张画卷里。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildIconButton(symbol: string, color: string, action: () => void): void {
    Button() {
      Text(symbol)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(color);
    }
    .width(42)
    .height(42)
    .backgroundColor(TodayTheme.surface(this.mode))
    .borderRadius(999)
    .border({
      width: 1,
      color: TodayTheme.border(this.mode)
    })
    .onClick(() => action())
  }

  @Builder
  private buildOverviewSection(): void {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.overviewStats, (item: TimelineStat) => {
          OverviewStatCard({ stat: item, mode: this.mode })
        }, (item: TimelineStat): string => item.id)
      }
      .padding({ top: 2, bottom: 2 })
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
    .height(116)
  }

  private summaryHeadline(): string {
    return this.insightSummary?.headline ?? '今天还没有总结';
  }

  private summaryNarrative(): string {
    return this.insightSummary?.narrative ?? '先记下一次心情、一个事件或一句备注。';
  }

  private summaryBadges(): Array<string> {
    return this.insightSummary?.badges ?? [];
  }

  private hasTimeline(): boolean {
    return this.timeline !== undefined;
  }

  private hasTimelineEntries(): boolean {
    return this.timeline !== undefined && this.timeline.entries.length > 0;
  }

  private timelineOrEmpty(): DayTimeline {
    if (this.timeline) {
      return this.timeline;
    }
    return {
      date: Date.now(),
      summary: '',
      source: TimelineSource.MOCK,
      stats: [],
      entries: []
    };
  }

  @Builder
  private buildSignatureSection(timeline: DayTimeline): void {
    ContentCard({ mode: this.mode }) {
      EyebrowLabel({ text: 'DAILY SIGNATURE', mode: this.mode });

      Text('今日脉络')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.color('ink', this.mode));

      Text('把一天里的起伏、停顿和推进压成一条流线，先看今天的流向，再回到具体片段。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));

      FlowSignatureView({ entries: timeline.entries, mode: this.mode })
        .height(82);

      Row() {
        Text('00:00')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkFaint', this.mode));
        Blank();
        Text('06:00')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkFaint', this.mode));
        Blank();
        Text('12:00')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkFaint', this.mode));
        Blank();
        Text('18:00')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkFaint', this.mode));
        Blank();
        Text('24:00')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(TodayTheme.color('inkFaint', this.mode));
      }
      .width('100%');
    }
  }

  @Builder
  private buildTimelineSection(timeline: DayTimeline): void {
    Column({ space: 14 }) {
      EyebrowLabel({ text: 'DAY TIMELINE', mode: this.mode });

      Text('今日时间轴')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.color('ink', this.mode));

      Text('从凌晨到夜里，一天的起伏与留白。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));

      DayScrollView({
        entries: timeline.entries,
        mode: this.mode,
        onEventTap: (event: InferredEvent) => {
          this.openEventDetail(event);
        },
        onBlankTap: (event: InferredEvent) => {
          this.openAnnotation(event);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSummarySection(): void {
    if (this.insightSummary) {
      ContentCard({ mode: this.mode }) {
        EyebrowLabel({ text: 'TODAY SUMMARY', mode: this.mode });

        Text('今日自动总结')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontStyle(FontStyle.Italic)
          .fontColor(TodayTheme.color('ink', this.mode));

        Text(this.summaryHeadline())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TodayTheme.color('inkSoft', this.mode));

        Text(this.summaryNarrative())
          .fontSize(14)
          .lineHeight(22)
          .fontColor(TodayTheme.color('inkMuted', this.mode));

        if (this.summaryBadges().length > 0) {
          FlexibleBadgeRow({
            badges: this.summaryBadges(),
            tone: 'accent',
            mode: this.mode
          })
        }
      }
    }
  }

  @Builder
  private buildRecentDaysSection(): void {
    if (this.recentDigests.length > 0) {
      ContentCard({ mode: this.mode }) {
        Row() {
          Column({ space: 6 }) {
            EyebrowLabel({ text: 'RECENT DAYS', mode: this.mode });

            Text('最近记录')
              .fontSize(24)
              .fontWeight(FontWeight.Medium)
              .fontStyle(FontStyle.Italic)
              .fontColor(TodayTheme.color('ink', this.mode));
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);

          Button('查看全部')
            .fontSize(13)
            .fontColor(TodayTheme.color('inkSoft', this.mode))
            .backgroundColor('#00000000')
            .onClick(() => {
              this.onOpenHistory();
            })
        }
        .width('100%');

        Column({ space: 10 }) {
          ForEach(this.recentDigests.slice(0, 3), (digest: RecentDayDigest) => {
            RecentDayCard({ digest: digest, mode: this.mode })
          }, (digest: RecentDayDigest): string => digest.id)
        }
        .width('100%');
      }
    }
  }

  @Builder
  private buildLoadingCard(): void {
    ContentCard({ mode: this.mode }) {
      EyebrowLabel({ text: 'LOADING', mode: this.mode });
      Text('正在整理今天的脉络...')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(TodayTheme.color('ink', this.mode));
      Text('这里会根据当前环境读取模拟数据或真实华为健康数据。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
  }

  @Builder
  private buildErrorCard(): void {
    ContentCard({ mode: this.mode }) {
      EyebrowLabel({ text: 'UNAVAILABLE', mode: this.mode });
      Text('时间线暂时不可用')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.color('ink', this.mode));
      Text(this.errorText)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
  }

  @Builder
  private buildEmptyCard(): void {
    ContentCard({ mode: this.mode }) {
      EyebrowLabel({ text: 'EMPTY STATE', mode: this.mode });
      Text('等待更多数据')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontStyle(FontStyle.Italic)
        .fontColor(TodayTheme.color('ink', this.mode));
      Text('先用下方的“记录此刻”手动打点，或者让手表继续积累心率、步数和训练数据。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
  }

  @Builder
  private buildBottomActionBar(): void {
    Column({ space: 12 }) {
      if (this.viewModel.activeRecord) {
        Column({ space: 4 }) {
          Text('进行中')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontFamily('monospace')
            .fontColor(TodayTheme.teal(this.mode))
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor(TodayTheme.tealSoft(this.mode))
            .borderRadius(TodayTheme.chipRadius());

          Text(this.viewModel.activeRecordTitle())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.textPrimary(this.mode));

          Text(this.viewModel.activeRecordDetail())
            .fontSize(13)
            .fontColor(TodayTheme.textSecondary(this.mode));
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Row({ space: 10 }) {
          Button('补一个打点')
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(TodayTheme.textPrimary(this.mode))
            .backgroundColor(TodayTheme.surface(this.mode))
            .borderRadius(18)
            .border({
              width: 1,
              color: TodayTheme.border(this.mode)
            })
            .onClick(() => {
              this.openPointComposer();
            });

          Button('结束这段状态')
            .layoutWeight(1)
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor(TodayTheme.teal(this.mode))
            .borderRadius(18)
            .onClick(() => {
              this.finishActiveRecord();
            });
        }
        .width('100%');
      } else {
        Button() {
          Column({ space: 4 }) {
            Text('+ 记录此刻')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF');

            Text('打点或开始一段状态')
              .fontSize(12)
              .fontColor(TodayTheme.alpha('#FFFFFF', 0.84));
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .backgroundColor(TodayTheme.accent(this.mode))
        .borderRadius(18)
        .onClick(() => {
          this.openQuickRecord();
        });
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(TodayTheme.alpha(TodayTheme.background(this.mode), 0.92))
    .backdropBlur(20)
    .borderRadius(22)
    .border({
      width: 1,
      color: TodayTheme.border(this.mode)
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 18 }) {
          this.buildHeader()
          this.buildOverviewSection()

          if (this.isLoading && !this.hasTimeline()) {
            this.buildLoadingCard()
          } else if (this.errorText.length > 0 && !this.hasTimeline()) {
            this.buildErrorCard()
          } else if (this.hasTimelineEntries()) {
            this.buildSignatureSection(this.timelineOrEmpty())
            this.buildTimelineSection(this.timelineOrEmpty())
          } else {
            this.buildEmptyCard()
          }

          this.buildSummarySection()

          if (this.weeklyInsight) {
            WeeklyInsightView({ insight: this.weeklyInsight, mode: this.mode })
          }

          this.buildRecentDaysSection()
        }
        .padding({
          left: 20,
          right: 20,
          top: 12,
          bottom: 230
        })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor(TodayTheme.background(this.mode));

      Column() {
        this.buildBottomActionBar()
      }
      .padding({ left: 20, right: 20, bottom: 94 });

      if (this.showQuickRecord) {
        QuickRecordSheet({
          mode: this.mode,
          quickRecordMode: this.viewModel.activeRecord ? 'pointOnly' : 'flexible',
          onDismiss: () => {
            this.closeQuickRecord();
          },
          onSave: (record: MoodRecord) => {
            this.saveRecord(record);
          }
        })
      }

      if (this.showEventDetail) {
        EventDetailView({
          event: this.selectedEvent,
          mode: this.mode,
          onDismiss: () => {
            this.showEventDetail = false;
          },
          onAnnotate: (event: InferredEvent) => {
            this.showEventDetail = false;
            this.openAnnotation(event);
          }
        })
      }

      if (this.showAnnotation) {
        AnnotationSheet({
          event: this.selectedEvent,
          mode: this.mode,
          onDismiss: () => {
            this.showAnnotation = false;
          },
          onSave: (title: string) => {
            this.saveAnnotation(title);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TodayTheme.background(this.mode))
  }
}
