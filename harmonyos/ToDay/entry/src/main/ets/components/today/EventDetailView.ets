import { FlexibleBadgeRow } from '../../common/components/FlexibleBadgeRow';
import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import {
  eventSubtitleFragments,
  eventTintColor,
  EventKind,
  formatClock,
  formatDuration,
  HeartRateSample,
  InferredEvent,
  PhotoReference,
  resolveEventName
} from '../../model/SharedDataTypes';

interface DetailMetricItem {
  id: string;
  label: string;
  value: string;
}

@Component
export struct EventDetailView {
  event: InferredEvent = {
    id: '',
    kind: EventKind.QUIET_TIME,
    startDate: 0,
    endDate: 0,
    confidence: 0,
    isLive: false,
    displayName: '',
    photoAttachments: []
  };
  mode: ThemeMode = ThemeMode.Light;
  onDismiss: () => void = () => {};
  onAnnotate: (event: InferredEvent) => void = () => {};

  private buildMetricItems(): DetailMetricItem[] {
    return [
      {
        id: 'avg-heart-rate',
        label: '平均心率',
        value: this.event.associatedMetrics?.averageHeartRate
          ? `${Math.round(this.event.associatedMetrics.averageHeartRate)} 次/分`
          : '--'
      },
      {
        id: 'steps',
        label: '步数',
        value: this.event.associatedMetrics?.stepCount
          ? `${Math.round(this.event.associatedMetrics.stepCount)} 步`
          : '--'
      },
      {
        id: 'distance',
        label: '距离',
        value: this.event.associatedMetrics?.distance
          ? `${Math.round(this.event.associatedMetrics.distance)} 米`
          : '--'
      }
    ];
  }

  private tintColor(): string {
    return eventTintColor(this.event, this.mode);
  }

  private subtitleFragments(): Array<string> {
    return eventSubtitleFragments(this.event);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TodayTheme.alpha('#000000', 0.4))
        .onClick(() => this.onDismiss());

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Text(resolveEventName(this.event))
              .fontSize(28)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.event.kind === EventKind.QUIET_TIME ? TodayTheme.color('ink', this.mode) : '#FFFFFF');

            Text(`${formatClock(this.event.startDate)} - ${formatClock(this.event.endDate)} · ${formatDuration(this.event.endDate - this.event.startDate)}`)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(this.event.kind === EventKind.QUIET_TIME ? TodayTheme.color('inkMuted', this.mode) : TodayTheme.alpha('#FFFFFF', 0.82));

            if (this.subtitleFragments().length > 0) {
              Text(this.subtitleFragments().join(' · '))
                .fontSize(14)
                .fontColor(this.event.kind === EventKind.QUIET_TIME ? TodayTheme.color('inkSoft', this.mode) : TodayTheme.alpha('#FFFFFF', 0.82));
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(this.event.kind === EventKind.QUIET_TIME ? TodayTheme.alpha(TodayTheme.color('card', this.mode), 0.35) : TodayTheme.alpha(this.tintColor(), 0.92))
          .borderRadius(TodayTheme.radius('card'));

          if (this.event.associatedMetrics?.photos && this.event.associatedMetrics.photos.length > 0) {
            Column({ space: 10 }) {
              Text('照片')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(TodayTheme.color('inkMuted', this.mode));

              Row({ space: 10 }) {
                ForEach(this.event.associatedMetrics.photos, (photo: PhotoReference) => {
                  Column()
                    .width(96)
                    .height(116)
                    .backgroundColor(photo.placeholderColor ?? TodayTheme.color('accentSoft', this.mode))
                    .borderRadius(16)
                }, (photo: PhotoReference): string => photo.id);
              }
            }
            .width('100%');
          }

          if (this.event.associatedMetrics?.heartRateSamples && this.event.associatedMetrics.heartRateSamples.length > 0) {
            Column({ space: 10 }) {
              Text('心率走势')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(TodayTheme.color('inkMuted', this.mode));

              Row({ space: 4 }) {
                ForEach(this.event.associatedMetrics.heartRateSamples, (sample: HeartRateSample) => {
                  Column()
                    .layoutWeight(1)
                    .height(Math.max(24, sample.value))
                    .backgroundColor(TodayTheme.alpha(this.tintColor(), 0.75))
                    .borderRadius(TodayTheme.radius('capsule'));
                }, (sample: HeartRateSample): string => `${sample.date}-${sample.value}`);
              }
              .alignItems(VerticalAlign.Bottom)
              .width('100%')
              .height(180);
            }
            .width('100%');
          }

          Row({ space: 10 }) {
            ForEach(this.buildMetricItems(), (item: DetailMetricItem) => {
              Column({ space: 6 }) {
                Text(item.label)
                  .fontSize(11)
                  .fontColor(TodayTheme.color('inkMuted', this.mode));
                Text(item.value)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(TodayTheme.color('ink', this.mode));
              }
              .layoutWeight(1)
              .padding(14)
              .backgroundColor(TodayTheme.color('background', this.mode))
              .borderRadius(16)
            }, (item: DetailMetricItem): string => item.id);
          }
          .width('100%');

          FlexibleBadgeRow({
            badges: [
              this.event.associatedMetrics?.location?.placeName ?? '地点待补充',
              this.event.associatedMetrics?.weather ? `${Math.round(this.event.associatedMetrics.weather.temperature)}°` : '天气待补充',
              this.event.isLive ? '进行中' : '已归档'
            ],
            tone: 'teal',
            mode: this.mode
          })

          if (this.event.kind === EventKind.QUIET_TIME || this.event.kind === EventKind.USER_ANNOTATED) {
            Button('标注这段时间')
              .width('100%')
              .backgroundColor(TodayTheme.color('teal', this.mode))
              .onClick(() => this.onAnnotate(this.event));
          }
        }
        .width('100%')
        .padding(20);
      }
      .width('100%')
      .height('76%')
      .backgroundColor(TodayTheme.color('card', this.mode))
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
