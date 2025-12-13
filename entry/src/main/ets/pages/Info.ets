import { common } from '@kit.AbilityKit';
import { TitleBarButton } from '../components/titlebar/TitleBarButton'
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Preview
@CustomDialog
struct Info {
  controller?: CustomDialogController

  uiContext = this.getUIContext();

  private onClickJumpRepo = () => {
    const context = this.uiContext?.getHostContext() as common.UIAbilityContext;

    context.openLink('https://github.com/TermonyHQ/Termony', { appLinkingOnly: false })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'failed to open link' + error);
      });
  }

  private onClickJumpIssue = () => {
    const context = this.uiContext?.getHostContext() as common.UIAbilityContext;

    context.openLink('https://github.com/TermonyHQ/Termony/issues', { appLinkingOnly: false })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'failed to open link' + error);
      });
  }

  build() {
    Stack() {
      Row() {
        Stack() {
          // Logo
          Image($r('app.media.startIcon'))
            .width(128)
            .height(128)
            .objectFit(ImageFit.Cover)
            .borderRadius(24)
        }
        .width("35%")
        .margin({
          top: 32
        })

        Stack()
          .width(1)
          .height("80%")
          .backgroundColor($r('app.color.fg'))
          .margin(16)

        Column() {
          Text("Termony")
            .fontSize(36)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)

          Text("版本: v0.0.0")
            .fontSize(16)
            .fontColor($r('app.color.fg4'))
            .margin({
              top: 12,
            })

          Text('仓库地址: https://github.com/TermonyHQ/Termony')
            .fontSize(16)
            .fontColor($r('app.color.fg2'))
            .margin({
              top: 12,
            })
            .hoverEffect(HoverEffect.Scale)
            .onClick(() => {
              this.onClickJumpRepo()
            })

          Text('提交反馈')
            .fontSize(16)
            .fontColor($r('app.color.fg0'))
            .margin({
              top: 12,
            })
            .hoverEffect(HoverEffect.Scale)
            .onClick(() => {
              this.onClickJumpIssue()
            })

          Text("MIT License")
            .fontSize(16)
            .fontColor($r('app.color.bg4'))
            .margin({
              top: 12,
            })

          Text("Copyright (c) 2025 Jiajie Chen")
            .fontSize(16)
            .fontColor($r('app.color.bg4'))
            .margin({
              top: 6,
            })
        }
        .width("55%")
      }
      .alignItems(VerticalAlign.Center)
      .height('100%')

      Row() {
        Row() {
          Stack() {
            // Logo
            Image($r('app.media.startIcon'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Cover)
              .borderRadius(6)
          }

          Text("关于")
            .fontSize(18)
            .fontColor(Color.White)
            .margin({ left: 8 })

          Blank()

          TitleBarButton({
            value: $r('sys.symbol.xmark')
          })
          .onClick(() => {
            this.controller?.close()
          })
        }
        .width('100%')
      }
      .padding(16)
      .width("100%")
    }
    .width("80%")
    .height("80%")
    .borderRadius(16)
    .backgroundColor($r('app.color.bg1'))
    .align(Alignment.Top)
  }
}

export { Info }