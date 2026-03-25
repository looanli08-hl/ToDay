import { AppContainer } from '../app/AppContainer';
import { ThemeMode, TodayTheme } from '../common/theme/TodayTheme';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

@Component
export struct SettingsPage {
  @Link mode: ThemeMode;

  private readonly viewModel: TodayViewModel = AppContainer.shared.todayViewModel;

  @State private healthStatus: string = '未授权';
  @State private locationStatus: string = '未授权';
  @State private photoStatus: string = '未授权';
  @State private summaryText: string = '今日记录 0 条，带备注 0 条';
  @State private showClearConfirm: boolean = false;
  @State private showClearSuccess: boolean = false;

  aboutToAppear(): void {
    this.syncFromViewModel();
  }

  private async syncFromViewModel(): Promise<void> {
    await this.viewModel.initialize();
    await this.viewModel.loadIfNeeded();
    this.healthStatus = this.viewModel.healthPermissionStatus;
    this.locationStatus = this.viewModel.locationPermissionStatus;
    this.photoStatus = this.viewModel.photoPermissionStatus;
    this.summaryText = `今日记录 ${this.viewModel.todayManualRecordCount} 条，带备注 ${this.viewModel.todayNoteCount} 条`;
    this.viewModel.setThemeMode(this.mode);
  }

  private openClearDialog(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.showClearConfirm = true;
    });
  }

  private closeClearDialog(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.showClearConfirm = false;
    });
  }

  private async clearAllData(): Promise<void> {
    await this.viewModel.clearAllData();
    await this.syncFromViewModel();
    this.showClearConfirm = false;
    this.showClearSuccess = true;
    setTimeout(() => {
      this.showClearSuccess = false;
    }, 1800);
  }

  @Builder
  private buildSectionTitle(title: string): void {
    Text(title)
      .width('100%')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(TodayTheme.color('inkMuted', this.mode));
  }

  @Builder
  private buildRow(title: string, detail: string, accentColor?: string, showArrow: boolean = false): void {
    Row({ space: 12 }) {
      Text(title)
        .fontSize(16)
        .fontColor(TodayTheme.color('ink', this.mode))
        .layoutWeight(1);

      Text(detail)
        .fontSize(16)
        .fontColor(accentColor ?? TodayTheme.color('inkMuted', this.mode));

      if (showArrow) {
        Text('›')
          .fontSize(16)
          .fontColor(TodayTheme.color('inkFaint', this.mode));
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 16, right: 16 })
    .backgroundColor(TodayTheme.color('card', this.mode))
  }

  @Builder
  private buildThemeCard(): void {
    Column({ space: 12 }) {
      this.buildSectionTitle('外观')

      Row({ space: 10 }) {
        Button('浅色')
          .layoutWeight(1)
          .fontColor(this.mode === ThemeMode.Light ? '#FFFFFF' : TodayTheme.color('ink', this.mode))
          .backgroundColor(this.mode === ThemeMode.Light ? TodayTheme.color('accent', this.mode) : TodayTheme.color('card', this.mode))
          .borderRadius(16)
          .border({
            width: 1,
            color: this.mode === ThemeMode.Light ? TodayTheme.color('accent', this.mode) : TodayTheme.color('border', this.mode)
          })
          .onClick(() => {
            this.mode = ThemeMode.Light;
            this.viewModel.setThemeMode(this.mode);
          });

        Button('深色')
          .layoutWeight(1)
          .fontColor(this.mode === ThemeMode.Dark ? '#FFFFFF' : TodayTheme.color('ink', this.mode))
          .backgroundColor(this.mode === ThemeMode.Dark ? TodayTheme.color('accent', this.mode) : TodayTheme.color('card', this.mode))
          .borderRadius(16)
          .border({
            width: 1,
            color: this.mode === ThemeMode.Dark ? TodayTheme.color('accent', this.mode) : TodayTheme.color('border', this.mode)
          })
          .onClick(() => {
            this.mode = ThemeMode.Dark;
            this.viewModel.setThemeMode(this.mode);
          });
      }
      .width('100%');

      Text(this.summaryText)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(TodayTheme.color('inkMuted', this.mode));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(TodayTheme.color('card', this.mode))
    .borderRadius(20)
    .border({
      width: 1,
      color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.8)
    })
  }

  @Builder
  private buildClearDialog(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TodayTheme.alpha('#000000', 0.28))
        .onClick(() => {
          this.closeClearDialog();
        });

      Column({ space: 16 }) {
        Text('确认清除？')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(TodayTheme.color('ink', this.mode));

        Text('此操作将删除所有手动标注和心情记录，无法撤销。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor(TodayTheme.color('inkMuted', this.mode))
          .textAlign(TextAlign.Center);

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor(TodayTheme.color('card', this.mode))
            .fontColor(TodayTheme.color('ink', this.mode))
            .borderRadius(16)
            .border({
              width: 1,
              color: TodayTheme.color('border', this.mode)
            })
            .onClick(() => {
              this.closeClearDialog();
            });

          Button('清除全部')
            .layoutWeight(1)
            .backgroundColor(TodayTheme.color('rose', this.mode))
            .fontColor('#FFFFFF')
            .borderRadius(16)
            .onClick(() => {
              this.clearAllData();
            });
        }
        .width('100%');
      }
      .width('82%')
      .padding(20)
      .backgroundColor(TodayTheme.color('background', this.mode))
      .borderRadius(24)
      .border({
        width: 1,
        color: TodayTheme.color('border', this.mode)
      });
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 18 }) {
          Text('设置')
            .width('100%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .fontColor(TodayTheme.color('ink', this.mode));

          this.buildThemeCard()

          this.buildSectionTitle('数据权限')
          Column({ space: 1 }) {
            this.buildRow('健康数据', this.healthStatus, this.healthStatus === '可用' ? TodayTheme.color('walkGreen', this.mode) : TodayTheme.color('workoutOrange', this.mode));
            this.buildRow('位置权限', this.locationStatus);
            this.buildRow('照片权限', this.photoStatus);
          }
          .width('100%')
          .backgroundColor(TodayTheme.color('border', this.mode))
          .borderRadius(20)
          .border({
            width: 1,
            color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.8)
          })

          this.buildSectionTitle('隐私')
          Column({ space: 1 }) {
            this.buildRow('隐私政策', '', undefined, true);
            this.buildRow('服务条款', '', undefined, true);
            this.buildRow('数据说明', '', undefined, true);
          }
          .width('100%')
          .backgroundColor(TodayTheme.color('border', this.mode))
          .borderRadius(20)
          .border({
            width: 1,
            color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.8)
          })

          this.buildSectionTitle('关于')
          Column({ space: 1 }) {
            this.buildRow('版本', '0.1.0 (1)');
            this.buildRow('联系我们', '', undefined, true);
            this.buildRow('官网', '', undefined, true);
          }
          .width('100%')
          .backgroundColor(TodayTheme.color('border', this.mode))
          .borderRadius(20)
          .border({
            width: 1,
            color: TodayTheme.alpha(TodayTheme.color('border', this.mode), 0.8)
          })

          this.buildSectionTitle('数据管理')
          Button('清除所有标注和记录')
            .width('100%')
            .height(52)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.color('rose', this.mode))
            .backgroundColor(TodayTheme.color('card', this.mode))
            .borderRadius(18)
            .border({
              width: 1,
              color: TodayTheme.alpha(TodayTheme.color('rose', this.mode), 0.35)
            })
            .onClick(() => {
              this.openClearDialog();
            });
        }
        .padding({
          left: TodayTheme.pagePadding(),
          right: TodayTheme.pagePadding(),
          top: TodayTheme.pagePadding(),
          bottom: 140
        })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor(TodayTheme.color('background', this.mode));

      if (this.showClearConfirm) {
        this.buildClearDialog();
      }

      if (this.showClearSuccess) {
        Column() {
          Text('已清除所有标注和记录')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(TodayTheme.color('ink', this.mode));
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(TodayTheme.color('card', this.mode))
        .borderRadius(999)
        .border({
          width: 1,
          color: TodayTheme.color('border', this.mode)
        })
        .margin({ left: 24, right: 24, top: 24 });
      }
    }
    .width('100%')
    .height('100%')
  }
}
