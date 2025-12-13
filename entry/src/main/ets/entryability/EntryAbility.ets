import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { emitter } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { UIStyle } from '../common/Constants'

const DOMAIN = 0x0000;

let windowStage_: window.WindowStage | null = null;

export default class EntryAbility extends UIAbility {

  private createWindow(eventData: emitter.EventData) {
    const data = eventData?.data;
    if (!data) {
      return;
    }

    if (windowStage_ == null) {
      console.error('Failed to create the subwindow. Cause: windowStage_ is null');
      return;
    }

    const mainWindow = windowStage_.getMainWindowSync();
    const mainProps = mainWindow.getWindowProperties();

    const mainRect = mainProps.windowRect;

    const subWidth = 1000;
    const subHeight = 1200;

    const targetX = Math.round(
      mainRect.left + (mainRect.width - subWidth) / 2
    );
    const targetY = Math.round(
      mainRect.top + (mainRect.height - subHeight) / 2
    );

    windowStage_.createSubWindowWithOptions(data.windowName,
      {
        title: data.title,
        decorEnabled: true,
      }).then((window) => {
        window.moveWindowTo(targetX, targetY, (err: BusinessError) => {
          let errCode: number = err.code;
          if (errCode) {
            hilog.error(DOMAIN, 'testTag', 'Failed to move the window. Cause:' + JSON.stringify(err));
            return;
          }
        });
        window.resize(subWidth, subHeight, (err: BusinessError) => {
          let errCode: number = err.code;
          if (errCode) {
            hilog.error(DOMAIN, 'testTag', 'Failed to change the window size. Cause:' + JSON.stringify(err));
            return;
          }
        });
        window.setUIContent(data.pageUrl).catch(() => {
          hilog.error(DOMAIN, 'testTag', 'failed to set ui content %{public}s for %{public}s',
            data.pageUrl, data.windowName);
        });
        window.showWindow().catch(() => {
          hilog.error(DOMAIN, 'testTag', 'failed to show window %{public}s for %{public}s',
            data.pageUrl, data.windowName);
        });

      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'createSubWindow failed %{public}s for %{public}s: %d',
          data.pageUrl, data.windowName, err.code);
      });
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    emitter.on("CREATE_NEW_WINDOW", (eventData) => {
      hilog.info(DOMAIN, 'testTag', 'emitter trigger: CREATE_NEW_WINDOW');
      this.createWindow(eventData);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage_ = windowStage;

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
        hilog.error(DOMAIN, 'testTag', 'Failed to set the style of button');
      }
    });

    const permissions: Array<Permissions> = [
      'ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY',
      'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY',
    ];

    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.context, permissions).catch(() => {
      hilog.error(DOMAIN, 'testTag', 'Failed to request permissions');
    })
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
