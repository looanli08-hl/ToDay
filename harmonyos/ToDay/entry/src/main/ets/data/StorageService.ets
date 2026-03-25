import { DayTimeline, startOfDay } from '../model/SharedDataTypes';
import { MoodRecord } from '../model/MoodRecord';

function dayKey(date: number): string {
  const value = new Date(startOfDay(date));
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export class StorageService {
  private moodRecords: MoodRecord[] = [];
  private timelines: Map<string, DayTimeline> = new Map();
  private annotations: Map<string, string> = new Map();

  // 首版先用内存实现接口，后续切换到鸿蒙 RDB 时保留相同方法签名即可。
  async loadMoodRecords(): Promise<MoodRecord[]> {
    return [...this.moodRecords].sort((left, right) => right.createdAt - left.createdAt);
  }

  async saveMoodRecords(records: MoodRecord[]): Promise<void> {
    this.moodRecords = [...records].sort((left, right) => right.createdAt - left.createdAt);
  }

  async loadTimeline(date: number): Promise<DayTimeline | undefined> {
    return this.timelines.get(dayKey(date));
  }

  async saveTimeline(timeline: DayTimeline): Promise<void> {
    this.timelines.set(dayKey(timeline.date), timeline);
  }

  async annotateEvent(eventId: string, title: string): Promise<void> {
    this.annotations.set(eventId, title);
  }

  async loadAnnotations(): Promise<Map<string, string>> {
    return new Map(this.annotations);
  }

  async clearAll(): Promise<void> {
    this.moodRecords = [];
    this.timelines.clear();
    this.annotations.clear();
  }
}
