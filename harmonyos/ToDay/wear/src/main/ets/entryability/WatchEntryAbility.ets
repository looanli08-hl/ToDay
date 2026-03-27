import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class WatchEntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        console.error(`手表页面加载失败: ${JSON.stringify(error)}`);
      }
    });
  }
}
