import { ThemeMode, TodayTheme } from '../../common/theme/TodayTheme';
import { EventKind, InferredEvent, resolveEventName } from '../../model/SharedDataTypes';

@Component
export struct AnnotationSheet {
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
  onSave: (title: string) => void = () => {};

  @State text: string = '';

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TodayTheme.alpha('#000000', 0.32))
        .onClick(() => this.onDismiss());

      Column({ space: 16 }) {
        Text('标注这段时间')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(TodayTheme.color('ink', this.mode));

        Text(`当前片段：${resolveEventName(this.event)}`)
          .fontSize(13)
          .fontColor(TodayTheme.color('inkMuted', this.mode));

        TextInput({ text: this.text, placeholder: '例如：咖啡店写方案 / 地铁上 / 陪家人散步' })
          .fontSize(14)
          .padding(14)
          .backgroundColor(TodayTheme.color('background', this.mode))
          .borderRadius(16)
          .onChange((value: string) => {
            this.text = value;
          });

        Button('保存标注')
          .width('100%')
          .backgroundColor(TodayTheme.color('teal', this.mode))
          .onClick(() => {
            this.onSave(this.text);
            this.onDismiss();
          });
      }
      .width('100%')
      .padding(20)
      .backgroundColor(TodayTheme.color('card', this.mode))
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
