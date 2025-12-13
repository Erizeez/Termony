import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { UIStyle } from '../common/Constants'

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      try {
        let windowClass = windowStage.getMainWindowSync();

        windowClass.setWindowDecorVisible(false)
        windowClass.setWindowDecorHeight(UIStyle.DECOR_HEIGHT)

        let colorMode : ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

        let style: window.DecorButtonStyle = {
          colorMode: colorMode,
          buttonBackgroundSize: UIStyle.DECOR_BUTTON_SIZE,
          spacingBetweenButtons: UIStyle.DECOR_BUTTON_SPACING,
          closeButtonRightMargin: 8,
        };
        windowClass.setDecorButtonStyle(style)
      } catch (exception) {
        console.error(`Failed to set the style of button. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    });

    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.context, ['ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY']).then((data) => {
      atManager.requestPermissionsFromUser(this.context, ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY']).then((data) => {
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
