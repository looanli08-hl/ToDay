import { DayDataAggregator } from '../data/DayDataAggregator';
import { EventInferenceEngine } from '../data/EventInferenceEngine';
import { HealthDataProvider } from '../data/HealthDataProvider';
import { LocationService } from '../data/LocationService';
import { MockDataProvider } from '../data/MockDataProvider';
import { StorageService } from '../data/StorageService';
import { WeatherService } from '../data/WeatherService';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

export class AppContainer {
  static readonly shared = new AppContainer();

  readonly storageService: StorageService;
  readonly mockDataProvider: MockDataProvider;
  readonly healthDataProvider: HealthDataProvider;
  readonly eventInferenceEngine: EventInferenceEngine;
  readonly dayDataAggregator: DayDataAggregator;
  readonly locationService: LocationService;
  readonly weatherService: WeatherService;
  readonly todayViewModel: TodayViewModel;

  private constructor() {
    this.storageService = new StorageService();
    this.mockDataProvider = new MockDataProvider();
    this.healthDataProvider = new HealthDataProvider(this.mockDataProvider);
    this.eventInferenceEngine = new EventInferenceEngine();
    this.dayDataAggregator = new DayDataAggregator(this.mockDataProvider, this.eventInferenceEngine, this.storageService);
    this.locationService = new LocationService();
    this.weatherService = new WeatherService();
    this.todayViewModel = new TodayViewModel(
      this.dayDataAggregator,
      this.storageService,
      this.healthDataProvider,
      this.locationService,
      this.weatherService
    );
  }
}
