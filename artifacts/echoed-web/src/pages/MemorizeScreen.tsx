import { useEffect, useRef, useState, useCallback } from 'react';
import { useGame } from '../lib/gameState';
import { TONE_COLORS } from '../lib/tones';
import { playTone } from '../lib/audio';

const PLAY_DURATION = 1600; // ms

export default function MemorizeScreen() {
  const { tones, currentTone, setCurrentTone, goRecreate } = useGame();
  const [playingIndex, setPlayingIndex] = useState<number | null>(null);
  const [listenedSet, setListenedSet] = useState<Set<number>>(new Set());
  const stopRef = useRef<(() => void) | null>(null);

  const playIndex = useCallback((i: number) => {
    if (stopRef.current) { stopRef.current(); stopRef.current = null; }
    setPlayingIndex(i);
    setCurrentTone(i);
    setListenedSet(prev => new Set([...prev, i]));
    stopRef.current = playTone(tones[i], PLAY_DURATION, 0.45);
    setTimeout(() => {
      setPlayingIndex(null);
    }, PLAY_DURATION);
  }, [tones, setCurrentTone]);

  // Auto-play tone 0 on mount
  useEffect(() => {
    const t = setTimeout(() => playIndex(0), 500);
    return () => clearTimeout(t);
  }, []); // eslint-disable-line

  // Cleanup on unmount
  useEffect(() => {
    return () => { if (stopRef.current) stopRef.current(); };
  }, []);

  const allListened = listenedSet.size >= tones.length;

  return (
    <div className="min-h-screen flex flex-col px-5 py-8" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div className="mb-6 fade-up">
        <p className="text-xs font-semibold tracking-widest uppercase text-muted mb-1">Step 1 of 2</p>
        <h2 className="text-2xl font-bold" style={{ color: 'var(--text)' }}>Memorize the Tones</h2>
        <p className="text-sm text-muted mt-1">Tap each card to play — listen carefully!</p>
      </div>

      {/* Tone cards */}
      <div className="flex flex-col gap-3 flex-1">
        {tones.map((hz, i) => {
          const color = TONE_COLORS[i];
          const isPlaying = playingIndex === i;
          const listened = listenedSet.has(i);
          return (
            <button
              key={i}
              onClick={() => playIndex(i)}
              className="relative w-full rounded-2xl p-4 flex items-center gap-4 transition-all duration-200 fade-up"
              style={{
                animationDelay: `${i * 0.08}s`,
                background: isPlaying
                  ? `linear-gradient(135deg, ${color}22, ${color}08)`
                  : listened
                    ? `linear-gradient(135deg, ${color}10, ${color}04)`
                    : 'var(--surface)',
                border: `1.5px solid ${isPlaying ? color : listened ? color + '44' : 'var(--border)'}`,
                boxShadow: isPlaying ? `0 0 20px ${color}33` : 'none',
              }}
            >
              {/* Tone number badge */}
              <div
                className="flex items-center justify-center w-10 h-10 rounded-full font-mono font-bold text-sm shrink-0"
                style={{
                  background: `${color}20`,
                  border: `1.5px solid ${color}66`,
                  color,
                }}
              >
                {i + 1}
              </div>

              {/* Info */}
              <div className="text-left flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-sm" style={{ color }}>Tone {i + 1}</span>
                  {listened && (
                    <span className="text-xs text-muted">
                      {isPlaying ? 'playing…' : 'tap to replay'}
                    </span>
                  )}
                </div>
                {!listened && (
                  <span className="text-xs text-muted">Tap to play</span>
                )}
              </div>

              {/* Waveform animation */}
              <WaveformIcon color={color} active={isPlaying} />
            </button>
          );
        })}
      </div>

      {/* Progress / CTA */}
      <div className="mt-6 fade-up" style={{ animationDelay: '0.5s' }}>
        {!allListened && (
          <p className="text-center text-sm text-muted mb-3">
            Listen to all {tones.length} tones first ({listenedSet.size}/{tones.length})
          </p>
        )}
        <button
          onClick={goRecreate}
          disabled={!allListened}
          className="w-full py-4 rounded-2xl font-semibold text-base transition-all duration-200"
          style={{
            background: allListened
              ? 'linear-gradient(135deg, rgba(0,245,255,0.2), rgba(0,245,255,0.08))'
              : 'var(--surface)',
            border: `1.5px solid ${allListened ? 'rgba(0,245,255,0.6)' : 'var(--border)'}`,
            color: allListened ? '#00F5FF' : 'var(--text2)',
            boxShadow: allListened ? '0 0 18px rgba(0,245,255,0.2)' : 'none',
            cursor: allListened ? 'pointer' : 'not-allowed',
          }}
        >
          {allListened ? "I'm Ready — Recreate Them →" : `Listen to all tones first (${listenedSet.size}/${tones.length})`}
        </button>
      </div>
    </div>
  );
}

function WaveformIcon({ color, active }: { color: string; active: boolean }) {
  const bars = [3, 6, 10, 7, 4, 9, 5];
  return (
    <div className="flex items-end gap-[3px] h-8 shrink-0">
      {bars.map((h, i) => (
        <div
          key={i}
          className="w-[3px] rounded-full transition-all"
          style={{
            height: active ? `${h + Math.sin(Date.now() / 200 + i) * 3}px` : `${h * 0.6}px`,
            background: color,
            opacity: active ? 0.9 : 0.35,
            transition: 'height 0.1s ease, opacity 0.3s ease',
          }}
        />
      ))}
    </div>
  );
}
