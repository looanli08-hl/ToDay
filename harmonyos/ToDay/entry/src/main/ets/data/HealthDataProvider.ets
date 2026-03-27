import { DayRawData, TimelineSource } from '../model/SharedDataTypes';

export interface DayDataProvider {
  readonly source: TimelineSource;
  isAvailable(): boolean;
  requestPermissions(): Promise<boolean>;
  loadDayRawData(date: number): Promise<DayRawData>;
}

export class HealthDataProvider implements DayDataProvider {
  readonly source: TimelineSource = TimelineSource.HEALTH_KIT;
  private readonly fallback: DayDataProvider;

  constructor(fallback: DayDataProvider) {
    this.fallback = fallback;
  }

  isAvailable(): boolean {
    // 首版先保留接入位，未在当前仓库中直接接真实 Health Kit SDK。
    return false;
  }

  async requestPermissions(): Promise<boolean> {
    return false;
  }

  async loadDayRawData(date: number): Promise<DayRawData> {
    return this.fallback.loadDayRawData(date);
  }
}
