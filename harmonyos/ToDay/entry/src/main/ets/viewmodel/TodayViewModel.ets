import { MoodRecord } from '../model/MoodRecord';
import { ThemeMode } from '../common/theme/TodayTheme';
import { DayDataAggregator } from '../data/DayDataAggregator';
import { HealthDataProvider } from '../data/HealthDataProvider';
import { LocationService } from '../data/LocationService';
import { StorageService } from '../data/StorageService';
import { WeatherService } from '../data/WeatherService';
import {
  DayTimeline,
  EventKind,
  InferredEvent,
  InsightSummary,
  RecentDayDigest,
  startOfDay,
  WeeklyInsight
} from '../model/SharedDataTypes';

const DAY_MS = 24 * 60 * 60 * 1000;

function formatClock(date: number): string {
  const value = new Date(date);
  return `${String(value.getHours()).padStart(2, '0')}:${String(value.getMinutes()).padStart(2, '0')}`;
}

@Observed
export class TodayViewModel {
  timeline?: DayTimeline = undefined;
  isLoading: boolean = false;
  errorMessage: string = '';
  showQuickRecord: boolean = false;
  quickRecordMode: 'flexible' | 'pointOnly' = 'flexible';
  activeRecord?: MoodRecord = undefined;
  insightSummary?: InsightSummary = undefined;
  weeklyInsight?: WeeklyInsight = undefined;
  recentDigests: RecentDayDigest[] = [];
  historyDigests: RecentDayDigest[] = [];
  todayManualRecordCount: number = 0;
  todayNoteCount: number = 0;
  healthPermissionStatus: string = 'Mock';
  locationPermissionStatus: string = 'Mock';
  photoPermissionStatus: string = '预留';
  themeMode: ThemeMode = ThemeMode.Light;

  private readonly aggregator: DayDataAggregator;
  private readonly storage: StorageService;
  private readonly healthProvider: HealthDataProvider;
  private readonly locationService: LocationService;
  private readonly weatherService: WeatherService;
  private initialized: boolean = false;
  private hasLoadedOnce: boolean = false;
  private moodRecords: MoodRecord[] = [];
  private annotations: Map<string, string> = new Map();
  private timelineCache: Map<number, DayTimeline> = new Map();

  constructor(
    aggregator: DayDataAggregator,
    storage: StorageService,
    healthProvider: HealthDataProvider,
    locationService: LocationService,
    weatherService: WeatherService
  ) {
    this.aggregator = aggregator;
    this.storage = storage;
    this.healthProvider = healthProvider;
    this.locationService = locationService;
    this.weatherService = weatherService;
  }

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.moodRecords = await this.storage.loadMoodRecords();
    this.annotations = await this.storage.loadAnnotations();
    this.activeRecord = this.findActiveRecord();
    this.healthPermissionStatus = this.healthProvider.isAvailable() ? '可用' : 'Mock';
    this.locationPermissionStatus = await this.locationService.getPermissionStatus();
    this.photoPermissionStatus = '预留';
    await this.weatherService.getPermissionStatus();
    await this.loadIfNeeded();
  }

  setThemeMode(mode: ThemeMode): void {
    this.themeMode = mode;
  }

  async loadIfNeeded(): Promise<void> {
    if (this.hasLoadedOnce) {
      return;
    }
    await this.load(false);
  }

  async load(forceReload: boolean = false): Promise<void> {
    if (this.isLoading) {
      return;
    }

    const today = startOfDay(Date.now());
    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.updateTodayCounters(today);
      const timeline = await this.aggregator.loadTimeline(
        today,
        this.recordsOnDate(today),
        this.todayNoteCount,
        forceReload
      );
      const applied = this.applyAnnotations(timeline);
      this.timeline = applied;
      this.timelineCache.set(today, applied);
      this.insightSummary = this.aggregator.composeInsightSummary(applied);
      await this.loadHistoryWindow(today, forceReload);
      this.hasLoadedOnce = true;
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '加载失败';
      }
    }

    this.isLoading = false;
  }

  openQuickRecordComposer(): void {
    this.quickRecordMode = this.activeRecord ? 'pointOnly' : 'flexible';
    this.showQuickRecord = true;
  }

  openPointComposer(): void {
    this.quickRecordMode = 'pointOnly';
    this.showQuickRecord = true;
  }

  async startMoodRecord(record: MoodRecord): Promise<void> {
    if (record.captureMode === 'session' && this.activeRecord) {
      this.errorMessage = '先结束当前状态，再开始新的一段。';
      return;
    }

    const nextRecords = this.moodRecords.slice();
    nextRecords.unshift(record);
    nextRecords.sort((left, right) => right.createdAt - left.createdAt);
    this.moodRecords = nextRecords;

    if (record.isTracking) {
      this.activeRecord = record;
    }
    this.showQuickRecord = false;
    await this.storage.saveMoodRecords(this.moodRecords);
    await this.load(true);
  }

  async finishActiveMoodRecord(): Promise<void> {
    if (!this.activeRecord) {
      return;
    }

    const updatedRecords: MoodRecord[] = [];
    const activeRecordId = this.activeRecord.id;
    this.moodRecords.forEach((record) => {
      if (record.id !== activeRecordId) {
        updatedRecords.push(record);
        return;
      }

      updatedRecords.push({
        id: record.id,
        mood: record.mood,
        note: record.note,
        createdAt: record.createdAt,
        endedAt: Date.now(),
        isTracking: false,
        captureMode: 'session',
        photoAttachments: record.photoAttachments
      });
    });

    this.moodRecords = updatedRecords;
    this.activeRecord = undefined;
    await this.storage.saveMoodRecords(this.moodRecords);
    await this.load(true);
  }

  async annotateEvent(event: InferredEvent, title: string): Promise<void> {
    const trimmed = title.trim();
    if (trimmed.length === 0) {
      return;
    }

    this.annotations.set(event.id, trimmed);
    await this.storage.annotateEvent(event.id, trimmed);
    if (this.timeline) {
      this.timeline = this.applyAnnotations(this.timeline);
    }
  }

  async loadTimelines(dates: number[], forceReload: boolean = false): Promise<DayTimeline[]> {
    const result: DayTimeline[] = [];
    for (const date of dates) {
      const day = startOfDay(date);
      const timeline = await this.aggregator.loadTimeline(day, this.recordsOnDate(day), this.noteCountOnDate(day), forceReload);
      const applied = this.applyAnnotations(timeline);
      this.timelineCache.set(day, applied);
      result.push(applied);
    }
    return result;
  }

  timelineForDate(date: number): DayTimeline | undefined {
    return this.timelineCache.get(startOfDay(date));
  }

  digestForDate(date: number): RecentDayDigest | undefined {
    const day = startOfDay(date);
    return this.historyDigests.find((item) => startOfDay(item.date) === day);
  }

  async clearAllData(): Promise<void> {
    await this.storage.clearAll();
    this.moodRecords = [];
    this.annotations.clear();
    this.activeRecord = undefined;
    this.timeline = undefined;
    this.recentDigests = [];
    this.historyDigests = [];
    this.hasLoadedOnce = false;
    await this.load(true);
  }

  quickRecordCaption(): string {
    if (!this.activeRecord) {
      return '打点或开始一段状态';
    }
    return '当前已有进行中的状态';
  }

  activeRecordTitle(): string {
    if (!this.activeRecord) {
      return '';
    }
    return '进行中的状态';
  }

  activeRecordDetail(): string {
    if (!this.activeRecord) {
      return '';
    }
    return `${formatClock(this.activeRecord.createdAt)} 开始`;
  }

  private async loadHistoryWindow(anchorDate: number, forceReload: boolean = false): Promise<void> {
    const dates: number[] = [];
    for (let offset = 13; offset >= 0; offset -= 1) {
      dates.push(anchorDate - offset * DAY_MS);
    }
    const timelines = await this.loadTimelines(dates, forceReload);
    const sorted = timelines.slice();
    sorted.sort((left, right) => right.date - left.date);
    this.historyDigests = sorted.map((timeline) => this.aggregator.toRecentDigest(timeline));
    this.recentDigests = this.historyDigests.slice(0, 3);
    this.weeklyInsight = this.aggregator.composeWeeklyInsight(timelines);
  }

  private updateTodayCounters(date: number): void {
    const records = this.recordsOnDate(date);
    this.todayManualRecordCount = records.length;
    this.todayNoteCount = records.filter((item) => item.note.trim().length > 0).length;
  }

  private recordsOnDate(date: number): MoodRecord[] {
    const day = startOfDay(date);
    return this.moodRecords.filter((record) => startOfDay(record.createdAt) === day);
  }

  private noteCountOnDate(date: number): number {
    return this.recordsOnDate(date).filter((item) => item.note.trim().length > 0).length;
  }

  private findActiveRecord(): MoodRecord | undefined {
    let result: MoodRecord | undefined = undefined;
    this.moodRecords.forEach((item) => {
      if (!result && item.isTracking) {
        result = item;
      }
    });
    return result;
  }

  private applyAnnotations(timeline: DayTimeline): DayTimeline {
    const entries: InferredEvent[] = [];

    timeline.entries.forEach((entry) => {
      const annotation = this.annotations.get(entry.id);
      if (!annotation) {
        entries.push(entry);
        return;
      }

      entries.push({
        id: entry.id,
        kind: entry.kind === EventKind.QUIET_TIME ? EventKind.USER_ANNOTATED : entry.kind,
        startDate: entry.startDate,
        endDate: entry.endDate,
        confidence: entry.confidence,
        isLive: entry.isLive,
        displayName: entry.displayName,
        userAnnotation: annotation,
        subtitle: entry.subtitle,
        associatedMetrics: entry.associatedMetrics,
        photoAttachments: entry.photoAttachments
      });
    });

    return {
      date: timeline.date,
      summary: timeline.summary,
      source: timeline.source,
      stats: timeline.stats,
      entries
    };
  }
}
