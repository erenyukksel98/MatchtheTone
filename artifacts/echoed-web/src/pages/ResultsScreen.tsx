import { useEffect, useRef, useState } from 'react';
import { useGame } from '../lib/gameState';
import { TONE_COLORS, sliderToHz } from '../lib/tones';
import { scoreToneHz, totalPercent, gradeLabel, gradeColor, funnyMessage, deviationCents, toneScoreColor } from '../lib/scoring';
import { playTone } from '../lib/audio';

export default function ResultsScreen() {
  const { tones, sliders, goHome } = useGame();
  const guesses = sliders.map(sliderToHz);
  const pct = totalPercent(tones, guesses);
  const grade = gradeLabel(pct);
  const gColor = gradeColor(pct);

  const [displayPct, setDisplayPct] = useState(0);

  // Count-up animation
  useEffect(() => {
    let frame = 0;
    const total = 60;
    const tick = () => {
      frame++;
      setDisplayPct(Math.round((frame / total) * pct));
      if (frame < total) requestAnimationFrame(tick);
    };
    const id = setTimeout(() => requestAnimationFrame(tick), 400);
    return () => clearTimeout(id);
  }, [pct]);

  return (
    <div className="min-h-screen flex flex-col px-5 py-8" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div className="text-center mb-6 fade-up">
        <p className="text-xs font-semibold tracking-widest uppercase text-muted mb-3">Results</p>

        {/* Big score */}
        <div
          className="font-mono text-7xl font-bold mb-1"
          style={{ color: gColor, textShadow: `0 0 32px ${gColor}66` }}
        >
          {displayPct.toFixed(0)}%
        </div>

        {/* Grade badge */}
        <div
          className="inline-block px-5 py-1.5 rounded-full text-sm font-bold tracking-wider mb-3"
          style={{
            background: `${gColor}18`,
            border: `1.5px solid ${gColor}55`,
            color: gColor,
          }}
        >
          {grade}
        </div>

        {/* Funny message */}
        <p className="text-sm text-muted leading-relaxed px-4">{funnyMessage(pct)}</p>
      </div>

      {/* Per-tone breakdown */}
      <div className="flex flex-col gap-3 flex-1">
        {tones.map((target, i) => {
          const guess = guesses[i];
          const pts = scoreToneHz(guess, target);
          const diff = Math.abs(guess - target);
          const cents = deviationCents(guess, target);
          const color = TONE_COLORS[i];
          const scoreCol = toneScoreColor(pts);
          const isPerfect = diff <= 5;

          return (
            <ToneCard
              key={i}
              index={i}
              target={target}
              guess={guess}
              pts={pts}
              diff={diff}
              cents={cents}
              color={color}
              scoreCol={scoreCol}
              isPerfect={isPerfect}
              delay={i * 0.08}
            />
          );
        })}
      </div>

      {/* Buttons */}
      <div className="mt-6 flex flex-col gap-3 fade-up" style={{ animationDelay: '0.6s' }}>
        <button
          onClick={goHome}
          className="w-full py-4 rounded-2xl font-semibold text-base"
          style={{
            background: 'linear-gradient(135deg, rgba(0,245,255,0.15), rgba(0,245,255,0.05))',
            border: '1.5px solid rgba(0,245,255,0.5)',
            color: '#00F5FF',
          }}
        >
          Play Again
        </button>
      </div>
    </div>
  );
}

function ToneCard({
  index, target, guess, pts, diff, cents, color, scoreCol, isPerfect, delay
}: {
  index: number; target: number; guess: number; pts: number;
  diff: number; cents: number; color: string; scoreCol: string;
  isPerfect: boolean; delay: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Draw waveform comparison
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const W = canvas.width;
    const H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    const cycles = 3;
    const drawWave = (hz: number, stroke: string, alpha: number) => {
      ctx.beginPath();
      ctx.strokeStyle = stroke;
      ctx.globalAlpha = alpha;
      ctx.lineWidth = 2;
      for (let x = 0; x < W; x++) {
        const t = (x / W) * cycles * 2 * Math.PI;
        const y = H / 2 + (H / 2 - 4) * Math.sin(t * (hz / target));
        x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      }
      ctx.stroke();
      ctx.globalAlpha = 1;
    };

    drawWave(target, color, 0.8);
    drawWave(guess, '#ffffff', 0.5);
  }, [target, guess, color]);

  const handlePlay = () => {
    playTone(target, 1200, 0.4);
  };

  return (
    <div
      className="rounded-2xl p-4 fade-up"
      style={{
        animationDelay: `${delay + 0.2}s`,
        background: 'var(--surface)',
        border: `1.5px solid ${isPerfect ? color + '55' : 'var(--border)'}`,
      }}
    >
      <div className="flex items-start gap-3">
        {/* Badge */}
        <div
          className="w-8 h-8 rounded-full flex items-center justify-center font-mono font-bold text-sm shrink-0"
          style={{ background: `${color}20`, border: `1.5px solid ${color}66`, color }}
        >
          {index + 1}
        </div>

        <div className="flex-1 min-w-0">
          {/* Hz row */}
          <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 mb-1">
            <span className="font-mono font-bold text-sm" style={{ color }}>
              {target} Hz <span className="text-xs font-normal text-muted">target</span>
            </span>
            <span className="font-mono font-bold text-sm" style={{ color: 'var(--text)' }}>
              {guess} Hz <span className="text-xs font-normal text-muted">you</span>
            </span>
          </div>

          {/* Diff */}
          <p className="text-xs" style={{ color: isPerfect ? '#7BF696' : 'var(--text2)' }}>
            {isPerfect
              ? '✓ Perfect — within 5 Hz'
              : `${diff.toFixed(1)} Hz off  (${cents.toFixed(0)} cents)`}
          </p>
        </div>

        {/* Points + play */}
        <div className="flex flex-col items-end gap-1 shrink-0">
          <span className="font-mono font-bold text-lg" style={{ color: scoreCol }}>
            +{pts.toFixed(1)}
          </span>
          <button
            onClick={handlePlay}
            className="text-xs px-2 py-1 rounded-lg"
            style={{ background: `${color}18`, color, border: `1px solid ${color}33` }}
          >
            ▶
          </button>
        </div>
      </div>

      {/* Waveform canvas */}
      <canvas
        ref={canvasRef}
        width={320}
        height={48}
        className="w-full mt-3 rounded-lg"
        style={{ background: 'var(--surface2)' }}
      />
      <div className="flex items-center gap-4 mt-1.5">
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-0.5 rounded" style={{ background: color }} />
          <span className="text-xs text-muted">Target</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-0.5 rounded" style={{ background: '#fff', opacity: 0.5 }} />
          <span className="text-xs text-muted">Your guess</span>
        </div>
        <div className="ml-auto">
          <span className="text-xs font-semibold" style={{ color: scoreCol }}>
            {((pts / 20) * 100).toFixed(0)}% match
          </span>
        </div>
      </div>
    </div>
  );
}
