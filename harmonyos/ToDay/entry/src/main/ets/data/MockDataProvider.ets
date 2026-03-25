import { MoodRecord } from '../model/MoodRecord';
import {
  ActivitySummaryData,
  CoordinateValue,
  createStableId,
  DateValueSample,
  DayRawData,
  HourlyWeather,
  LocationVisit,
  PhotoReference,
  SleepSample,
  SleepStage,
  TimelineSource,
  startOfDay,
  WorkoutSample
} from '../model/SharedDataTypes';
import { DayDataProvider } from './HealthDataProvider';
import { WeatherService } from './WeatherService';

function atTime(base: number, hour: number, minute: number): number {
  return base + (hour * 60 + minute) * 60 * 1000;
}

function buildHeartRateSample(startDate: number, endDate: number, value: number): DateValueSample {
  return { startDate, endDate, value };
}

function buildStepSample(startDate: number, endDate: number, value: number): DateValueSample {
  return { startDate, endDate, value };
}

function buildCalorieSample(startDate: number, endDate: number, value: number): DateValueSample {
  return { startDate, endDate, value };
}

function dayVariant(dayStart: number): number {
  return new Date(dayStart).getDate() % 4;
}

export class MockDataProvider implements DayDataProvider {
  readonly source: TimelineSource = TimelineSource.MOCK;
  private readonly weatherService: WeatherService = new WeatherService();

  isAvailable(): boolean {
    return true;
  }

  async requestPermissions(): Promise<boolean> {
    return true;
  }

  async loadDayRawData(date: number): Promise<DayRawData> {
    const dayStart = startOfDay(date);
    const variant = dayVariant(dayStart);
    const coordinate: CoordinateValue = { latitude: 31.2304, longitude: 121.4737 };
    const activitySummary: ActivitySummaryData = {
      activeEnergyBurned: 520 + variant * 64,
      activeEnergyGoal: 550,
      exerciseMinutes: 24 + variant * 11,
      exerciseGoal: 30,
      standHours: 9 + variant,
      standGoal: 10
    };

    const hourlyWeather = await this.weatherService.loadHourlyWeather(date);
    const sleepSamples = this.buildSleepSamples(dayStart, variant);
    const workouts = this.buildWorkouts(dayStart, variant);
    const stepSamples = this.buildStepSamples(dayStart, variant);
    const heartRateSamples = this.buildHeartRateSamples(dayStart, variant);
    const activeEnergySamples = this.buildEnergySamples(dayStart, variant);
    const locationVisits: LocationVisit[] = [
      {
        id: createStableId('home'),
        coordinate,
        arrivalDate: atTime(dayStart, 0, 0),
        departureDate: atTime(dayStart, 7, 40),
        placeName: '家'
      },
      {
        id: createStableId('office'),
        coordinate,
        arrivalDate: atTime(dayStart, 8, 25),
        departureDate: atTime(dayStart, 18, 10),
        placeName: '工作室'
      },
      {
        id: createStableId('park'),
        coordinate,
        arrivalDate: atTime(dayStart, 18, 30),
        departureDate: atTime(dayStart, 19, 20),
        placeName: '滨江步道'
      }
    ];

    const photos: PhotoReference[] = [
      {
        id: createStableId('photo-morning'),
        creationDate: atTime(dayStart, 7 + variant, 10),
        location: coordinate,
        pixelWidth: 1200,
        pixelHeight: 1600,
        placeholderColor: [ '#E9D18B', '#D89898', '#9AB7DD', '#D9B27E' ][variant]
      },
      {
        id: createStableId('photo-run'),
        creationDate: atTime(dayStart, 18, 20 + variant * 8),
        location: coordinate,
        pixelWidth: 1200,
        pixelHeight: 1600,
        placeholderColor: [ '#C97B7B', '#5B9A8B', '#4A5FA9', '#D76F3D' ][variant]
      }
    ];

    const moodRecords: MoodRecord[] = this.buildMoodRecords(dayStart, variant);

    return {
      date: dayStart,
      activitySummary,
      hourlyWeather,
      locationVisits,
      photos,
      heartRateSamples,
      stepSamples,
      sleepSamples,
      workouts,
      activeEnergySamples,
      moodRecords
    };
  }

  private buildSleepSamples(dayStart: number, variant: number): SleepSample[] {
    const wakeOffset = variant * 8;
    return [
      { startDate: dayStart - 45 * 60 * 1000, endDate: atTime(dayStart, 1, 5 + variant * 5), stage: SleepStage.LIGHT },
      { startDate: atTime(dayStart, 1, 5 + variant * 5), endDate: atTime(dayStart, 3, 15 + variant * 6), stage: SleepStage.DEEP },
      { startDate: atTime(dayStart, 3, 15 + variant * 6), endDate: atTime(dayStart, 5, 2 + variant * 8), stage: SleepStage.REM },
      { startDate: atTime(dayStart, 5, 2 + variant * 8), endDate: atTime(dayStart, 6, 24 + wakeOffset), stage: SleepStage.LIGHT },
      { startDate: atTime(dayStart, 6, 24 + wakeOffset), endDate: atTime(dayStart, 6, 38 + wakeOffset), stage: SleepStage.AWAKE },
      { startDate: atTime(dayStart, 13, 10 + variant * 3), endDate: atTime(dayStart, 13, 42 + variant * 5), stage: SleepStage.LIGHT }
    ];
  }

  private buildWorkouts(dayStart: number, variant: number): WorkoutSample[] {
    const variants: WorkoutSample[][] = [
      [
        {
          id: createStableId(`workout-run-${dayStart}`),
          startDate: atTime(dayStart, 18, 28),
          endDate: atTime(dayStart, 19, 12),
          activityType: '户外跑步',
          activeEnergy: 322,
          distance: 5680
        }
      ],
      [
        {
          id: createStableId(`workout-cycle-${dayStart}`),
          startDate: atTime(dayStart, 7, 5),
          endDate: atTime(dayStart, 7, 48),
          activityType: '通勤骑行',
          activeEnergy: 266,
          distance: 8240
        }
      ],
      [],
      [
        {
          id: createStableId(`workout-hiit-${dayStart}`),
          startDate: atTime(dayStart, 20, 6),
          endDate: atTime(dayStart, 20, 34),
          activityType: '室内训练',
          activeEnergy: 214,
          distance: 0
        }
      ]
    ];
    return variants[variant];
  }

  private buildStepSamples(dayStart: number, variant: number): DateValueSample[] {
    const samples: DateValueSample[] = [];
    const blocksByVariant: Array<Array<[number, number, number]>> = [
      [ [7, 42, 460], [8, 8, 520], [12, 6, 380], [17, 48, 560], [20, 8, 260] ],
      [ [7, 6, 520], [7, 26, 560], [12, 12, 280], [18, 6, 420], [21, 2, 180] ],
      [ [8, 12, 260], [12, 22, 220], [15, 10, 180], [19, 18, 320] ],
      [ [6, 52, 210], [9, 36, 340], [13, 8, 360], [20, 10, 520] ]
    ];
    const blocks = blocksByVariant[variant];

    blocks.forEach((block, blockIndex) => {
      const hour = block[0];
      const minute = block[1];
      const value = block[2];
      for (let step = 0; step < 4; step += 1) {
        const startDate = atTime(dayStart, hour, minute + step * 5);
        const endDate = startDate + 5 * 60 * 1000;
        samples.push(buildStepSample(startDate, endDate, value + blockIndex * 18));
      }
    });

    return samples;
  }

  private buildHeartRateSamples(dayStart: number, variant: number): DateValueSample[] {
    const samples: DateValueSample[] = [];
    for (let hour = 0; hour < 24; hour += 1) {
      const startDate = atTime(dayStart, hour, 0);
      const endDate = startDate + 15 * 60 * 1000;
      let value = 57 + variant;
      if (variant === 0) {
        if (hour >= 7 && hour < 9) {
          value = 96;
        } else if (hour >= 9 && hour < 17) {
          value = 72;
        } else if (hour >= 18 && hour < 20) {
          value = 138;
        } else if (hour >= 13 && hour < 14) {
          value = 62;
        }
      } else if (variant === 1) {
        if (hour >= 6 && hour < 8) {
          value = 118;
        } else if (hour >= 8 && hour < 18) {
          value = 70;
        } else if (hour >= 18 && hour < 21) {
          value = 84;
        }
      } else if (variant === 2) {
        if (hour >= 8 && hour < 17) {
          value = 68;
        } else if (hour >= 19 && hour < 21) {
          value = 88;
        }
      } else {
        if (hour >= 9 && hour < 12) {
          value = 82;
        } else if (hour >= 20 && hour < 21) {
          value = 132;
        } else if (hour >= 13 && hour < 14) {
          value = 64;
        }
      }
      samples.push(buildHeartRateSample(startDate, endDate, value));
    }
    return samples;
  }

  private buildEnergySamples(dayStart: number, variant: number): DateValueSample[] {
    const variants: DateValueSample[][] = [
      [
        buildCalorieSample(atTime(dayStart, 7, 40), atTime(dayStart, 8, 25), 80),
        buildCalorieSample(atTime(dayStart, 12, 6), atTime(dayStart, 12, 28), 38),
        buildCalorieSample(atTime(dayStart, 18, 28), atTime(dayStart, 19, 12), 322),
        buildCalorieSample(atTime(dayStart, 20, 8), atTime(dayStart, 20, 25), 34)
      ],
      [
        buildCalorieSample(atTime(dayStart, 7, 5), atTime(dayStart, 7, 48), 266),
        buildCalorieSample(atTime(dayStart, 18, 5), atTime(dayStart, 18, 36), 66)
      ],
      [
        buildCalorieSample(atTime(dayStart, 8, 12), atTime(dayStart, 8, 28), 32),
        buildCalorieSample(atTime(dayStart, 19, 18), atTime(dayStart, 19, 36), 46)
      ],
      [
        buildCalorieSample(atTime(dayStart, 13, 8), atTime(dayStart, 13, 24), 54),
        buildCalorieSample(atTime(dayStart, 20, 6), atTime(dayStart, 20, 34), 214)
      ]
    ];
    return variants[variant];
  }

  private buildMoodRecords(dayStart: number, variant: number): MoodRecord[] {
    const variants: MoodRecord[][] = [
      [
        {
          id: createStableId(`mood-1-${dayStart}`),
          mood: 'focused',
          note: '上午开会前进入状态很快。',
          createdAt: atTime(dayStart, 9, 20),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        },
        {
          id: createStableId(`mood-2-${dayStart}`),
          mood: 'satisfied',
          note: '跑步后整个人轻了下来。',
          createdAt: atTime(dayStart, 19, 12),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        }
      ],
      [
        {
          id: createStableId(`mood-3-${dayStart}`),
          mood: 'grateful',
          note: '早骑结束后，整天节奏都很顺。',
          createdAt: atTime(dayStart, 8, 6),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        },
        {
          id: createStableId(`mood-4-${dayStart}`),
          mood: 'calm',
          note: '傍晚回家路上比预想的更放松。',
          createdAt: atTime(dayStart, 18, 40),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        }
      ],
      [
        {
          id: createStableId(`mood-5-${dayStart}`),
          mood: 'tired',
          note: '中午小睡后才慢慢恢复。',
          createdAt: atTime(dayStart, 13, 58),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        },
        {
          id: createStableId(`mood-6-${dayStart}`),
          mood: 'focused',
          note: '晚上把白天没收完的事情补齐了。',
          createdAt: atTime(dayStart, 20, 16),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        }
      ],
      [
        {
          id: createStableId(`mood-7-${dayStart}`),
          mood: 'happy',
          note: '下午的工作推进很顺，晚上训练也状态不错。',
          createdAt: atTime(dayStart, 15, 42),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        },
        {
          id: createStableId(`mood-8-${dayStart}`),
          mood: 'excited',
          note: '夜里做完训练还有余力。',
          createdAt: atTime(dayStart, 20, 36),
          isTracking: false,
          captureMode: 'point',
          photoAttachments: []
        }
      ]
    ];
    return variants[variant];
  }
}
