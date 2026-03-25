import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';
import { getMoodDescriptor, getMoodDescriptors, Mood, MoodPhotoAttachment, MoodRecord, moodFromStoredValue } from './MoodRecord';

export enum EventKind {
  SLEEP = 'sleep',
  WORKOUT = 'workout',
  COMMUTE = 'commute',
  ACTIVE_WALK = 'activeWalk',
  QUIET_TIME = 'quietTime',
  USER_ANNOTATED = 'userAnnotated',
  MOOD = 'mood'
}

export enum EventConfidence {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2
}

export enum SleepStage {
  AWAKE = 'awake',
  REM = 'rem',
  LIGHT = 'light',
  DEEP = 'deep',
  UNKNOWN = 'unknown'
}

export enum TimelineSource {
  MOCK = 'mock',
  HEALTH_KIT = 'healthKit'
}

export interface ActivitySummaryData {
  activeEnergyBurned: number;
  activeEnergyGoal?: number;
  exerciseMinutes: number;
  exerciseGoal?: number;
  standHours: number;
  standGoal?: number;
}

export interface CoordinateValue {
  latitude: number;
  longitude: number;
}

export interface DateValueSample {
  startDate: number;
  endDate: number;
  value: number;
}

export interface HeartRateSample {
  date: number;
  value: number;
}

export interface SleepSample {
  startDate: number;
  endDate: number;
  stage: SleepStage;
}

export interface WorkoutSample {
  id?: string;
  startDate: number;
  endDate: number;
  activityType: string | number;
  activeEnergy?: number;
  distance?: number;
  displayName?: string;
}

export interface LocationVisit {
  id?: string;
  coordinate?: CoordinateValue;
  latitude?: number;
  longitude?: number;
  arrivalDate: number;
  departureDate: number;
  placeName?: string;
}

export interface HourlyWeather {
  date: number;
  temperature: number;
  condition: string;
  symbolName: string;
}

export interface PhotoReference {
  id: string;
  creationDate: number;
  date?: number;
  location?: CoordinateValue;
  pixelWidth?: number;
  pixelHeight?: number;
  placeholderColor?: string;
  color?: string;
}

export interface SleepStageSegment {
  start: number;
  end: number;
  stage: SleepStage;
}

export interface EventMetrics {
  averageHeartRate?: number;
  maxHeartRate?: number;
  minHeartRate?: number;
  heartRateSamples?: HeartRateSample[];
  weather?: HourlyWeather;
  location?: LocationVisit;
  photos?: PhotoReference[];
  sleepStages?: SleepStageSegment[];
  stepCount?: number;
  activeEnergy?: number;
  distance?: number;
  workoutType?: string | number;
}

export interface InferredEvent {
  id: string;
  kind: EventKind;
  startDate: number;
  endDate: number;
  confidence: EventConfidence;
  isLive: boolean;
  displayName: string;
  userAnnotation?: string;
  subtitle?: string;
  associatedMetrics?: EventMetrics;
  photoAttachments: MoodPhotoAttachment[];
}

export interface TimelineStat {
  id: string;
  title: string;
  label: string;
  value: string;
  tone: string;
  softTone: string;
}

export interface DayTimeline {
  date: number;
  summary: string;
  source: TimelineSource | 'mock' | 'healthKit';
  stats: TimelineStat[];
  entries: InferredEvent[];
}

export interface DayRawData {
  date: number;
  heartRateSamples: DateValueSample[];
  stepSamples: DateValueSample[];
  activeEnergySamples: DateValueSample[];
  sleepSamples: SleepSample[];
  workouts: WorkoutSample[];
  activitySummary?: ActivitySummaryData;
  locationVisits: LocationVisit[];
  hourlyWeather: HourlyWeather[];
  photos: PhotoReference[];
  moodRecords: MoodRecord[];
}

export interface InsightSummary {
  headline: string;
  narrative: string;
  badges: string[];
}

export interface WeeklyInsight {
  headline: string;
  narrative: string;
  badges: string[];
}

export interface RecentDayDigest {
  id: string;
  date: number;
  summary: string;
  dominantMood?: Mood;
  eventColors: EventKind[];
  eventCount: number;
  recordCount: number;
  moodEmoji?: string;
  title?: string;
  detail?: string;
  notePreview?: string;
  dotColor?: string;
}

export interface EventVisual {
  tone: string;
  softTone: string;
  intensity: number;
  title: string;
}

export interface MoodVisual {
  key: Mood;
  label: string;
  emoji: string;
  tone: string;
  softTone: string;
}

export class TodayStatModel {
  id: string;
  label: string;
  value: string;
  detail: string;
  tone: string;

  constructor(id: string, label: string, value: string, detail: string, tone: string) {
    this.id = id;
    this.label = label;
    this.value = value;
    this.detail = detail;
    this.tone = tone;
  }
}

export class TimelineEventModel {
  id: string;
  kind: EventKind;
  title: string;
  timeLabel: string;
  summary: string;
  badge: string;
  color: string;

  constructor(
    id: string,
    kind: EventKind,
    title: string,
    timeLabel: string,
    summary: string,
    badge: string,
    color: string
  ) {
    this.id = id;
    this.kind = kind;
    this.title = title;
    this.timeLabel = timeLabel;
    this.summary = summary;
    this.badge = badge;
    this.color = color;
  }
}

export class HistoryDigestModel {
  id: string;
  dateLabel: string;
  title: string;
  summary: string;
  moodLabel: string;
  streakLabel: string;
  color: string;

  constructor(
    id: string,
    dateLabel: string,
    title: string,
    summary: string,
    moodLabel: string,
    streakLabel: string,
    color: string
  ) {
    this.id = id;
    this.dateLabel = dateLabel;
    this.title = title;
    this.summary = summary;
    this.moodLabel = moodLabel;
    this.streakLabel = streakLabel;
    this.color = color;
  }
}

export class WeeklyInsightModel {
  headline: string;
  summary: string;
  badgeOne: string;
  badgeTwo: string;
  badgeThree: string;

  constructor(headline: string, summary: string, badgeOne: string, badgeTwo: string, badgeThree: string) {
    this.headline = headline;
    this.summary = summary;
    this.badgeOne = badgeOne;
    this.badgeTwo = badgeTwo;
    this.badgeThree = badgeThree;
  }
}

export class MoodOptionModel {
  id: string;
  label: string;
  emoji: string;
  color: string;

  constructor(id: string, label: string, emoji: string, color: string) {
    this.id = id;
    this.label = label;
    this.emoji = emoji;
    this.color = color;
  }
}

function toMillis(date: number | Date): number {
  if (date instanceof Date) {
    return date.getTime();
  }
  return date;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

function weekdayLabel(date: number | Date): string {
  const labels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return labels[new Date(toMillis(date)).getDay()];
}

function hashString(value: string): string {
  let hash = 2166136261;
  let index = 0;
  while (index < value.length) {
    hash ^= value.charCodeAt(index);
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
    index += 1;
  }
  return Math.abs(hash >>> 0).toString(16);
}

export function createStableId(seed: string): string {
  return `td-${hashString(seed)}`;
}

export function createEventId(kind: EventKind, startDate: number | Date, endDate: number | Date, displayName: string | number): string {
  return createStableId(`${kind}|${toMillis(startDate)}|${toMillis(endDate)}|${String(displayName)}`);
}

export function startOfDay(date: number | Date): number {
  const value = new Date(toMillis(date));
  value.setHours(0, 0, 0, 0);
  return value.getTime();
}

export function endOfDay(date: number | Date): number {
  const value = new Date(startOfDay(date));
  value.setHours(23, 59, 59, 999);
  return value.getTime();
}

export function durationMinutes(start: number | Date, end: number | Date): number {
  return Math.max(0, Math.round((toMillis(end) - toMillis(start)) / 60000));
}

export function formatClock(date: number | Date): string {
  const value = new Date(toMillis(date));
  return `${pad2(value.getHours())}:${pad2(value.getMinutes())}`;
}

export function formatDateFull(date: number | Date): string {
  const value = new Date(toMillis(date));
  return `${value.getFullYear()} · ${pad2(value.getMonth() + 1)} · ${pad2(value.getDate())} ${weekdayLabel(value)}`;
}

export function formatDateHeader(date: number | Date): string {
  const value = new Date(toMillis(date));
  return `${pad2(value.getMonth() + 1)}.${pad2(value.getDate())} ${weekdayLabel(value)}`;
}

export function formatDuration(durationMs: number): string {
  const totalMinutes = Math.max(0, Math.round(durationMs / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours > 0 && minutes > 0) {
    return `${hours}h ${minutes}m`;
  }
  if (hours > 0) {
    return `${hours}h`;
  }
  return `${minutes}m`;
}

export function formatDistance(distanceMeters: number | undefined): string {
  if (distanceMeters === undefined) {
    return '';
  }
  if (distanceMeters >= 1000) {
    return `${Math.round(distanceMeters / 100) / 10} 公里`;
  }
  return `${Math.round(distanceMeters)} 米`;
}

export function getMoodOptions(): MoodVisual[] {
  const items: MoodVisual[] = [];
  getMoodDescriptors().forEach((item) => {
    items.push(moodByKey(item.key));
  });
  return items;
}

export function moodByKey(mood: Mood): MoodVisual {
  const descriptor = getMoodDescriptor(mood);
  return {
    key: descriptor.key,
    label: descriptor.label,
    emoji: descriptor.emoji,
    tone: descriptor.tone,
    softTone: descriptor.softTone
  };
}

export function inferMoodKeyFromText(text: string): Mood | undefined {
  const normalized = text.trim();
  const storedMood = moodFromStoredValue(normalized);
  if (storedMood) {
    return storedMood;
  }

  const match = getMoodDescriptors().find((item) => {
    return normalized.includes(item.label) || normalized.includes(item.emoji);
  });
  return match?.key;
}

export function getEventVisual(kind: EventKind): EventVisual {
  switch (kind) {
    case EventKind.SLEEP:
      return { tone: 'sleepIndigo', softTone: 'blueSoft', intensity: 0.34, title: '睡眠' };
    case EventKind.WORKOUT:
      return { tone: 'workoutOrange', softTone: 'accentSoft', intensity: 0.92, title: '训练' };
    case EventKind.COMMUTE:
      return { tone: 'accent', softTone: 'accentSoft', intensity: 0.48, title: '通勤' };
    case EventKind.ACTIVE_WALK:
      return { tone: 'walkGreen', softTone: 'tealSoft', intensity: 0.68, title: '步行' };
    case EventKind.USER_ANNOTATED:
      return { tone: 'teal', softTone: 'tealSoft', intensity: 0.4, title: '标注' };
    case EventKind.MOOD:
      return { tone: 'rose', softTone: 'roseSoft', intensity: 0.52, title: '情绪' };
    case EventKind.QUIET_TIME:
    default:
      return { tone: 'inkMuted', softTone: 'elevatedCard', intensity: 0.2, title: '留白' };
  }
}

export function eventTintColor(event: InferredEvent | EventKind, mode: ThemeMode): string {
  const kind = typeof event === 'string' ? event : event.kind;
  return TodayTheme.color(getEventVisual(kind).tone, mode);
}

export function sleepStageTone(stage: SleepStage, mode: ThemeMode): string {
  switch (stage) {
    case SleepStage.DEEP:
      return TodayTheme.color('sleepIndigo', mode);
    case SleepStage.LIGHT:
      return TodayTheme.color('blue', mode);
    case SleepStage.REM:
      return TodayTheme.color('accent', mode);
    case SleepStage.AWAKE:
      return TodayTheme.color('rose', mode);
    default:
      return TodayTheme.color('inkFaint', mode);
  }
}

export function quietTimeTitle(startDate: number | Date): string {
  const hour = new Date(toMillis(startDate)).getHours();
  if (hour < 6) {
    return '深夜留白';
  }
  if (hour < 11) {
    return '晨间留白';
  }
  if (hour < 15) {
    return '午后留白';
  }
  if (hour < 19) {
    return '傍晚留白';
  }
  return '夜间留白';
}

export function resolveEventName(event: InferredEvent): string {
  if (event.userAnnotation && event.userAnnotation.trim().length > 0) {
    return event.userAnnotation;
  }
  if (event.displayName.trim().length > 0) {
    return event.displayName;
  }
  return getEventVisual(event.kind).title;
}

export function isBlankCandidate(event: InferredEvent): boolean {
  return event.kind === EventKind.QUIET_TIME;
}

export function eventSubtitleFragments(event: InferredEvent): string[] {
  const fragments: string[] = [];
  if (event.subtitle && event.subtitle.trim().length > 0) {
    const pieces = event.subtitle.split('·').map((item) => item.trim()).filter((item) => item.length > 0);
    pieces.forEach((item) => {
      fragments.push(item);
    });
  }
  if (event.userAnnotation && event.userAnnotation.trim().length > 0) {
    fragments.push(event.userAnnotation.trim());
  }
  return fragments;
}

export function buildTimelineStats(timeline: DayTimeline, manualRecordCount: number, noteCount: number): TimelineStat[] {
  const sleepDuration = timeline.entries
    .filter((item) => item.kind === EventKind.SLEEP)
    .reduce((sum, item) => sum + (item.endDate - item.startDate), 0);
  const moveDuration = timeline.entries
    .filter((item) => item.kind === EventKind.ACTIVE_WALK || item.kind === EventKind.COMMUTE || item.kind === EventKind.WORKOUT)
    .reduce((sum, item) => sum + (item.endDate - item.startDate), 0);

  return [
    {
      id: 'sleep',
      title: '睡眠',
      label: '睡眠',
      value: formatDuration(sleepDuration),
      tone: 'sleepIndigo',
      softTone: 'blueSoft'
    },
    {
      id: 'move',
      title: '移动',
      label: '移动',
      value: formatDuration(moveDuration),
      tone: 'walkGreen',
      softTone: 'tealSoft'
    },
    {
      id: 'record',
      title: '记录',
      label: '记录',
      value: `${manualRecordCount}/${Math.max(manualRecordCount, noteCount)} 条`,
      tone: 'accent',
      softTone: 'accentSoft'
    }
  ];
}

export function resolveWorkoutDisplayName(activityType: string | number): string {
  if (typeof activityType === 'number') {
    return '训练';
  }
  return activityType;
}

function moodLabelAt(index: number): string {
  const labels = ['平静', '专注', '开心', '疲惫', '兴奋', '困倦'];
  return labels[index % labels.length];
}

function summaryAt(index: number): string {
  const labels = [
    '节律稳定，下午步行量明显提升。',
    '睡眠恢复不错，夜间心率更平滑。',
    '工作块专注时间长，晚间留白更充分。',
    '运动后恢复更快，晚上状态更轻松。'
  ];
  return labels[index % labels.length];
}

function titleAt(index: number): string {
  const labels = ['稳稳推进', '呼吸顺了', '专注在线', '节奏拉满'];
  return labels[index % labels.length];
}

function formatMonthDay(date: number | Date): string {
  const value = new Date(toMillis(date));
  return `${pad2(value.getMonth() + 1)}月${pad2(value.getDate())}日`;
}

export function buildTodayStats(): TodayStatModel[] {
  return [
    new TodayStatModel('sleep', '睡眠', '7h 42m', '深睡 1h 38m', TodayTheme.color('sleepIndigo', ThemeMode.Light)),
    new TodayStatModel('energy', '活力', '83', '较昨天 +6', TodayTheme.color('accent', ThemeMode.Light)),
    new TodayStatModel('walk', '步行', '8,426', '午后完成 62%', TodayTheme.color('walkGreen', ThemeMode.Light))
  ];
}

export function buildTodayEvents(): TimelineEventModel[] {
  return [
    new TimelineEventModel('sleep-1', EventKind.SLEEP, '整夜睡眠', '00:18 - 07:36', '睡眠段完整，清晨醒来前 REM 比例更高。', '恢复良好', TodayTheme.color('sleepIndigo', ThemeMode.Light)),
    new TimelineEventModel('focus-1', EventKind.QUIET_TIME, '上午深度专注', '09:10 - 11:05', '心率稳定，步数较少，说明这段时间进入了连续工作流。', '工作流', TodayTheme.color('teal', ThemeMode.Light)),
    new TimelineEventModel('walk-1', EventKind.ACTIVE_WALK, '午后快走', '13:24 - 13:56', '午饭后有一段明显的步行高峰，步频和热量都抬起来了。', '轻运动', TodayTheme.color('walkGreen', ThemeMode.Light)),
    new TimelineEventModel('workout-1', EventKind.WORKOUT, '傍晚训练', '18:40 - 19:18', '高强度区间出现两次，整体恢复时间比上周更短。', '训练完成', TodayTheme.color('workoutOrange', ThemeMode.Light)),
    new TimelineEventModel('mood-1', EventKind.MOOD, '情绪打点', '21:12', '你记录了“平静”，并备注今天的完成感比预期更高。', '自我记录', TodayTheme.color('rose', ThemeMode.Light))
  ];
}

export function buildHistoryDigests(): HistoryDigestModel[] {
  const items: HistoryDigestModel[] = [];
  const today = startOfDay(Date.now());
  let index = 0;
  while (index < 14) {
    const date = today - index * 24 * 60 * 60 * 1000;
    items.push(
      new HistoryDigestModel(
        `day-${index}`,
        formatMonthDay(date),
        titleAt(index),
        summaryAt(index),
        moodLabelAt(index),
        `连续记录 ${14 - index} 天`,
        index % 2 === 0 ? TodayTheme.color('teal', ThemeMode.Light) : TodayTheme.color('accent', ThemeMode.Light)
      )
    );
    index += 1;
  }
  return items;
}

export function buildWeeklyInsight(): WeeklyInsightModel {
  return new WeeklyInsightModel(
    '这周的节律比上周更稳',
    '睡眠起床时间更集中，下午的步行和晚间恢复段也更成体系，已经开始形成一条比较清晰的生活曲线。',
    '平均睡眠 7h 42m',
    '运动完成 4 次',
    '情绪记录 11 次'
  );
}

export function buildMoodOptions(): MoodOptionModel[] {
  return getMoodOptions().slice(0, 6).map((item) => {
    return new MoodOptionModel(item.key, item.label, item.emoji, TodayTheme.color(item.tone, ThemeMode.Light));
  });
}
