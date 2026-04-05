/** Echoed scoring — Hz-difference based */

const MAX_POINTS = 20;
const PERFECT_ZONE_HZ = 5;
const ZERO_ZONE_HZ = 50;

export function scoreToneHz(guessHz: number, targetHz: number): number {
  const diff = Math.abs(guessHz - targetHz);
  if (diff <= PERFECT_ZONE_HZ) return MAX_POINTS;
  if (diff >= ZERO_ZONE_HZ)    return 0;
  const t = (diff - PERFECT_ZONE_HZ) / (ZERO_ZONE_HZ - PERFECT_ZONE_HZ);
  return MAX_POINTS * (1 - t);
}

export function totalScore(tones: number[], guesses: number[]): number {
  return tones.reduce((s, t, i) => s + scoreToneHz(guesses[i] ?? 0, t), 0);
}

export function totalPercent(tones: number[], guesses: number[]): number {
  return (totalScore(tones, guesses) / (MAX_POINTS * tones.length)) * 100;
}

export function gradeLabel(pct: number): string {
  if (pct >= 97) return 'S+';
  if (pct >= 90) return 'S';
  if (pct >= 80) return 'A';
  if (pct >= 65) return 'B';
  if (pct >= 50) return 'C';
  if (pct >= 30) return 'D';
  return 'F';
}

export function gradeColor(pct: number): string {
  if (pct >= 90) return '#7BF696';
  if (pct >= 70) return '#B0F67B';
  if (pct >= 50) return '#F6D67B';
  if (pct >= 30) return '#F6A07B';
  return '#F67B7B';
}

export function funnyMessage(pct: number): string {
  if (pct >= 97) return "Are you even human? Absolute ear wizardry. 🧙";
  if (pct >= 90) return "Golden ears detected. Seriously impressive.";
  if (pct >= 80) return "Sharp as a tuning fork. Great round!";
  if (pct >= 65) return "Pretty solid! Your inner piano tuner is showing.";
  if (pct >= 50) return "Not bad — a musician in the making? Maybe.";
  if (pct >= 30) return "Your ears tried their best. Respect the effort.";
  if (pct >= 10) return "Tone-deaf legend. The frequencies were just vibes anyway.";
  return "Bold strategy — zero points. Absolute chaos. We love it. 😂";
}

export function deviationCents(guessHz: number, targetHz: number): number {
  return 1200 * Math.log2(guessHz / targetHz);
}

export function toneScoreColor(pts: number): string {
  const pct = (pts / MAX_POINTS) * 100;
  return gradeColor(pct);
}
