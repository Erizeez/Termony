import { UIStyle } from '../../common/Constants'
import { curves } from '@kit.ArkUI';

@ComponentV2
struct TitleBarButton {
  @Param@Once@Require value: Resource;
  @Local myBackgroundColor: ResourceColor = $r('app.color.bg')

  build() {
    Button() {
      SymbolGlyph(this.value)
        .fontColor([Color.White])
        .fontSize(UIStyle.DECOR_BUTTON_ICON_SIZE)
    }
    .backgroundColor(this.myBackgroundColor)
    .type(ButtonType.ROUNDED_RECTANGLE)
    .width(UIStyle.DECOR_BUTTON_SIZE)
    .height(UIStyle.DECOR_BUTTON_SIZE)
    .onHover((hovered) => {
      this.getUIContext()?.animateTo({
        curve: curves.springMotion(),
        duration: 200,
      }, () => {
        this.myBackgroundColor = hovered ? $r('app.color.neutral_gray') : $r('app.color.bg');
      })
    })
  }
}

export { TitleBarButton };
