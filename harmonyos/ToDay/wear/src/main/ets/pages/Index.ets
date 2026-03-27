class WatchSummaryCard {
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly detail: string;
  readonly tone: string;

  constructor(id: string, label: string, value: string, detail: string, tone: string) {
    this.id = id;
    this.label = label;
    this.value = value;
    this.detail = detail;
    this.tone = tone;
  }
}

class WatchEventItem {
  readonly id: string;
  readonly timeLabel: string;
  readonly title: string;
  readonly detail: string;
  readonly tone: string;

  constructor(id: string, timeLabel: string, title: string, detail: string, tone: string) {
    this.id = id;
    this.timeLabel = timeLabel;
    this.title = title;
    this.detail = detail;
    this.tone = tone;
  }
}

@Entry
@Component
struct Index {
  @State moodLabel: string = '🌿 平静';
  @State statusLabel: string = '今天以户外跑步为主，手表端保留最常看的高频信息。';
  @State syncLabel: string = '已切换到手表快速视图';

  private readonly cards: Array<WatchSummaryCard> = [
    new WatchSummaryCard('sleep', '睡眠', '7h 55m', '恢复窗口', '#A7B8FF'),
    new WatchSummaryCard('move', '移动', '2h 24m', '步行 + 跑步', '#82D3BE'),
    new WatchSummaryCard('note', '记录', '2 条', '含 1 条备注', '#E3B17B')
  ];

  private readonly events: Array<WatchEventItem> = [
    new WatchEventItem('w1', '06:40', '结束睡眠', '起床后节律平稳，恢复情况不错。', '#A7B8FF'),
    new WatchEventItem('w2', '11:20', '午间快走', '12 分钟快走，延续日间活动感。', '#82D3BE'),
    new WatchEventItem('w3', '18:10', '户外跑步', '今天最明显的推进片段，强度适中。', '#E8905B')
  ];

  @Builder
  private buildHero(): void {
    Column({ space: 10 }) {
      Text('ToDay')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F8F4EC');

      Text('Watch GT 5 快速视图')
        .fontSize(12)
        .fontColor('#B8B2A9');

      Stack() {
        Column({ space: 8 }) {
          Text('今日节律')
            .fontSize(12)
            .fontColor('#B8B2A9');

          Text('稳定推进')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8F4EC');

          Text(this.moodLabel)
            .fontSize(13)
            .fontColor('#1A1A1A')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#E9D5B7')
            .borderRadius(999);
        }
        .justifyContent(FlexAlign.Center)
        .width(176)
        .height(176)
        .borderRadius(999)
        .backgroundColor('#171A18');

        Column()
          .width(208)
          .height(208)
          .borderRadius(999)
          .border({
            width: 10,
            color: '#2A2F2B'
          });
      }
      .width('100%')
      .height(208);

      Text(this.statusLabel)
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#D6D0C8');
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding(18)
    .backgroundColor('#202522')
    .borderRadius(32)
  }

  @Builder
  private buildSummaryCard(item: WatchSummaryCard): void {
    Column({ space: 6 }) {
      Text(item.label)
        .fontSize(12)
        .fontColor('#A9A39A');

      Text(item.value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F8F4EC');

      Text(item.detail)
        .fontSize(11)
        .fontColor(item.tone);
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(14)
    .backgroundColor('#202522')
    .borderRadius(24)
  }

  @Builder
  private buildEventCard(item: WatchEventItem): void {
    Row({ space: 10 }) {
      Column()
        .width(10)
        .height(10)
        .borderRadius(999)
        .backgroundColor(item.tone)
        .margin({ top: 6 });

      Column({ space: 4 }) {
        Row() {
          Text(item.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8F4EC');

          Blank();

          Text(item.timeLabel)
            .fontSize(11)
            .fontColor('#B8B2A9');
        }
        .width('100%');

        Text(item.detail)
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#D6D0C8');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#202522')
    .borderRadius(24)
  }

  @Builder
  private buildActionRow(): void {
    Row({ space: 10 }) {
      Button('记心情')
        .layoutWeight(1)
        .fontSize(13)
        .fontColor('#10110F')
        .backgroundColor('#D9B27E')
        .borderRadius(999)
        .onClick(() => {
          this.moodLabel = '✨ 满足';
          this.syncLabel = '已在手表端记录一条情绪';
        });

      Button('同步手机')
        .layoutWeight(1)
        .fontSize(13)
        .fontColor('#F8F4EC')
        .backgroundColor('#2C332E')
        .borderRadius(999)
        .onClick(() => {
          this.syncLabel = '已准备和手机端时间轴对齐';
        });
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.buildHero()

        Row({ space: 10 }) {
          ForEach(this.cards, (item: WatchSummaryCard) => {
            this.buildSummaryCard(item)
          }, (item: WatchSummaryCard): string => item.id)
        }
        .width('100%');

        Text('关键片段')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8F4EC');

        ForEach(this.events, (item: WatchEventItem) => {
          this.buildEventCard(item)
        }, (item: WatchEventItem): string => item.id)

        this.buildActionRow()

        Text(this.syncLabel)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#A9A39A')
          .textAlign(TextAlign.Center);
      }
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
      .width('100%');
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor('#111412')
  }
}
