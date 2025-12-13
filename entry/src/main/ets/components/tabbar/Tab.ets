import { TerminalManager, TerminalTab } from '../../controller/TerminalManager'
import { UIStyle } from '../../common/Constants'
import { curves } from '@kit.ArkUI';

@ComponentV2
struct Tab {
  @Param@Require manager: TerminalManager;

  @Param@Require tab: TerminalTab;

  @Local hovered: boolean = false;
  @Param clicked: boolean = false;

  @Local closeButtonBackgroundColor: ResourceColor = 'rgba(0, 0, 0, 0)'
  @Param@Require tabWidth: number;

  resolveTabColor() {
    if (this.clicked) return $r('app.color.bg0_h');
    if (this.hovered) return $r('app.color.bg3');
    return $r('app.color.bg1');
  }

  build() {
    Row() {
      Text(this.tab.title)
        .fontColor(Color.White)
        .fontSize(16)
        .padding({ left: 12, right: 12 })

      // Auto fill space
      Blank()

      Button() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontColor([Color.White])
          .fontSize(16)
      }
      .size({ width: 26, height: 26 })
      .type(ButtonType.ROUNDED_RECTANGLE)
      .backgroundColor(this.closeButtonBackgroundColor)
      .onHover((hovered) => {
        this.getUIContext()?.animateTo({
          curve: curves.springMotion(),
          duration: 100,
        }, () => {
          this.closeButtonBackgroundColor = hovered ? 'rgba(200, 200, 200, 0.3)' : 'rgba(0, 0, 0, 0)';
        })
      })
      .onClick(() => {
        this.manager.removeTerminal(this.tab.id)
      })
      .margin({ right: 10 })
    }
    .width(this.tabWidth)
    .height(UIStyle.TAB_HEIGHT)
    .backgroundColor(this.resolveTabColor())
    .borderRadius({
      topLeft: 10,
      topRight: 10,
      bottomLeft: 0,
      bottomRight: 0
    })
    .onHover((hovered) => {
      this.hovered = hovered
    })
    .onClick(() => {
      this.manager.switchTerminal(this.tab.id)
    })
  }
}

export { Tab }
