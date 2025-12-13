import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { inputMethod } from '@kit.IMEKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import testNapi from 'libentry.so';
import { TerminalController } from './TerminalController'
import { TerminalManager } from '../../controller/TerminalManager'
import { KeyMapping } from './KeyMapping'

const DOMAIN = 0x0000;

function encodeUtf8(s: string): Uint8Array {
  const encoder = new util.TextEncoder('utf-8');
  return encoder.encodeInto(s);
}

@Entry
@ComponentV2
struct Terminal {
  @Param@Require manager: TerminalManager;

  @Local leftCtrlPressed: boolean = false;
  @Local touchState: Map<number, number> = new Map();

  @Local sessionId: string = "";

  @Local xComponentController: TerminalController = new TerminalController();

  reconstructTerminal() {
    this.sessionId = this.manager.getCurrentSessionId()

    this.xComponentController.changeSession(this.sessionId)
    hilog.info(DOMAIN, 'testTag', 'reconstruct terminal for: %s', this.sessionId);
  }

  aboutToAppear() {
    this.manager.subscribe(() => {
      this.reconstructTerminal();
    });

    this.reconstructTerminal();
  }

  imController: inputMethod.InputMethodController = inputMethod.getController();
  imControllerOnce: Function = () => {
    this.imController.on('insertText', string => {
      console.log('ime insert text:', string.length, string);
      if (string.length) {
        testNapi.send(BigInt(this.sessionId), encodeUtf8(string).buffer);
      }
    })

    this.imController.on('deleteLeft', len => {
      console.log('ime backspace:', len);
      if (len) {
        testNapi.send(BigInt(this.sessionId), new Uint8Array(new Array(len).fill(0x7f)).buffer);
      }
    })

    this.imController.on('sendFunctionKey', _ => {
      // this will only send ENTER key
      console.log('ime enter:', JSON.stringify(_));
      testNapi.send(BigInt(this.sessionId), new Uint8Array([0x0d]).buffer);
    })

    // updating cursor position is complicated
    this.imController.updateCursor({
      top: 0,
      left: 0,
      width: 600,
      height: 48,
    })

    this.imControllerOnce = () => {}
  }
  timer: number = -1;

  // minimize automatically detach it
  // FIXME: ime still active on context menu
  enableIme() {
    this.imController.attach(false, {
      inputAttribute: {
        textInputType: inputMethod.TextInputType.TEXT,
        enterKeyType: inputMethod.EnterKeyType.NEWLINE,
      }
    })
      .then(() => {
        console.log('ime attached');
        this.imControllerOnce();
      })
      .catch((err: BusinessError) => {
        console.log('ime attach error:', JSON.stringify(err))
      })
  }

  onPageShow() {
    this.timer = setInterval(() => {
      let res: string | undefined = testNapi.checkCopy(BigInt(this.sessionId));
      if (res !== undefined) {
        hilog.info(DOMAIN, 'testTag', 'Copy to pasteboard in ArkTS: %{public}s', res);
        let base64 = new util.Base64Helper();
        let data = base64.decodeSync(res);
        let textDecoder = util.TextDecoder.create('utf-8');
        let result = textDecoder.decodeToString(data);
        hilog.info(DOMAIN, 'testTag', 'Copy to pasteboard in ArkTS decoded: %{public}s', result);
        let pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, result);
        let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteData, (err, data) => {
          if (err) {
            hilog.info(0x0000, 'mainTag', 'Failed to set pasteboard: %{public}s', JSON.stringify(err));
            return;
          } else {
            promptAction.showToast({
              message: "Copied to pasteboard",
              duration: 1000,
              bottom: "center",
            })
          }
        });
      }

      if (testNapi.checkPaste(BigInt(this.sessionId))) {
        // need to paste
        const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        atManager.requestPermissionsFromUser(getContext(), ['ohos.permission.READ_PASTEBOARD']).then(async () => {
          let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
          let data = await systemPasteboard.getData();
          hilog.info(DOMAIN, 'testTag', 'Got pasteboard data: %{public}s', JSON.stringify(data));
          let count = data.getRecordCount();
          for (let i = 0;i < count;i++) {
            let record = data.getRecord(i);
            hilog.info(DOMAIN, 'testTag', 'Got pasteboard record: %{public}s', JSON.stringify(record));
            let plainText: string = record.plainText;
            let encodeResult = encodeUtf8(plainText);
            let base64 = new util.Base64Helper();
            let encoded = base64.encodeToStringSync(encodeResult);
            testNapi.pushPaste(BigInt(this.sessionId), encoded);
          }

          promptAction.showToast({
            message: "Pasted from pasteboard",
            duration: 1000,
            bottom: "center",
          })
        });
      }
    }, 100);
    // there is a race condition if current pid is not focused
    // attach will fail
    setTimeout(():void => this.enableIme(), 500);
    testNapi.onForeground(BigInt(this.sessionId));
  }

  onPageHide() {
    clearInterval(this.timer);
    testNapi.onBackground(BigInt(this.sessionId));
  }

  @Builder MenuBuilder() {
    Menu() {
      MenuItem({ content: "Paste" })
        .onClick(async () => {
          const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
          await atManager.requestPermissionsFromUser(getContext(), ['ohos.permission.READ_PASTEBOARD']);
          let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
          let data = await systemPasteboard.getData();
          hilog.info(DOMAIN, 'testTag', 'Got pasteboard data: %{public}s', JSON.stringify(data));
          let count = data.getRecordCount();
          for (let i = 0;i < count;i++) {
            let record = data.getRecord(i);
            hilog.info(DOMAIN, 'testTag', 'Got pasteboard record: %{public}s', JSON.stringify(record));
            let plainText: string = record.plainText;
            let encodeResult = encodeUtf8(plainText);
            testNapi.send(BigInt(this.sessionId), encodeResult.buffer);
          }
        })
    }
  }

  build() {
    Row() {
      Column() {
        XComponent({
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
        .bindContextMenu(this.MenuBuilder, ResponseType.RightClick)
        .onAxisEvent((event: AxisEvent) => {
          let offset = event.getVerticalAxisValue()
          // hilog.info(DOMAIN, 'testTag', 'Got Axis offset: %{public}d', offset);
          testNapi.scroll(BigInt(this.sessionId), offset);
        })
        .focusable(true)
        .focusOnTouch(true)
        .onKeyEvent((event: KeyEvent) => {
          hilog.info(DOMAIN, 'testTag', 'Got key: %{public}s', JSON.stringify(event));
          if (event.type === KeyType.Down) {
            if (this.leftCtrlPressed && event.unicode as number >= 97 && event.unicode as number <= 122) {
              // Ctrl-A to Ctrl-Z
              const escape = event.unicode as number - 97 + 1; // ^A is 0x1
              testNapi.send(BigInt(this.sessionId), new Uint8Array([escape]).buffer);
            } else if (event.keyText === "KEYCODE_EQUALS") {
              let buffer = new ArrayBuffer(1);
              let view = new Uint8Array(buffer);
              // workaround
              if (event.unicode === 0x3d) {
                view[0] = 0x2b;
              } else {
                view[0] = 0x3d;
              }
              testNapi.send(BigInt(this.sessionId), buffer);
            } else if (event.unicode !== 0) {
              const array = encodeUtf8(String.fromCharCode(event.unicode as number));
              testNapi.send(BigInt(this.sessionId), array.buffer);
            } else {
              if (event.keyText === "KEYCODE_CTRL_LEFT") {
                this.leftCtrlPressed = true;
              } else if (KeyMapping.has(event.keyText)) {
                const sequence = KeyMapping.get(event.keyText)!;
                testNapi.send(BigInt(this.sessionId), new Uint8Array(sequence).buffer);
              }
            }
          } else if (event.type === KeyType.Up) {
            if (event.keyText === "KEYCODE_CTRL_LEFT") {
              this.leftCtrlPressed = false;
            }
          }
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onTouch((event: TouchEvent) => {
      // hilog.info(DOMAIN, 'testTag', 'Got touch: %{public}s', JSON.stringify(event));
      for (let touch of event.touches) {
        if (touch.type === TouchType.Down) {
          this.touchState.set(touch.id, touch.y);
        } else if (touch.type === TouchType.Move) {
          // we use pixels, convert from vp to px
          let offset = vp2px(this.touchState.get(touch.id) as number - touch.y);
          this.touchState.set(touch.id, touch.y);
          // hilog.info(DOMAIN, 'testTag', 'Got touch offset: %{public}d', offset);
          testNapi.scroll(BigInt(this.sessionId), offset);
        }
      }
    })
  }
}

export { Terminal };
