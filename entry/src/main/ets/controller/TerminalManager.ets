import testNapi from 'libentry.so';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

export interface TerminalTab {
  id: number;        // Logic ID (for UI)
  title: string;     // Tab name
  sessionId: string;
}

export type TerminalListener = () => void;

export class TerminalManager {
  private tabs: TerminalTab[] = [];
  private listeners: TerminalListener[] = [];
  private nextId: number = 1;

  private currentId: number = 0; // point to tabs[i].id

  constructor() {
    // add a terminal by default
    this.addTerminal();
  }

  subscribe(listener: TerminalListener) {
    this.listeners.push(listener);
  }

  unsubscribe(listener: TerminalListener) {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  private notify() {
    this.listeners.forEach(fn => fn());
  }

  addTerminal() {
    const id = this.nextId++;

    const sessionId = testNapi.createSession();
    testNapi.runSession(sessionId);

    const newTab: TerminalTab = {
      id: id,
      title: `Terminal ${id}`,
      sessionId: sessionId.toString(),
    };

    this.tabs.push(newTab);
    this.currentId = newTab.id;

    this.notify();
  }

  removeTerminal(id: number) {
    if (this.tabs.length <= 1) return;

    const index = this.tabs.findIndex(t => t.id === id);
    if (index === -1) return;

    const removed = this.tabs[index];
    this.tabs.splice(index, 1);

    if (this.currentId === id) {
      this.currentId = this.tabs[Math.max(index - 1, 0)].id;
    }

    this.notify();

    // finally destroy session
    hilog.info(DOMAIN, 'testTag', 'destroySession sessionId: %{public}s',
      removed.sessionId);
    testNapi.destroySession(BigInt(removed.sessionId));
  }

  switchTerminal(id: number) {
    const exists = this.tabs.some(t => t.id === id);
    if (!exists) return;

    this.currentId = id;
    this.notify();
  }

  getTabs() {
    return this.tabs;
  }

  getCurrentId() {
    return this.currentId;
  }

  getCurrentSessionId(): string {
    return this.tabs.find(t => t.id === this.currentId)!.sessionId;
  }
}
