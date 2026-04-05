/** Deterministic tone generator — LCG seeded by date or user seed */

const LOG_MIN = Math.log(200);
const LOG_MAX = Math.log(1800);
const N_TONES = 5;

function lcg(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(1664525, s) + 1013904223) >>> 0;
    return s / 0xFFFFFFFF;
  };
}

function seedFromDate(date: Date): number {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  const d = date.getUTCDate();
  // Simple numeric hash
  return (y * 10000 + m * 100 + d) & 0xFFFFFFFF;
}

export function generateTones(seed: number): number[] {
  const rand = lcg(seed);
  return Array.from({ length: N_TONES }, () => {
    const t = rand();
    return Math.round(Math.exp(LOG_MIN + t * (LOG_MAX - LOG_MIN)));
  });
}

export function generateDailyTones(): { tones: number[]; seed: number } {
  const seed = seedFromDate(new Date());
  return { tones: generateTones(seed), seed };
}

export function generateRandomTones(): { tones: number[]; seed: number } {
  const seed = (Math.random() * 0xFFFFFFFF) >>> 0;
  return { tones: generateTones(seed), seed };
}

/** Logarithmic Hz from slider value [0..1] */
export function sliderToHz(value: number): number {
  return Math.round(Math.exp(LOG_MIN + value * (LOG_MAX - LOG_MIN)));
}

/** Slider value [0..1] from Hz */
export function hzToSlider(hz: number): number {
  return (Math.log(hz) - LOG_MIN) / (LOG_MAX - LOG_MIN);
}

export const TONE_COLORS = [
  '#00F5FF', // cyan
  '#38bdf8', // sky
  '#a78bfa', // violet
  '#f472b6', // pink
  '#FF00FF', // magenta
];
