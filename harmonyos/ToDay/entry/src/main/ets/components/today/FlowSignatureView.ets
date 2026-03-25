import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { eventTintColor, getEventVisual, InferredEvent } from '../../model/SharedDataTypes';

interface SignatureBar {
  id: string;
  intensity: number;
  height: number;
  color: string;
  isPeak: boolean;
}

const SIGNATURE_BARS = 48;

@Component
export struct FlowSignatureView {
  entries: InferredEvent[] = [];
  mode: ThemeMode = ThemeMode.Light;

  private buildBars(): SignatureBar[] {
    const bars: SignatureBar[] = [];
    const dayStart = this.entries.length > 0 ? new Date(this.entries[0].startDate) : new Date(Date.now());
    dayStart.setHours(0, 0, 0, 0);
    const startOfDay = dayStart.getTime();
    const slotSize = (24 * 60) / SIGNATURE_BARS;

    for (let index = 0; index < SIGNATURE_BARS; index += 1) {
      const slotStartMinute = index * slotSize;
      const slotEndMinute = slotStartMinute + slotSize;
      let selectedEntry: InferredEvent | undefined = undefined;
      let selectedIntensity = 0.12;

      this.entries.forEach((entry) => {
        const entryStartMinute = (entry.startDate - startOfDay) / 60000;
        const entryEndMinute = Math.max(entryStartMinute + 1, (entry.endDate - startOfDay) / 60000);
        const overlaps = entryEndMinute > slotStartMinute && entryStartMinute < slotEndMinute;
        if (!overlaps) {
          return;
        }

        const intensity = Math.max(0.12, getEventVisual(entry.kind).intensity);
        if (intensity >= selectedIntensity) {
          selectedIntensity = intensity;
          selectedEntry = entry;
        }
      });

      const color = selectedEntry
        ? eventTintColor(selectedEntry, this.mode)
        : TodayTheme.alpha(TodayTheme.color('inkFaint', this.mode), 0.26);

      bars.push({
        id: `signature-${index}`,
        intensity: selectedIntensity,
        height: 16 + selectedIntensity * 42,
        color: color,
        isPeak: selectedIntensity >= 0.75
      });
    }

    return bars;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        Column()
          .width('100%')
          .height(58)
          .linearGradient({
            angle: 90,
            colors: [
              [TodayTheme.alpha(TodayTheme.color('scrollNight', this.mode), 0.04), 0],
              [TodayTheme.alpha(TodayTheme.color('scrollSunrise', this.mode), 0.08), 0.18],
              [TodayTheme.alpha(TodayTheme.color('scrollGold', this.mode), 0.12), 0.38],
              [TodayTheme.alpha(TodayTheme.color('scrollNoon', this.mode), 0.08), 0.58],
              [TodayTheme.alpha(TodayTheme.color('scrollSunset', this.mode), 0.12), 0.78],
              [TodayTheme.alpha(TodayTheme.color('scrollViolet', this.mode), 0.16), 1]
            ]
          })
          .borderRadius(20);
      }
      .width('100%')
      .height(58);

      Row({ space: 1 }) {
        ForEach(this.buildBars(), (bar: SignatureBar) => {
          Column({ space: 4 }) {
            if (bar.isPeak) {
              Row()
                .width(7)
                .height(7)
                .borderRadius(999)
                .backgroundColor(bar.color);
            } else {
              Blank()
                .height(7);
            }

            Stack({ alignContent: Alignment.Bottom }) {
              Column()
                .width('100%')
                .height(18 + bar.intensity * 30)
                .backgroundColor(TodayTheme.alpha(bar.color, 0.2))
                .borderRadius(TodayTheme.radius('capsule'));

              Column()
                .width('100%')
                .height(bar.height)
                .backgroundColor(bar.color)
                .borderRadius(TodayTheme.radius('capsule'));
            }
            .width('100%')
          }
          .layoutWeight(1)
        }, (bar: SignatureBar): string => bar.id)
      }
      .width('100%')
      .height(82)
      .alignItems(VerticalAlign.Bottom);
    }
    .width('100%')
    .height(82)
  }
}
