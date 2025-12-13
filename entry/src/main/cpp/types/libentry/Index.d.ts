// -------------------------
// Session
// -------------------------
export const createSession: () => BigInt;
export const destroySession: (sessionId: BigInt) => void;
export const runSession: (sessionId: BigInt) => void;

// -------------------------
// Surface
// -------------------------
export const createSurface: (sessionId: BigInt, id: BigInt) => void;
export const destroySurface: (id: BigInt) => void;
export const resizeSurface: (sessionId: BigInt, width: number, height: number) => void;

// -------------------------
// Terminal Operations
// -------------------------
export const send: (sessionId: BigInt, data: ArrayBuffer) => void;
export const scroll: (sessionId: BigInt, offset: number) => void;
// poll if any thing to copy/paste
export const checkCopy: (sessionId: BigInt) => string | undefined;
export const checkPaste: (sessionId: BigInt) => boolean;
// send paste result
export const pushPaste: (sessionId: BigInt, base64: string) => void;

// TODO
export const onForeground: (sessionId: BigInt) => void;
export const onBackground: (sessionId: BigInt) => void;