import { Terminal } from '../components/terminal/Terminal';
import { TitleBar } from '../components/titlebar/TitleBar'
import { TabBar } from '../components/tabbar/TabBar'
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { TerminalManager } from '../controller/TerminalManager'

const DOMAIN = 0x0000;

enum PageType {
  Terminal,
  Settings,
  Help,
  About,
}

@Entry
@ComponentV2
struct Index {
  @Local currentPage: PageType = PageType.Terminal;
  @Local currentTab: number = 0;

  @Local titlePaddingRight: number = 0;

  private manager: TerminalManager = new TerminalManager();

  async onPageShow() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      hilog.error(DOMAIN, 'testTag', 'failed to get host context');
    }

    try {
      const windowClass = await window.getLastWindow(context);

      if (!windowClass) {
        hilog.error(DOMAIN, 'testTag', 'failed to get last window');
        return;
      }

      const rect = windowClass.getTitleButtonRect()
      this.titlePaddingRight = rect.width

      windowClass.on("windowTitleButtonRectChange", (rect) => {
        this.titlePaddingRight = rect.width
        hilog.info(DOMAIN, "testTag", "titlePaddingRight change to: %d", this.titlePaddingRight)
      })

    } catch (err) {
    }
  }

  build() {
    Column() {
      // -------------------------------
      // Title Bar
      // -------------------------------
      TitleBar({
        titlePaddingRight: this.titlePaddingRight
      })
        .border({
          width: { bottom: 1 },
          color: { bottom: $r('app.color.fg4') }
        })

      // -------------------------------
      // Tab Bar
      // -------------------------------
      TabBar({
        manager: this.manager
      })

      // -------------------------------
      // Terminal Area
      // -------------------------------
      Terminal({
        manager: this.manager
      }).layoutWeight(1)
    }
    .height('100%')
    .width('100%')
  }
}
