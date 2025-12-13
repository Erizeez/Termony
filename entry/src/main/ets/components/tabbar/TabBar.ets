import { TerminalManager, TerminalTab } from '../../controller/TerminalManager'
import { UIStyle } from '../../common/Constants'
import { curves } from '@kit.ArkUI'
import { Tab } from './Tab'
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@ComponentV2
struct TabBar {
  @Param@Require manager: TerminalManager

  @Local tabs: TerminalTab[] = []

  @Local current: number = 0

  @Local focusTabWidth: number = UIStyle.TAB_MAX_WIDTH
  @Local tabWidth: number = UIStyle.TAB_MAX_WIDTH

  @Local addButtonBackgroundColor: ResourceColor = $r('app.color.bg1')

  tabBarWidth: Length = 0

  updateTabInfos() {
    this.tabs = [...this.manager.getTabs()];
    this.current = this.manager.getCurrentId();

    let newTabWidth = this.tabBarWidth as number / this.tabs.length
    if (newTabWidth < UIStyle.TAB_MIN_WIDTH) {
      this.tabWidth = UIStyle.TAB_MIN_WIDTH
    } else if (newTabWidth > UIStyle.TAB_MAX_WIDTH) {
      this.tabWidth = UIStyle.TAB_MAX_WIDTH
    } else {
      this.tabWidth = newTabWidth
    }

    if (newTabWidth < UIStyle.TAB_FOCUS_MIN_WIDTH) {
      this.focusTabWidth = UIStyle.TAB_FOCUS_MIN_WIDTH
    } else if (newTabWidth > UIStyle.TAB_MAX_WIDTH) {
      this.focusTabWidth = UIStyle.TAB_MAX_WIDTH
    } else {
      this.focusTabWidth = newTabWidth
    }
  }

  aboutToAppear() {
    this.manager.subscribe(() => {
      this.updateTabInfos();
    });

    this.updateTabInfos();
  }

  build() {
    Row() {
      Row() {
        Scroll() {
          Row() {
            ForEach(this.tabs, (item: TerminalTab, index: number) => {
              Tab({
                manager: this.manager,
                tab: item,
                tabWidth: item.id == this.current ? this.focusTabWidth : this.tabWidth,
                clicked: item.id == this.current,
              })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBarWidth(0)
        .align(Alignment.Start)
        .layoutWeight(1)
        .onAreaChange((oldArea, newArea) => {
          this.tabBarWidth = newArea.width
          this.updateTabInfos()
        })

        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontColor([Color.White])
            .fontSize(16)
        }
        .type(ButtonType.ROUNDED_RECTANGLE)
        .size({ width: 28, height: 28 })
        .margin({ left: 10, right: 10 })
        .backgroundColor(this.addButtonBackgroundColor)
        .onHover((hovered) => {
          this.getUIContext()?.animateTo({
            curve: curves.springMotion(),
            duration: 200,
          }, () => {
            this.addButtonBackgroundColor = hovered ? $r('app.color.fg4') : $r('app.color.bg1');
          })
        })
        .onClick(() => {
          this.manager.addTerminal()
        })
      }
    }
    .height(UIStyle.TAB_BAR_HEIGHT)
    .padding({ left: 8 })
    .backgroundColor($r('app.color.bg1'))
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }
}

export { TabBar };