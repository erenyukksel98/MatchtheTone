import { useState } from 'react';
import { useGame } from '../lib/gameState';
import { generateRandomTones, generateDailyTones } from '../lib/tones';

export default function HomeScreen() {
  const { startSolo, startDaily } = useGame();
  const [loading, setLoading] = useState<'solo' | 'daily' | null>(null);

  const handleSolo = () => {
    setLoading('solo');
    const { tones, seed } = generateRandomTones();
    startSolo(tones, seed);
  };

  const handleDaily = () => {
    setLoading('daily');
    const { tones, seed } = generateDailyTones();
    startDaily(tones, seed);
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 py-12" style={{ background: 'var(--bg)' }}>
      {/* Logo / Title */}
      <div className="text-center mb-12 fade-up">
        <div className="relative inline-block mb-6">
          <svg width="72" height="72" viewBox="0 0 72 72" fill="none">
            {/* Concentric waveform rings */}
            {[28, 20, 13, 7].map((r, i) => (
              <circle
                key={r}
                cx="36" cy="36" r={r}
                stroke={i === 0 ? '#00F5FF' : i === 1 ? '#38bdf8' : i === 2 ? '#a78bfa' : '#FF00FF'}
                strokeWidth={i === 0 ? 2 : 1.5}
                fill="none"
                opacity={1 - i * 0.18}
              />
            ))}
            <circle cx="36" cy="36" r="4" fill="#00F5FF" />
          </svg>
          <div
            className="absolute inset-0 rounded-full"
            style={{ background: 'radial-gradient(circle, rgba(0,245,255,0.1) 0%, transparent 70%)' }}
          />
        </div>

        <h1
          className="font-mono text-5xl font-bold tracking-tight mb-2"
          style={{ color: '#00F5FF', textShadow: '0 0 24px rgba(0,245,255,0.5)' }}
        >
          ECHOED
        </h1>
        <p className="text-muted text-sm tracking-widest uppercase">Five tones. One shot. How sharp is your ear?</p>
      </div>

      {/* Buttons */}
      <div className="w-full max-w-xs flex flex-col gap-4 fade-up" style={{ animationDelay: '0.15s' }}>
        <button
          onClick={handleSolo}
          disabled={loading !== null}
          className="relative w-full py-4 rounded-2xl font-semibold text-base transition-all duration-200"
          style={{
            background: 'linear-gradient(135deg, rgba(0,245,255,0.15), rgba(0,245,255,0.05))',
            border: '1.5px solid rgba(0,245,255,0.5)',
            color: '#00F5FF',
            boxShadow: loading === 'solo' ? '0 0 24px rgba(0,245,255,0.4)' : '0 0 0px transparent',
          }}
        >
          {loading === 'solo' ? 'Generating tones…' : '🎵  Play Solo'}
        </button>

        <button
          onClick={handleDaily}
          disabled={loading !== null}
          className="relative w-full py-4 rounded-2xl font-semibold text-base transition-all duration-200"
          style={{
            background: 'linear-gradient(135deg, rgba(255,0,255,0.15), rgba(255,0,255,0.05))',
            border: '1.5px solid rgba(255,0,255,0.5)',
            color: '#FF00FF',
            boxShadow: loading === 'daily' ? '0 0 24px rgba(255,0,255,0.4)' : '0 0 0px transparent',
          }}
        >
          {loading === 'daily' ? 'Loading daily challenge…' : '📅  Daily Challenge'}
        </button>
      </div>

      {/* How to play */}
      <div
        className="mt-12 w-full max-w-xs rounded-2xl p-5 fade-up"
        style={{ background: 'var(--surface)', border: '1px solid var(--border)', animationDelay: '0.3s' }}
      >
        <p className="text-xs font-semibold tracking-widest uppercase text-muted mb-3">How to play</p>
        <ol className="text-sm text-muted space-y-2">
          <li><span className="text-cyan">01.</span> Listen to 5 pure sine tones</li>
          <li><span className="text-cyan">02.</span> Recreate each frequency with sliders</li>
          <li><span className="text-cyan">03.</span> ±5 Hz = perfect. ±50 Hz = zero</li>
        </ol>
      </div>

      <p className="mt-8 text-xs text-muted fade-up" style={{ animationDelay: '0.45s' }}>
        Best with headphones • 200–1800 Hz range
      </p>
    </div>
  );
}
