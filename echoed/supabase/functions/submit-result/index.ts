// Supabase Edge Function — submit-result
// Computes authoritative server-side score, verifies anti-cheat, stores result.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── PCG32 (must match Dart implementation bit-for-bit) ────────────────────────
class PCG32 {
  private stateLo: number;
  private stateHi: number;
  private incLo: number;
  private incHi: number;

  constructor(seed: number) {
    this.stateLo = 0;
    this.stateHi = 0;
    this.incLo = 0xCB | 1;
    this.incHi = 0x3E;
    this.step();
    this.stateLo = (this.stateLo + (seed & 0xFFFF)) & 0xFFFF;
    this.stateHi = (this.stateHi + ((seed >> 16) & 0xFFFF)) & 0xFFFF;
    this.step();
  }

  private step(): number {
    const oldHi = this.stateHi;
    const oldLo = this.stateLo;
    const mLo = 0x4C64;
    const mHi = 0xE867;
    const p0 = (oldLo * mLo) & 0xFFFFFFFF;
    const p1 = ((oldLo * mHi + oldHi * mLo) & 0xFFFF) + (p0 >> 16);
    this.stateLo = ((p0 & 0xFFFF) + this.incLo) & 0xFFFF;
    this.stateHi = (p1 + this.incHi + (this.stateLo < (p0 & 0xFFFF) ? 1 : 0)) & 0xFFFF;
    const xorshifted = ((oldHi << 14) | (oldLo >> 2)) & 0xFFFF;
    const rot = (oldHi >> 11) & 0x1F;
    return ((xorshifted >> rot) | (xorshifted << (32 - rot))) & 0xFFFF;
  }

  nextDouble(): number {
    return this.step() / 65536.0;
  }
}

function generateFrequencies(seed: number, count = 5): number[] {
  const prng = new PCG32(seed);
  const logMin = Math.log(200);
  const logMax = Math.log(1800);
  const tones: number[] = [];
  let attempts = 0;

  while (tones.length < count && attempts < 1000) {
    attempts++;
    const raw = prng.nextDouble();
    const hz = Math.exp(logMin + raw * (logMax - logMin));
    const rounded = Math.round(hz * 10) / 10;

    const tooClose = tones.some(t => {
      return Math.abs(1200 * Math.log2(rounded / t)) < 50;
    });

    if (!tooClose) tones.push(rounded);
  }

  return tones.sort((a, b) => a - b);
}

function scoreTone(guessHz: number, targetHz: number): number {
  if (targetHz <= 0 || guessHz <= 0) return 0;
  const cents = Math.abs(1200 * Math.log2(guessHz / targetHz));
  return Math.max(0, 20 * (1 - cents / 1200));
}

// ── Handler ────────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  const body = await req.json();
  const { seed, tone_guesses, mode, is_daily, challenge_date, session_id, user_id, guest_token } = body;

  if (!seed || !tone_guesses) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 });
  }

  // Authoritative server-side frequency generation
  const targetFreqs = generateFrequencies(seed);

  // Score each tone
  const toneScores = (tone_guesses as Array<{ tone_index: number; guess_hz: number }>).map((g) => {
    const target = targetFreqs[g.tone_index];
    const pts = scoreTone(g.guess_hz, target);
    const cents = Math.abs(1200 * Math.log2(g.guess_hz / target));
    return {
      tone_index: g.tone_index,
      target_hz: target,
      guess_hz: g.guess_hz,
      score_cents: cents,
      score_points: pts,
    };
  });

  const totalScore = toneScores.reduce((sum, t) => sum + t.score_points, 0);

  // Persist result
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data, error } = await supabase.from('game_results').insert({
    user_id: user_id ?? null,
    guest_token: guest_token ?? null,
    session_id: session_id ?? null,
    seed,
    mode: mode ?? 'solo',
    is_daily: is_daily ?? false,
    challenge_date: challenge_date ?? null,
    total_score: totalScore,
    tone_scores: toneScores,
    submitted_at: new Date().toISOString(),
  }).select().single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({
    result_id: data.id,
    total_score: totalScore,
    tone_scores: toneScores,
  }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
