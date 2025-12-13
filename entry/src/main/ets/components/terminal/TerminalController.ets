import { hilog } from '@kit.PerformanceAnalysisKit';
import testNapi from 'libentry.so';

const DOMAIN = 0x0000;

export class TerminalController extends XComponentController {
  private sessionId: string = "";
  private surfaceId: string = "";
  private boundedSurfaceId: string = "";
  private surfaceRect: SurfaceRect | null = null;

  constructor() {
    super();
  }

  changeSession(sessionId: string) {
    this.sessionId = sessionId;
    this.tryBind();
  }

  onSurfaceCreated(surfaceId: string): void {
    this.surfaceId = surfaceId;
    this.tryBind();
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    this.surfaceRect = rect;

    if (this.sessionId == "") return;
    hilog.info(DOMAIN, 'testTag', 'onSurfaceChanged sessionId: %{public}s rect: %{public}s',
      this.sessionId, JSON.stringify(rect));

    testNapi.resizeSurface(BigInt(this.sessionId), rect.surfaceWidth, rect.surfaceHeight);
  }

  onSurfaceDestroyed(surfaceId: string): void {
    if (this.boundedSurfaceId != "") {
      testNapi.destroySurface(BigInt(surfaceId));
      this.boundedSurfaceId = "";
    }
    this.surfaceId = "";
  }

  private tryBind() {
    if (this.sessionId === "" || this.surfaceId === "") {
      return;
    }

    if (this.boundedSurfaceId == "") {
      hilog.info(DOMAIN, 'testTag', 'onSurfaceCreated sessionId: %{public}s, surfaceId: %{public}s',
        this.sessionId, this.surfaceId);
      testNapi.createSurface(BigInt(this.sessionId), BigInt(this.surfaceId));
      this.boundedSurfaceId = this.surfaceId;
    } else {
      // session 已存在，仅切换逻辑
      hilog.info(DOMAIN, 'testTag', 'onSurfaceDestroyed sessionId: %{public}s, surfaceId: %{public}s',
        this.sessionId, this.surfaceId);
      testNapi.destroySurface(BigInt(this.boundedSurfaceId));
      hilog.info(DOMAIN, 'testTag', 'onSurfaceCreated sessionId: %{public}s, surfaceId: %{public}s',
        this.sessionId, this.surfaceId);
      testNapi.createSurface(BigInt(this.sessionId), BigInt(this.surfaceId));
      this.boundedSurfaceId = this.surfaceId;
    }

    if (this.surfaceRect != null) {
      testNapi.resizeSurface(BigInt(this.sessionId), this.surfaceRect.surfaceWidth, this.surfaceRect.surfaceHeight);
    }
  }
}
