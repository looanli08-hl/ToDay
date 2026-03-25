import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { getMoodDescriptor, MoodDescriptor } from '../../model/MoodRecord';
import {
  eventSubtitleFragments,
  eventTintColor,
  EventKind,
  formatClock,
  formatDuration,
  InferredEvent,
  inferMoodKeyFromText,
  isBlankCandidate,
  resolveEventName,
  SleepStageSegment,
  sleepStageTone
} from '../../model/SharedDataTypes';

@Component
export struct EventCardView {
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

  private blankCandidate(): boolean {
    return isBlankCandidate(this.event);
  }

  private hasPhotos(): boolean {
    return this.event.photoAttachments.length > 0;
  }

  private subtitleText(): string {
    return eventSubtitleFragments(this.event).join(' · ');
  }

  private hasSubtitle(): boolean {
    return this.subtitleText().length > 0;
  }

  private sleepSegmentWeight(segment: SleepStageSegment): number {
    return Math.max(1, Math.round((segment.end - segment.start) / 60000));
  }

  build() {
    if (this.event.kind === EventKind.MOOD) {
      this.buildMoodMarker();
    } else {
      this.buildEventCard();
    }
  }

  @Builder
  private buildEventCard(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.kindBadgeTitle())
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontFamily('monospace')
          .fontColor(this.kindBadgeColor());

        Text(resolveEventName(this.event))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.cardTitleColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);

        if (this.event.isLive) {
          Row({ space: 5 }) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(999)
              .backgroundColor(TodayTheme.color('walkGreen', this.mode));

            Text('进行中')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.liveMetaColor());
          }
        }

        Text(formatDuration(this.event.endDate - this.event.startDate))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontFamily('monospace')
          .fontColor(this.cardMetaColor());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.hasSubtitle()) {
        Text(this.subtitleText())
          .fontSize(13)
          .lineHeight(18)
          .fontColor(this.cardDetailColor())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }

      if (this.event.associatedMetrics?.sleepStages && this.event.associatedMetrics.sleepStages.length > 0) {
        Row({ space: 2 }) {
          ForEach(this.event.associatedMetrics.sleepStages, (segment: SleepStageSegment) => {
            Row()
              .layoutWeight(this.sleepSegmentWeight(segment))
              .height(6)
              .borderRadius(3)
              .backgroundColor(sleepStageTone(segment.stage, this.mode));
          });
        }
        .width('100%')
      }

      if (this.blankCandidate() || this.hasPhotos()) {
        Row({ space: 8 }) {
          if (this.blankCandidate()) {
            Text('点击记录')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(TodayTheme.color('inkSoft', this.mode))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(TodayTheme.alpha(TodayTheme.color('card', this.mode), 0.72))
              .borderRadius(TodayTheme.radius('capsule'));
          }

          Blank();

          if (this.hasPhotos()) {
            Text(`📷 ${this.event.photoAttachments.length}`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.blankCandidate() ? TodayTheme.color('inkSoft', this.mode) : this.liveMetaColor())
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.badgeBackgroundColor(this.blankCandidate()))
              .borderRadius(TodayTheme.radius('capsule'));
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.cardBackgroundColor())
    .backdropBlur(20)
    .borderRadius(14)
    .border({
      width: this.blankCandidate() ? 1 : 0.5,
      color: this.blankCandidate()
        ? TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.35)
        : TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.5),
      style: this.blankCandidate() ? BorderStyle.Dashed : BorderStyle.Solid
    })
  }

  @Builder
  private buildMoodMarker(): void {
    Row({ space: 8 }) {
      Row() {
        Text(this.resolveMoodDescriptor().emoji)
          .fontSize(11);
      }
        .width(20)
        .height(20)
        .borderRadius(999)
        .backgroundColor(eventTintColor(this.event, this.mode))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center);

      Text(resolveEventName(this.event))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(TodayTheme.color('ink', this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);

      Text(formatClock(this.event.startDate))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontFamily('monospace')
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(TodayTheme.alpha(TodayTheme.color('card', this.mode), 0.6))
    .backdropBlur(20)
    .borderRadius(TodayTheme.radius('capsule'))
    .border({
      width: 0.5,
      color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.5)
    })
  }

  private resolveMoodDescriptor(): MoodDescriptor {
    const moodKey = inferMoodKeyFromText(resolveEventName(this.event)) ?? inferMoodKeyFromText(this.event.subtitle ?? '') ?? 'happy';
    return getMoodDescriptor(moodKey);
  }

  private cardBackgroundColor(): string {
    switch (this.event.kind) {
      case EventKind.SLEEP:
        return TodayTheme.alpha(TodayTheme.color('sleepIndigo', this.mode), 0.78);
      case EventKind.WORKOUT:
        return this.workoutBackgroundColor();
      case EventKind.COMMUTE:
      case EventKind.ACTIVE_WALK:
        return TodayTheme.alpha(TodayTheme.color('walkGreen', this.mode), 0.86);
      case EventKind.USER_ANNOTATED:
        return TodayTheme.alpha(TodayTheme.color('teal', this.mode), 0.82);
      case EventKind.MOOD:
        return TodayTheme.alpha(TodayTheme.color('accent', this.mode), 0.85);
      case EventKind.QUIET_TIME:
      default:
        return TodayTheme.glass(this.mode, 0.18);
    }
  }

  private workoutBackgroundColor(): string {
    const workoutType = String(this.event.associatedMetrics?.workoutType ?? this.event.displayName ?? '');
    if (workoutType.includes('骑') || workoutType.toLowerCase().includes('cycle') || workoutType.toLowerCase().includes('bike')) {
      return TodayTheme.alpha(TodayTheme.color('blue', this.mode), 0.86);
    }
    if (workoutType.includes('跑') || workoutType.toLowerCase().includes('run')) {
      return TodayTheme.alpha(TodayTheme.color('workoutOrange', this.mode), 0.9);
    }
    return TodayTheme.alpha(TodayTheme.color('rose', this.mode), 0.88);
  }

  private kindBadgeTitle(): string {
    switch (this.event.kind) {
      case EventKind.SLEEP:
        return 'SLEEP';
      case EventKind.WORKOUT:
        return 'WORKOUT';
      case EventKind.COMMUTE:
        return 'COMMUTE';
      case EventKind.ACTIVE_WALK:
        return 'WALK';
      case EventKind.USER_ANNOTATED:
        return 'NOTE';
      case EventKind.MOOD:
        return 'MOOD';
      case EventKind.QUIET_TIME:
      default:
        return 'QUIET';
    }
  }

  private cardTitleColor(): string {
    if (isBlankCandidate(this.event)) {
      return TodayTheme.color('ink', this.mode);
    }
    return TodayTheme.alpha('#FFFFFF', 0.95);
  }

  private cardMetaColor(): string {
    if (isBlankCandidate(this.event)) {
      return TodayTheme.color('inkMuted', this.mode);
    }
    return TodayTheme.alpha('#FFFFFF', 0.75);
  }

  private cardDetailColor(): string {
    if (isBlankCandidate(this.event)) {
      return TodayTheme.color('inkMuted', this.mode);
    }
    return TodayTheme.alpha('#FFFFFF', 0.7);
  }

  private kindBadgeColor(): string {
    if (isBlankCandidate(this.event)) {
      return eventTintColor(this.event, this.mode);
    }
    return TodayTheme.alpha('#FFFFFF', 0.82);
  }

  private liveMetaColor(): string {
    return isBlankCandidate(this.event) ? TodayTheme.color('inkSoft', this.mode) : TodayTheme.alpha('#FFFFFF', 0.88);
  }

  private badgeBackgroundColor(blankCandidate: boolean): string {
    if (blankCandidate) {
      return TodayTheme.alpha(TodayTheme.color('card', this.mode), 0.72);
    }
    return TodayTheme.alpha('#FFFFFF', 0.16);
  }
}
