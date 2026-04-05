/** Web Audio API sine wave synthesizer */

let ctx: AudioContext | null = null;

function getCtx(): AudioContext {
  if (!ctx || ctx.state === 'closed') {
    ctx = new AudioContext();
  }
  if (ctx.state === 'suspended') {
    ctx.resume();
  }
  return ctx;
}

/** Play a pure sine tone for `durationMs` milliseconds. Returns a stop function. */
export function playTone(hz: number, durationMs = 1500, volume = 0.4): () => void {
  const ac = getCtx();
  const osc = ac.createOscillator();
  const gain = ac.createGain();

  osc.type = 'sine';
  osc.frequency.setValueAtTime(hz, ac.currentTime);

  // Fade in / out to avoid clicks
  gain.gain.setValueAtTime(0, ac.currentTime);
  gain.gain.linearRampToValueAtTime(volume, ac.currentTime + 0.02);
  gain.gain.setValueAtTime(volume, ac.currentTime + durationMs / 1000 - 0.05);
  gain.gain.linearRampToValueAtTime(0, ac.currentTime + durationMs / 1000);

  osc.connect(gain);
  gain.connect(ac.destination);
  osc.start(ac.currentTime);
  osc.stop(ac.currentTime + durationMs / 1000 + 0.01);

  let stopped = false;
  const stop = () => {
    if (stopped) return;
    stopped = true;
    try {
      const now = ac.currentTime;
      gain.gain.cancelScheduledValues(now);
      gain.gain.linearRampToValueAtTime(0, now + 0.04);
      osc.stop(now + 0.05);
    } catch { /* already stopped */ }
  };

  osc.onended = () => stop();
  return stop;
}

/** Preview tone while slider moves — restarts automatically. */
let previewStop: (() => void) | null = null;
export function previewHz(hz: number) {
  if (previewStop) { previewStop(); previewStop = null; }
  previewStop = playTone(hz, 400, 0.3);
}

export function stopAll() {
  if (previewStop) { previewStop(); previewStop = null; }
}
