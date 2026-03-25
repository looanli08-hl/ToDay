import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { getMoodOptions, MoodVisual } from '../../model/SharedDataTypes';
import { Mood, MoodRecord } from '../../model/MoodRecord';

@Component
export struct QuickRecordSheet {
  mode: ThemeMode = ThemeMode.Light;
  quickRecordMode: 'flexible' | 'pointOnly' = 'flexible';
  onDismiss: () => void = () => {};
  onSave: (record: MoodRecord) => void = () => {};

  @State selectedMood: Mood = 'happy';
  @State note: string = '';
  @State offsetMinutes: number = 0;

  private createRecord(captureMode: 'point' | 'session'): MoodRecord {
    const createdAt = Date.now() - this.offsetMinutes * 60 * 1000;
    return {
      id: `${createdAt}-${captureMode}-${this.selectedMood}`,
      mood: this.selectedMood,
      note: this.note,
      createdAt,
      endedAt: captureMode === 'point' ? createdAt : undefined,
      isTracking: captureMode === 'session',
      captureMode,
      photoAttachments: []
    };
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TodayTheme.alpha('#000000', 0.36))
        .onClick(() => this.onDismiss());

      Scroll() {
        Column({ space: 18 }) {
        Row() {
          Column({ space: 8 }) {
            Text(this.quickRecordMode === 'flexible' ? '记录此刻' : '补一个打点')
              .fontSize(24)
              .fontWeight(FontWeight.Medium)
              .fontColor(TodayTheme.color('ink', this.mode));

            Text(this.quickRecordMode === 'flexible' ? '你可以只打一个点，也可以开始一段持续状态。' : '当前已有进行中的状态，本次只补充一个打点。')
              .fontSize(13)
              .fontColor(TodayTheme.color('inkMuted', this.mode));
          }
          .layoutWeight(1);

          Text(this.quickRecordMode === 'flexible' ? '灵活' : '打点')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.color(this.quickRecordMode === 'flexible' ? 'accent' : 'teal', this.mode))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(TodayTheme.color(this.quickRecordMode === 'flexible' ? 'accentSoft' : 'tealSoft', this.mode))
            .borderRadius(TodayTheme.radius('capsule'));
        }
        .width('100%');

        GridRow({ columns: 12 }) {
          ForEach(getMoodOptions(), (mood: MoodVisual) => {
            GridCol({ span: 4 }) {
              Column({ space: 8 }) {
                Text(mood.emoji).fontSize(24);
                Text(mood.label)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(TodayTheme.color('inkSoft', this.mode));
              }
              .width(80)
              .height(80)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.selectedMood === mood.key ? TodayTheme.color('accentSoft', this.mode) : TodayTheme.color('card', this.mode))
              .borderRadius(18)
              .border({
                width: this.selectedMood === mood.key ? 1.5 : 1,
                color: this.selectedMood === mood.key ? TodayTheme.color('accent', this.mode) : TodayTheme.color('border', this.mode)
              })
              .onClick(() => {
                animateTo({ duration: 150, curve: Curve.Friction }, () => {
                  this.selectedMood = mood.key;
                });
              });
            }
          }, (mood: MoodVisual): string => mood.key);
        }
        .width('100%');

        TextArea({ text: this.note, placeholder: '写下这一刻发生了什么' })
          .fontSize(14)
          .backgroundColor(TodayTheme.color('background', this.mode))
          .borderRadius(16)
          .padding(14)
          .onChange((value: string) => {
            this.note = value;
          });

        Column({ space: 10 }) {
          Text('时间')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.color('inkMuted', this.mode));

          Row({ space: 10 }) {
            ForEach([0, 15, 30, 60], (item: number) => {
              Text(item === 0 ? '现在' : `提前 ${item} 分钟`)
                .fontSize(12)
                .fontColor(this.offsetMinutes === item ? TodayTheme.color('teal', this.mode) : TodayTheme.color('inkSoft', this.mode))
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor(this.offsetMinutes === item ? TodayTheme.color('tealSoft', this.mode) : TodayTheme.color('background', this.mode))
                .borderRadius(TodayTheme.radius('capsule'))
                .onClick(() => {
                  this.offsetMinutes = item;
                });
            });
          }
        }
        .width('100%');

        Column({ space: 8 }) {
          Text('照片')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.color('inkMuted', this.mode));

          Row({ space: 10 }) {
            ForEach([1, 2, 3], (placeholderSlot: number) => {
              Column({ space: 4 }) {
                Text('+').fontSize(20).fontColor(TodayTheme.color('inkMuted', this.mode));
                Text('待接入')
                  .fontSize(11)
                  .fontColor(TodayTheme.color('inkFaint', this.mode));
              }
              .width(84)
              .height(84)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(TodayTheme.color('background', this.mode))
              .borderRadius(16)
            }, (placeholderSlot: number): string => `photo-slot-${placeholderSlot}`);
          }
        }

        if (this.quickRecordMode === 'flexible') {
          Row({ space: 10 }) {
            Button('打点')
              .layoutWeight(1)
              .backgroundColor(TodayTheme.color('accent', this.mode))
              .onClick(() => this.onSave(this.createRecord('point')));

            Button('开始一段')
              .layoutWeight(1)
              .backgroundColor(TodayTheme.color('teal', this.mode))
              .onClick(() => this.onSave(this.createRecord('session')));
          }
        } else {
          Button('保存打点')
            .width('100%')
            .backgroundColor(TodayTheme.color('teal', this.mode))
            .onClick(() => this.onSave(this.createRecord('point')));
        }
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .backgroundColor(TodayTheme.color('card', this.mode))
      .borderRadius({ topLeft: 24, topRight: 24 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
