import { MoodRecord } from '../model/MoodRecord';
import {
  buildTimelineStats,
  DayRawData,
  DayTimeline,
  EventKind,
  formatDuration,
  inferMoodKeyFromText,
  InferredEvent,
  InsightSummary,
  RecentDayDigest,
  startOfDay,
  WeeklyInsight
} from '../model/SharedDataTypes';
import { EventInferenceEngine } from './EventInferenceEngine';
import { DayDataProvider } from './HealthDataProvider';
import { StorageService } from './StorageService';

export class DayDataAggregator {
  private readonly provider: DayDataProvider;
  private readonly engine: EventInferenceEngine;
  private readonly storage: StorageService;

  constructor(provider: DayDataProvider, engine: EventInferenceEngine, storage: StorageService) {
    this.provider = provider;
    this.engine = engine;
    this.storage = storage;
  }

  async loadTimeline(date: number, manualRecords: MoodRecord[], noteCount: number, forceReload: boolean = false): Promise<DayTimeline> {
    const day = startOfDay(date);
    if (!forceReload) {
      const cached = await this.storage.loadTimeline(day);
      if (cached) {
        return this.withStats(cached, manualRecords.length, noteCount);
      }
    }

    const rawData = await this.provider.loadDayRawData(day);
    const mergedRawData = this.mergeManualRecords(rawData, manualRecords);
    const entries = await this.engine.inferEvents(mergedRawData, day);

    const timeline: DayTimeline = {
      date: day,
      summary: this.composeSummary(entries),
      source: this.provider.source,
      stats: [],
      entries
    };
    timeline.stats = buildTimelineStats(timeline, manualRecords.length, noteCount);
    await this.storage.saveTimeline(timeline);
    return timeline;
  }

  composeInsightSummary(timeline: DayTimeline): InsightSummary {
    let workoutCount = 0;
    let walkDuration = 0;
    let sleepDuration = 0;

    timeline.entries.forEach((item) => {
      if (item.kind === EventKind.WORKOUT) {
        workoutCount += 1;
      }
      if (item.kind === EventKind.ACTIVE_WALK || item.kind === EventKind.COMMUTE) {
        walkDuration += item.endDate - item.startDate;
      }
      if (item.kind === EventKind.SLEEP) {
        sleepDuration += item.endDate - item.startDate;
      }
    });

    return {
      headline: workoutCount > 0 ? `活跃的一天，完成 ${workoutCount} 段训练` : '今天整体节奏平稳',
      narrative: `你把${formatDuration(walkDuration)}的移动和${formatDuration(sleepDuration)}的休息都留了下来，画卷里既有推进也有停顿。`,
      badges: [
        `${timeline.entries.length} 个片段`,
        `${Math.round(walkDuration / 60000)} 分钟移动`,
        `${Math.round((sleepDuration / 3600000) * 10) / 10} 小时睡眠`
      ]
    };
  }

  composeWeeklyInsight(timelines: DayTimeline[]): WeeklyInsight {
    const startIndex = Math.max(0, timelines.length - 7);
    const valid = timelines.slice(startIndex);
    let stepTotal = 0;
    let workoutCount = 0;
    let sleepTotal = 0;

    valid.forEach((timeline) => {
      timeline.entries.forEach((entry) => {
        stepTotal += entry.associatedMetrics?.stepCount ?? 0;
        if (entry.kind === EventKind.WORKOUT) {
          workoutCount += 1;
        }
        if (entry.kind === EventKind.SLEEP) {
          sleepTotal += entry.endDate - entry.startDate;
        }
      });
    });

    const divisor = Math.max(1, valid.length);
    const averageSteps = stepTotal / divisor;
    const averageSleepHours = sleepTotal / divisor / 3600000;

    return {
      headline: workoutCount >= 4 ? '本周节律稳定而有推进' : '本周更偏向温和的日常节奏',
      narrative: `最近 7 天平均每天 ${Math.round(averageSteps)} 步，训练 ${workoutCount} 次，睡眠 ${Math.round(averageSleepHours * 10) / 10} 小时。`,
      badges: [
        `日均 ${Math.round(averageSteps)} 步`,
        `运动 ${workoutCount} 次`,
        `睡眠 ${Math.round(averageSleepHours * 10) / 10} 小时`
      ]
    };
  }

  toRecentDigest(timeline: DayTimeline): RecentDayDigest {
    let moodTitle = '';
    let moodSubtitle = '';
    const eventColors: EventKind[] = [];

    timeline.entries.forEach((item) => {
      if (item.kind === EventKind.MOOD && moodTitle.length === 0) {
        moodTitle = item.displayName;
        moodSubtitle = item.subtitle ?? '';
      }
      if (item.kind !== EventKind.MOOD && eventColors.length < 6) {
        eventColors.push(item.kind);
      }
    });

    const dominantMood = moodTitle.length > 0 ? inferMoodKeyFromText(moodTitle) : undefined;
    return {
      id: `digest-${timeline.date}`,
      date: timeline.date,
      summary: timeline.summary,
      dominantMood,
      eventColors,
      eventCount: timeline.entries.length,
      recordCount: timeline.entries.filter((item) => item.kind === EventKind.MOOD).length,
      moodEmoji: moodTitle.length > 0 ? moodTitle.slice(0, 2) : undefined,
      title: timeline.summary,
      detail: timeline.summary,
      notePreview: moodSubtitle.length > 0 ? moodSubtitle : undefined,
      dotColor: eventColors.length > 0 ? `${eventColors[0]}` : undefined
    };
  }

  private withStats(timeline: DayTimeline, manualRecordCount: number, noteCount: number): DayTimeline {
    return {
      date: timeline.date,
      summary: timeline.summary,
      source: timeline.source,
      stats: buildTimelineStats(timeline, manualRecordCount, noteCount),
      entries: timeline.entries
    };
  }

  private mergeManualRecords(rawData: DayRawData, manualRecords: MoodRecord[]): DayRawData {
    return {
      date: rawData.date,
      heartRateSamples: rawData.heartRateSamples,
      stepSamples: rawData.stepSamples,
      activeEnergySamples: rawData.activeEnergySamples,
      sleepSamples: rawData.sleepSamples,
      workouts: rawData.workouts,
      activitySummary: rawData.activitySummary,
      locationVisits: rawData.locationVisits,
      hourlyWeather: rawData.hourlyWeather,
      photos: rawData.photos,
      moodRecords: manualRecords
    };
  }

  private composeSummary(entries: InferredEvent[]): string {
    let workoutName = '';
    let sleepDurationText = '';
    let moodName = '';

    entries.forEach((item) => {
      if (workoutName.length === 0 && item.kind === EventKind.WORKOUT) {
        workoutName = item.displayName;
      }
      if (sleepDurationText.length === 0 && item.kind === EventKind.SLEEP) {
        sleepDurationText = formatDuration(item.endDate - item.startDate);
      }
      if (moodName.length === 0 && item.kind === EventKind.MOOD) {
        moodName = item.displayName;
      }
    });

    if (workoutName.length > 0 && sleepDurationText.length > 0 && moodName.length > 0) {
      return `今天先从 ${sleepDurationText} 的睡眠开始，傍晚有一段 ${workoutName}，最后用 ${moodName} 收尾。`;
    }

    if (workoutName.length > 0) {
      return `今天有一段明显的推进：${workoutName}，其余时间保持温和节奏。`;
    }

    return '先把今天铺成一张可回看的画卷，再决定哪些片段值得长期留下。';
  }
}
