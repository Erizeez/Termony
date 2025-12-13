import { UIStyle } from '../common/Constants'

const DOMAIN = 0x0000;

@ComponentV2
struct TitleBar {
  @Param titlePaddingRight: number = 0;

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
        Button() {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontColor([Color.White])
            .fontSize(UIStyle.DECOR_BUTTON_ICON_SIZE)
        }
        .backgroundColor($r('app.color.bg'))
        .type(ButtonType.ROUNDED_RECTANGLE)
        .width(UIStyle.DECOR_BUTTON_SIZE)
        .height(UIStyle.DECOR_BUTTON_SIZE)

        Button() {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontColor([Color.White])
            .fontSize(UIStyle.DECOR_BUTTON_ICON_SIZE)
        }
        .fontColor(Color.White)
        .backgroundColor($r('app.color.bg'))
        .type(ButtonType.ROUNDED_RECTANGLE)
        .width(UIStyle.DECOR_BUTTON_SIZE)
        .height(UIStyle.DECOR_BUTTON_SIZE)

        Button() {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontColor([Color.White])
            .fontSize(UIStyle.DECOR_BUTTON_ICON_SIZE)
        }
        .fontColor(Color.White)
        .backgroundColor($r('app.color.bg'))
        .type(ButtonType.ROUNDED_RECTANGLE)
        .width(UIStyle.DECOR_BUTTON_SIZE)
        .height(UIStyle.DECOR_BUTTON_SIZE)
        .onClick(() => {
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
