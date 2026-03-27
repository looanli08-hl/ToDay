import { MoodRecord } from '../model/MoodRecord';
import {
  createEventId,
  DateValueSample,
  DayRawData,
  EventConfidence,
  EventKind,
  EventMetrics,
  formatDistance,
  formatDuration,
  HeartRateSample,
  HourlyWeather,
  InferredEvent,
  LocationVisit,
  PhotoReference,
  quietTimeTitle,
  resolveWorkoutDisplayName,
  SleepSample,
  SleepStage,
  SleepStageSegment,
  startOfDay,
  endOfDay,
  WorkoutSample,
  moodByKey
} from '../model/SharedDataTypes';

const MERGE_GAP_THRESHOLD = 5 * 60 * 1000;
const MINIMUM_INFERRED_DURATION = 5 * 60 * 1000;
const MOVEMENT_MIN_CLUSTER_DURATION = 10 * 60 * 1000;
const ELEVATED_HR_OFFSET = 30;

interface HasStartDate {
  startDate: number;
}

function overlaps(startA: number, endA: number, startB: number, endB: number): boolean {
  return startA < endB && endA > startB;
}

function overlapDuration(startA: number, endA: number, startB: number, endB: number): number {
  if (!overlaps(startA, endA, startB, endB)) {
    return 0;
  }
  return Math.min(endA, endB) - Math.max(startA, startB);
}

function average(values: number[]): number | undefined {
  if (values.length === 0) {
    return undefined;
  }
  let total = 0;
  let index = 0;
  while (index < values.length) {
    total += values[index];
    index += 1;
  }
  return total / values.length;
}

function maxValue(values: number[]): number | undefined {
  if (values.length === 0) {
    return undefined;
  }
  let result = values[0];
  let index = 1;
  while (index < values.length) {
    result = Math.max(result, values[index]);
    index += 1;
  }
  return result;
}

function minValue(values: number[]): number | undefined {
  if (values.length === 0) {
    return undefined;
  }
  let result = values[0];
  let index = 1;
  while (index < values.length) {
    result = Math.min(result, values[index]);
    index += 1;
  }
  return result;
}

function cloneAndSortByStart<T extends HasStartDate>(items: Array<T>): Array<T> {
  const copied = items.slice();
  copied.sort((left, right) => left.startDate - right.startDate);
  return copied;
}

function buildBaseEvent(
  id: string,
  kind: EventKind,
  startDate: number,
  endDate: number,
  confidence: EventConfidence,
  displayName: string
): InferredEvent {
  return {
    id,
    kind,
    startDate,
    endDate,
    confidence,
    isLive: false,
    displayName,
    subtitle: '',
    photoAttachments: []
  };
}

export class EventInferenceEngine {
  async inferEvents(rawData: DayRawData, date: number): Promise<InferredEvent[]> {
    const dayStart = startOfDay(date);
    const dayEnd = endOfDay(date);

    if (
      rawData.sleepSamples.length === 0 &&
      rawData.workouts.length === 0 &&
      rawData.stepSamples.length === 0 &&
      rawData.moodRecords.length === 0
    ) {
      return [this.createQuietEvent(dayStart, dayEnd)];
    }

    const fixedEvents: InferredEvent[] = [];
    const sleepEvents = this.buildSleepEvents(rawData.sleepSamples);
    const workoutEvents = this.buildWorkoutEvents(rawData.workouts);
    sleepEvents.forEach((item) => fixedEvents.push(item));
    workoutEvents.forEach((item) => fixedEvents.push(item));
    fixedEvents.sort((left, right) => left.startDate - right.startDate);

    const movementEvents = this.buildMovementEvents(rawData, fixedEvents);
    const timelineEvents: InferredEvent[] = [];
    fixedEvents.forEach((item) => timelineEvents.push(item));
    movementEvents.forEach((item) => timelineEvents.push(item));
    timelineEvents.sort((left, right) => left.startDate - right.startDate);

    const quietEvents = this.buildQuietEvents(timelineEvents, rawData.date);
    const moodEvents = this.buildMoodEvents(rawData.moodRecords);

    const allEvents: InferredEvent[] = [];
    timelineEvents.forEach((item) => allEvents.push(item));
    quietEvents.forEach((item) => allEvents.push(item));
    moodEvents.forEach((item) => allEvents.push(item));

    const finalEvents: InferredEvent[] = [];
    allEvents.sort((left, right) => left.startDate - right.startDate);
    allEvents.forEach((item) => {
      finalEvents.push(this.attachMetrics(item, rawData));
    });
    return finalEvents;
  }

  private buildSleepEvents(samples: SleepSample[]): InferredEvent[] {
    const result: InferredEvent[] = [];
    const sorted = cloneAndSortByStart(samples);
    let current: SleepSample[] = [];

    sorted.forEach((sample) => {
      if (current.length === 0) {
        current.push(sample);
        return;
      }

      const previous = current[current.length - 1];
      if (sample.startDate - previous.endDate <= MERGE_GAP_THRESHOLD) {
        current.push(sample);
        return;
      }

      result.push(this.makeSleepEvent(current));
      current = [sample];
    });

    if (current.length > 0) {
      result.push(this.makeSleepEvent(current));
    }

    return result;
  }

  private makeSleepEvent(samples: SleepSample[]): InferredEvent {
    const startDate = samples[0].startDate;
    const endDate = samples[samples.length - 1].endDate;
    const durations = new Map<SleepStage, number>();
    const sleepStages: SleepStageSegment[] = [];

    samples.forEach((sample) => {
      const duration = sample.endDate - sample.startDate;
      const current = durations.get(sample.stage) ?? 0;
      durations.set(sample.stage, current + duration);
      sleepStages.push({
        start: sample.startDate,
        end: sample.endDate,
        stage: sample.stage
      });
    });

    const order: SleepStage[] = [SleepStage.DEEP, SleepStage.LIGHT, SleepStage.REM, SleepStage.AWAKE];
    const subtitleParts: string[] = [];
    order.forEach((stage) => {
      if (durations.has(stage)) {
        subtitleParts.push(`${this.sleepStageLabel(stage)} ${formatDuration(durations.get(stage) ?? 0)}`);
      }
    });

    const metrics: EventMetrics = {};
    metrics.sleepStages = sleepStages;

    const event = buildBaseEvent(
      createEventId(EventKind.SLEEP, startDate, endDate, '睡眠'),
      EventKind.SLEEP,
      startDate,
      endDate,
      EventConfidence.HIGH,
      '睡眠'
    );
    event.subtitle = subtitleParts.join(', ');
    event.associatedMetrics = metrics;
    return event;
  }

  private buildWorkoutEvents(workouts: WorkoutSample[]): InferredEvent[] {
    const result: InferredEvent[] = [];
    workouts.forEach((workout) => {
      const duration = workout.endDate - workout.startDate;
      const fragments: string[] = [];
      const workoutName = workout.displayName ?? resolveWorkoutDisplayName(workout.activityType);
      fragments.push(formatDuration(duration));
      if (workout.activeEnergy !== undefined) {
        fragments.push(`${Math.round(workout.activeEnergy)} 千卡`);
      }
      if (workout.distance !== undefined) {
        fragments.push(formatDistance(workout.distance));
      }

      const metrics: EventMetrics = {};
      metrics.activeEnergy = workout.activeEnergy;
      metrics.distance = workout.distance;
      metrics.workoutType = workoutName;

      const event = buildBaseEvent(
        createEventId(EventKind.WORKOUT, workout.startDate, workout.endDate, workout.activityType),
        EventKind.WORKOUT,
        workout.startDate,
        workout.endDate,
        EventConfidence.HIGH,
        workoutName
      );
      event.subtitle = fragments.filter((item) => item.length > 0).join(' · ');
      event.associatedMetrics = metrics;
      result.push(event);
    });
    return result;
  }

  private buildMovementEvents(rawData: DayRawData, fixedEvents: InferredEvent[]): InferredEvent[] {
    const steps = cloneAndSortByStart(rawData.stepSamples);
    const heartRateValues = rawData.heartRateSamples.map((sample) => sample.value);
    heartRateValues.sort((left, right) => left - right);
    const restingLength = Math.max(1, Math.ceil(heartRateValues.length * 0.25));
    const restingSlice = heartRateValues.slice(0, restingLength);
    const restingHeartRate = average(restingSlice) ?? 60;
    const threshold = restingHeartRate + ELEVATED_HR_OFFSET;

    const clusters: DateValueSample[][] = [];
    let current: DateValueSample[] = [];

    steps.forEach((sample) => {
      let inFixedEvent = false;
      fixedEvents.forEach((event) => {
        if (overlaps(sample.startDate, sample.endDate, event.startDate, event.endDate)) {
          inFixedEvent = true;
        }
      });
      if (inFixedEvent) {
        return;
      }

      if (current.length === 0) {
        current.push(sample);
        return;
      }

      const previous = current[current.length - 1];
      if (sample.startDate - previous.endDate <= MERGE_GAP_THRESHOLD) {
        current.push(sample);
      } else {
        clusters.push(current);
        current = [sample];
      }
    });

    if (current.length > 0) {
      clusters.push(current);
    }

    const result: InferredEvent[] = [];
    clusters.forEach((cluster) => {
      const event = this.classifyMovementCluster(cluster, rawData, threshold);
      if (event) {
        result.push(event);
      }
    });
    return result;
  }

  private classifyMovementCluster(
    cluster: DateValueSample[],
    rawData: DayRawData,
    elevatedHrThreshold: number
  ): InferredEvent | undefined {
    const startDate = cluster[0].startDate;
    const endDate = cluster[cluster.length - 1].endDate;
    const duration = endDate - startDate;
    if (duration < MOVEMENT_MIN_CLUSTER_DURATION) {
      return undefined;
    }

    let totalSteps = 0;
    cluster.forEach((sample) => {
      totalSteps += sample.value;
    });
    const cadence = totalSteps / Math.max(1, duration / 60000);
    const heartRateValues: number[] = [];
    rawData.heartRateSamples.forEach((sample) => {
      if (overlaps(sample.startDate, sample.endDate, startDate, endDate)) {
        heartRateValues.push(sample.value);
      }
    });
    const averageHr = average(heartRateValues) ?? 0;

    let kind = EventKind.ACTIVE_WALK;
    let confidence = EventConfidence.MEDIUM;
    let displayName = '活跃步行';

    if (averageHr >= elevatedHrThreshold && cadence >= 60) {
      kind = EventKind.ACTIVE_WALK;
      confidence = EventConfidence.HIGH;
      displayName = '活跃步行';
    } else if (averageHr >= elevatedHrThreshold && cadence < 60) {
      kind = EventKind.QUIET_TIME;
      confidence = EventConfidence.MEDIUM;
      displayName = '安静的片刻';
    } else if (cadence >= 60) {
      kind = EventKind.ACTIVE_WALK;
      confidence = EventConfidence.MEDIUM;
      displayName = '步行片段';
    } else {
      const startHour = new Date(startDate).getHours();
      if ((startHour === 7 || startHour === 8 || startHour === 17 || startHour === 18) && duration >= 15 * 60 * 1000 && duration <= 60 * 60 * 1000) {
        kind = EventKind.COMMUTE;
        confidence = EventConfidence.MEDIUM;
        displayName = '通勤路上';
      }
    }

    if (duration < MINIMUM_INFERRED_DURATION) {
      return undefined;
    }

    const metrics: EventMetrics = {};
    metrics.stepCount = Math.round(totalSteps);
    metrics.averageHeartRate = averageHr;

    const event = buildBaseEvent(
      createEventId(kind, startDate, endDate, displayName),
      kind,
      startDate,
      endDate,
      confidence,
      displayName
    );
    event.subtitle = `${Math.round(totalSteps)} 步 · 平均 ${Math.round(averageHr || 72)} 次/分`;
    event.associatedMetrics = metrics;
    return event;
  }

  private buildQuietEvents(events: InferredEvent[], date: number): InferredEvent[] {
    const dayStart = startOfDay(date);
    const dayEnd = endOfDay(date);
    const boundaries: number[] = [
      dayStart + 6 * 60 * 60 * 1000,
      dayStart + 12 * 60 * 60 * 1000,
      dayStart + 14 * 60 * 60 * 1000,
      dayStart + 18 * 60 * 60 * 1000,
      dayStart + 22 * 60 * 60 * 1000,
      dayEnd
    ];
    const result: InferredEvent[] = [];
    let cursor = dayStart;

    events.forEach((event) => {
      if (event.startDate > cursor) {
        const segments = this.segmentQuietRange(cursor, event.startDate, boundaries);
        segments.forEach((item) => result.push(item));
      }
      cursor = Math.max(cursor, event.endDate);
    });

    if (cursor < dayEnd) {
      const segments = this.segmentQuietRange(cursor, dayEnd, boundaries);
      segments.forEach((item) => result.push(item));
    }

    const filtered: InferredEvent[] = [];
    result.forEach((item) => {
      if (item.endDate - item.startDate >= MINIMUM_INFERRED_DURATION) {
        filtered.push(item);
      }
    });
    return filtered;
  }

  private segmentQuietRange(startDate: number, endDate: number, boundaries: number[]): InferredEvent[] {
    const result: InferredEvent[] = [];
    let segmentStart = startDate;
    boundaries.forEach((boundary) => {
      if (segmentStart >= endDate) {
        return;
      }
      const segmentEnd = Math.min(boundary, endDate);
      if (segmentEnd > segmentStart) {
        result.push(this.createQuietEvent(segmentStart, segmentEnd));
        segmentStart = segmentEnd;
      }
    });
    return result;
  }

  private createQuietEvent(startDate: number, endDate: number): InferredEvent {
    const title = quietTimeTitle(startDate);
    const event = buildBaseEvent(
      createEventId(EventKind.QUIET_TIME, startDate, endDate, title),
      EventKind.QUIET_TIME,
      startDate,
      endDate,
      EventConfidence.LOW,
      title
    );
    event.subtitle = formatDuration(endDate - startDate);
    return event;
  }

  private buildMoodEvents(records: MoodRecord[]): InferredEvent[] {
    const result: InferredEvent[] = [];
    records.forEach((record) => {
      const mood = moodByKey(record.mood);
      const endDate = record.captureMode === 'session' ? (record.endedAt ?? Date.now()) : record.createdAt + 60 * 1000;
      const event = buildBaseEvent(
        record.id,
        EventKind.MOOD,
        record.createdAt,
        endDate,
        EventConfidence.HIGH,
        `${mood.emoji} ${mood.label}`
      );
      event.isLive = record.isTracking;
      event.subtitle = record.note;
      event.photoAttachments = record.photoAttachments;
      result.push(event);
    });
    return result;
  }

  private attachMetrics(event: InferredEvent, rawData: DayRawData): InferredEvent {
    const heartRateSamples: HeartRateSample[] = [];
    rawData.heartRateSamples.forEach((sample) => {
      if (overlaps(sample.startDate, sample.endDate, event.startDate, event.endDate)) {
        heartRateSamples.push({
          date: sample.startDate,
          value: sample.value
        });
      }
    });

    const heartRateValues = heartRateSamples.map((sample) => sample.value);
    const metrics: EventMetrics = {};
    if (event.associatedMetrics) {
      metrics.averageHeartRate = event.associatedMetrics.averageHeartRate;
      metrics.maxHeartRate = event.associatedMetrics.maxHeartRate;
      metrics.minHeartRate = event.associatedMetrics.minHeartRate;
      metrics.heartRateSamples = event.associatedMetrics.heartRateSamples;
      metrics.weather = event.associatedMetrics.weather;
      metrics.location = event.associatedMetrics.location;
      metrics.photos = event.associatedMetrics.photos;
      metrics.sleepStages = event.associatedMetrics.sleepStages;
      metrics.stepCount = event.associatedMetrics.stepCount;
      metrics.activeEnergy = event.associatedMetrics.activeEnergy;
      metrics.distance = event.associatedMetrics.distance;
      metrics.workoutType = event.associatedMetrics.workoutType;
    }

    metrics.heartRateSamples = heartRateSamples;
    if (metrics.averageHeartRate === undefined) {
      metrics.averageHeartRate = average(heartRateValues);
    }
    if (metrics.maxHeartRate === undefined) {
      metrics.maxHeartRate = maxValue(heartRateValues);
    }
    if (metrics.minHeartRate === undefined) {
      metrics.minHeartRate = minValue(heartRateValues);
    }
    metrics.weather = this.closestWeather(event, rawData.hourlyWeather);
    metrics.location = this.findLocation(event, rawData.locationVisits);
    metrics.photos = this.findPhotos(event, rawData.photos);
    if (metrics.stepCount === undefined) {
      metrics.stepCount = this.sumValues(rawData.stepSamples, event.startDate, event.endDate);
    }
    if (metrics.activeEnergy === undefined) {
      metrics.activeEnergy = this.sumValues(rawData.activeEnergySamples, event.startDate, event.endDate);
    }
    if (metrics.distance === undefined && metrics.stepCount !== undefined && metrics.stepCount > 0) {
      metrics.distance = metrics.stepCount * 0.72;
    }
    if (event.kind === EventKind.SLEEP && !metrics.sleepStages) {
      const sleepStages: SleepStageSegment[] = [];
      rawData.sleepSamples.forEach((sample) => {
        if (overlaps(sample.startDate, sample.endDate, event.startDate, event.endDate)) {
          sleepStages.push({
            start: sample.startDate,
            end: sample.endDate,
            stage: sample.stage
          });
        }
      });
      metrics.sleepStages = sleepStages;
    }

    const enriched: InferredEvent = {
      id: event.id,
      kind: event.kind,
      startDate: event.startDate,
      endDate: event.endDate,
      confidence: event.confidence,
      isLive: event.isLive,
      displayName: event.displayName,
      userAnnotation: event.userAnnotation,
      subtitle: event.subtitle,
      photoAttachments: event.photoAttachments,
      associatedMetrics: metrics
    };
    return enriched;
  }

  private closestWeather(event: InferredEvent, items: HourlyWeather[]): HourlyWeather | undefined {
    if (items.length === 0) {
      return undefined;
    }
    const middle = event.startDate + Math.round((event.endDate - event.startDate) / 2);
    const sorted = items.slice();
    sorted.sort((left, right) => Math.abs(left.date - middle) - Math.abs(right.date - middle));
    return sorted[0];
  }

  private findLocation(event: InferredEvent, visits: LocationVisit[]): LocationVisit | undefined {
    let result: LocationVisit | undefined = undefined;
    visits.forEach((visit) => {
      if (!result && overlaps(visit.arrivalDate, visit.departureDate, event.startDate, event.endDate)) {
        result = visit;
      }
    });
    return result;
  }

  private findPhotos(event: InferredEvent, photos: PhotoReference[]): PhotoReference[] {
    const result: PhotoReference[] = [];
    photos.forEach((photo) => {
      if (photo.creationDate >= event.startDate && photo.creationDate <= event.endDate) {
        result.push(photo);
      }
    });
    return result;
  }

  private sumValues(samples: DateValueSample[], startDate: number, endDate: number): number {
    let total = 0;
    samples.forEach((sample) => {
      const duration = Math.max(1, sample.endDate - sample.startDate);
      const ratio = overlapDuration(sample.startDate, sample.endDate, startDate, endDate) / duration;
      total += sample.value * ratio;
    });
    return total;
  }

  private sleepStageLabel(stage: SleepStage): string {
    switch (stage) {
      case SleepStage.DEEP:
        return '深睡';
      case SleepStage.LIGHT:
        return '浅睡';
      case SleepStage.REM:
        return '快眼动';
      case SleepStage.AWAKE:
        return '清醒';
      default:
        return '未知';
    }
  }
}
