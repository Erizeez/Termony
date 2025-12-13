import { UIStyle } from '../../common/Constants'
import { TitleBarButton } from './TitleBarButton'
import { Info } from '../../pages/Info'
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { emitter } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

@ComponentV2
struct TitleBar {
  @Param titlePaddingRight: number = 0;

  onClickOpenSettings() {
    emitter.emit("CREATE_NEW_WINDOW",
      {
        data: {
          pageUrl: "pages/Settings",
          windowName: "Settings",
          title: "设置"
        }
      }
    );
  }

  infoDialogController: CustomDialogController = new CustomDialogController({
    builder: Info(),
    autoCancel: false,
    customStyle: true,
  })

  uiContext = this.getUIContext();

  private onClickJumpHelp = () => {
    const context = this.uiContext?.getHostContext() as common.UIAbilityContext;

    context.openLink('https://github.com/TermonyHQ/Termony/blob/master/README_CN.md',
      { appLinkingOnly: false })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'failed to open link' + error);
      });
  }

  build() {
    Row() {
      // Left side
      Row() {
        Stack() {
          // Logo
          Image($r('app.media.startIcon'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Cover)
            .borderRadius(6)
        }

        Text("Termony")
          .fontSize(18)
          .fontColor(Color.White)
          .margin({ left: 8 })
      }
      .margin({ left: 12 })

      // Auto fill space
      Blank()

      // Right side
      Row({ space: UIStyle.DECOR_BUTTON_SPACING }) {
        TitleBarButton({
          value: $r('sys.symbol.gearshape')
        })
          .onClick(() => {
            this.onClickOpenSettings();
          })

        TitleBarButton({
          value: $r('sys.symbol.questionmark_circle')
        })
          .onClick(() => {
            this.onClickJumpHelp();
          })

        TitleBarButton({
          value: $r('sys.symbol.info_circle')
        })
          .onClick(() => {
            this.infoDialogController.open();
          })
      }
      .margin({ right: this.titlePaddingRight })
    }
    .width('100%')
    .height(UIStyle.DECOR_HEIGHT)
    .backgroundColor($r('app.color.bg'))
  }
}

export { TitleBar };
